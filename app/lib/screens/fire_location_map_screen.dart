import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart'; // Yêu cầu: flutter_map: ^6.0.0 hoặc ^7.0.0
import 'package:latlong2/latlong.dart';      // Yêu cầu: latlong2: ^0.9.0
import 'package:url_launcher/url_launcher.dart'; // Yêu cầu: url_launcher: ^6.1.11

class FireLocationMapScreen extends StatefulWidget {
  final double latitude;
  final double longitude;
  final String address;
  final String esp32Ip;
  final double fireDurationSeconds;
  final int fireCount;
  final int smokeCount;

  const FireLocationMapScreen({
    Key? key,
    required this.latitude,
    required this.longitude,
    required this.address,
    required this.esp32Ip,
    required this.fireDurationSeconds,
    required this.fireCount,
    required this.smokeCount,
  }) : super(key: key);

  @override
  State<FireLocationMapScreen> createState() => _FireLocationMapScreenState();
}

class _FireLocationMapScreenState extends State<FireLocationMapScreen> {
  // Controller để điều khiển map (zoom, di chuyển)
  final MapController _mapController = MapController();
  late LatLng _fireLocation;

  @override
  void initState() {
    super.initState();
    // Khởi tạo tọa độ cháy từ dữ liệu truyền vào
    _fireLocation = LatLng(widget.latitude, widget.longitude);

    debugPrint('🗺️ Map Screen: Vị trí cháy = ${widget.latitude}, ${widget.longitude}');

    // Tự động zoom vào vị trí cháy sau khi giao diện đã dựng xong
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Delay nhỏ để đảm bảo map đã sẵn sàng
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          _mapController.move(_fireLocation, 16.5);
        }
      });
    });
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '📍 Vị trí cháy',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location),
            onPressed: () {
              // Nút để quay về vị trí cháy nếu lỡ vuốt map đi chỗ khác
              _mapController.move(_fireLocation, 16.5);
            },
            tooltip: 'Về tâm đám cháy',
          ),
        ],
      ),
      body: Stack(
        children: [
          // --- LỚP 1: BẢN ĐỒ (FULL MÀN HÌNH) ---
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _fireLocation, // Tọa độ ban đầu
              initialZoom: 16.0,            // Độ zoom ban đầu
              minZoom: 5.0,
              maxZoom: 18.0,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all, // Cho phép vuốt, zoom 2 ngón
              ),
            ),
            children: [
              // 1. Lớp hiển thị bản đồ nền (Tile Layer)
              TileLayer(
                // Sử dụng CartoDB Voyager (giao diện đẹp, free)
                urlTemplate: 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png',
                subdomains: const ['a', 'b', 'c', 'd'],
                userAgentPackageName: 'com.fire.alert.app', // Thay bằng package name thật của app bạn
                maxZoom: 19,
              ),

              // 2. Lớp bản quyền (Bắt buộc với OSM)
              RichAttributionWidget(
                alignment: AttributionAlignment.bottomLeft,
                attributions: [
                  TextSourceAttribution(
                    'OpenStreetMap contributors',
                    onTap: () => launchUrl(Uri.parse('https://openstreetmap.org/copyright')),
                  ),
                  TextSourceAttribution(
                    'CARTO',
                    onTap: () => launchUrl(Uri.parse('https://carto.com/attributions')),
                  ),
                ],
              ),

              // 3. Lớp vòng tròn cảnh báo (Circle Layer)
              CircleLayer(
                circles: [
                  CircleMarker(
                    point: _fireLocation,
                    radius: 120, // Bán kính cảnh báo (mét)
                    useRadiusInMeter: true,
                    color: Colors.red.withOpacity(0.2), // Màu nền mờ
                    borderColor: Colors.red,            // Viền đỏ đậm
                    borderStrokeWidth: 2,
                  ),
                ],
              ),

              // 4. Lớp Marker vị trí cháy (Marker Layer)
              MarkerLayer(
                markers: [
                  Marker(
                    point: _fireLocation,
                    width: 100,
                    height: 100,
                    // Child widget hiển thị icon
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Icon đám lửa
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.red.withOpacity(0.6),
                                blurRadius: 15,
                                spreadRadius: 5,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.local_fire_department,
                            color: Colors.white,
                            size: 35,
                          ),
                        ),
                        const SizedBox(height: 4),
                        // Label chữ
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.black26,
                                blurRadius: 4,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Text(
                            'ĐIỂM CHÁY',
                            style: TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.w900,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),

          // --- LỚP 2: BẢNG THÔNG TIN (Ở DƯỚI CÙNG) ---
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              margin: const EdgeInsets.all(12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Tiêu đề bảng thông tin
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'PHÁT HIỆN CHÁY!',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.red,
                              ),
                            ),
                            Text(
                              'Thời gian cháy: ${widget.fireDurationSeconds.toStringAsFixed(0)} giây',
                              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),

                  // Danh sách thông số
                  _buildInfoRow(Icons.location_on, 'Địa chỉ:', widget.address),
                  _buildInfoRow(Icons.router, 'Thiết bị:', widget.esp32Ip),
                  Row(
                    children: [
                      Expanded(child: _buildInfoRow(Icons.whatshot, 'Lửa:', '${widget.fireCount} điểm')),
                      Expanded(child: _buildInfoRow(Icons.cloud, 'Khói:', '${widget.smokeCount} mức')),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Hàng nút bấm hành động
                  Row(
                    children: [
                      // Nút Google Maps/Apple Maps
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _openInMapsApp,
                          icon: const Icon(Icons.directions),
                          label: const Text('Chỉ đường'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Nút Web Browser
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _openInBrowser,
                          icon: const Icon(Icons.public),
                          label: const Text('Xem Web'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.blue,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            side: const BorderSide(color: Colors.blue),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                    ],
                  )
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Widget con để hiển thị từng dòng thông tin
  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(color: Colors.grey[600], fontSize: 13, fontWeight: FontWeight.w500),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // Hàm mở ứng dụng bản đồ mặc định trong điện thoại
  Future<void> _openInMapsApp() async {
    // Geo URI scheme hoạt động trên cả iOS và Android
    final Uri googleMapsUrl = Uri.parse(
        'google.navigation:q=${widget.latitude},${widget.longitude}&mode=d');
    final Uri appleMapsUrl = Uri.parse(
        'https://maps.apple.com/?q=${widget.latitude},${widget.longitude}');

    // Thử mở Google Maps (Android ưu tiên) hoặc Apple Maps (iOS)
    if (await canLaunchUrl(googleMapsUrl)) {
      await launchUrl(googleMapsUrl);
    } else if (await canLaunchUrl(appleMapsUrl)) {
      await launchUrl(appleMapsUrl);
    } else {
      // Fallback: Mở Geo intent chung
      final Uri geoUrl = Uri.parse('geo:${widget.latitude},${widget.longitude}?q=${widget.latitude},${widget.longitude}');
      if (await canLaunchUrl(geoUrl)) {
        await launchUrl(geoUrl);
      } else {
        _showError('Không tìm thấy ứng dụng bản đồ nào.');
      }
    }
  }

  // Hàm mở vị trí trên trình duyệt
  Future<void> _openInBrowser() async {
    final Uri url = Uri.parse(
        'https://www.openstreetmap.org/?mlat=${widget.latitude}&mlon=${widget.longitude}&zoom=18');

    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      _showError('Không thể mở trình duyệt.');
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}