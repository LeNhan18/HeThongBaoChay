import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:async';
import '../services/esp32_camera_service.dart';
import '../models/detection_result.dart';
import '../services/notification_service.dart';
import '../services/alert_service.dart';

class ESP32CameraScreen extends StatefulWidget {
  const ESP32CameraScreen({Key? key}) : super(key: key);

  @override
  State<ESP32CameraScreen> createState() => _ESP32CameraScreenState();
}

class _ESP32CameraScreenState extends State<ESP32CameraScreen> {
  final ESP32CameraService _esp32Service = ESP32CameraService();
  final TextEditingController _ipController = TextEditingController();
  final NotificationService _notificationService = NotificationService();
  final AlertService _alertService = AlertService();

  bool _isConnected = false;
  bool _isLoading = false;
  bool _isCapturing = false;
  bool _isStreaming = false;
  bool _directMode = false;
  String _statusMessage = "Chưa kết nối";
  DetectionResult? _lastResult;
  String? _capturedImageUrl;
  double _confidence = 0.25;

  // Auto detection variables
  bool _autoDetection = false;
  Timer? _detectionTimer;
  bool _lastFireDetected = false;

  // Stream refresh timer
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _ipController.text = "172.20.10.2"; // IP thực của ESP32-CAM
  }

  @override
  void dispose() {
    _ipController.dispose();
    _detectionTimer?.cancel();
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _showMessage(String message, {bool isError = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 3),
      ),
    );
  }

  void _toggleAutoDetection() {
    setState(() {
      _autoDetection = !_autoDetection;
    });

    if (_autoDetection) {
      if (!_isConnected) {
        _showMessage("Vui lòng kết nối ESP32-CAM trước");
        setState(() {
          _autoDetection = false;
        });
        return;
      }

      _startAutoDetection();
      String mode = _directMode ? " (Direct Mode)" : "";
      _showMessage("Bắt đầu phát hiện tự động$mode", isError: false);
    } else {
      _stopAutoDetection();
      _showMessage("Dừng phát hiện tự động", isError: false);
    }
  }

  void _startAutoDetection() {
    _detectionTimer = Timer.periodic(Duration(seconds: 3), (timer) async {
      if (!_isConnected || _isCapturing) return;

      try {
        setState(() {
          _isCapturing = true;
        });

        // Always use backend for AI analysis
        final result = await _esp32Service.captureAndAnalyze(
          _ipController.text,
          confidence: _confidence,
        );

        final detectionResult = DetectionResult.fromJson(result);

        setState(() {
          _lastResult = detectionResult;
          _isCapturing = false;
        });

        // Chỉ thông báo khi phát hiện lửa lần đầu (tránh spam)
        if (detectionResult.fireDetected && !_lastFireDetected) {
          _lastFireDetected = true;

          // Save alert to history
          await _alertService.saveESP32Alert(
            detectionResult,
            _ipController.text,
            null,
          );

          // Send notification
          await _notificationService.showNotification(
            title: '🔥 CẢNH BÁO CHÁY - ESP32-CAM (AUTO)',
            body:
                'Phát hiện tự động: ${detectionResult.fireCount} lửa, ${detectionResult.smokeCount} khói từ ESP32-CAM',
          );

          _showFireAlert(detectionResult);
        } else if (!detectionResult.fireDetected) {
          _lastFireDetected = false; // Reset khi không còn lửa
        }
      } catch (e) {
        print('Auto detection error: $e');
        setState(() {
          _isCapturing = false;
        });
      }
    });
  }

  void _stopAutoDetection() {
    _detectionTimer?.cancel();
    _detectionTimer = null;
    _lastFireDetected = false;
  }

  void _startRefreshTimer() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(Duration(seconds: 1), (_) {
      if (_isConnected) {
        setState(() {
          // Force rebuild to refresh image with new timestamp
        });
      }
    });
  }

  Future<void> _connectToESP32() async {
    if (_ipController.text.isEmpty) {
      _showMessage("Vui lòng nhập địa chỉ IP của ESP32-CAM");
      return;
    }

    setState(() {
      _isLoading = true;
      _statusMessage = "Đang kết nối...";
    });

    try {
      // Always use backend mode for better AI integration
      final result = await _esp32Service.connectToESP32(_ipController.text);

      setState(() {
        _isConnected = result['status'] == 'connected';
        _statusMessage = result['message'];
        _isLoading = false;
      });

      if (_isConnected) {
        // Start refresh timer for live preview
        _startRefreshTimer();
        _showMessage("Kết nối ESP32-CAM thành công!", isError: false);
      } else {
        _showMessage(
          "Không thể kết nối ESP32-CAM: ${result['message']}",
          isError: true,
        );
      }
    } catch (e) {
      setState(() {
        _isConnected = false;
        _statusMessage = "Lỗi kết nối: ${e.toString()}";
        _isLoading = false;
      });
      _showMessage("Lỗi kết nối: ${e.toString()}", isError: true);
    }
  }

  Future<void> _captureImage() async {
    if (!_isConnected) {
      _showMessage("Vui lòng kết nối ESP32-CAM trước");
      return;
    }

    setState(() {
      _isCapturing = true;
    });

    try {
      // Always use backend for AI analysis
      final result = await _esp32Service.captureAndAnalyze(
        _ipController.text,
        confidence: _confidence,
      );

      setState(() {
        _lastResult = DetectionResult.fromJson(result);
        _isCapturing = false;
      });

      if (_lastResult!.fireDetected) {
        // Save alert to history
        await _alertService.saveESP32Alert(
          _lastResult!,
          _ipController.text,
          null,
        );

        // Send notification
        await _notificationService.showNotification(
          title: '🔥 CẢNH BÁO CHÁY - ESP32-CAM',
          body:
              'Phát hiện ${_lastResult!.fireCount} lửa, ${_lastResult!.smokeCount} khói từ ESP32-CAM (${_ipController.text})',
        );

        _showFireAlert(_lastResult!);
      } else {
        _showMessage(
          "Chụp ảnh thành công - Không phát hiện lửa/khói",
          isError: false,
        );
      }
    } catch (e) {
      setState(() {
        _isCapturing = false;
      });
      _showMessage("Lỗi chụp ảnh: ${e.toString()}", isError: true);
    }
  }

  Future<void> _captureWithBoundingBoxes() async {
    if (!_isConnected) {
      _showMessage("Vui lòng kết nối ESP32-CAM trước");
      return;
    }

    setState(() {
      _isCapturing = true;
    });

    try {
      late List<int> imageBytes;

      imageBytes = await _esp32Service.captureWithBoundingBoxes(
        _ipController.text,
        confidence: _confidence,
      );

      // Save image temporarily to display
      final tempDir = Directory.systemTemp;
      final tempFile = File(
        '${tempDir.path}/esp32_capture_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      await tempFile.writeAsBytes(imageBytes);

      setState(() {
        _capturedImageUrl = tempFile.path;
        _isCapturing = false;
      });

      // Check if there was a detection result from previous capture
      if (_lastResult != null && _lastResult!.fireDetected) {
        // Update alert with image path
        await _alertService.saveESP32Alert(
          _lastResult!,
          _ipController.text,
          tempFile.path,
        );

        // Send notification with image info
        await _notificationService.showNotification(
          title: '📷 Ảnh Cảnh Báo Cháy - ESP32-CAM',
          body: 'Đã chụp ảnh chi tiết từ ESP32-CAM với khung phát hiện',
        );
      }

      _showMessage("Chụp ảnh với khung phát hiện thành công!", isError: false);
    } catch (e) {
      setState(() {
        _isCapturing = false;
      });
      _showMessage("Lỗi chụp ảnh: ${e.toString()}", isError: true);
    }
  }

  Widget _buildCameraStream() {
    if (!_isConnected) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.videocam_off, color: Colors.white, size: 48),
            SizedBox(height: 16),
            Text(
              'Chưa kết nối ESP32-CAM',
              style: TextStyle(color: Colors.white),
            ),
          ],
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Live Snapshot Display (refreshes every second)
        Container(
          width: double.infinity,
          height: 160,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              'http://172.20.10.4:8000/esp32/capture_with_boxes'
              '?esp32_ip=${_ipController.text}'
              '&confidence=$_confidence'
              '&t=${DateTime.now().millisecondsSinceEpoch}',
              fit: BoxFit.cover,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(strokeWidth: 2),
                      SizedBox(height: 4),
                      Text(
                        'Đang tải ảnh...',
                        style: TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ],
                  ),
                );
              },
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  color: Colors.black87,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.camera_alt_outlined,
                          color: Colors.orange,
                          size: 24,
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Không thể tải ảnh\nKiểm tra kết nối ESP32-CAM\nIP: ${_ipController.text}',
                          style: TextStyle(color: Colors.white, fontSize: 12),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),

        SizedBox(height: 8),

        // Backend snapshot info
        Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            '📷 Live Snapshot (1fps) qua Backend AI Server\n🤖 Tự động phát hiện lửa/khói với khung bao',
            style: TextStyle(fontSize: 11, color: Colors.blue.shade700),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }

  void _showFireAlert(DetectionResult result) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => AlertDialog(
            backgroundColor: Colors.red.shade50,
            title: Row(
              children: [
                Icon(Icons.warning, color: Colors.red, size: 30),
                SizedBox(width: 10),
                Text(
                  'CẢNH BÁO CHÁY!',
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Thời gian: ${result.timestamp}'),
                SizedBox(height: 8),
                Text('Phát hiện: ${result.message}'),
                SizedBox(height: 8),
                Text('Mức độ cảnh báo: ${result.alertLevel}'),
                SizedBox(height: 8),
                Text(
                  'Độ tin cậy: ${(result.confidence * 100).toStringAsFixed(1)}%',
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('ĐÓNG'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _captureWithBoundingBoxes();
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: Text(
                  'XEM CHI TIẾT',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('ESP32-CAM Stream'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Connection Section
              Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Kết nối ESP32-CAM',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 8),

                      // Backend Mode Info
                      Container(
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.cloud, color: Colors.blue, size: 20),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Backend Mode: Stream qua AI Server (192.168.2.29:8000)',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.blue.shade700,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 16),
                      TextField(
                        controller: _ipController,
                        decoration: InputDecoration(
                          labelText: 'Địa chỉ IP ESP32-CAM',
                          hintText: '192.168.1.100',
                          prefixIcon: Icon(Icons.wifi),
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                      ),
                      SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _isLoading ? null : _connectToESP32,
                              icon:
                                  _isLoading
                                      ? SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                      : Icon(
                                        _isConnected
                                            ? Icons.wifi
                                            : Icons.wifi_off,
                                      ),
                              label: Text(
                                _isLoading
                                    ? 'Đang kết nối...'
                                    : (_isConnected ? 'Đã kết nối' : 'Kết nối'),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                    _isConnected ? Colors.green : Colors.blue,
                                foregroundColor: Colors.white,
                                padding: EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            _isConnected ? Icons.check_circle : Icons.error,
                            color: _isConnected ? Colors.green : Colors.red,
                            size: 20,
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _statusMessage,
                              style: TextStyle(
                                color: _isConnected ? Colors.green : Colors.red,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // Confidence Slider
              Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Độ tin cậy phát hiện',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 8),
                      Slider(
                        value: _confidence,
                        min: 0.1,
                        max: 0.9,
                        divisions: 8,
                        label: '${(_confidence * 100).toStringAsFixed(0)}%',
                        onChanged: (value) {
                          setState(() {
                            _confidence = value;
                          });
                        },
                      ),
                      Text(
                        'Hiện tại: ${(_confidence * 100).toStringAsFixed(0)}%',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),

              // Auto Detection Control Section
              Card(
                color: _autoDetection ? Colors.green.shade50 : null,
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            _autoDetection
                                ? Icons.auto_mode
                                : Icons.motion_photos_off,
                            color: _autoDetection ? Colors.green : Colors.grey,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Phát hiện Tự động',
                            style: Theme.of(
                              context,
                            ).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: _autoDetection ? Colors.green : null,
                            ),
                          ),
                          Spacer(),
                          Switch(
                            value: _autoDetection,
                            onChanged: (_) => _toggleAutoDetection(),
                            activeColor: Colors.green,
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      Text(
                        _autoDetection
                            ? '🔥 Đang tự động phát hiện cháy mỗi 3 giây...'
                            : 'Bật để tự động phát hiện cháy liên tục',
                        style: TextStyle(
                          color:
                              _autoDetection
                                  ? Colors.green.shade700
                                  : Colors.grey.shade600,
                          fontSize: 13,
                        ),
                      ),
                      if (_autoDetection && _isCapturing)
                        Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Đang phân tích...',
                                style: TextStyle(
                                  color: Colors.blue,
                                  fontSize: 12,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              // Control Buttons
              Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Điều khiển Camera',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed:
                                  (_isConnected && !_isCapturing)
                                      ? _captureImage
                                      : null,
                              icon:
                                  _isCapturing
                                      ? SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                      : Icon(Icons.camera_alt),
                              label: Text(
                                _isCapturing
                                    ? 'Đang chụp...'
                                    : 'Chụp & Phân tích',
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                foregroundColor: Colors.white,
                                padding: EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed:
                                  (_isConnected && !_isCapturing)
                                      ? _captureWithBoundingBoxes
                                      : null,
                              icon:
                                  _isCapturing
                                      ? SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                      : Icon(Icons.crop_free),
                              label: Text(
                                _isCapturing
                                    ? 'Đang chụp...'
                                    : 'Chụp với Khung',
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange,
                                foregroundColor: Colors.white,
                                padding: EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // Camera Stream Section
              if (_isConnected)
                Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Camera ESP32-CAM',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    _isStreaming ? Colors.green : Colors.grey,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                _isStreaming ? 'LIVE' : 'READY',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 16),
                        Container(
                          width: double.infinity,
                          height: 240,
                          decoration: BoxDecoration(
                            color: Colors.black,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: _buildCameraStream(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // Captured Image Section
              if (_capturedImageUrl != null)
                Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Ảnh đã chụp',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 16),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(
                            File(_capturedImageUrl!),
                            width: double.infinity,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                height: 200,
                                color: Colors.grey[300],
                                child: Center(
                                  child: Text('Không thể hiển thị ảnh'),
                                ),
                              );
                            },
                          ),
                        ),
                        SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  setState(() {
                                    _capturedImageUrl = null;
                                  });
                                },
                                icon: Icon(Icons.clear),
                                label: Text('Xóa ảnh'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.grey,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

              // Results Section
              if (_lastResult != null)
                Card(
                  color:
                      _lastResult!.fireDetected
                          ? Colors.red.shade50
                          : Colors.green.shade50,
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              _lastResult!.fireDetected
                                  ? Icons.warning
                                  : Icons.check_circle,
                              color:
                                  _lastResult!.fireDetected
                                      ? Colors.red
                                      : Colors.green,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Kết quả phát hiện',
                              style: Theme.of(
                                context,
                              ).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color:
                                    _lastResult!.fireDetected
                                        ? Colors.red
                                        : Colors.green,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 12),
                        _buildResultRow('Thời gian', _lastResult!.timestamp),
                        _buildResultRow(
                          'Trạng thái',
                          _lastResult!.fireDetected
                              ? 'PHÁT HIỆN CHÁY'
                              : 'AN TOÀN',
                        ),
                        _buildResultRow(
                          'Lửa',
                          '${_lastResult!.fireCount} điểm',
                        ),
                        _buildResultRow(
                          'Khói',
                          '${_lastResult!.smokeCount} điểm',
                        ),
                        _buildResultRow(
                          'Mức cảnh báo',
                          _lastResult!.alertLevel,
                        ),
                        _buildResultRow(
                          'Độ tin cậy',
                          '${(_lastResult!.confidence * 100).toStringAsFixed(1)}%',
                        ),
                        if (_lastResult!.message.isNotEmpty)
                          _buildResultRow('Chi tiết', _lastResult!.message),
                      ],
                    ),
                  ),
                ),

              SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResultRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
