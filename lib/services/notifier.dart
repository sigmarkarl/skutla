import 'notifier_io.dart' if (dart.library.html) 'notifier_web.dart' as impl;

class Notifier {
  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    await impl.init();
  }

  static Future<void> notify({
    required String title,
    required String body,
    int id = 0,
  }) =>
      impl.notify(title: title, body: body, id: id);
}
