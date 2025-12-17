import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import '../services/camera_detection_service.dart';
import '../services/notification_service.dart';
import '../models/detection_result.dart';
import '../constants.dart';

class CameraDetectionScreen extends StatefulWidget {
  const CameraDetectionScreen({super.key});

  @override
  State<CameraDetectionScreen> createState() => _CameraDetectionScreenState();
}

class _CameraDetectionScreenState extends State<CameraDetectionScreen>
    with WidgetsBindingObserver {
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  bool _isCameraInitialized = false;
  bool _isDetectionActive = false;
  bool _isProcessingFrame = false;

  final CameraDetectionService _detectionService = CameraDetectionService();
  DetectionResult? _lastDetectionResult;

  Timer? _detectionTimer;
  int _currentCameraIndex = 0;

  // Statistics
  int _totalFramesProcessed = 0;
  int _totalDetections = 0;
  DateTime? _sessionStartTime;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _detectionTimer?.cancel();
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive) {
      _cameraController?.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initializeCamera();
    }
  }

  Future<void> _initializeCamera() async {
    try {
      // Request camera permission
      final cameraPermission = await Permission.camera.request();
      if (!cameraPermission.isGranted) {
        _showError('Cần cấp quyền camera để sử dụng tính năng này');
        return;
      }

      // Get available cameras
      _cameras = await availableCameras();
      if (_cameras == null || _cameras!.isEmpty) {
        _showError('Không tìm thấy camera trên thiết bị');
        return;
      }

      // Initialize camera controller
      _cameraController = CameraController(
        _cameras![_currentCameraIndex],
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await _cameraController!.initialize();

      if (mounted) {
        setState(() {
          _isCameraInitialized = true;
        });
      }
    } catch (e) {
      _showError('Lỗi khởi tạo camera: $e');
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  void _showSuccess(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _toggleDetection() async {
    if (!_isCameraInitialized) return;

    if (_isDetectionActive) {
      _stopDetection();
    } else {
      _startDetection();
    }
  }

  void _startDetection() {
    setState(() {
      _isDetectionActive = true;
      _sessionStartTime = DateTime.now();
      _totalFramesProcessed = 0;
      _totalDetections = 0;
    });

    _showSuccess('Bắt đầu phát hiện lửa và khói');

    // Start detection timer - process frame every 500ms
    _detectionTimer = Timer.periodic(const Duration(milliseconds: 500), (
      timer,
    ) {
      _processFrame();
    });
  }

  void _stopDetection() {
    _detectionTimer?.cancel();
    setState(() {
      _isDetectionActive = false;
      _isProcessingFrame = false;
      _lastDetectionResult = null;
    });

    _showSuccess('Dừng phát hiện');
  }

  Future<void> _processFrame() async {
    if (!_isDetectionActive ||
        _isProcessingFrame ||
        !_cameraController!.value.isInitialized) {
      return;
    }

    setState(() {
      _isProcessingFrame = true;
    });

    try {
      // Capture image
      final XFile image = await _cameraController!.takePicture();

      // Send to detection service for JSON result only
      debugPrint(' Sending image to server: ${image.path}');
      final result = await _detectionService.detectFromImage(image.path);
      debugPrint(
        ' Received detection result with ${result.detections.length} objects',
      );

      if (mounted) {
        setState(() {
          _lastDetectionResult = result;
          _totalFramesProcessed++;

          if (result.detections.isNotEmpty) {
            _totalDetections += result.detections.length;

            // Send fire/smoke alert notifications
            _sendAlertNotifications(result);
          }

          // Show alert if fire or smoke detected
        });
      }
    } catch (e) {
      print('Detection error: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isProcessingFrame = false;
        });
      }
    }
  }


  void _sendAlertNotifications(DetectionResult result) async {
    // Send notifications for fire/smoke detection
    bool hasFire = result.detections.any(
      (d) => (d['class'] as String).toLowerCase() == 'fire',
    );
    bool hasSmoke = result.detections.any(
      (d) => (d['class'] as String).toLowerCase() == 'smoke',
    );

    if (hasFire) {
      await NotificationService().sendFireAlert(
        location: 'Camera Live Detection',
        confidence: result.detections
            .where((d) => (d['class'] as String).toLowerCase() == 'fire')
            .map((d) => (d['confidence'] as double))
            .reduce((a, b) => a > b ? a : b),
      );
    }

    if (hasSmoke) {
      await NotificationService().sendSmokeAlert(
        location: 'Camera Live Detection',
        confidence: result.detections
            .where((d) => (d['class'] as String).toLowerCase() == 'smoke')
            .map((d) => (d['confidence'] as double))
            .reduce((a, b) => a > b ? a : b),
      );
    }
  }

  Future<void> _switchCamera() async {
    if (_cameras == null || _cameras!.length < 2) return;

    _currentCameraIndex = (_currentCameraIndex + 1) % _cameras!.length;

    await _cameraController?.dispose();
    await _initializeCamera();
  }

  String _getSessionStats() {
    if (_sessionStartTime == null) return '';

    final duration = DateTime.now().difference(_sessionStartTime!);
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;

    return 'Thời gian: ${minutes}m ${seconds}s | '
        'Khung hình: $_totalFramesProcessed | '
        'Phát hiện: $_totalDetections';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Phát Hiện Lửa Real-time'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        actions: [
          if (_cameras != null && _cameras!.length > 1)
            IconButton(
              onPressed: _switchCamera,
              icon: const Icon(Icons.flip_camera_ios),
              tooltip: 'Chuyển camera',
            ),
        ],
      ),
      body:
          _isCameraInitialized
              ? Column(
                children: [
                  // Camera Preview
                  Expanded(
                    flex: 3,
                    child: Stack(
                      children: [
                        // Camera view with bounding boxes overlay
                        Center(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: AspectRatio(
                              aspectRatio: 3 / 4, // Standard phone camera ratio
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  // Live camera preview
                                  CameraPreview(_cameraController!),

                                  // Real-time bounding boxes overlay
                                  if (_lastDetectionResult != null)
                                    _buildDetectionOverlay(),
                                ],
                              ),
                            ),
                          ),
                        ),

                        // Detection overlay
                        if (_lastDetectionResult != null)
                          _buildDetectionOverlay(),

                        // Processing indicator
                        if (_isProcessingFrame)
                          const Positioned(
                            top: 20,
                            right: 20,
                            child: CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.orange,
                              ),
                              strokeWidth: 3,
                            ),
                          ),

                        // Status indicator
                        Positioned(
                          top: 20,
                          left: 20,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color:
                                  _isDetectionActive
                                      ? Colors.green.withOpacity(0.8)
                                      : Colors.grey.withOpacity(0.8),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _isDetectionActive
                                      ? Icons.visibility
                                      : Icons.visibility_off,
                                  color: Colors.white,
                                  size: 16,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _isDetectionActive
                                      ? 'ĐANG PHÁT HIỆN'
                                      : 'TẠM DỪNG',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Detection Results Panel
                  Expanded(
                    flex: 1,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(20),
                        ),
                      ),
                      child: _buildDetectionPanel(),
                    ),
                  ),
                ],
              )
              : const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text(
                      'Đang khởi tạo camera...',
                      style: TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
      floatingActionButton:
          _isCameraInitialized
              ? FloatingActionButton.extended(
                onPressed: _toggleDetection,
                backgroundColor:
                    _isDetectionActive ? Colors.red : kPrimaryColor,
                icon: Icon(_isDetectionActive ? Icons.stop : Icons.play_arrow),
                label: Text(
                  _isDetectionActive ? 'DỪNG' : 'BẮT ĐẦU',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              )
              : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildDetectionOverlay() {
    final result = _lastDetectionResult!;

    return Positioned.fill(
      child: CustomPaint(painter: DetectionOverlayPainter(result)),
    );
  }

  Widget _buildDetectionPanel() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Session Stats
          if (_sessionStartTime != null) ...[
            Text(
              'Thống kê phiên làm việc',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              _getSessionStats(),
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
          ],

          // Detection Results
          Text(
            'Kết quả phát hiện',
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),

          if (_lastDetectionResult != null) ...[
            _buildDetectionCard(_lastDetectionResult!),
          ] else ...[
            const Text(
              'Chưa có kết quả phát hiện',
              style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDetectionCard(DetectionResult result) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: result.hasFireOrSmoke ? Colors.red : Colors.green,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    result.message,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: result.hasFireOrSmoke ? Colors.red : Colors.green,
                    ),
                  ),
                ),
              ],
            ),

            if (result.detections.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Chi tiết: ${result.detections.length} đối tượng phát hiện',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 8,
                children:
                    result.detections.map((detection) {
                      return Chip(
                        label: Text(
                          '${detection['class']} (${(detection['confidence'] * 100).toStringAsFixed(1)}%)',
                          style: const TextStyle(fontSize: 12),
                        ),
                        backgroundColor:
                            detection['class'].toLowerCase() == 'fire'
                                ? Colors.orange.withOpacity(0.2)
                                : Colors.blue.withOpacity(0.2),
                      );
                    }).toList(),
              ),
            ],

            const SizedBox(height: 4),
            Text(
              'Cập nhật: ${DateTime.parse(result.timestamp).toString().substring(11, 19)}',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }
}

