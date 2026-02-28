import 'package:flutter/material.dart';
import '../models/camera.dart';
import '../services/mock_api_service.dart';
import 'live_view_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final MockApiService _apiService = MockApiService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: FutureBuilder<List<Camera>>(
        future: _apiService.fetchCameras(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Container(
              color: Colors.grey[50],
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Đang tải danh sách camera...'),
                  ],
                ),
              ),
            );
          }

          if (snapshot.hasError) {
            return Container(
              color: Colors.grey[50],
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, size: 64, color: Colors.red),
                    SizedBox(height: 16),
                    Text('Lỗi: ${snapshot.error}', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            );
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Container(
              color: Colors.grey[50],
              child: const Center(
                child: Text('Không có camera nào'),
              ),
            );
          }

          return ListView.builder(
            itemCount: snapshot.data!.length,
            itemBuilder: (context, index) {
              final camera = snapshot.data![index];
              return Card(
                margin: const EdgeInsets.all(8.0),
                child: ListTile(
                  leading: Icon(
                    camera.isESP32
                        ? (camera.status == 'online'
                            ? Icons.camera_alt
                            : Icons.camera_alt_outlined)
                        : (camera.status == 'online'
                            ? Icons.videocam
                            : Icons.videocam_off),
                    color:
                        camera.status == 'online' 
                            ? (camera.isESP32 ? Colors.orange : Colors.green)
                            : Colors.grey,
                    size: 30,
                  ),
                  title: Text(
                    camera.name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        camera.status == 'online' ? 'Trực tuyến' : 'Ngoại tuyến',
                        style: TextStyle(
                          color:
                              camera.status == 'online'
                                  ? Colors.green
                                  : Colors.grey,
                        ),
                      ),
                      if (camera.isESP32 && camera.ip != null)
                        Text(
                          camera.port != null
                              ? 'IP: ${camera.ip}:${camera.port}'
                              : 'IP: ${camera.ip}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                    ],
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => LiveViewScreen(camera: camera),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
