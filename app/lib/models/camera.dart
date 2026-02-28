class Camera {
  final String id;
  final String name;
  final String status;
  final String thumbnailUrl;
  final String type; // 'system' or 'esp32'
  final String? ip; // IP address for ESP32 cameras
  final String? port; // Port for Flask server (default 8000 for backend, 5000 for Flask)

  const Camera({
    required this.id,
    required this.name,
    required this.status,
    required this.thumbnailUrl,
    this.type = 'system',
    this.ip,
    this.port,
  });

  factory Camera.fromJson(Map<String, dynamic> json) {
    return Camera(
      id: json['id'] as String,
      name: json['name'] as String,
      status: json['status'] as String,
      thumbnailUrl: json['thumbnailUrl'] as String,
      type: json['type'] as String? ?? 'system',
      ip: json['ip'] as String?,
      port: json['port'] as String?,
    );
  }

  bool get isESP32 => type == 'esp32';
  bool get isFlaskServer => port == '5000';
}
