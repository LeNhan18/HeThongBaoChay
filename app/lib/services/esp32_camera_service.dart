import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

class ESP32CameraService {
  static const Duration _timeout = Duration(seconds: 10);

  /// Test connection to ESP32-CAM device
  Future<Map<String, dynamic>> connectToESP32(String esp32Ip) async {
    try {
      final response = await http
          .post(
            Uri.parse(
              '${ApiConfig.getApiBaseUrl()}/esp32/connect?esp32_ip=$esp32Ip',
            ),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(_timeout);

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      throw Exception('Kết nối thất bại: $e');
    }
  }

  /// Capture image from ESP32-CAM and analyze for fire/smoke detection
  Future<Map<String, dynamic>> captureAndAnalyze(
    String esp32Ip, {
    double confidence = 0.25,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse(
              '${ApiConfig.getApiBaseUrl()}/esp32/capture?esp32_ip=$esp32Ip&confidence=$confidence',
            ),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(_timeout);

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      throw Exception('Chụp ảnh thất bại: $e');
    }
  }

  /// Capture image from ESP32-CAM with bounding boxes
  Future<Uint8List> captureWithBoundingBoxes(
    String esp32Ip, {
    double confidence = 0.25,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse(
              '${ApiConfig.getApiBaseUrl()}/esp32/capture_with_boxes?esp32_ip=$esp32Ip&confidence=$confidence',
            ),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(_timeout);

      if (response.statusCode == 200) {
        return response.bodyBytes;
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      throw Exception('Chụp ảnh với khung thất bại: $e');
    }
  }

  /// Get stream URL for ESP32-CAM
  String getStreamUrl(String esp32Ip, {double confidence = 0.25}) {
    return '${ApiConfig.getApiBaseUrl()}/esp32/stream?esp32_ip=$esp32Ip&confidence=$confidence';
  }

  /// Test API connection
  Future<Map<String, dynamic>> testConnection() async {
    try {
      final response = await http
          .get(
            Uri.parse('${ApiConfig.getApiBaseUrl()}/test/'),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(_timeout);

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      throw Exception('Test kết nối thất bại: $e');
    }
  }

  /// Get server health status
  Future<Map<String, dynamic>> getHealthStatus() async {
    try {
      final response = await http
          .get(
            Uri.parse('${ApiConfig.getApiBaseUrl()}/health/'),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(_timeout);

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      throw Exception('Kiểm tra trạng thái server thất bại: $e');
    }
  }
}
