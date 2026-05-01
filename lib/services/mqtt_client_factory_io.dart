import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

MqttClient createPlatformMqttClient({
  required String host,
  required int port,
  required String path,
  required String clientId,
}) {
  final scheme = port == 8884 ? 'wss' : 'ws';
  final client = MqttServerClient.withPort('$scheme://$host$path', clientId, port);
  client.useWebSocket = true;
  client.websocketProtocols = MqttClientConstants.protocolsMultipleDefault;
  client.keepAlivePeriod = 30;
  client.connectTimeoutPeriod = 15000;
  client.logging(on: false);
  return client;
}
