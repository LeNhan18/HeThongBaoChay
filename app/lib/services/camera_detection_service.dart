import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import '../models/detection_result.dart';
import '../constants.dart';

class CameraDetectionService {
  static const String _baseUrl = '$API_BASE_URL/mobile/camera';
  static const Duration _timeout = Duration(seconds: 10);

  // Singleton pattern
  static final CameraDetectionService _instance =
      CameraDetectionService._internal();
  factory CameraDetectionService() => _instance;
  CameraDetectionService._internal();

  /// Detect fire and smoke from image file path
  Future<DetectionResult> detectFromImage(
    String imagePath, {
    double confidence = 0.25,
  }) async {
    try {
      if (kIsWeb) {
        throw Exception('Camera detection is not supported on web platform');
      }

      final file = File(imagePath);
      if (!await file.exists()) {
        throw Exception('Image file not found: $imagePath');
      }

      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$_baseUrl/detect?confidence=$confidence'),
      );

      // Add image file
      request.files.add(
        await http.MultipartFile.fromPath(
          'file',
          imagePath,
          filename: 'camera_frame.jpg',
        ),
      );

      // Add headers
      request.headers.addAll({
        'Content-Type': 'multipart/form-data',
        'Accept': 'application/json',
      });

      // Send request with timeout
      final streamedResponse = await request.send().timeout(_timeout);
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        return DetectionResult.fromJson(data);
      } else {
        throw Exception('API Error: ${response.statusCode} - ${response.body}');
      }
    } on SocketException {
      throw Exception(
        'Không thể kết nối đến server. Vui lòng kiểm tra kết nối mạng.',
      );
    } on http.ClientException {
      throw Exception('Lỗi kết nối. Vui lòng thử lại sau.');
    } on FormatException {
      throw Exception('Lỗi định dạng dữ liệu từ server.');
    } catch (e) {
      throw Exception('Lỗi phát hiện: $e');
    }
  }

  /// Detect fire and smoke from image bytes
  Future<DetectionResult> detectFromBytes(
    List<int> imageBytes, {
    double confidence = 0.25,
    String filename = 'camera_frame.jpg',
  }) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$_baseUrl/detect?confidence=$confidence'),
      );

      // Add image bytes
      request.files.add(
        http.MultipartFile.fromBytes('file', imageBytes, filename: filename),
      );

      // Add headers
      request.headers.addAll({
        'Content-Type': 'multipart/form-data',
        'Accept': 'application/json',
      });

      // Send request with timeout
      final streamedResponse = await request.send().timeout(_timeout);
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        return DetectionResult.fromJson(data);
      } else {
        throw Exception('API Error: ${response.statusCode} - ${response.body}');
      }
    } on SocketException {
      throw Exception(
        'Không thể kết nối đến server. Vui lòng kiểm tra kết nối mạng.',
      );
    } on http.ClientException {
      throw Exception('Lỗi kết nối. Vui lòng thử lại sau.');
    } on FormatException {
      throw Exception('Lỗi định dạng dữ liệu từ server.');
    } catch (e) {
      throw Exception('Lỗi phát hiện: $e');
    }
  }

  /// Get annotated image with detection results
  Future<List<int>> detectWithAnnotatedImage(
    String imagePath, {
    double confidence = 0.25,
  }) async {
    try {
      final file = File(imagePath);
      if (!await file.exists()) {
        throw Exception('Image file not found: $imagePath');
      }

      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$_baseUrl/detect_with_image?confidence=$confidence'),
      );

      // Add image file
      request.files.add(
        await http.MultipartFile.fromPath(
          'file',
          imagePath,
          filename: 'camera_frame.jpg',
        ),
      );

      // Add headers
      request.headers.addAll({
        'Content-Type': 'multipart/form-data',
        'Accept': 'image/jpeg',
      });
      // Send request with timeout
      final streamedResponse = await request.send().timeout(_timeout);
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        // Return image bytes
        return response.bodyBytes;
      } else {
        throw Exception(
          'API Error: ${response.statusCode} - ${response.reasonPhrase}',
        );
      }
    } on SocketException {
      throw Exception(
        'Không thể kết nối đến server. Vui lòng kiểm tra kết nối mạng.',
      );
    } on http.ClientException {
      throw Exception('Lỗi kết nối. Vui lòng thử lại sau.');
    } catch (e) {
      throw Exception('Lỗi phát hiện ảnh: $e');
    }
  }

  /// Check API health
  Future<bool> checkApiHealth() async {
    try {
      final response = await http
          .get(
            Uri.parse('$API_BASE_URL/health'),
            headers: {'Accept': 'application/json'},
          )
          .timeout(_timeout);

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// Test detection service with a simple call
  Future<Map<String, dynamic>> testConnection() async {
    try {
      final response = await http
          .get(
            Uri.parse('$API_BASE_URL/'),
            headers: {'Accept': 'application/json'},
          )
          .timeout(_timeout);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': 'Kết nối API thành công',
          'data': json.decode(response.body),
        };
      } else {
        return {
          'success': false,
          'message': 'API không phản hồi đúng: ${response.statusCode}',
        };
      }
    } on SocketException {
      return {
        'success': false,
        'message':
            'Không thể kết nối đến server. Kiểm tra địa chỉ IP trong constants.dart',
      };
    } catch (e) {
      return {'success': false, 'message': 'Lỗi kết nối: $e'};
    }
  }
}
