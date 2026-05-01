import 'package:mqtt_client/mqtt_browser_client.dart';
import 'package:mqtt_client/mqtt_client.dart';

MqttClient createPlatformMqttClient({
  required String host,
  required int port,
  required String path,
  required String clientId,
}) {
  final scheme = port == 8884 ? 'wss' : 'ws';
  final url = '$scheme://$host:$port$path';
  final client = MqttBrowserClient.withPort(url, clientId, port);
  client.websocketProtocols = MqttClientConstants.protocolsMultipleDefault;
  client.keepAlivePeriod = 30;
  client.logging(on: false);
  return client;
}
