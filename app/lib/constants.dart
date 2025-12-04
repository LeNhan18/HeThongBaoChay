// import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

const String apiBaseUrl = 'http://localhost:8000';
const String API_BASE_URL = 'http://localhost:8000';

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
