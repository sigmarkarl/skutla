import 'dart:js_interop';

import 'package:web/web.dart' as web;

Future<void> init() async {
  if (web.Notification.permission == 'default') {
    await web.Notification.requestPermission().toDart;
  }
}

Future<void> notify({
  required String title,
  required String body,
  int id = 0,
}) async {
  if (web.Notification.permission != 'granted') return;
  if (web.document.visibilityState == 'visible') return;
  web.Notification(title, web.NotificationOptions(body: body));
}
