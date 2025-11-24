import 'package:flutter/material.dart';
// import 'package:firebase_core/firebase_core.dart';
import 'constants.dart';
import 'services/notification_service.dart';
import 'screens/wrapper.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // await Firebase.initializeApp(options: firebaseOptions);
  await NotificationService().init();

  runApp(const FireAlertApp());
}



class FireAlertApp extends StatelessWidget {
  const FireAlertApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Hệ Thống Báo Cháy',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.deepOrange, useMaterial3: true),
      home: const Wrapper(),
    );
  }
}
