import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/camera.dart';
import '../constants.dart';

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

  @override
  void initState() {
    super.initState();
    _startCamera();
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
    _stopCamera();
    super.dispose();
  }

  Future<void> _stopCamera() async {
    try {
      await http.post(Uri.parse('$apiBaseUrl/camera/stop/'));
    } catch (e) {
      debugPrint('Error stopping camera: $e');
    }
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
                    child: Image.network(
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
                : const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Starting camera...'),
                    ],
                  ),
      ),
    );
  }
}







