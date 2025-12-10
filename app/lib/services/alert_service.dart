import '../models/detection_result.dart';

class AlertService {
  static final AlertService _instance = AlertService._internal();
  factory AlertService() => _instance;
  AlertService._internal();

  // In-memory storage for alerts
  final List<Map<String, dynamic>> _alerts = [];

  /// Save ESP32-CAM fire detection alert
  Future<void> saveESP32Alert(
    DetectionResult result,
    String esp32Ip,
    String? imagePath,
  ) async {
    try {
      final alert = {
        'id': 'esp32_${DateTime.now().millisecondsSinceEpoch}',
        'camera_name': 'ESP32-CAM ($esp32Ip)',
        'type': result.fireDetected ? 'FIRE_DETECTED' : 'SMOKE_DETECTED',
        'timestamp': result.timestamp,
        'snapshot_url': imagePath ?? '',
        'source': 'ESP32-CAM',
        'esp32_ip': esp32Ip,
        'fire_count': result.fireCount,
        'smoke_count': result.smokeCount,
        'confidence': result.confidence,
        'alert_level': result.alertLevel,
        'message': result.message,
        'detections': result.detections,
      };

      // Add at the beginning (newest first)
      _alerts.insert(0, alert);

      // Keep only last 100 alerts to avoid memory overflow
      if (_alerts.length > 100) {
        _alerts.removeRange(100, _alerts.length);
      }

      print('✅ ESP32 alert saved: ${alert['type']} at ${alert['timestamp']}');
    } catch (e) {
      print('❌ Failed to save ESP32 alert: $e');
    }
  }

  /// Save regular alert (from mobile camera or other sources)
  Future<void> saveRegularAlert(
    String cameraName,
    String type,
    String? imagePath,
  ) async {
    try {
      final alert = {
        'id': 'alert_${DateTime.now().millisecondsSinceEpoch}',
        'camera_name': cameraName,
        'type': type,
        'timestamp': DateTime.now().toIso8601String(),
        'snapshot_url': imagePath ?? '',
        'source': 'MOBILE_CAMERA',
      };

      _alerts.insert(0, alert);

      // Keep only last 100 alerts
      if (_alerts.length > 100) {
        _alerts.removeRange(100, _alerts.length);
      }

      print('✅ Regular alert saved: ${alert['type']} at ${alert['timestamp']}');
    } catch (e) {
      print('❌ Failed to save regular alert: $e');
    }
  }

  /// Get all alerts
  List<Map<String, dynamic>> getAllAlerts() {
    return List.from(_alerts);
  }

  /// Get ESP32-CAM alerts only
  List<Map<String, dynamic>> getESP32Alerts() {
    return _alerts.where((alert) => alert['source'] == 'ESP32-CAM').toList();
  }

  /// Get regular alerts only
  List<Map<String, dynamic>> getRegularAlerts() {
    return _alerts
        .where((alert) => alert['source'] == 'MOBILE_CAMERA')
        .toList();
  }

  /// Clear all alerts
  void clearAllAlerts() {
    _alerts.clear();
    print('✅ All alerts cleared');
  }

  /// Clear ESP32 alerts only
  void clearESP32Alerts() {
    _alerts.removeWhere((alert) => alert['source'] == 'ESP32-CAM');
    print('✅ ESP32 alerts cleared');
  }

  /// Get alert statistics
  Map<String, int> getAlertStats() {
    int fireCount = 0;
    int smokeCount = 0;
    int esp32Count = 0;
    int mobileCount = 0;

    for (final alert in _alerts) {
      if (alert['type'].toString().contains('FIRE')) {
        fireCount++;
      } else if (alert['type'].toString().contains('SMOKE')) {
        smokeCount++;
      }

      if (alert['source'] == 'ESP32-CAM') {
        esp32Count++;
      } else {
        mobileCount++;
      }
    }

    return {
      'total': _alerts.length,
      'fire': fireCount,
      'smoke': smokeCount,
      'esp32': esp32Count,
      'mobile': mobileCount,
    };
  }
}
