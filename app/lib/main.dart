import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'services/notification_service.dart';
import 'services/alert_service.dart';
import 'screens/wrapper.dart';
import 'package:google_fonts/google_fonts.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Fix cho màn hình đen trên emulator
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  // Set preferred orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Initialize Firebase với error handling riêng
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print(' Firebase initialized successfully');
  } catch (e) {
    print(' Firebase initialization error: $e');
    print(' App will continue without Firebase features');
  }

  // Initialize notification service (có thể hoạt động không cần Firebase)
  try {
    await NotificationService().init();
    print(' Notification service initialized');
  } catch (e) {
    print(' Notification service init error: $e');
    print(' App will continue without notifications');
  }

  // Register FCM token với backend (có error handling riêng trong service)
  try {
    await AlertService().registerFCMToken();
    print(' FCM token registration attempted');
  } catch (e) {
    print(' FCM token registration error: $e');
  }

  // Auto-start polling để nhận alerts từ ESP32 (không block)
  // Delay một chút để đảm bảo app đã khởi động hoàn toàn
  Future.delayed(Duration(seconds: 2), () {
    try {
      AlertService().startLiveAlertPolling();
      print(' Alert polling started automatically');
    } catch (e) {
      print('Alert polling start error: $e');
    }
  });

  runApp(const FireAlertApp());
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
        textTheme: GoogleFonts.interTextTheme(),
        fontFamily: GoogleFonts.inter().fontFamily,
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
          titleTextStyle: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
      home: const Wrapper(),
    );
  }
}
