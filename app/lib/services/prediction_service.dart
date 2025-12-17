import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../constants.dart';

class PredictionService {
  Future<Map<String, dynamic>> uploadAndPredict(File file, String type) async {
    try {
      final uri = Uri.parse('$apiBaseUrl/predict');
      final request = http.MultipartRequest('POST', uri);

      // Add file to request
      if (type == 'image') {
        request.files.add(
          await http.MultipartFile.fromPath('file', file.path),
        );
      } else if (type == 'video') {
        request.files.add(
          await http.MultipartFile.fromPath('video', file.path),
        );
      }

      // Send request
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        return json.decode(response.body);
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
