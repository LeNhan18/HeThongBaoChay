import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import 'package:glassmorphism/glassmorphism.dart';
import 'package:shimmer/shimmer.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/foundation.dart';
import '../services/prediction_service.dart';
import '../services/notification_service.dart';
import '../utils/platform_utils.dart' as platform_utils;

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
        // Demo mode for web - simulate API response
        await Future.delayed(
          const Duration(seconds: 2),
        ); // Simulate processing time
        result = _createDemoResult();
      } else {
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
        debugPrint('🎥 Result video path: $resultVideoPath');

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
                  debugPrint('✅ Result video with bounding boxes initialized');
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
                  debugPrint('❌ Error initializing result video: $error');
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

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.deepOrange.shade50,
            Colors.orange.shade50,
            Colors.amber.shade50,
          ],
        ),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Title with icon
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Colors.deepOrange, Colors.orange],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.deepOrange.withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.psychology,
                    color: Colors.white,
                    size: 28,
                  ),
                ).animate().scale(duration: 600.ms),
                const SizedBox(width: 16),
                Text(
                  'AI Dự Đoán Cháy',
                  style: GoogleFonts.poppins(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: Colors.deepOrange[800],
                  ),
                ).animate().fadeIn(duration: 600.ms).slideX(),
              ],
            ),

            const SizedBox(height: 24),

            // Action buttons with glassmorphism
            Row(
              children: [
                Expanded(
                  child: _buildActionButton(
                    icon: Icons.image_rounded,
                    label: 'Chọn Ảnh',
                    gradient: [Colors.blue[400]!, Colors.blue[600]!],
                    onPressed: _isProcessing ? null : _pickImage,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildActionButton(
                    icon: Icons.videocam_rounded,
                    label: 'Chọn Video',
                    gradient: [Colors.purple[400]!, Colors.purple[600]!],
                    onPressed: _isProcessing ? null : _pickVideo,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Preview area
            if (_selectedFile != null) ...[
              GlassmorphicContainer(
                width: double.infinity,
                height: 360,
                borderRadius: 20,
                blur: 20,
                alignment: Alignment.center,
                border: 2,
                linearGradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withOpacity(0.2),
                    Colors.white.withOpacity(0.05),
                  ],
                ),
                borderGradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withOpacity(0.5),
                    Colors.white.withOpacity(0.2),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
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
                            child: Shimmer.fromColors(
                              baseColor: Colors.grey[300]!,
                              highlightColor: Colors.grey[100]!,
                              child: const Icon(Icons.video_library, size: 64),
                            ),
                          ),
                ),
              ).animate().fadeIn(duration: 400.ms).scale(delay: 100.ms),

              const SizedBox(height: 16),

              // Show annotated image result with bounding boxes
              if (_fileType == 'image' &&
                  _predictionResult != null &&
                  _predictionResult!.containsKey('result_image_path') &&
                  _predictionResult!['has_bounding_boxes'] == true)
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          width: double.infinity,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.orange.withOpacity(0.8),
                                Colors.red.withOpacity(0.8),
                              ],
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.visibility,
                                color: Colors.white,
                                size: 16,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'KẾT QUẢ PHÁT HIỆN (CÓ BOUNDING BOX)',
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
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
                                  style: GoogleFonts.poppins(
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ).animate().fadeIn(duration: 800.ms).scale(delay: 200.ms),

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
                          '🎯 Video này hiển thị bounding boxes với nhãn tiếng Việt',
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
                    child: _buildTestButton(
                      'Test Báo Cháy',
                      Icons.local_fire_department,
                      Colors.red,
                      () => _testFireNotification(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildTestButton(
                      'Test Báo Khói',
                      Icons.smoke_free,
                      Colors.grey,
                      () => _testSmokeNotification(),
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
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 22),
              const SizedBox(width: 8),
              Text(
                label,
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
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
                      ? '🎥 Video có Bounding Boxes'
                      : '🎥 Video không có phát hiện',
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
                    '🔥 Lửa',
                    fireCount,
                    Colors.red.withOpacity(0.1),
                    Colors.red,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildDetectionBadge(
                    '💨 Khói',
                    smokeCount,
                    Colors.blue.withOpacity(0.1),
                    Colors.blue,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),
            Text(
              '📊 $framesProcessed khung hình đã được phân tích',
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
    ).animate().fadeIn(delay: 100.ms).slideX(begin: 0.2);
  }

  // Test notification methods
  Future<void> _testFireNotification() async {
    try {
      await NotificationService().sendFireAlert(
        location: 'Khu vực test',
        confidence: 0.95,
      );
      _showSuccess('✅ Đã gửi thông báo test cháy!');
    } catch (e) {
      _showError('❌ Lỗi gửi thông báo: $e');
    }
  }

  Future<void> _testSmokeNotification() async {
    try {
      await NotificationService().sendSmokeAlert(
        location: 'Khu vực test',
        confidence: 0.85,
      );
      _showSuccess('✅ Đã gửi thông báo test khói!');
    } catch (e) {
      _showError('❌ Lỗi gửi thông báo: $e');
    }
  }

  Widget _buildTestButton(
    String text,
    IconData icon,
    Color color,
    VoidCallback onPressed,
  ) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withOpacity(0.7), color.withOpacity(0.9)],
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 18),
              const SizedBox(width: 6),
              Text(
                text,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
