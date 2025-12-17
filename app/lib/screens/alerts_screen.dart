import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'dart:async';
import '../services/alert_service.dart';

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  final AlertService _alertService = AlertService();
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    // Auto-refresh mỗi 5 giây để cập nhật alerts mới
    _refreshTimer = Timer.periodic(Duration(seconds: 5), (_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          setState(() {});
        },
        child: _buildAlertsList(),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _showAlertStats(context);
        },
        child: Icon(Icons.analytics),
        tooltip: 'Thống kê cảnh báo',
      ),
    );
  }

  Widget _buildAlertsList() {
    final alerts = _alertService.getAllAlerts();

    if (alerts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.notification_important_outlined,
              size: 80,
              color: Colors.grey[400],
            ),
            SizedBox(height: 16),
            Text(
              'Chưa có cảnh báo nào',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Các cảnh báo từ ESP32-CAM và camera sẽ xuất hiện ở đây',
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(8),
      itemCount: alerts.length,
      itemBuilder: (context, index) {
        final alert = alerts[index];
        return _buildAlertCard(alert);
      },
    );
  }

  Widget _buildAlertCard(Map<String, dynamic> alert) {
    final isFireAlert = alert['type'].toString().contains('FIRE');
    final isESP32 = alert['source'] == 'ESP32-CAM';
    final timestamp = DateTime.tryParse(alert['timestamp']) ?? DateTime.now();
    final formattedTime = DateFormat('dd/MM/yyyy HH:mm:ss').format(timestamp);

    return Card(
      margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      elevation: 2,
      color: isFireAlert ? Colors.red.shade50 : Colors.orange.shade50,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isFireAlert ? Colors.red : Colors.orange,
          child: Icon(
            isFireAlert ? Icons.local_fire_department : Icons.cloud,
            color: Colors.white,
            size: 24,
          ),
        ),
        title: Text(
          isFireAlert ? 'PHÁT HIỆN LỬA!' : 'Phát Hiện Khói',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isFireAlert ? Colors.red.shade700 : Colors.orange.shade700,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('📷 ${alert['camera_name']}'),
            Text('🕒 $formattedTime'),
            if (isESP32) ...[
              Text(
                '🔥 Lửa: ${alert['fire_count'] ?? 0} | 💨 Khói: ${alert['smoke_count'] ?? 0}',
              ),
              Text(
                '📊 Độ tin cậy: ${((alert['confidence'] ?? 0.0) * 100).toStringAsFixed(1)}%',
              ),
            ],
            if (alert['message'] != null && alert['message'].isNotEmpty)
              Text('💬 ${alert['message']}'),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isESP32)
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.blue.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'ESP32',
                  style: TextStyle(
                    color: Colors.blue.shade700,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            SizedBox(width: 8),
            Icon(Icons.chevron_right, color: Colors.grey[400]),
          ],
        ),
        onTap: () {
          _showAlertDetails(context, alert);
        },
      ),
    );
  }

  void _showAlertDetails(BuildContext context, Map<String, dynamic> alert) {
    final isESP32 = alert['source'] == 'ESP32-CAM';
    final hasImage =
        alert['snapshot_url'] != null && alert['snapshot_url'].isNotEmpty;

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Row(
              children: [
                Icon(
                  alert['type'].toString().contains('FIRE')
                      ? Icons.local_fire_department
                      : Icons.cloud,
                  color:
                      alert['type'].toString().contains('FIRE')
                          ? Colors.red
                          : Colors.orange,
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Chi tiết cảnh báo',
                    style: TextStyle(fontSize: 18),
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildDetailRow('Camera', alert['camera_name']),
                  _buildDetailRow('Loại', alert['type']),
                  _buildDetailRow('Thời gian', alert['timestamp']),
                  _buildDetailRow('Nguồn', alert['source']),

                  if (isESP32) ...[
                    _buildDetailRow('IP ESP32', alert['esp32_ip'] ?? 'N/A'),
                    _buildDetailRow(
                      'Số điểm lửa',
                      '${alert['fire_count'] ?? 0}',
                    ),
                    _buildDetailRow(
                      'Số điểm khói',
                      '${alert['smoke_count'] ?? 0}',
                    ),
                    _buildDetailRow(
                      'Độ tin cậy',
                      '${((alert['confidence'] ?? 0.0) * 100).toStringAsFixed(1)}%',
                    ),
                    _buildDetailRow(
                      'Mức cảnh báo',
                      alert['alert_level'] ?? 'N/A',
                    ),
                  ],

                  if (alert['message'] != null && alert['message'].isNotEmpty)
                    _buildDetailRow('Thông điệp', alert['message']),

                  if (hasImage) ...[
                    SizedBox(height: 16),
                    Text(
                      'Ảnh chụp:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(
                        File(alert['snapshot_url']),
                        width: double.infinity,
                        height: 200,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            height: 100,
                            color: Colors.grey[300],
                            child: Center(
                              child: Text('Không thể hiển thị ảnh'),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('ĐÓNG'),
              ),
            ],
          ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  void _showAlertStats(BuildContext context) {
    final stats = _alertService.getAlertStats();

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Row(
              children: [
                Icon(Icons.analytics, color: Colors.blue),
                SizedBox(width: 8),
                Text('Thống kê cảnh báo'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildStatRow(
                  'Tổng số cảnh báo',
                  '${stats['total']}',
                  Icons.notifications,
                ),
                _buildStatRow(
                  'Phát hiện lửa',
                  '${stats['fire']}',
                  Icons.local_fire_department,
                ),
                _buildStatRow(
                  'Phát hiện khói',
                  '${stats['smoke']}',
                  Icons.cloud,
                ),
                _buildStatRow(
                  'Từ ESP32-CAM',
                  '${stats['esp32']}',
                  Icons.camera_alt,
                ),
                _buildStatRow(
                  'Từ Mobile',
                  '${stats['mobile']}',
                  Icons.phone_android,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  _alertService.clearAllAlerts();
                  Navigator.of(context).pop();
                  setState(() {});
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Đã xóa tất cả cảnh báo')),
                  );
                },
                child: Text('XÓA TẤT CẢ', style: TextStyle(color: Colors.red)),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('ĐÓNG'),
              ),
            ],
          ),
    );
  }

  Widget _buildStatRow(String label, String value, IconData icon) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          SizedBox(width: 12),
          Expanded(child: Text(label)),
          Text(
            value,
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ],
      ),
    );
  }
}
