import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  // callback بيتنادى لما المستخدم يضغط على الإشعار
  static void Function(String payload)? onNotificationTap;

  static Future<void> init() async {
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings settings =
        InitializationSettings(android: androidSettings);

    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        // لما المستخدم يضغط على الإشعار والتطبيق شغال
        final payload = response.payload ?? '';
        onNotificationTap?.call(payload);
      },
    );

    // لو التطبيق كان مقفول والمستخدم فتحه من الإشعار
    final NotificationAppLaunchDetails? launchDetails =
        await _plugin.getNotificationAppLaunchDetails();
    if (launchDetails?.didNotificationLaunchApp == true) {
      final payload = launchDetails?.notificationResponse?.payload ?? '';
      if (payload.isNotEmpty) {
        // نأخر شوية عشان الـ app يتبني الأول
        Future.delayed(const Duration(milliseconds: 500), () {
          onNotificationTap?.call(payload);
        });
      }
    }

    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  static Future<void> showTimerAlert(String deviceName, int minutes) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'timer_alerts',
      'تنبيهات التايمر',
      channelDescription: 'إشعارات انتهاء وقت الجهاز',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      icon: '@mipmap/ic_launcher',
    );

    const NotificationDetails details =
        NotificationDetails(android: androidDetails);

    await _plugin.show(
      deviceName.hashCode,
      '⏰ انتهى الوقت!',
      'الجهاز "$deviceName" وصل لـ $minutes دقيقة',
      details,
      payload: 'timer',
    );
  }

  static Future<void> showCustomerOrderAlert(
      String deviceName, String orderText) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'customer_orders',
      'طلبات العملاء',
      channelDescription: 'إشعارات الطلبات الواردة من العملاء',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      icon: '@mipmap/ic_launcher',
      color: Color(0xFF38bdf8),
    );

    const NotificationDetails details =
        NotificationDetails(android: androidDetails);

    final short = orderText.length > 60
        ? '${orderText.substring(0, 60)}...'
        : orderText;

    await _plugin.show(
      'order_$deviceName'.hashCode,
      '🛎️ طلب جديد من $deviceName',
      short,
      details,
      payload: 'orders',
    );
  }
}
