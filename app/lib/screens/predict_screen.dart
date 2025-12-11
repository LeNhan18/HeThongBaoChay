import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/foundation.dart';
import 'dart:io' show Platform;
import 'dart:typed_data';
import '../services/prediction_service.dart';
import '../services/notification_service.dart';
import '../utils/platform_utils.dart' as platform_utils;
import '../utils/network_utils.dart';
import '../config/api_config.dart';

// Platform-specific imports
import 'dart:io' as io if (dart.library.io) 'dart:io';

class PredictScreen extends StatefulWidget {
  const PredictScreen({super.key});

  @override
  State<PredictScreen> createState() => _PredictScreenState();
}

class _PredictScreenState extends State<PredictScreen> {
  final PredictionService _predictionService = PredictionService();
  final ImagePicker _picker = ImagePicker();

  dynamic _selectedFile;
  String? _fileType;
  bool _isProcessing = false;
  Map<String, dynamic>? _predictionResult;
  VideoPlayerController? _videoController;

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        setState(() {
          _selectedFile =
              image; // Always use XFile for cross-platform compatibility
          _fileType = 'image';
          _predictionResult = null;
          _videoController?.dispose();
          _videoController = null;
        });
      }
    } catch (e) {
      _showError('Lỗi chọn ảnh: $e');
    }
  }

  Future<void> _pickVideo() async {
    try {
      if (kIsWeb) {
        _showError(
          'Chức năng video chưa hỗ trợ đầy đủ trên web browser. Vui lòng sử dụng ứng dụng mobile để có trải nghiệm tốt nhất.',
        );
        return;
      }

      final XFile? video = await _picker.pickVideo(source: ImageSource.gallery);
      if (video != null) {
        setState(() {
          _selectedFile = video;
          _fileType = 'video';
          _predictionResult = null;
        });

        _videoController?.dispose();
        if (kIsWeb) {
          // On web, create a blob URL for the video
          final bytes = await video.readAsBytes();
          final url = platform_utils.createImageUrl(bytes);
          _videoController = VideoPlayerController.networkUrl(Uri.parse(url));
        } else {
          _videoController = VideoPlayerController.file(io.File(video.path));
        }

        _videoController!.initialize().then((_) {
          setState(() {});
        });
      }
    } catch (e) {
      _showError('Lỗi chọn video: $e');
    }
  }

  Map<String, dynamic> _createDemoResult() {
    // Create realistic demo data for web testing
    final random = DateTime.now().millisecond;
    final hasFireOrSmoke = random % 3 == 0; // 33% chance of detection

    if (_fileType == 'image') {
      return {
        'fire_detected': hasFireOrSmoke,
        'confidence':
            hasFireOrSmoke
                ? 0.85 + (random % 15) / 100
                : 0.1 + (random % 20) / 100,
        'detections':
            hasFireOrSmoke
                ? [
                  {
                    'class': random % 2 == 0 ? 'fire' : 'smoke',
                    'confidence': 0.87,
                    'bbox': [100, 100, 200, 200],
                  },
                ]
                : [],
        'summary': {
          'fire': hasFireOrSmoke && random % 2 == 0 ? 1 : 0,
          'smoke': hasFireOrSmoke && random % 2 == 1 ? 1 : 0,
        },
      };
    } else {
      return {
        'fire_detected': hasFireOrSmoke,
        'confidence':
            hasFireOrSmoke
                ? 0.82 + (random % 18) / 100
                : 0.05 + (random % 25) / 100,
        'detections': hasFireOrSmoke ? 3 + (random % 5) : 0,
        'fire_count': hasFireOrSmoke ? 1 + (random % 3) : 0,
        'smoke_count': hasFireOrSmoke ? 1 + (random % 2) : 0,
        'has_bounding_boxes': hasFireOrSmoke,
        'summary': {
          'total_frames': 120,
          'fire_frames': hasFireOrSmoke ? 15 + (random % 10) : 0,
          'smoke_frames': hasFireOrSmoke ? 8 + (random % 8) : 0,
        },
      };
    }
  }

  Future<void> _predict() async {
    if (_selectedFile == null || _fileType == null) {
      _showError('Vui lòng chọn ảnh hoặc video');
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      Map<String, dynamic> result;

      if (kIsWeb) {
        // Demo mode only for web - simulate API response
        await Future.delayed(
          const Duration(seconds: 2),
        ); // Simulate processing time
        result = _createDemoResult();
        _showSuccess('🧪 Demo mode - Web không support real API');
      } else {
        // Real API call for mobile/desktop
        result = await _predictionService.uploadAndPredict(
          _selectedFile!,
          _fileType!,
        );
      }

      setState(() {
        _predictionResult = result;
      });

      if (result['fire_detected'] == true) {
        await NotificationService().showNotification(
          title: 'CẢNH BÁO CHÁY!',
          body:
              'Phát hiện lửa trong ${_fileType == 'video' ? 'video' : 'ảnh'} vừa phân tích!',
        );
      }

      _showSuccess('Dự đoán thành công!');
    } catch (e) {
      _showError('Lỗi dự đoán: $e');
    } finally {
      setState(() {
        _isProcessing = false;
      });

      // If video result is available, play it with bounding boxes
      if (!kIsWeb &&
          _predictionResult != null &&
          _predictionResult!.containsKey('result_video_path')) {
        final resultVideoPath = _predictionResult!['result_video_path'];
        debugPrint(' Result video path: $resultVideoPath');

        final videoFile = io.File(resultVideoPath);
        final exists = await videoFile.exists();
        final size = exists ? await videoFile.length() : 0;
        debugPrint(
          '📹 Result video exists: $exists, size: ${(size / (1024 * 1024)).toStringAsFixed(2)} MB',
        );

        if (exists && size > 0) {
          _videoController?.dispose();
          _videoController = VideoPlayerController.file(videoFile)
            ..initialize()
                .then((_) {
                  debugPrint(' Result video with bounding boxes initialized');
                  setState(() {});

                  // Show notification about bounding boxes
                  final hasBoxes =
                      _predictionResult!['has_bounding_boxes'] ?? false;
                  if (hasBoxes) {
                    final detections = _predictionResult!['detections'] ?? 0;
                    final fireCount = _predictionResult!['fire_count'] ?? 0;
                    final smokeCount = _predictionResult!['smoke_count'] ?? 0;

                    _showSuccess(
                      'Video phân tích hoàn tất với $detections phát hiện! '
                      '🔥 Lửa: $fireCount, 💨 Khói: $smokeCount',
                    );
                  }

                  _videoController!.play();
                })
                .catchError((error) {
                  debugPrint(' Error initializing result video: $error');
                  _showError('Lỗi khởi tạo video kết quả: $error');
                });
        } else {
          _showError('Video kết quả không hợp lệ hoặc bị lỗi');
        }
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red[600],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green[600],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _testConnection() async {
    final currentHost = ApiConfig.getApiBaseUrl();
    _showError(' Đang test kết nối đến $currentHost...');

    try {
      // Use the new test endpoint
      final result = await _predictionService.testConnection();

      if (result['success'] == true) {
        _showSuccess(
          ' ${result['message']}\n'
          ' Server IP: ${result['server_ip']}\n'
          ' Port: ${result['server_port']}\n'
          ' ${result['timestamp']}',
        );
      } else {
        _showError(' Test thất bại: ${result['error']}');

        // Try to find a working host with detailed logging
        _showError(' Đang tìm kiếm server khả dụng...');

        for (String host in ApiConfig.getHostsToTry()) {
          _showError('Testing: $host');
          bool hostWorks = await NetworkUtils.testConnection(host);
          if (hostWorks) {
            _showSuccess(' Tìm thấy server hoạt động: $host');
            _showSuccess(' Hãy cập nhật constants.dart với host này');
            return;
          } else {
            _showError(' $host không hoạt động');
          }
          // Small delay between tests
          await Future.delayed(Duration(milliseconds: 500));
        }

        _showError(
          '🔧 Không tìm thấy server nào hoạt động.\n'
          'Debug info:\n'
          '- Server chạy: uvicorn main:app --host 0.0.0.0 --port 8000\n'
          '- Kiểm tra firewall Windows\n'
          '- Đảm bảo điện thoại và PC cùng WiFi\n'
          '- IP hiện tại: 192.168.1.149\n'
          '- Thử disable Windows Defender Firewall tạm thời',
        );
      }
    } catch (e) {
      _showError('Lỗi test connection: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blue.shade50,
      appBar: AppBar(
        title: Text(
          '🔥 AI Fire Detection',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.blue.shade700,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Tiêu đề chính
            Center(
              child: Text(
                'Fire Detection System',
                style: GoogleFonts.poppins(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.red.shade700,
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Upload functionality - Simplified
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Text(
                      'Chọn file để phân tích',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _isProcessing ? null : _pickImage,
                            icon: const Icon(Icons.image),
                            label: const Text('Chọn ảnh'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue.shade600,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _isProcessing ? null : _pickVideo,
                            icon: const Icon(Icons.video_library),
                            label: const Text('Chọn video'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green.shade600,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Debug connection button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _testConnection,
                        icon: const Icon(Icons.wifi_find, size: 16),
                        label: const Text('Test kết nối Server'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange.shade600,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Show preview area
            if (_selectedFile != null) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                height: 300,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.3),
                      blurRadius: 5,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child:
                      _fileType == 'image'
                          ? (kIsWeb
                              ? Image.network(
                                (_selectedFile as XFile).path,
                                fit: BoxFit.contain,
                                errorBuilder: (context, error, stackTrace) {
                                  return FutureBuilder<Uint8List>(
                                    future:
                                        (_selectedFile as XFile).readAsBytes(),
                                    builder: (context, snapshot) {
                                      if (snapshot.hasData) {
                                        return Image.memory(
                                          snapshot.data!,
                                          fit: BoxFit.contain,
                                        );
                                      }
                                      return const Center(
                                        child: CircularProgressIndicator(),
                                      );
                                    },
                                  );
                                },
                              )
                              : FutureBuilder<Uint8List>(
                                future: (_selectedFile as XFile).readAsBytes(),
                                builder: (context, snapshot) {
                                  if (snapshot.hasData) {
                                    return Image.memory(
                                      snapshot.data!,
                                      fit: BoxFit.contain,
                                    );
                                  }
                                  return const Center(
                                    child: CircularProgressIndicator(),
                                  );
                                },
                              ))
                          : (_videoController != null &&
                              _videoController!.value.isInitialized)
                          ? AspectRatio(
                            aspectRatio: _videoController!.value.aspectRatio,
                            child: VideoPlayer(_videoController!),
                          )
                          : Center(
                            child: Icon(
                              Icons.video_library,
                              size: 64,
                              color: Colors.grey,
                            ),
                          ),
                ),
              ),

              const SizedBox(height: 16),

              // Show annotated image result with bounding boxes
              if (_fileType == 'image' &&
                  _predictionResult != null &&
                  _predictionResult!.containsKey('result_image_path') &&
                  _predictionResult!['has_bounding_boxes'] == true)
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange),
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        width: double.infinity,
                        color: Colors.orange,
                        child: Text(
                          'KẾT QUẢ PHÁT HIỆN (CÓ BOUNDING BOX)',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      Image.file(
                        io.File(_predictionResult!['result_image_path']),
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            height: 200,
                            child: Center(
                              child: Text(
                                'Không thể hiển thị ảnh kết quả',
                                style: TextStyle(color: Colors.grey),
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),

              // Video result indicator
              if (_fileType == 'video' &&
                  _predictionResult != null &&
                  _predictionResult!.containsKey('has_bounding_boxes') &&
                  _predictionResult!['has_bounding_boxes'] == true)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.green.withOpacity(0.1),
                        Colors.blue.withOpacity(0.1),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.visibility,
                        color: Colors.green[600],
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          ' Video này hiển thị bounding boxes với nhãn tiếng Việt',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Colors.green[700],
                          ),
                        ),
                      ),
                    ],
                  ),
                ).animate().fadeIn(duration: 600.ms).slideX(begin: 0.3),

              // Video controls
              if (_fileType == 'video' &&
                  _videoController != null &&
                  _videoController!.value.isInitialized)
                Center(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Colors.black87, Colors.black54],
                      ),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: IconButton(
                      iconSize: 32,
                      icon: Icon(
                        _videoController!.value.isPlaying
                            ? Icons.pause_circle_filled
                            : Icons.play_circle_filled,
                        color: Colors.white,
                      ),
                      onPressed: () {
                        setState(() {
                          _videoController!.value.isPlaying
                              ? _videoController!.pause()
                              : _videoController!.play();
                        });
                      },
                    ),
                  ).animate().scale(delay: 200.ms),
                ),

              const SizedBox(height: 20),

              // Predict button
              Container(
                height: 60,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors:
                        _isProcessing
                            ? [Colors.grey[400]!, Colors.grey[500]!]
                            : [Colors.deepOrange, Colors.orange[700]!],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.deepOrange.withOpacity(0.4),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _isProcessing ? null : _predict,
                    borderRadius: BorderRadius.circular(16),
                    child: Center(
                      child:
                          _isProcessing
                              ? Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 3,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Text(
                                    'Đang phân tích...',
                                    style: GoogleFonts.poppins(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              )
                              : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.auto_awesome,
                                    color: Colors.white,
                                    size: 24,
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    'Phân Tích Ngay',
                                    style: GoogleFonts.poppins(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                    ),
                  ),
                ),
              ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.2),

              const SizedBox(height: 16),

              // Test Notification Buttons
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _testFireNotification,
                      icon: Icon(Icons.local_fire_department),
                      label: Text('Test Báo Cháy'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _testSmokeNotification,
                      icon: Icon(Icons.smoke_free),
                      label: Text('Test Báo Khói'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ],

            // Results Area
            if (_predictionResult != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withOpacity(0.9),
                      Colors.white.withOpacity(0.7),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.6),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Colors.green[400]!, Colors.green[600]!],
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.analytics,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Kết Quả Phân Tích',
                          style: GoogleFonts.poppins(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    if (_predictionResult!.containsKey('fire_detected'))
                      _buildModernResultItem(
                        icon: Icons.local_fire_department,
                        label: 'Phát hiện cháy',
                        value:
                            _predictionResult!['fire_detected']
                                ? 'CÓ'
                                : 'KHÔNG',
                        valueColor:
                            _predictionResult!['fire_detected']
                                ? Colors.red
                                : Colors.green,
                        iconColor:
                            _predictionResult!['fire_detected']
                                ? Colors.red
                                : Colors.green,
                      ),

                    if (_predictionResult!.containsKey('confidence'))
                      _buildModernResultItem(
                        icon: Icons.speed,
                        label: 'Độ tin cậy',
                        value:
                            '${(_predictionResult!['confidence'] * 100).toStringAsFixed(1)}%',
                        valueColor: Colors.blue[700]!,
                        iconColor: Colors.blue,
                      ),

                    if (_predictionResult!.containsKey('detections'))
                      _buildModernResultItem(
                        icon: Icons.category,
                        label: 'Vật thể phát hiện',
                        value: '${_predictionResult!['detections']}',
                        valueColor: Colors.orange[700]!,
                        iconColor: Colors.orange,
                      ),

                    // Bounding Box Information for Video
                    if (_fileType == 'video' &&
                        _predictionResult!.containsKey('has_bounding_boxes'))
                      _buildBoundingBoxInfo(),

                    if (_predictionResult!.containsKey('processing_time'))
                      _buildModernResultItem(
                        icon: Icons.timer,
                        label: 'Thời gian xử lý',
                        value:
                            '${_predictionResult!['processing_time'].toStringAsFixed(2)}s',
                        valueColor: Colors.purple[700]!,
                        iconColor: Colors.purple,
                      ),
                  ],
                ),
              ).animate().fadeIn(duration: 500.ms).slideY(begin: 0.3),
            ],

            // Empty state
            if (_selectedFile == null)
              Container(
                height: 300,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.deepOrange.withOpacity(0.3),
                    width: 2,
                    style: BorderStyle.solid,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                          Icons.cloud_upload_outlined,
                          size: 80,
                          color: Colors.deepOrange.withOpacity(0.4),
                        )
                        .animate(onPlay: (controller) => controller.repeat())
                        .shimmer(duration: 2000.ms),
                    const SizedBox(height: 16),
                    Text(
                      'Chọn ảnh hoặc video\nđể bắt đầu phân tích',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        color: Colors.grey[600],
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn(duration: 800.ms),
          ],
        ),
      ),
    );
  }

  Widget _buildBoundingBoxInfo() {
    final hasBoxes = _predictionResult!['has_bounding_boxes'] ?? false;
    final fireCount = _predictionResult!['fire_count'] ?? 0;
    final smokeCount = _predictionResult!['smoke_count'] ?? 0;
    final framesProcessed = _predictionResult!['frames_processed'] ?? 0;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors:
              hasBoxes
                  ? [
                    Colors.green.withOpacity(0.1),
                    Colors.blue.withOpacity(0.1),
                  ]
                  : [
                    Colors.grey.withOpacity(0.1),
                    Colors.grey.withOpacity(0.05),
                  ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color:
              hasBoxes
                  ? Colors.green.withOpacity(0.3)
                  : Colors.grey.withOpacity(0.3),
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                hasBoxes ? Icons.check_box : Icons.check_box_outline_blank,
                color: hasBoxes ? Colors.green : Colors.grey,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  hasBoxes
                      ? ' Video có Bounding Boxes'
                      : ' Video không có phát hiện',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: hasBoxes ? Colors.green[700] : Colors.grey[600],
                  ),
                ),
              ),
            ],
          ),

          if (hasBoxes) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildDetectionBadge(
                    ' Lua',
                    fireCount,
                    Colors.red.withOpacity(0.1),
                    Colors.red,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildDetectionBadge(
                    ' Khói',
                    smokeCount,
                    Colors.grey.withOpacity(0.1),
                    Colors.grey,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),
            Text(
              ' $framesProcessed khung hình đã được phân tích',
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: Colors.grey[600],
                fontStyle: FontStyle.italic,
              ),
            ),

            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: Colors.green[600]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Video kết quả hiển thị các khung bounding box màu đỏ (lửa) và xanh (khói)',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: Colors.green[700],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            const SizedBox(height: 8),
            Text(
              'Không có lửa hoặc khói được phát hiện trong video này',
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: Colors.grey[600],
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDetectionBadge(
    String label,
    int count,
    Color bgColor,
    Color textColor,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: textColor.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          const SizedBox(width: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: textColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              count.toString(),
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernResultItem({
    required IconData icon,
    required String label,
    required String value,
    required Color valueColor,
    required Color iconColor,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.7),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: iconColor.withOpacity(0.3), width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
            ),
          ),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }

  // Test notification methods
  Future<void> _testFireNotification() async {
    try {
      await NotificationService().sendFireAlert(
        location: 'Khu vực test',
        confidence: 0.95,
      );
      _showSuccess(' Đã gửi thông báo test cháy!');
    } catch (e) {
      _showError('Lỗi gửi thông báo: $e');
    }
  }

  Future<void> _testSmokeNotification() async {
    try {
      await NotificationService().sendSmokeAlert(
        location: 'Khu vực test',
        confidence: 0.85,
      );
      _showSuccess(' Đã gửi thông báo test khói!');
    } catch (e) {
      _showError(' Lỗi gửi thông báo: $e');
    }
  }
}
