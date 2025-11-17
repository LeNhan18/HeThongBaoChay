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
      body: FutureBuilder<List<Camera>>(
        future: _apiService.fetchCameras(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Lỗi: ${snapshot.error}'));
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('Không có camera nào'));
          }

          return ListView.builder(
            itemCount: snapshot.data!.length,
            itemBuilder: (context, index) {
              final camera = snapshot.data![index];
              return Card(
                margin: const EdgeInsets.all(8.0),
                child: ListTile(
                  leading: Icon(
                    camera.status == 'online'
                        ? Icons.videocam
                        : Icons.videocam_off,
                    color:
                        camera.status == 'online' ? Colors.green : Colors.grey,
                    size: 30,
                  ),
                  title: Text(
                    camera.name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    camera.status == 'online' ? 'Trực tuyến' : 'Ngoại tuyến',
                    style: TextStyle(
                      color:
                          camera.status == 'online'
                              ? Colors.green
                              : Colors.grey,
                    ),
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
