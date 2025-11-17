class Alert {
  final String id;
  final String cameraName;
  final String type;
  final String timestamp;
  final String snapshotUrl;

  const Alert({
    required this.id,
    required this.cameraName,
    required this.type,
    required this.timestamp,
    required this.snapshotUrl,
  });

  factory Alert.fromJson(Map<String, dynamic> json) {
    return Alert(
      id: json['id'] as String,
      cameraName: json['camera_name'] as String,
      type: json['type'] as String,
      timestamp: json['timestamp'] as String,
      snapshotUrl: json['snapshot_url'] as String,
    );
  }
}
