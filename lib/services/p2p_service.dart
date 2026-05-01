import 'dart:async';

import 'package:mqtt_client/mqtt_client.dart';

import '../models/messages.dart';
import 'geohash.dart';
import 'mqtt_client_factory.dart';

class P2PConfig {
  const P2PConfig({
    this.host = 'broker.hivemq.com',
    this.port = 8884,
    this.path = '/mqtt',
    this.topicRoot = 'skutla/v1',
    this.geohashPrecision = 5,
  });

  final String host;
  final int port;
  final String path;
  final String topicRoot;
  final int geohashPrecision;
}

class P2PService {
  P2PService({required this.peerId, this.config = const P2PConfig()});

  final String peerId;
  final P2PConfig config;

  MqttClient? _client;
  bool _connected = false;

  final _connectionState = StreamController<bool>.broadcast();
  final _drivers = StreamController<DriverPresence>.broadcast();
  final _inbox = StreamController<InboxMessage>.broadcast();
  final _rideRequests = StreamController<InboxMessage>.broadcast();

  Stream<bool> get connectionState => _connectionState.stream;
  Stream<DriverPresence> get driverUpdates => _drivers.stream;
  Stream<InboxMessage> get inbox => _inbox.stream;
  Stream<InboxMessage> get rideRequests => _rideRequests.stream;
  bool get isConnected => _connected;

  void _setConnected(bool v) {
    _connected = v;
    _connectionState.add(v);
  }

  String? _driverCurrentCell;
  Set<String> _passengerCells = const {};
  Set<String> _driverRequestCells = const {};
  final Map<String, MqttQos> _subscriptions = {};

  String _driverCellTopic(String cell, String id) =>
      '${config.topicRoot}/drivers/geo/$cell/$id';
  String _driverCellWildcard(String cell) =>
      '${config.topicRoot}/drivers/geo/$cell/+';
  String _inboxTopic(String id) => '${config.topicRoot}/inbox/$id';
  String _requestsCellTopic(String cell) =>
      '${config.topicRoot}/requests/geo/$cell';

  Future<void> connect() async {
    if (_client != null) return;
    final client = createMqttClient(
      host: config.host,
      port: config.port,
      path: config.path,
      clientId: 'skutla-$peerId',
    );
    client.setProtocolV311();

    client.onConnected = () => _setConnected(true);
    client.onDisconnected = () => _setConnected(false);
    client.onAutoReconnect = () {};
    client.onAutoReconnected = _replaySubscriptions;
    client.autoReconnect = true;

    client.connectionMessage = MqttConnectMessage()
        .withClientIdentifier('skutla-$peerId')
        .startClean();

    _client = client;
    try {
      await client.connect();
    } catch (e) {
      _setConnected(false);
      rethrow;
    }
    final state = client.connectionStatus?.state;
    if (state == MqttConnectionState.connected) {
      _setConnected(true);
    }
    client.updates?.listen(_onMessages);
  }

  void _onMessages(List<MqttReceivedMessage<MqttMessage>> events) {
    for (final event in events) {
      final recMsg = event.payload as MqttPublishMessage;
      final raw = MqttPublishPayload.bytesToStringAsString(
        recMsg.payload.message,
      );
      final topic = event.topic;
      if (topic.startsWith('${config.topicRoot}/drivers/geo/')) {
        if (raw.isEmpty) continue;
        final p = DriverPresence.tryDecode(raw);
        if (p != null) _drivers.add(p);
      } else if (topic == _inboxTopic(peerId)) {
        final m = InboxMessage.tryDecode(raw);
        if (m != null) _inbox.add(m);
      } else if (topic.startsWith('${config.topicRoot}/requests/geo/')) {
        if (raw.isEmpty) continue;
        final m = InboxMessage.tryDecode(raw);
        if (m != null) _rideRequests.add(m);
      }
    }
  }

  void _track(String topic, MqttQos qos) {
    _subscriptions[topic] = qos;
    _client?.subscribe(topic, qos);
  }

  void _untrack(String topic) {
    _subscriptions.remove(topic);
    _client?.unsubscribe(topic);
  }

  void _replaySubscriptions() {
    final entries = _subscriptions.entries.toList();
    for (final e in entries) {
      _client?.subscribe(e.key, e.value);
    }
  }

  void subscribeToOwnInbox() {
    _track(_inboxTopic(peerId), MqttQos.atLeastOnce);
  }

  void updateDriverPresence(DriverPresence presence) {
    final newCell = encodeGeohash(
      presence.lat,
      presence.lng,
      precision: config.geohashPrecision,
    );
    final oldCell = _driverCurrentCell;
    if (oldCell != null && oldCell != newCell) {
      _publishEmpty(_driverCellTopic(oldCell, presence.driverId));
    }
    _driverCurrentCell = newCell;
    _publishRetained(
      _driverCellTopic(newCell, presence.driverId),
      presence.encode(),
    );
  }

  void clearDriverPresence(String driverId) {
    final cell = _driverCurrentCell;
    if (cell == null) return;
    _publishEmpty(_driverCellTopic(cell, driverId));
    _driverCurrentCell = null;
  }

  void updatePassengerSearchArea(double lat, double lng) {
    final newCells = geohashSearchCells(
      lat,
      lng,
      precision: config.geohashPrecision,
    );
    final toAdd = newCells.difference(_passengerCells);
    final toRemove = _passengerCells.difference(newCells);
    for (final cell in toAdd) {
      _track(_driverCellWildcard(cell), MqttQos.atMostOnce);
    }
    for (final cell in toRemove) {
      _untrack(_driverCellWildcard(cell));
    }
    _passengerCells = newCells;
  }

  void updateDriverRequestArea(double lat, double lng) {
    final newCells = geohashSearchCells(
      lat,
      lng,
      precision: config.geohashPrecision,
    );
    final toAdd = newCells.difference(_driverRequestCells);
    final toRemove = _driverRequestCells.difference(newCells);
    for (final cell in toAdd) {
      _track(_requestsCellTopic(cell), MqttQos.atLeastOnce);
    }
    for (final cell in toRemove) {
      _untrack(_requestsCellTopic(cell));
    }
    _driverRequestCells = newCells;
  }

  void broadcastRideRequest(InboxMessage message, String cell) {
    if (!_connected) return;
    final builder = MqttClientPayloadBuilder()..addString(message.encode());
    _client?.publishMessage(
      _requestsCellTopic(cell),
      MqttQos.atLeastOnce,
      builder.payload!,
    );
  }

  void sendInbox(InboxMessage message) {
    if (!_connected) return;
    final builder = MqttClientPayloadBuilder()..addString(message.encode());
    _client?.publishMessage(
      _inboxTopic(message.toId),
      MqttQos.atLeastOnce,
      builder.payload!,
    );
  }

  void _publishRetained(String topic, String body) {
    if (!_connected) return;
    final builder = MqttClientPayloadBuilder()..addString(body);
    _client?.publishMessage(
      topic,
      MqttQos.atLeastOnce,
      builder.payload!,
      retain: true,
    );
  }

  void _publishEmpty(String topic) {
    if (!_connected) return;
    final builder = MqttClientPayloadBuilder();
    _client?.publishMessage(
      topic,
      MqttQos.atLeastOnce,
      builder.payload!,
      retain: true,
    );
  }

  Future<void> disconnect() async {
    _client?.disconnect();
    _client = null;
  }

  void dispose() {
    _client?.disconnect();
    _connectionState.close();
    _drivers.close();
    _inbox.close();
    _rideRequests.close();
  }
}
