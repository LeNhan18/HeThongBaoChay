import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import '../constants.dart';

class PredictionService {
  Future<Map<String, dynamic>> uploadAndPredict(File file, String type) async {
    try {
      final endpoint = type == 'image' ? 'predict_json' : 'analyze_video';
      final uri = Uri.parse('$apiBaseUrl/$endpoint/');
      final request = http.MultipartRequest('POST', uri);

      // Add file to request
      request.files.add(
        await http.MultipartFile.fromPath('file', file.path),
      );

      // Send request
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        if (type == 'image') {
          final jsonResponse = json.decode(response.body);
          final summary = jsonResponse['summary'];
          
          // Calculate max confidence
          double maxConf = 0.0;
          if (jsonResponse['detections'] != null) {
            for (var d in jsonResponse['detections']) {
              if (d['confidence'] > maxConf) maxConf = d['confidence'];
            }
          }

          return {
            'fire_detected': summary['fire'] > 0,
            'confidence': maxConf,
            'detections': summary['total'],
            'processing_time': 0.5, // Estimated
          };
        } else {
          // Video analysis returns headers with stats
          final headers = response.headers;
          final processingTimeStr = headers['x-processing-time']?.replaceAll('s', '') ?? '0';
          final detectionsCount = int.tryParse(headers['x-detections-total'] ?? '0') ?? 0;
          final fireCount = int.tryParse(headers['x-fire-count'] ?? '0') ?? 0;
          final smokeCount = int.tryParse(headers['x-smoke-count'] ?? '0') ?? 0;
          final framesProcessed = int.tryParse(headers['x-frames-processed'] ?? '0') ?? 0;
          
          print('🎥 Video Analysis Results:');
          print('   Frames processed: $framesProcessed');
          print('   Total detections: $detectionsCount');
          print('   Fire detections: $fireCount');
          print('   Smoke detections: $smokeCount');
          print('   Processing time: $processingTimeStr');
          print('   Response size: ${response.bodyBytes.length} bytes');
          
          // Save annotated video to temp file
          final tempDir = await getTemporaryDirectory();
          final timestamp = DateTime.now().millisecondsSinceEpoch;
          final videoFile = File('${tempDir.path}/annotated_video_$timestamp.mp4');
          await videoFile.writeAsBytes(response.bodyBytes);
          
          print('📁 Saved annotated video to: ${videoFile.path}');
          final exists = await videoFile.exists();
          final size = exists ? await videoFile.length() : 0;
          print('✅ Video file exists: $exists, size: ${size / (1024*1024):.2f} MB');

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
        throw Exception('Failed to predict: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error uploading file: $e');
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
