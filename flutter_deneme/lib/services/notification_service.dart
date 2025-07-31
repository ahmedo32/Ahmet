import 'package:flutter_local_notifications/flutter_local_notifications.dart';


class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();

  /// Call this once in main()
  static Future<void> init() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings();
    await _plugin.initialize(const InitializationSettings(
      android: android,
      iOS: ios,
    ));
  }

  /// Show a simple notification
  static Future<void> show({
    required int id,
    required String title,
    required String body,
  }) =>
      _plugin.show(
        id,
        title,
        body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'conditional_channel',
            'Conditional Alerts',
            channelDescription: 'Alerts for OCR failure conditions',
            importance: Importance.max,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
      );
}
