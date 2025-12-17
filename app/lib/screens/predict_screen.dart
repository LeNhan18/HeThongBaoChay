import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import 'package:glassmorphism/glassmorphism.dart';
import 'package:shimmer/shimmer.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:io';
import '../services/prediction_service.dart';

class PredictScreen extends StatefulWidget {
  const PredictScreen({super.key});

  @override
  State<PredictScreen> createState() => _PredictScreenState();
}

class _PredictScreenState extends State<PredictScreen> {
  final PredictionService _predictionService = PredictionService();
  final ImagePicker _picker = ImagePicker();

  File? _selectedFile;
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
          _selectedFile = File(image.path);
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
      final XFile? video = await _picker.pickVideo(source: ImageSource.gallery);
      if (video != null) {
        final file = File(video.path);
        setState(() {
          _selectedFile = file;
          _fileType = 'video';
          _predictionResult = null;
        });

        _videoController?.dispose();
        _videoController = VideoPlayerController.file(file)
          ..initialize().then((_) {
            setState(() {});
          });
      }
    } catch (e) {
      _showError('Lỗi chọn video: $e');
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
      final result = await _predictionService.uploadAndPredict(
        _selectedFile!,
        _fileType!,
      );

      setState(() {
        _predictionResult = result;
      });

      _showSuccess('Dự đoán thành công!');
    } catch (e) {
      _showError('Lỗi dự đoán: $e');
    } finally {
      setState(() {
        _isProcessing = false;
      });
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
        // Đã thêm tham số child cho SingleChildScrollView
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
                  child: const Icon(Icons.psychology, color: Colors.white, size: 28),
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

            // Preview area (Sử dụng spread operator ...[])
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
                  child: _fileType == 'image'
                      ? Image.file(
                    _selectedFile!,
                    fit: BoxFit.contain,
                  )
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
                      child:
                      const Icon(Icons.video_library, size: 64),
                    ),
                  ),
                ),
              ).animate().fadeIn(duration: 400.ms).scale(delay: 100.ms),

              const SizedBox(height: 16),

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
                    colors: _isProcessing
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
                      child: _isProcessing
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
                          const Icon(Icons.auto_awesome,
                              color: Colors.white, size: 24),
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
            ], // Kết thúc spread operator cho phần Preview

            const SizedBox(height: 24),

            // Results Area (Sử dụng spread operator ...[])
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
                          child: const Icon(Icons.analytics,
                              color: Colors.white, size: 24),
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
                        value: _predictionResult!['fire_detected']
                            ? 'CÓ'
                            : 'KHÔNG',
                        valueColor: _predictionResult!['fire_detected']
                            ? Colors.red
                            : Colors.green,
                        iconColor: _predictionResult!['fire_detected']
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
            ], // Kết thúc spread operator cho phần Results

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
        boxShadow: onPressed != null
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
        border: Border.all(
          color: iconColor.withOpacity(0.3),
          width: 1.5,
        ),
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
}