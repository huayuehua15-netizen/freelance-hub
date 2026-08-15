import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// 本地通知服务：订阅到期提醒等。
/// 用 flutter_local_notifications（已在依赖，Android 13+ 需运行时请求通知权限）。
class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const String _channelId = 'subscription_reminder';
  static const String _channelName = 'Subscription Reminders';
  static const String _timerChannelId = 'timer';
  static const String _timerChannelName = 'Timer';
  static const int _timerNotificationId = 1000;

  static Future<void> init() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinInit = DarwinInitializationSettings();
    const initSettings = InitializationSettings(
      android: androidInit,
      iOS: darwinInit,
    );
    await _plugin.initialize(initSettings);
  }

  static Future<void> requestPermission() async {
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  static Future<void> show({
    required int id,
    required String title,
    required String body,
  }) async {
    const channel = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: 'Alerts about your subscription status',
      importance: Importance.high,
      priority: Priority.high,
    );
    const details = NotificationDetails(
      android: channel,
      iOS: DarwinNotificationDetails(),
    );
    await _plugin.show(id, title, body, details);
  }

  /// 计时器运行中的常驻通知（不可滑动清除）。
  static Future<void> showTimerRunning({String body = ''}) async {
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        _timerChannelId,
        _timerChannelName,
        channelDescription: 'Ongoing timer status',
        importance: Importance.low,
        priority: Priority.low,
        ongoing: true,
        autoCancel: false,
        showWhen: false,
      ),
      iOS: DarwinNotificationDetails(),
    );
    await _plugin.show(
      _timerNotificationId,
      'Timer running',
      body.isEmpty ? 'Tracking your work time' : body,
      details,
    );
  }

  /// 计时器暂停通知。
  static Future<void> showTimerPaused() async {
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        _timerChannelId,
        _timerChannelName,
        channelDescription: 'Ongoing timer status',
        importance: Importance.low,
        priority: Priority.low,
        ongoing: true,
        autoCancel: false,
        showWhen: false,
      ),
      iOS: DarwinNotificationDetails(),
    );
    await _plugin.show(
      _timerNotificationId,
      'Timer paused',
      'Resume or stop to save your session',
      details,
    );
  }

  /// 取消计时器通知（结束/取消计时时调用）。
  static Future<void> cancelTimer() async {
    await _plugin.cancel(_timerNotificationId);
  }
}
