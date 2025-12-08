import 'package:flutter/material.dart';
import '../services/esp32_streaming_service.dart';

class StreamingView extends StatefulWidget {
  final Function(Map<String, dynamic>) onFireAlert;
  final Function(String) onError;
  final Function(String) onSuccess;
  final Map<String, dynamic>? predictionResult;
  final bool isProcessing;

  const StreamingView({
    Key? key,
    required this.onFireAlert,
    required this.onError,
    required this.onSuccess,
    this.predictionResult,
    required this.isProcessing,
  }) : super(key: key);

  @override
  State<StreamingView> createState() => _StreamingViewState();
}

class _StreamingViewState extends State<StreamingView> {
  final ESP32StreamingService _streamingService = ESP32StreamingService();

  @override
  void initState() {
    super.initState();
    _streamingService.setCallbacks(
      onFireDetected: widget.onFireAlert,
      onError: widget.onError,
      onSuccess: widget.onSuccess,
      onStateChanged: () => setState(() {}),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ESP32 Connection Status
        _buildConnectionStatus(),
        const SizedBox(height: 16),

        // Auto Detection Toggle
        _buildAutoDetectionToggle(),
        const SizedBox(height: 20),

        // Live Stream Preview
        _buildStreamPreview(),
        const SizedBox(height: 20),

        // Streaming Controls
        _buildStreamingControls(),

        // Detection Results
        if (widget.predictionResult != null) ...[
          const SizedBox(height: 20),
          _buildDetectionResults(),
        ],

        // Bounding Box Image
        if (_streamingService.boundingBoxImage != null) ...[
          const SizedBox(height: 16),
          _buildBoundingBoxImage(),
        ],
      ],
    );
  }

  Widget _buildConnectionStatus() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color:
            _streamingService.isConnected ? Colors.green[50] : Colors.red[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _streamingService.isConnected ? Colors.green : Colors.red,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            _streamingService.isConnected ? Icons.wifi : Icons.wifi_off,
            color: _streamingService.isConnected ? Colors.green : Colors.red,
            size: 24,
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _streamingService.isConnected
                      ? 'ESP32-CAM Đã Kết Nối'
                      : 'ESP32-CAM Ngắt Kết Nối',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color:
                        _streamingService.isConnected
                            ? Colors.green[700]
                            : Colors.red[700],
                  ),
                ),
                if (_streamingService.isConnected)
                  Text(
                    'IP: ${_streamingService.esp32IP}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
              ],
            ),
          ),
          TextButton(
            onPressed:
                _streamingService.isConnected
                    ? _streamingService.disconnectESP32
                    : _streamingService.connectESP32,
            child: Text(
              _streamingService.isConnected ? 'Ngắt Kết Nối' : 'Kết Nối',
              style: TextStyle(
                color:
                    _streamingService.isConnected ? Colors.red : Colors.green,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAutoDetectionToggle() {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue[200]!, width: 1),
      ),
      child: Row(
        children: [
          Icon(Icons.auto_awesome, color: Colors.blue[600], size: 20),
          SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tự Động Phát Hiện Lửa/Khói',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[700],
                    fontSize: 13,
                  ),
                ),
                Text(
                  _streamingService.autoDetectionEnabled
                      ? 'Đang phân tích real-time với YOLO AI'
                      : 'Chỉ hiển thị video, không phân tích',
                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          Switch(
            value: _streamingService.autoDetectionEnabled,
            onChanged: _streamingService.setAutoDetection,
            activeColor: Colors.blue[600],
          ),
        ],
      ),
    );
  }

  Widget _buildStreamPreview() {
    return Container(
      height: 300,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child:
            _streamingService.currentFrame != null
                ? Image.memory(
                  _streamingService.currentFrame!,
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                )
                : Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.videocam_off,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      SizedBox(height: 16),
                      Text(
                        _streamingService.isConnected
                            ? 'Nhấn "Bắt Đầu Stream" để xem video trực tiếp'
                            : 'Kết nối ESP32-CAM để xem video',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey[400], fontSize: 14),
                      ),
                    ],
                  ),
                ),
      ),
    );
  }

  Widget _buildStreamingControls() {
    return Row(
      children: [
        Expanded(
          child: _buildActionButton(
            icon: _streamingService.isStreaming ? Icons.stop : Icons.play_arrow,
            label:
                _streamingService.isStreaming
                    ? 'Dừng Stream'
                    : 'Bắt Đầu Stream',
            gradient:
                _streamingService.isStreaming
                    ? [Colors.red[400]!, Colors.red[600]!]
                    : [Colors.green[400]!, Colors.green[600]!],
            onPressed:
                !_streamingService.isConnected
                    ? null
                    : () {
                      if (_streamingService.isStreaming) {
                        _streamingService.stopStreaming();
                      } else {
                        _streamingService.startStreaming();
                      }
                    },
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildActionButton(
            icon: Icons.camera_alt,
            label: 'Chụp & Phân Tích',
            gradient: [Colors.blue[400]!, Colors.blue[600]!],
            onPressed:
                !_streamingService.isConnected || widget.isProcessing
                    ? null
                    : _streamingService.captureAndAnalyze,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required List<Color> gradient,
    required VoidCallback? onPressed,
  }) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: gradient),
        borderRadius: BorderRadius.circular(14),
        boxShadow:
            onPressed != null
                ? [
                  BoxShadow(
                    color: gradient[0].withOpacity(0.4),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
                : [],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onPressed,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetectionResults() {
    final result = widget.predictionResult!;
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors:
              result['fire_detected'] == true
                  ? [Colors.red[50]!, Colors.orange[50]!]
                  : [Colors.green[50]!, Colors.blue[50]!],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: result['fire_detected'] == true ? Colors.red : Colors.green,
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                result['fire_detected'] == true
                    ? Icons.local_fire_department
                    : Icons.check_circle,
                color:
                    result['fire_detected'] == true
                        ? Colors.red[700]
                        : Colors.green[700],
                size: 24,
              ),
              SizedBox(width: 8),
              Text(
                result['fire_detected'] == true
                    ? '🚨 PHÁT HIỆN LỬA/KHÓI!'
                    : '✅ An Toàn',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color:
                      result['fire_detected'] == true
                          ? Colors.red[800]
                          : Colors.green[800],
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            'Độ tin cậy: ${(result['confidence'] * 100).toStringAsFixed(1)}%',
            style: TextStyle(fontSize: 14, color: Colors.grey[700]),
          ),
          if (result['detections'] != null && result['detections'].isNotEmpty)
            Text(
              'Phát hiện: ${result['detections'].length} vật thể',
              style: TextStyle(fontSize: 14, color: Colors.grey[700]),
            ),
          Text(
            'Thời gian: ${DateTime.now().toString().substring(11, 19)}',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildBoundingBoxImage() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange[300]!, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.orange[100],
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(10),
                topRight: Radius.circular(10),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.crop_free, color: Colors.orange[700], size: 16),
                SizedBox(width: 6),
                Text(
                  'BOUNDING BOXES (YOLO)',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange[700],
                  ),
                ),
              ],
            ),
          ),
          ClipRRect(
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(10),
              bottomRight: Radius.circular(10),
            ),
            child: Image.memory(
              _streamingService.boundingBoxImage!,
              fit: BoxFit.contain,
              width: double.infinity,
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    // Don't dispose the service as it's a singleton
    super.dispose();
  }
}
