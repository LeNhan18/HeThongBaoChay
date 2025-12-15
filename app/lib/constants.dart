// import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

// 🔧 HƯỚNG DẪN CẤU HÌNH SERVER AI:
// 1. Khởi động server AI (python main.py hoặc uvicorn main:app --host 0.0.0.0 --port 8000)
// 2. Tìm IP của máy chạy server: ipconfig (Windows) hoặc ifconfig (Mac/Linux)
// 3. Bỏ comment và cập nhật IP address phù hợp bên dưới:

// 🤖 Auto-detect best host based on platform
const String apiBaseUrl = 'http://192.168.2.29:8000'; // Server IP
const String API_BASE_URL = 'http://172.20.10.4:8000'; // Backend API endpoints
const String ESP32_CONNECT_ENDPOINT = '/esp32/connect';
const String ESP32_CAPTURE_ENDPOINT = '/esp32/capture';
const String ESP32_STREAM_ENDPOINT = '/esp32/stream';

// App Colors
const Color kPrimaryColor = Colors.deepOrange;
const Color kSecondaryColor = Colors.orange;
const Color kBackgroundColor = Color(0xFFF5F5F5);
const Color kSurfaceColor = Colors.white;
const Color kErrorColor = Colors.red;
const Color kSuccessColor = Colors.green;

// Detection Colors
const Color kFireColor = Colors.red;
const Color kSmokeColor = Colors.grey;

const String firebaseConfigEnv = String.fromEnvironment('__firebase_config');
const String appIdEnv = String.fromEnvironment('__app_id');

// final FirebaseOptions firebaseOptions = FirebaseOptions(
//   apiKey: const String.fromEnvironment('__firebase_config.apiKey'),
//   authDomain: const String.fromEnvironment('__firebase_config.authDomain'),
//   projectId: const String.fromEnvironment('__firebase_config.projectId'),
//   storageBucket: const String.fromEnvironment(
//     '__firebase_config.storageBucket',
//   ),
//   messagingSenderId: const String.fromEnvironment(
//     '__firebase_config.messagingSenderId',
//   ),
//   appId: appIdEnv,
// );

const String appId = appIdEnv;