// Custom painter for detection overlay
class DetectionOverlayPainter extends CustomPainter {
  final DetectionResult result;

  DetectionOverlayPainter(this.result);

  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3;

    // Draw bounding boxes (this is a simplified version)
    // In a real implementation, you'd need to scale the coordinates
    // from the detection result to match the camera preview size

    for (final detection in result.detections) {
      final bbox = detection['bbox'];
      final className = detection['class'];
      final confidence = detection['confidence'];

      // Set color and Vietnamese label based on class
      Color boxColor;
      String vietnameseLabel;
      if (className.toLowerCase() == 'fire') {
        boxColor = Colors.red;
        vietnameseLabel = '🔥 LỬA';
      } else {
        boxColor = Colors.orange;
        vietnameseLabel = '💨 KHÓI';
      }

      paint.color = boxColor;
      paint.strokeWidth = 4;

      // Scale coordinates from detection result to current screen size
      // The detection coordinates are already normalized or in pixel coordinates
      final rect = Rect.fromLTRB(
        (bbox['x1'] as double) * size.width / 640,
        (bbox['y1'] as double) * size.height / 480,
        (bbox['x2'] as double) * size.width / 640,
        (bbox['y2'] as double) * size.height / 480,
      );

      // Draw bounding box
      canvas.drawRect(rect, paint);

      // Draw corner markers
      final cornerSize = 15.0;
      paint.style = PaintingStyle.fill;
      canvas.drawRect(
        Rect.fromLTWH(rect.left, rect.top, cornerSize, cornerSize),
        paint,
      );
      canvas.drawRect(
        Rect.fromLTWH(
          rect.right - cornerSize,
          rect.top,
          cornerSize,
          cornerSize,
        ),
        paint,
      );
      canvas.drawRect(
        Rect.fromLTWH(
          rect.left,
          rect.bottom - cornerSize,
          cornerSize,
          cornerSize,
        ),
        paint,
      );
      canvas.drawRect(
        Rect.fromLTWH(
          rect.right - cornerSize,
          rect.bottom - cornerSize,
          cornerSize,
          cornerSize,
        ),
        paint,
      );

      // Reset paint style
      paint.style = PaintingStyle.stroke;

      // Draw label with Vietnamese text
      final confidencePercent = (confidence * 100).toStringAsFixed(1);
      final textSpan = TextSpan(
        text: '$vietnameseLabel $confidencePercent%',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.bold,
          shadows: [Shadow(blurRadius: 2, color: Colors.black)],
        ),
      );

      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();

      // Draw semi-transparent background for text
      final bgHeight = textPainter.height + 8;
      final bgWidth = textPainter.width + 16;
      canvas.drawRRect(
        RRect.fromLTRBR(
          rect.left,
          rect.top - bgHeight - 4,
          rect.left + bgWidth,
          rect.top - 4,
          const Radius.circular(4),
        ),
        Paint()..color = boxColor.withOpacity(0.9),
      );

      // Draw text
      textPainter.paint(canvas, Offset(rect.left + 8, rect.top - bgHeight + 2));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
