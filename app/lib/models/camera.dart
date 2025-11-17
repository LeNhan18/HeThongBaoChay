class Camera {
  final String id;
  final String name;
  final String status;
  final String thumbnailUrl;

  const Camera({
    required this.id,
    required this.name,
    required this.status,
    required this.thumbnailUrl,
  });

  factory Camera.fromJson(Map<String, dynamic> json) {
    return Camera(
      id: json['id'] as String,
      name: json['name'] as String,
      status: json['status'] as String,
      thumbnailUrl: json['thumbnailUrl'] as String,
    );
  }
}
