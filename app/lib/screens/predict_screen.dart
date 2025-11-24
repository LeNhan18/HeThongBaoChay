import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
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
  String? _fileType; // 'image' or 'video'
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
        
        // Initialize video player
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
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Pick buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isProcessing ? null : _pickImage,
                    icon: const Icon(Icons.image),
                    label: const Text('Chọn Ảnh'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.all(16),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isProcessing ? null : _pickVideo,
                    icon: const Icon(Icons.video_library),
                    label: const Text('Chọn Video'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.all(16),
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 20),
            
            // Preview
            if (_selectedFile != null) ...[
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: _fileType == 'image'
                      ? Image.file(
                          _selectedFile!,
                          height: 300,
                          fit: BoxFit.contain,
                        )
                      : _videoController != null && _videoController!.value.isInitialized
                          ? AspectRatio(
                              aspectRatio: _videoController!.value.aspectRatio,
                              child: VideoPlayer(_videoController!),
                            )
                          : const SizedBox(
                              height: 300,
                              child: Center(child: CircularProgressIndicator()),
                            ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Video controls
              if (_fileType == 'video' && _videoController != null && _videoController!.value.isInitialized)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: Icon(
                        _videoController!.value.isPlaying
                            ? Icons.pause
                            : Icons.play_arrow,
                      ),
                      onPressed: () {
                        setState(() {
                          _videoController!.value.isPlaying
                              ? _videoController!.pause()
                              : _videoController!.play();
                        });
                      },
                    ),
                  ],
                ),
              
              const SizedBox(height: 16),
              
              // Predict button
              ElevatedButton.icon(
                onPressed: _isProcessing ? null : _predict,
                icon: _isProcessing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.psychology),
                label: Text(_isProcessing ? 'Đang xử lý...' : 'Dự Đoán'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                  backgroundColor: Colors.deepOrange,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
            
            const SizedBox(height: 20),
            
            // Results
            if (_predictionResult != null) ...[
              Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Kết Quả Dự Đoán',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Divider(),
                      const SizedBox(height: 8),
                      
                      // Display result based on structure
                      if (_predictionResult!.containsKey('fire_detected'))
                        _buildResultItem(
                          'Phát hiện cháy',
                          _predictionResult!['fire_detected'] ? 'CÓ' : 'KHÔNG',
                          _predictionResult!['fire_detected'] ? Colors.red : Colors.green,
                        ),
                      
                      if (_predictionResult!.containsKey('confidence'))
                        _buildResultItem(
                          'Độ tin cậy',
                          '${(_predictionResult!['confidence'] * 100).toStringAsFixed(2)}%',
                          Colors.blue,
                        ),
                      
                      if (_predictionResult!.containsKey('detections'))
                        _buildResultItem(
                          'Số vật thể phát hiện',
                          '${_predictionResult!['detections']}',
                          Colors.orange,
                        ),
                      
                      if (_predictionResult!.containsKey('processing_time'))
                        _buildResultItem(
                          'Thời gian xử lý',
                          '${_predictionResult!['processing_time'].toStringAsFixed(2)}s',
                          Colors.grey,
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildResultItem(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 16),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
