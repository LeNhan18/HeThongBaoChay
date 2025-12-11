import 'package:flutter/foundation.dart';
import 'dart:io' show Platform;

class ApiConfig {
  /// Get the appropriate API base URL based on platform
  static String getApiBaseUrl() {
    if (kIsWeb) {
      // Web: use localhost
      return 'http://localhost:8000';
    } else if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      // Desktop: use localhost
      return 'http://localhost:8000';
    } else if (Platform.isAndroid) {
      // Android real device: use PC's IP address
      return 'http://192.168.2.29:8000'; // For real device
      // return 'http://10.0.2.2:8000'; // Use this for emulator
    } else if (Platform.isIOS) {
      // iOS Simulator: use localhost
      return 'http://localhost:8000';
    }

    // Fallback
    return 'http://localhost:8000';
  }

  /// Get list of hosts to try in order of preference
  static List<String> getHostsToTry() {
    if (kIsWeb) {
      return ['http://localhost:8000', 'http://127.0.0.1:8000'];
    } else if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      return ['http://localhost:8000', 'http://127.0.0.1:8000'];
    } else if (Platform.isAndroid) {
      return [
        'http://192.168.2.29:8000', // Your machine IP - primary
        'http://10.0.2.2:8000', // Android emulator fallback
        'http://localhost:8000', // Fallback
        'http://127.0.0.1:8000', // Fallback
      ];
    } else if (Platform.isIOS) {
      return ['http://localhost:8000', 'http://127.0.0.1:8000'];
    }

    return ['http://localhost:8000'];
  }
}
