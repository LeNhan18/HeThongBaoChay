import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'services/notification_service.dart';
import 'services/alert_service.dart';
import 'screens/wrapper.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Fix cho màn hình đen trên emulator
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  // Set preferred orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Chạy app trước, khởi tạo services sau (không block UI)
  debugPrint(' Starting FireAlertApp...');
  runApp(const FireAlertApp());
  debugPrint(' FireAlertApp started');
  // Initialize services sau khi app đã chạy (không block)
  _initializeServicesAsync();
}

class FireAlertApp extends StatelessWidget {
  const FireAlertApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Hệ Thống Báo Cháy',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Color(0xFF667eea),
          brightness: Brightness.light,
        ),
        cardTheme: CardTheme(
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
        ),
        appBarTheme: AppBarTheme(
          centerTitle: true,
          elevation: 0,
          titleTextStyle: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
      home: const Wrapper(),
      // Error handling để tránh màn trắng khi có lỗi
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(1.0)),
          child: child ?? const SizedBox(),
        );
      },
    );
  }
}

// Initialize services async để không block UI
Future<void> _initializeServicesAsync() async {
  // Delay một chút để app render xong
  await Future.delayed(Duration(milliseconds: 500));
  
  // Initialize Firebase với error handling riêng
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint(' Firebase initialized successfully');
  } catch (e) {
    debugPrint(' Firebase initialization error: $e');
    debugPrint(' App will continue without Firebase features');
  }

  // Initialize notification service (có thể hoạt động không cần Firebase)
  try {
    await NotificationService().init();
    debugPrint(' Notification service initialized');
  } catch (e) {
    debugPrint(' Notification service init error: $e');
    debugPrint(' App will continue without notifications');
  }

  // Register FCM token với backend (có error handling riêng trong service)
  try {
    await AlertService().registerFCMToken();
    debugPrint(' FCM token registration attempted');
  } catch (e) {
    debugPrint(' FCM token registration error: $e');
  }

  // Auto-start polling để nhận alerts từ ESP32 (không block)
  // Delay một chút để đảm bảo app đã khởi động hoàn toàn
  Future.delayed(Duration(seconds: 2), () {
    try {
      AlertService().startLiveAlertPolling();
      debugPrint(' Alert polling started automatically');
    } catch (e) {
      debugPrint('Alert polling start error: $e');
    }
  });
}
