import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants.dart';

class NotificationService {
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> init() async {
    // Request permission for notifications
    NotificationSettings settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      // Get FCM token
      String? token = await _fcm.getToken();
      if (token != null) {
        await _saveTokenToDatabase(token);
      }

      // Listen for token refresh
      FirebaseMessaging.instance.onTokenRefresh.listen(_saveTokenToDatabase);

      // Handle foreground messages
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        // Handle foreground notification
        print('Received foreground message: ${message.notification?.title}');
      });

      // Handle background/terminated messages
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        // Handle background notification tap
        print('Notification opened app: ${message.notification?.title}');
      });
    }
  }

  Future<void> _saveTokenToDatabase(String token) async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await _firestore
            .collection('artifacts')
            .doc(appId)
            .collection('users')
            .doc(user.uid)
            .collection('profile')
            .doc('data')
            .set({
              'fcmToken': token,
              'updatedAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));
      }
    } catch (e) {
      // Handle the case where profile document might not exist
      if (e.toString().contains('not-found')) {
        User? user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          await _firestore
              .collection('artifacts')
              .doc(appId)
              .collection('users')
              .doc(user.uid)
              .collection('profile')
              .doc('data')
              .set({
                'fcmToken': token,
                'createdAt': FieldValue.serverTimestamp(),
              });
        }
      }
    }
  }
}
