import '../models/camera.dart';
import '../models/alert.dart';

class MockApiService {
  final List<Map<String, dynamic>> _mockCameras = [
    {
      'id': '1',
      'name': 'System Camera (Live)',
      'status': 'online',
      'thumbnailUrl':
          'https://via.placeholder.com/640x360/4CAF50/FFFFFF?text=System+Camera',
    },
  ];

  final List<Map<String, dynamic>> _mockAlerts = [
    {
      'id': '1',
      'camera_name': 'Camera Tầng 1',
      'type': 'fire',
      'timestamp': '2025-11-17 14:30:00',
      'snapshot_url':
          'https://via.placeholder.com/640x360/F44336/FFFFFF?text=FIRE+DETECTED',
    },
    {
      'id': '2',
      'camera_name': 'Camera Tầng 2',
      'type': 'smoke',
      'timestamp': '2025-11-17 13:15:00',
      'snapshot_url':
          'https://via.placeholder.com/640x360/9E9E9E/FFFFFF?text=SMOKE+DETECTED',
    },
  ];

  Future<List<Camera>> fetchCameras() async {
    await Future.delayed(const Duration(seconds: 1));
    return _mockCameras.map((json) => Camera.fromJson(json)).toList();
  }

  Future<List<Alert>> fetchAlerts() async {
    await Future.delayed(const Duration(milliseconds: 500));
    return _mockAlerts.map((json) => Alert.fromJson(json)).toList();
  }
}
