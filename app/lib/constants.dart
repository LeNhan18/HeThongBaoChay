// import 'package:firebase_core/firebase_core.dart';

const String apiBaseUrl = 'http://10.0.2.2:8000';

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
