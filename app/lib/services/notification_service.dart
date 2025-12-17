import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'dart:developer' as dev;
import 'alert_service.dart';

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

    // Tạo notification channel với sound và vibration cho Android
    await _createNotificationChannel();

    // Initialize Firebase FCM (FREE)
    await _initFirebaseMessaging();
  }

  Future<void> _createNotificationChannel() async {
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'fire_alert_channel',
      'Fire Alerts',
      description: 'Notifications for fire and smoke detection alerts',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
    );

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
    
    dev.log(' Notification channel created: fire_alert_channel');
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
        dev.log(' Firebase notifications permission granted');

        // Get FCM token
        String? token = await _firebaseMessaging.getToken();
        dev.log(' FCM Token: $token');

        // Configure foreground message handler
        FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

        // Configure background message handler
        FirebaseMessaging.onBackgroundMessage(_handleBackgroundMessage);

        // Handle notification tap when app is terminated
        FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);
      } else {
        dev.log(' Firebase notifications permission denied');
      }
    } catch (e) {
      dev.log(' Firebase FCM init error: $e');
      dev.log(' Continuing with local notifications only');
      // Continue with local notifications only
    }
  }

  Future<void> showNotification({
    required String title,
    required String body,
    bool isFireAlert = false,
  }) async {
    // Tạo notification ID unique dựa trên timestamp
    final notificationId = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
          'fire_alert_channel',
          'Fire Alerts',
          channelDescription: 'Notifications for fire detection',
          importance: Importance.max,
          priority: Priority.high,
          showWhen: true,
          enableVibration: true,
          playSound: true,
          // Thêm icon và màu sắc cho fire alert
          icon: '@mipmap/ic_launcher',
          color: Color(0xFFFF5722), // Màu đỏ cam cho cảnh báo lửa
        );
    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
    );

    await flutterLocalNotificationsPlugin.show(
      notificationId,
      title,
      body,
      platformChannelSpecifics,
    );
    
    dev.log(' Notification shown: $title');
  }

  // Firebase message handlers
  void _handleForegroundMessage(RemoteMessage message) {
    dev.log(' Foreground FCM: ${message.notification?.title}');

    // Show local notification when app is in foreground
    if (message.notification != null) {
      showNotification(
        title: message.notification!.title ?? 'Cảnh báo lửa',
        body: message.notification!.body ?? 'Phát hiện lửa trong khu vực',
      );

      // Save FCM alert to local storage
      _saveFCMAlert(message);
    }
  }

  void _saveFCMAlert(RemoteMessage message) {
    try {
      final data = message.data;
      if (data['type'] == 'fire_alert') {
        // Save to AlertService
        final alertData = {
          'id': '${DateTime.now().millisecondsSinceEpoch}',
          'camera_name': 'ESP32-CAM (${data['esp32_ip'] ?? 'Unknown'})',
          'type': 'FCM_FIRE_DETECTED',
          'timestamp': data['timestamp'] ?? DateTime.now().toIso8601String(),
          'source': 'FCM Push Notification',
          'esp32_ip': data['esp32_ip'] ?? '',
          'fire_count': int.tryParse(data['fire_count'] ?? '0') ?? 0,
          'smoke_count': int.tryParse(data['smoke_count'] ?? '0') ?? 0,
          'confidence':
              double.tryParse(data['confidence']?.replaceAll('%', '') ?? '0') ??
              0,
          'alert_level': 'HIGH',
          'message': message.notification?.body ?? 'Phát hiện lửa từ FCM',
          'detections': [],
        };

        AlertService().addFCMAlert(alertData);
        dev.log(' FCM alert saved to local storage');
      }
    } catch (e) {
      dev.log(' Error saving FCM alert: $e');
    }
  }

  void _handleNotificationTap(RemoteMessage message) {
    dev.log(' Notification tapped: ${message.notification?.title}');
    // Handle navigation when notification is tapped
  }

  // Get FCM token for sending targeted notifications
  Future<String?> getFCMToken() async {
    try {
      return await _firebaseMessaging.getToken();
    } catch (e) {
      dev.log(' Error getting FCM token: $e');
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
      title: ' CẢNH BÁO LỬA!',
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
      title: ' CẢNH BÁO KHÓI!',
      body:
          'Phát hiện khói tại $location\nĐộ tin cậy: ${(confidence * 100).toStringAsFixed(1)}%',
    );
  }
}

// Background message handler (must be top-level function)
@pragma('vm:entry-point')
Future<void> _handleBackgroundMessage(RemoteMessage message) async {
  dev.log(' Background message: ${message.notification?.title}');
}
