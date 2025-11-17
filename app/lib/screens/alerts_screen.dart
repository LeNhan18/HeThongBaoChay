import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/alert.dart';
import '../services/mock_api_service.dart';

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  final MockApiService _apiService = MockApiService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<List<Alert>>(
        future: _apiService.fetchAlerts(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Lỗi: ${snapshot.error}'));
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('Không có cảnh báo nào'));
          }

          return ListView.builder(
            itemCount: snapshot.data!.length,
            itemBuilder: (context, index) {
              final alert = snapshot.data![index];
              return Card(
                margin: const EdgeInsets.all(8.0),
                child: ListTile(
                  leading: Icon(
                    alert.type == 'fire'
                        ? Icons.local_fire_department
                        : Icons.smoke_free,
                    color: alert.type == 'fire' ? Colors.red : Colors.grey,
                    size: 30,
                  ),
                  title: Text(
                    alert.type == 'fire' ? 'PHÁT HIỆN LỬA!' : 'Phát Hiện Khói',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: alert.type == 'fire' ? Colors.red : Colors.orange,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Camera: ${alert.cameraName}'),
                      Text(_formatTimestamp(alert.timestamp)),
                    ],
                  ),
                  onTap: () {
                    _showAlertDialog(context, alert);
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }

  String _formatTimestamp(String timestamp) {
    try {
      final dateTime = DateTime.parse(timestamp);
      final formatter = DateFormat('HH:mm, dd/MM/yyyy');
      return formatter.format(dateTime);
    } catch (e) {
      return timestamp;
    }
  }

  void _showAlertDialog(BuildContext context, Alert alert) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            alert.type == 'fire' ? 'PHÁT HIỆN LỬA!' : 'Phát Hiện Khói',
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.network(
                alert.snapshotUrl,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    height: 200,
                    color: Colors.grey[300],
                    child: const Center(child: Icon(Icons.error)),
                  );
                },
              ),
              const SizedBox(height: 10),
              Text('Camera: ${alert.cameraName}'),
              Text('Thời gian: ${_formatTimestamp(alert.timestamp)}'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Đóng'),
            ),
          ],
        );
      },
    );
  }
}
