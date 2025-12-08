import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../constants.dart';
import 'notification_service.dart';

class ESP32StreamingService {
  static final ESP32StreamingService _instance =
      ESP32StreamingService._internal();
  factory ESP32StreamingService() => _instance;
  ESP32StreamingService._internal();

  // ESP32 State
  String _esp32IP = '172.20.10.2';
  bool _isConnected = false;
  bool _isStreaming = false;
  bool _autoDetectionEnabled = true;
  Uint8List? _currentFrame;
  Uint8List? _boundingBoxImage;
  Timer? _streamTimer;
  DateTime? _lastDetectionTime;
  int _detectionFrameSkip = 0;

  // Getters
  String get esp32IP => _esp32IP;
  bool get isConnected => _isConnected;
  bool get isStreaming => _isStreaming;
  bool get autoDetectionEnabled => _autoDetectionEnabled;
  Uint8List? get currentFrame => _currentFrame;
  Uint8List? get boundingBoxImage => _boundingBoxImage;

  // Callbacks
  Function(Map<String, dynamic>)? onFireDetected;
  Function(String)? onError;
  Function(String)? onSuccess;
  VoidCallback? onStateChanged;

  void setCallbacks({
    Function(Map<String, dynamic>)? onFireDetected,
    Function(String)? onError,
    Function(String)? onSuccess,
    VoidCallback? onStateChanged,
  }) {
    this.onFireDetected = onFireDetected;
    this.onError = onError;
    this.onSuccess = onSuccess;
    this.onStateChanged = onStateChanged;
  }

  void setAutoDetection(bool enabled) {
    _autoDetectionEnabled = enabled;
    if (!enabled) {
      _boundingBoxImage = null;
    }
    onStateChanged?.call();
  }

