import 'package:mqtt_client/mqtt_client.dart';

import 'mqtt_client_factory_io.dart'
    if (dart.library.html) 'mqtt_client_factory_web.dart';

MqttClient createMqttClient({
  required String host,
  required int port,
  required String path,
  required String clientId,
}) => createPlatformMqttClient(
  host: host,
  port: port,
  path: path,
  clientId: clientId,
);
