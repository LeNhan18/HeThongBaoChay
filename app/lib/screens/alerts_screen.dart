import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'dart:async';
import '../services/alert_service.dart';
import 'fire_location_map_screen.dart';

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
              // TÍNH NĂNG MỚI: Hiển thị tọa độ nếu có
              if (alert['latitude'] != null && alert['longitude'] != null)
                Text(
                  '📍 ${(alert['latitude'] as num).toStringAsFixed(6)}, ${(alert['longitude'] as num).toStringAsFixed(6)}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
            ],
            if (alert['message'] != null && alert['message'].isNotEmpty)
              Text('💬 ${alert['message']}'),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // TÍNH NĂNG MỚI: Badge vị trí nếu cháy >= 30s
            if (alert['show_location'] == true)
              Container(
                margin: EdgeInsets.only(right: 8),
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.red.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.location_on, color: Colors.red, size: 16),
                    SizedBox(width: 4),
                    Text(
                      'Vị trí',
                      style: TextStyle(
                        color: Colors.red.shade700,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
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
    // Kiểm tra ESP32 dựa trên source hoặc có esp32_ip
    final isESP32 = alert['source'] == 'ESP32-CAM' || 
                    alert['source'] == 'Live Detection' ||
                    alert['esp32_ip'] != null;
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

                  // TÍNH NĂNG MỚI: Hiển thị thông tin vị trí
                  if (isESP32 && alert['latitude'] != null && alert['longitude'] != null) ...[
                    SizedBox(height: 8),
                    Divider(),
                    SizedBox(height: 8),
                    _buildDetailRow(
                      '📍 Tọa độ GPS',
                      '${(alert['latitude'] as num).toStringAsFixed(6)}, ${(alert['longitude'] as num).toStringAsFixed(6)}',
                    ),
                    if (alert['address'] != null)
                      _buildDetailRow('Địa chỉ', alert['address']),
                    if (alert['fire_duration_seconds'] != null && alert['fire_duration_seconds'] > 0)
                      _buildDetailRow(
                        '⏱️ Thời gian cháy',
                        '${(alert['fire_duration_seconds'] as num).toStringAsFixed(1)} giây',
                      ),
                  ],

                  // TÍNH NĂNG MỚI: Nút xem vị trí trên bản đồ (luôn hiển thị nếu có tọa độ)
                  if (isESP32 && alert['latitude'] != null && alert['longitude'] != null) ...[
                    SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          try {
                            Navigator.of(context).pop(); // Đóng dialog
                            final lat = alert['latitude'];
                            final lng = alert['longitude'];
                            final duration = alert['fire_duration_seconds'] ?? 0.0;
                            
                            // Kiểm tra tọa độ hợp lệ
                            if (lat == null || lng == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Không có thông tin vị trí'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                              return;
                            }
                            
                            print('🗺️ Opening map: lat=$lat, lng=$lng');
                            
                            // Convert fire_count và smoke_count sang int
                            int fireCount = 0;
                            int smokeCount = 0;
                            if (alert['fire_count'] != null) {
                              fireCount = alert['fire_count'] is int 
                                  ? alert['fire_count'] as int
                                  : int.tryParse(alert['fire_count'].toString()) ?? 0;
                            }
                            if (alert['smoke_count'] != null) {
                              smokeCount = alert['smoke_count'] is int
                                  ? alert['smoke_count'] as int
                                  : int.tryParse(alert['smoke_count'].toString()) ?? 0;
                            }
                            
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => FireLocationMapScreen(
                                  latitude: lat is double ? lat : (lat as num).toDouble(),
                                  longitude: lng is double ? lng : (lng as num).toDouble(),
                                  address: alert['address'] ?? 'ESP32-CAM (${alert['esp32_ip'] ?? 'unknown'})',
                                  esp32Ip: alert['esp32_ip'] ?? 'unknown',
                                  fireDurationSeconds: duration is double ? duration : (duration as num).toDouble(),
                                  fireCount: fireCount,
                                  smokeCount: smokeCount,
                                ),
                              ),
                            );
                          } catch (e) {
                            print('❌ Error opening map: $e');
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Lỗi khi mở bản đồ: $e'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        },
                        icon: Icon(Icons.map),
                        label: Text('📍 Xem vị trí trên bản đồ'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],

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