  Future<bool> connectESP32() async {
    try {
      final response = await http
          .get(Uri.parse('http://$_esp32IP/'), headers: {'Accept': 'text/html'})
          .timeout(Duration(seconds: 5));

      if (response.statusCode == 200) {
        _isConnected = true;
        onSuccess?.call('✅ Kết nối ESP32-CAM thành công!');
        onStateChanged?.call();
        return true;
      } else {
        _isConnected = false;
        onError?.call('❌ ESP32-CAM không phản hồi: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      _isConnected = false;
      onError?.call('❌ Không thể kết nối ESP32-CAM: $e');
      return false;
    }
  }

  void disconnectESP32() {
    stopStreaming();
    _isConnected = false;
    _currentFrame = null;
    _boundingBoxImage = null;
    onSuccess?.call('🔌 Đã ngắt kết nối ESP32-CAM');
    onStateChanged?.call();
  }

  void startStreaming() {
    if (!_isConnected) return;

    _isStreaming = true;
    _detectionFrameSkip = 0;
    onStateChanged?.call();

    _streamTimer = Timer.periodic(Duration(milliseconds: 500), (timer) async {
      if (!_isStreaming || !_isConnected) {
        timer.cancel();
        return;
      }

      try {
        final response = await http
            .get(
              Uri.parse('http://$_esp32IP/capture'),
              headers: {'Accept': 'image/jpeg'},
            )
            .timeout(Duration(seconds: 3));

        if (response.statusCode == 200) {
          _currentFrame = response.bodyBytes;
          onStateChanged?.call();

          // Auto AI detection every 3rd frame (1.5 seconds)
          _detectionFrameSkip++;
          if (_autoDetectionEnabled && _detectionFrameSkip >= 3) {
            _detectionFrameSkip = 0;
            _analyzeCurrentFrame();
          }
        }
      } catch (e) {
        debugPrint('❌ Error getting ESP32 frame: $e');
      }
    });
  }

  void stopStreaming() {
    _streamTimer?.cancel();
    _isStreaming = false;
    _detectionFrameSkip = 0;
    onStateChanged?.call();
  }

  Future<Map<String, dynamic>?> captureAndAnalyze() async {
    if (!_isConnected) return null;

    try {
      // Use backend ESP32 capture endpoint for integrated AI analysis
      final response = await http
          .post(
            Uri.parse(
              '$apiBaseUrl/esp32/capture?esp32_ip=$_esp32IP&confidence=0.25',
            ),
            headers: {'Accept': 'application/json'},
          )
          .timeout(Duration(seconds: 15));

      if (response.statusCode == 200) {
        final result = json.decode(response.body);

        // Fetch bounding box image if there are detections
        if (result['has_bounding_boxes'] == true &&
            result['total_detections'] > 0) {
          try {
            final boxResponse = await http
                .post(
                  Uri.parse(
                    '$apiBaseUrl/esp32/capture_with_boxes?esp32_ip=$_esp32IP&confidence=0.25',
                  ),
                  headers: {'Accept': 'image/jpeg'},
                )
                .timeout(Duration(seconds: 10));

            if (boxResponse.statusCode == 200) {
              _boundingBoxImage = boxResponse.bodyBytes;
            }
          } catch (e) {
            debugPrint('❌ Error fetching bounding box image: $e');
          }
        } else {
          _boundingBoxImage = null;
        }

        if (result['fire_detected'] == true) {
          await NotificationService().showNotification(
            title: '🚨 CẢNH BÁO CHÁY ESP32!',
            body:
                'ESP32-CAM phát hiện lửa - Độ tin cậy: ${(result['confidence'] * 100).toInt()}%',
          );

          onFireDetected?.call({
            'location': 'ESP32-CAM ($_esp32IP)',
            'confidence': result['confidence'],
            'device_id': 'esp32_cam',
            'device_name': 'ESP32-CAM',
            'timestamp': result['timestamp'],
          });
        }

        onSuccess?.call('📸 Đã chụp và phân tích ảnh từ ESP32 qua backend AI!');
        onStateChanged?.call();
        return result;
      } else {
        onError?.call(
          '❌ Backend không thể phân tích ESP32: ${response.statusCode}',
        );
        return null;
      }
    } catch (e) {
      onError?.call('❌ Lỗi phân tích ESP32 qua backend: $e');
      return null;
    }
  }

  Future<void> _analyzeCurrentFrame() async {
    if (_currentFrame == null) return;

    // Tránh spam detection - chỉ detect 1 lần mỗi 10 giây
    final now = DateTime.now();
    if (_lastDetectionTime != null &&
        now.difference(_lastDetectionTime!).inSeconds < 10) {
      return;
    }

    try {
      // Phân tích qua backend thay vì trực tiếp
      final response = await http
          .post(
            Uri.parse(
              '$apiBaseUrl/esp32/capture?esp32_ip=$_esp32IP&confidence=0.25',
            ),
            headers: {'Accept': 'application/json'},
          )
          .timeout(Duration(seconds: 8));

      if (response.statusCode != 200) {
        debugPrint('❌ Backend ESP32 analysis failed: ${response.statusCode}');
        return;
      }

      final result = json.decode(response.body);

      if (result['fire_detected'] == true) {
        _lastDetectionTime = now;

        // Gửi push notification
        await NotificationService().showNotification(
          title: '🚨 CẢNH BÁO CHÁY ESP32!',
          body:
              'ESP32-CAM phát hiện lửa - Độ tin cậy: ${(result['confidence'] * 100).toInt()}%',
        );

        // Fetch bounding box image for fire detection
        try {
          final boxResponse = await http
              .post(
                Uri.parse(
                  '$apiBaseUrl/esp32/capture_with_boxes?esp32_ip=$_esp32IP&confidence=0.25',
                ),
                headers: {'Accept': 'image/jpeg'},
              )
              .timeout(Duration(seconds: 8));

          if (boxResponse.statusCode == 200) {
            _boundingBoxImage = boxResponse.bodyBytes;
          }
        } catch (e) {
          debugPrint('❌ Error fetching real-time bounding boxes: $e');
        }

        // Trigger fire detected callback
        onFireDetected?.call({
          'location': 'ESP32-CAM ($_esp32IP)',
          'confidence': result['confidence'],
          'device_id': 'esp32_cam',
          'device_name': 'ESP32-CAM',
          'timestamp': now.toIso8601String(),
        });

        onStateChanged?.call();

        debugPrint(
          '🔥 Fire detected in ESP32 stream! Confidence: ${(result['confidence'] * 100).toInt()}%',
        );
      }
    } catch (e) {
      debugPrint('❌ Error analyzing ESP32 frame: $e');
    }
  }

  void dispose() {
    _streamTimer?.cancel();
    _isConnected = false;
    _isStreaming = false;
    _currentFrame = null;
    _boundingBoxImage = null;
  }
}
