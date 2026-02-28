import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import '../models/camera.dart';
import '../constants.dart';
import '../services/esp32_camera_service.dart';
import '../config/api_config.dart';

class LiveViewScreen extends StatefulWidget {
  final Camera camera;
  const LiveViewScreen({super.key, required this.camera});

  @override
  State<LiveViewScreen> createState() => _LiveViewScreenState();
}

class _LiveViewScreenState extends State<LiveViewScreen> {
  bool _isCameraStarted = false;
  String _cameraStatus = 'Connecting...';
  String? _error;
  final ESP32CameraService _esp32Service = ESP32CameraService();
  Timer? _refreshTimer;
  bool _isESP32Connected = false;

  @override
  void initState() {
    super.initState();
    if (widget.camera.isESP32) {
      _connectESP32();
    } else {
      _startCamera();
    }
  }

  Future<void> _startCamera() async {
    try {
      // Start camera 0 by default as per main.py
      final response = await http.post(Uri.parse('$apiBaseUrl/camera/start/?camera_index=0'));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (mounted) {
          setState(() {
            _isCameraStarted = true;
            _cameraStatus = data['camera_status'] == 'online' ? 'Online' : 'Offline';
          });
        }
      } else if (response.statusCode == 400) {
         // Already running
         if (mounted) {
          setState(() {
            _isCameraStarted = true;
            _cameraStatus = 'Online';
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _error = 'Failed to start camera: ${response.statusCode}';
            _cameraStatus = 'Error';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Error starting camera: $e';
          _cameraStatus = 'Error';
        });
      }
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    if (widget.camera.isESP32) {
      // ESP32 không cần stop, chỉ cần cancel timer
    } else {
      _stopCamera();
    }
    super.dispose();
  }

  Future<void> _stopCamera() async {
    try {
      await http.post(Uri.parse('$apiBaseUrl/camera/stop/'));
    } catch (e) {
      debugPrint('Error stopping camera: $e');
    }
  }

  Future<void> _connectESP32() async {
    if (widget.camera.ip == null || widget.camera.ip!.isEmpty) {
      if (mounted) {
        setState(() {
          _error = 'ESP32-CAM không có địa chỉ IP';
          _cameraStatus = 'Error';
        });
      }
      return;
    }

    setState(() {
      _cameraStatus = widget.camera.isFlaskServer 
          ? 'Đang kết nối Flask server...' 
          : 'Đang kết nối ESP32...';
      _isCameraStarted = false;
    });

    try {
      // Nếu là Flask server, chỉ cần kiểm tra health endpoint
      if (widget.camera.isFlaskServer && widget.camera.port != null) {
        final healthUrl = 'http://${widget.camera.ip}:${widget.camera.port}/health';
        final response = await http.get(Uri.parse(healthUrl)).timeout(
          const Duration(seconds: 5),
        );
        
        if (mounted) {
          setState(() {
            _isESP32Connected = response.statusCode == 200;
            _isCameraStarted = _isESP32Connected;
            _cameraStatus = _isESP32Connected ? 'Online' : 'Offline';
            _error = _isESP32Connected ? null : 'Không thể kết nối Flask server';
          });
        }
      } else {
        // Kết nối qua backend API
        final result = await _esp32Service.connectToESP32(widget.camera.ip!);
        
        if (mounted) {
          setState(() {
            _isESP32Connected = result['status'] == 'connected';
            _isCameraStarted = _isESP32Connected;
            _cameraStatus = _isESP32Connected ? 'Online' : 'Offline';
            _error = _isESP32Connected ? null : result['message'] ?? 'Kết nối thất bại';
          });
        }
      }

      if (_isESP32Connected) {
        _startRefreshTimer();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = widget.camera.isFlaskServer 
              ? 'Lỗi kết nối Flask server: $e'
              : 'Lỗi kết nối ESP32: $e';
          _cameraStatus = 'Error';
          _isESP32Connected = false;
        });
      }
    }
  }

  void _startRefreshTimer() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _isESP32Connected) {
        setState(() {
          // Force rebuild to refresh image with new timestamp
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.camera.name),
            Text(
              'Status: $_cameraStatus',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
            ),
          ],
        ),
      ),
      body: Center(
        child: _error != null
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(_error!, style: const TextStyle(color: Colors.red)),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _error = null;
                      });
                      _startCamera();
                    },
                    child: const Text('Retry'),
                  ),
                ],
              )
            : _isCameraStarted
                ? AspectRatio(
                    aspectRatio: 16 / 9,
                    child: widget.camera.isESP32
                        ? _buildESP32Stream()
                        : Image.network(
                            '$apiBaseUrl/camera/stream/?camera_index=0',
                            fit: BoxFit.cover,
                            gaplessPlayback: true,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                color: Colors.grey[300],
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.videocam_off, size: 50, color: Colors.grey),
                                    const SizedBox(height: 16),
                                    const Text('Stream connection failed'),
                                    const SizedBox(height: 8),
                                    ElevatedButton(
                                      onPressed: () {
                                        setState(() {
                                          // Force rebuild image
                                          _isCameraStarted = false;
                                        });
                                        Future.delayed(const Duration(milliseconds: 500), () {
                                          if (mounted) {
                                            setState(() {
                                              _isCameraStarted = true;
                                            });
                                          }
                                        });
                                      },
                                      child: const Text('Reconnect'),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 16),
                      Text(widget.camera.isESP32 
                          ? 'Đang kết nối ESP32-CAM...' 
                          : 'Starting camera...'),
                    ],
                  ),
      ),
    );
  }

  Widget _buildESP32Stream() {
    if (!_isESP32Connected || widget.camera.ip == null) {
      return Container(
        color: Colors.grey[300],
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.videocam_off, size: 50, color: Colors.grey),
            const SizedBox(height: 16),
            const Text('ESP32-CAM chưa kết nối'),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _connectESP32,
              child: const Text('Kết nối lại'),
            ),
          ],
        ),
      );
    }

    // Kiểm tra nếu là Flask server (port 5000) hoặc backend API (port 8000)
    final String streamUrl;
    if (widget.camera.isFlaskServer && widget.camera.port != null) {
      // Kết nối đến Flask server
      streamUrl = 'http://${widget.camera.ip}:${widget.camera.port}/frame?t=${DateTime.now().millisecondsSinceEpoch}';
    } else {
      // Kết nối đến backend API
      streamUrl = '${ApiConfig.getApiBaseUrl()}/esp32/capture_with_boxes'
          '?esp32_ip=${widget.camera.ip}'
          '&confidence=0.25'
          '&t=${DateTime.now().millisecondsSinceEpoch}';
    }

    return Image.network(
      streamUrl,
      fit: BoxFit.cover,
      gaplessPlayback: true,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return Container(
          color: Colors.black,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(
                  value: loadingProgress.expectedTotalBytes != null
                      ? loadingProgress.cumulativeBytesLoaded /
                          loadingProgress.expectedTotalBytes!
                      : null,
                ),
                const SizedBox(height: 16),
                Text(
                  widget.camera.isFlaskServer 
                      ? 'Đang tải stream từ Flask server...'
                      : 'Đang tải stream ESP32...',
                  style: const TextStyle(color: Colors.white),
                ),
              ],
            ),
          ),
        );
      },
      errorBuilder: (context, error, stackTrace) {
        return Container(
          color: Colors.grey[300],
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.videocam_off, size: 50, color: Colors.grey),
              const SizedBox(height: 16),
              Text(
                widget.camera.isFlaskServer
                    ? 'Không thể tải stream từ Flask server\nIP: ${widget.camera.ip}:${widget.camera.port}'
                    : 'Không thể tải stream ESP32\nIP: ${widget.camera.ip}',
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: _connectESP32,
                child: const Text('Kết nối lại'),
              ),
            ],
          ),
        );
      },
    );
  }
}







