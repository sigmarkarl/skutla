import 'package:flutter_local_notifications/flutter_local_notifications.dart';

final FlutterLocalNotificationsPlugin _plugin =
    FlutterLocalNotificationsPlugin();

Future<void> init() async {
  const settings = InitializationSettings(
    android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    iOS: DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: false,
      requestSoundPermission: true,
    ),
    macOS: DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: false,
      requestSoundPermission: true,
    ),
  );
  await _plugin.initialize(settings: settings);

  await _plugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.requestNotificationsPermission();
}

Future<void> notify({
  required String title,
  required String body,
  int id = 0,
}) async {
  const details = NotificationDetails(
    android: AndroidNotificationDetails(
      'skutla_default',
      'Skutla',
      channelDescription: 'Ride requests and offers',
      importance: Importance.high,
      priority: Priority.high,
    ),
    iOS: DarwinNotificationDetails(),
    macOS: DarwinNotificationDetails(),
  );
  await _plugin.show(
    id: id,
    title: title,
    body: body,
    notificationDetails: details,
  );
}
