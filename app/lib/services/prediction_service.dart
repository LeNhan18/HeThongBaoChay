import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:image_picker/image_picker.dart';
import '../constants.dart';
import '../config/api_config.dart';

class PredictionService {
  /// Test connection to server
  Future<Map<String, dynamic>> testConnection() async {
    final baseUrl = ApiConfig.getApiBaseUrl();
    print(' Testing connection to: $baseUrl');

    try {
      final uri = Uri.parse('$baseUrl/test/');
      print(' Test URL: $uri');

      final response = await http
          .get(uri, headers: {'Content-Type': 'application/json'})
          .timeout(Duration(seconds: 10));

      print(' Test response status: ${response.statusCode}');
      print(' Test response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'success': true,
          'message': data['message'],
          'server_ip': data['server_ip'],
          'server_port': data['server_port'],
          'timestamp': data['timestamp'],
        };
      } else {
        return {
          'success': false,
          'error': 'Server returned status ${response.statusCode}',
          'response': response.body,
        };
      }
    } catch (e) {
      print(' Connection test failed: $e');
      return {'success': false, 'error': 'Connection failed: $e'};
    }
  }

  Future<Map<String, dynamic>> uploadAndPredict(
    dynamic file,
    String type,
  ) async {
    final baseUrl = ApiConfig.getApiBaseUrl(); // Use dynamic host
    print('Connecting to: $baseUrl'); // Debug log
    try {
      final endpoint = type == 'image' ? 'predict' : 'analyze_video';
      final uri = Uri.parse('$baseUrl/$endpoint/');
      print('Full URL: $uri'); // Debug log
      final request = http.MultipartRequest('POST', uri);

      // Add file to request - Handle XFile for both web and mobile platforms
      if (file is XFile) {
        final bytes = await file.readAsBytes();
        request.files.add(
          http.MultipartFile.fromBytes('file', bytes, filename: file.name),
        );
      } else if (file is File) {
        request.files.add(await http.MultipartFile.fromPath('file', file.path));
      } else {
        throw Exception('Unsupported file type: ${file.runtimeType}');
      }

      // Send request
      print(' Sending request to server...'); // Debug log
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      print(' Response status: ${response.statusCode}'); // Debug log

      if (response.statusCode == 200) {
        if (type == 'image') {
          // Image prediction returns JPEG with detection info in headers
          final headers = response.headers;
          final detectionsCount =
              int.tryParse(headers['x-detections-count'] ?? '0') ?? 0;
          final fireCount = int.tryParse(headers['x-fire-count'] ?? '0') ?? 0;
          final smokeCount = int.tryParse(headers['x-smoke-count'] ?? '0') ?? 0;

          // Save annotated image to temp file
          final tempDir = await getTemporaryDirectory();
          final timestamp = DateTime.now().millisecondsSinceEpoch;
          final imageFile = File(
            '${tempDir.path}/annotated_image_$timestamp.jpg',
          );
          await imageFile.writeAsBytes(response.bodyBytes);

          return {
            'fire_detected': fireCount > 0,
            'smoke_detected': smokeCount > 0,
            'confidence':
                fireCount > 0 || smokeCount > 0 ? 0.85 : 0.0, // Estimated
            'detections': detectionsCount,
            'fire_count': fireCount,
            'smoke_count': smokeCount,
            'processing_time': 0.5, // Estimated
            'result_image_path': imageFile.path,
            'has_bounding_boxes': detectionsCount > 0,
          };
        } else {
          // Video analysis returns headers with stats
          final headers = response.headers;
          final processingTimeStr =
              headers['x-processing-time']?.replaceAll('s', '') ?? '0';
          final detectionsCount =
              int.tryParse(headers['x-detections-total'] ?? '0') ?? 0;
          final fireCount = int.tryParse(headers['x-fire-count'] ?? '0') ?? 0;
          final smokeCount = int.tryParse(headers['x-smoke-count'] ?? '0') ?? 0;
          final framesProcessed =
              int.tryParse(headers['x-frames-processed'] ?? '0') ?? 0;

          print('   Video Analysis Results:');
          print('   Frames processed: $framesProcessed');
          print('   Total detections: $detectionsCount');
          print('   Fire detections: $fireCount');
          print('   Smoke detections: $smokeCount');
          print('   Processing time: $processingTimeStr');
          print('   Response size: ${response.bodyBytes.length} bytes');

          // Save annotated video to temp file
          final tempDir = await getTemporaryDirectory();
          final timestamp = DateTime.now().millisecondsSinceEpoch;
          final videoFile = File(
            '${tempDir.path}/annotated_video_$timestamp.mp4',
          );
          await videoFile.writeAsBytes(response.bodyBytes);

          print(' Saved annotated video to: ${videoFile.path}');
          final exists = await videoFile.exists();
          final size = exists ? await videoFile.length() : 0;
          print(
            ' Video file exists: $exists, size: ${(size / (1024 * 1024)).toStringAsFixed(2)} MB',
          );

          return {
            'fire_detected': fireCount > 0,
            'smoke_detected': smokeCount > 0,
            'confidence': 0.85, // Estimated for video
            'detections': detectionsCount,
            'fire_count': fireCount,
            'smoke_count': smokeCount,
            'frames_processed': framesProcessed,
            'processing_time': double.tryParse(processingTimeStr) ?? 0.0,
            'result_video_path': videoFile.path,
            'has_bounding_boxes': detectionsCount > 0,
          };
        }
      } else {
        throw Exception(
          'Server error ${response.statusCode}: ${response.body}. '
          'Đảm bảo server AI đang chạy tại $baseUrl',
        );
      }
    } catch (e) {
      if (e.toString().contains('Connection refused') ||
          e.toString().contains('Network is unreachable')) {
        throw Exception(
          'Không thể kết nối đến server AI tại $baseUrl. '
          'Vui lòng:\n'
          '1. Kiểm tra server AI có đang chạy không\n'
          '2. Nếu Android device thật: cập nhật IP trong api_config.dart\n'
          '3. Kiểm tra firewall và network connection\n'
          'Chi tiết lỗi: $e',
        );
      }
      throw Exception('Lỗi upload file: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getPredictionHistory() async {
    try {
      final uri = Uri.parse('$apiBaseUrl/predictions/history');
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.cast<Map<String, dynamic>>();
      } else {
        throw Exception('Failed to get history: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error getting history: $e');
    }
  }
}
