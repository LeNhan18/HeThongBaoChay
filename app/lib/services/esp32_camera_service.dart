import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

class ESP32CameraService {
  static const Duration _timeout = Duration(seconds: 10);

  /// Direct connection to ESP32-CAM (bypass backend)
  Future<Map<String, dynamic>> connectDirectly(String esp32Ip) async {
    try {
      final response = await http
          .get(
            Uri.parse('http://$esp32Ip/'),
            headers: {'Accept': 'application/json'},
          )
          .timeout(_timeout);

      if (response.statusCode == 200) {
        return {
          'status': 'connected',
          'message': 'Kết nối trực tiếp ESP32-CAM thành công!',
          'esp32_ip': esp32Ip,
          'direct_mode': true,
        };
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      throw Exception('Kết nối trực tiếp thất bại: $e');
    }
  }

  /// Start stream on ESP32-CAM
  Future<bool> startStream(String esp32Ip) async {
    try {
      final response = await http
          .get(
            Uri.parse('http://$esp32Ip/control?var=stream&val=1'),
            headers: {'Accept': 'application/json'},
          )
          .timeout(_timeout);

      return response.statusCode == 200;
    } catch (e) {
      print('Start stream error: $e');
      return false;
    }
  }

  /// Direct capture from ESP32-CAM
  Future<Map<String, dynamic>> captureDirectly(
    String esp32Ip, {
    double confidence = 0.25,
  }) async {
    try {
      final response = await http
          .get(
            Uri.parse('http://$esp32Ip/capture'),
            headers: {'Accept': 'image/jpeg'},
          )
          .timeout(_timeout);

      if (response.statusCode == 200) {
        // Return mock detection result for now
        return {
          'fire_detected': false,
          'fire_count': 0,
          'smoke_count': 0,
          'confidence': 0.0,
          'message': 'Chụp ảnh trực tiếp từ ESP32-CAM thành công',
          'image_data': response.bodyBytes,
          'direct_mode': true,
        };
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      throw Exception('Chụp ảnh trực tiếp thất bại: $e');
    }
  }

  /// Test connection to ESP32-CAM device (via backend)
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
