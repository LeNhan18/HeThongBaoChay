import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'dart:developer' as dev;

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;

  factory NotificationService() {
    return _instance;
  }

  NotificationService._internal();

  Future<void> init() async {
    // Initialize local notifications
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);

    await flutterLocalNotificationsPlugin.initialize(initializationSettings);

    // Initialize Firebase FCM (FREE)
    await _initFirebaseMessaging();
  }

  Future<void> _initFirebaseMessaging() async {
    try {
      // Request permission for notifications
      NotificationSettings settings = await _firebaseMessaging
          .requestPermission(
            alert: true,
            badge: true,
            sound: true,
            provisional: false,
          );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        dev.log('🔔 Firebase notifications permission granted');

        // Get FCM token
        String? token = await _firebaseMessaging.getToken();
        dev.log('🔑 FCM Token: $token');

        // Configure foreground message handler
        FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

        // Configure background message handler
        FirebaseMessaging.onBackgroundMessage(_handleBackgroundMessage);

        // Handle notification tap when app is terminated
        FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);
      } else {
        dev.log('❌ Firebase notifications permission denied');
      }
    } catch (e) {
      dev.log('❌ Firebase FCM init error: $e');
    }
  }

  Future<void> showNotification({
    required String title,
    required String body,
  }) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
          'fire_alert_channel',
          'Fire Alerts',
          channelDescription: 'Notifications for fire detection',
          importance: Importance.max,
          priority: Priority.high,
          showWhen: true,
        );
    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
    );

    await flutterLocalNotificationsPlugin.show(
      DateTime.now().millisecond, // Unique ID
      title,
      body,
      platformChannelSpecifics,
    );
  }

  // Firebase message handlers
  void _handleForegroundMessage(RemoteMessage message) {
    dev.log('🔔 Foreground message: ${message.notification?.title}');

    // Show local notification when app is in foreground
    if (message.notification != null) {
      showNotification(
        title: message.notification!.title ?? 'Cảnh báo lửa',
        body: message.notification!.body ?? 'Phát hiện lửa trong khu vực',
      );
    }
  }

  void _handleNotificationTap(RemoteMessage message) {
    dev.log('🔔 Notification tapped: ${message.notification?.title}');
    // Handle navigation when notification is tapped
  }

  // Get FCM token for sending targeted notifications
  Future<String?> getFCMToken() async {
    try {
      return await _firebaseMessaging.getToken();
    } catch (e) {
      dev.log('❌ Error getting FCM token: $e');
      return null;
    }
  }

  // Send fire detection alert (can be called from backend)
  Future<void> sendFireAlert({
    required String location,
    required double confidence,
    String? imageUrl,
  }) async {
    await showNotification(
      title: '🚨 CẢNH BÁO LỬA!',
      body:
          'Phát hiện lửa tại $location\nĐộ tin cậy: ${(confidence * 100).toStringAsFixed(1)}%',
    );
  }

  // Send smoke detection alert
  Future<void> sendSmokeAlert({
    required String location,
    required double confidence,
    String? imageUrl,
  }) async {
    await showNotification(
      title: '💨 CẢNH BÁO KHÓI!',
      body:
          'Phát hiện khói tại $location\nĐộ tin cậy: ${(confidence * 100).toStringAsFixed(1)}%',
    );
  }
}

// Background message handler (must be top-level function)
@pragma('vm:entry-point')
Future<void> _handleBackgroundMessage(RemoteMessage message) async {
  dev.log('🔔 Background message: ${message.notification?.title}');
}
