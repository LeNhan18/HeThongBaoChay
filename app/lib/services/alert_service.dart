import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/detection_result.dart';
import '../config/api_config.dart';
import 'notification_service.dart';

class AlertService {
  static final AlertService _instance = AlertService._internal();
  factory AlertService() => _instance;
  AlertService._internal();

  // In-memory storage for alerts
  final List<Map<String, dynamic>> _alerts = [];
  final NotificationService _notificationService = NotificationService();

  // Live alert polling
  Timer? _alertTimer;
  bool _isPolling = false;
  Set<int> _processedAlertIds = {};

  /// Register FCM token with backend for push notifications
  Future<void> registerFCMToken() async {
    try {
      // Get FCM token from notification service
      String? fcmToken = await _notificationService.getFCMToken();

      if (fcmToken == null) {
        print(' No FCM token available');
        return;
      }

      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/mobile/register_fcm_token'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'token': fcmToken}),
      );

      if (response.statusCode == 200) {
        print(' FCM token registered with backend');
      } else {
        print(' Failed to register FCM token: ${response.statusCode}');
      }
    } catch (e) {
      print(' Error registering FCM token: $e');
    }
  }

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

      print(' ESP32 alert saved: ${alert['type']} at ${alert['timestamp']}');
    } catch (e) {
      print(' Failed to save ESP32 alert: $e');
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

      print(' Regular alert saved: ${alert['type']} at ${alert['timestamp']}');
    } catch (e) {
      print(' Failed to save regular alert: $e');
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
    print(' All alerts cleared');
  }

  /// Clear ESP32 alerts only
  void clearESP32Alerts() {
    _alerts.removeWhere((alert) => alert['source'] == 'ESP32-CAM');
    print(' ESP32 alerts cleared');
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

  /// Start polling for live alerts from backend
  void startLiveAlertPolling() {
    if (_isPolling) return;

    _isPolling = true;
    print(' Starting live alert polling...');

    _alertTimer = Timer.periodic(Duration(seconds: 30), (_) async {
      await _fetchLiveAlerts();
    });
  }

  /// Stop polling for live alerts
  void stopLiveAlertPolling() {
    if (!_isPolling) return;

    _isPolling = false;
    _alertTimer?.cancel();
    _alertTimer = null;
    print(' Stopped live alert polling');
  }

  /// Fetch new alerts from backend
  Future<void> _fetchLiveAlerts() async {
    try {
      final response = await http
          .get(
            Uri.parse(
              '${ApiConfig.baseUrl}/mobile/get_alerts?unread_only=true',
            ),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final alerts = data['alerts'] as List;

        for (final alert in alerts) {
          final alertId = alert['id'] as int;

          // Skip if already processed
          if (_processedAlertIds.contains(alertId)) {
            continue;
          }

          // Mark as processed
          _processedAlertIds.add(alertId);

          // Show notification for new alert
          await _notificationService.showNotification(
            title: alert['title'] ?? ' CẢNH BÁO CHÁY',
            body: alert['body'] ?? 'Phát hiện lửa/khói',
          );

          // Save to local alerts
          _alerts.insert(0, {
            'id': alert['id'].toString(),
            'camera_name': 'Live Detection (${alert['esp32_ip']})',
            'type': 'LIVE_FIRE_DETECTED',
            'timestamp': alert['timestamp'],
            'source': alert['source'] ?? 'Live Detection',
            'esp32_ip': alert['esp32_ip'],
            'fire_count': alert['fire_count'] ?? 0,
            'smoke_count': alert['smoke_count'] ?? 0,
            'confidence': alert['confidence'] ?? 0,
            'alert_level': 'HIGH',
            'message': alert['vietnamese_message'] ?? alert['body'],
            'detections': [],
          });

          // Mark as read on backend (only for new alerts)
          _markAlertAsRead(alertId);

          print(' New live alert received: ${alert['body']}');
        }

        // Keep only last 100 alerts
        if (_alerts.length > 100) {
          _alerts.removeRange(100, _alerts.length);
        }
      }
    } catch (e) {
      print(' Error fetching live alerts: $e');
    }
  }

  /// Mark alert as read on backend
  Future<void> _markAlertAsRead(int alertId) async {
    try {
      await http.post(
        Uri.parse('${ApiConfig.baseUrl}/mobile/mark_alert_read'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'alert_id': alertId}),
      );
    } catch (e) {
      print(' Error marking alert as read: $e');
    }
  }

  /// Add FCM alert to local storage
  void addFCMAlert(Map<String, dynamic> alertData) {
    _alerts.insert(0, alertData);

    // Keep only last 100 alerts
    if (_alerts.length > 100) {
      _alerts.removeRange(100, _alerts.length);
    }

    print(' FCM alert added: ${alertData['message']}');
  }

  /// Dispose resources
  void dispose() {
    stopLiveAlertPolling();
  }
}
