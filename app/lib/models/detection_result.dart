class DetectionResult {
  final bool success;
  final String timestamp;
  final List<Map<String, dynamic>> detections;
  final Map<String, int> detectionCount;
  final int totalDetections;
  final bool hasFire;
  final bool hasSmoke;
  final String alertLevel;
  final String message;
  final int? annotatedImageSize;
  final bool fireDetected;
  final double confidence;
  final int fireCount;
  final int smokeCount;

  DetectionResult({
    required this.success,
    required this.timestamp,
    required this.detections,
    required this.detectionCount,
    required this.totalDetections,
    required this.hasFire,
    required this.hasSmoke,
    required this.alertLevel,
    required this.message,
    this.annotatedImageSize,
    bool? fireDetected,
    double? confidence,
    int? fireCount,
    int? smokeCount,
  }) : fireDetected = fireDetected ?? hasFire || hasSmoke,
       confidence = confidence ?? 0.0,
       fireCount = fireCount ?? (detectionCount['fire'] ?? 0),
       smokeCount = smokeCount ?? (detectionCount['smoke'] ?? 0);

  factory DetectionResult.fromJson(Map<String, dynamic> json) {
    return DetectionResult(
      success: json['success'] ?? false,
      timestamp: json['timestamp'] ?? DateTime.now().toIso8601String(),
      detections: List<Map<String, dynamic>>.from(json['detections'] ?? []),
      detectionCount: Map<String, int>.from(json['detection_count'] ?? {}),
      totalDetections: json['total_detections'] ?? 0,
      hasFire: json['has_fire'] ?? false,
      hasSmoke: json['has_smoke'] ?? false,
      alertLevel: json['alert_level'] ?? 'LOW',
      message: json['message'] ?? 'Không có phát hiện',
      annotatedImageSize: json['annotated_image_size'],
      fireDetected: json['fire_detected'] ?? false,
      confidence: (json['confidence'] ?? 0.0).toDouble(),
      fireCount: json['fire_count'] ?? 0,
      smokeCount: json['smoke_count'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'timestamp': timestamp,
      'detections': detections,
      'detection_count': detectionCount,
      'total_detections': totalDetections,
      'has_fire': hasFire,
      'has_smoke': hasSmoke,
      'alert_level': alertLevel,
      'message': message,
      'annotated_image_size': annotatedImageSize,
    };
  }

  bool get hasFireOrSmoke => hasFire || hasSmoke;

  bool get isHighAlert => alertLevel == 'HIGH';
  bool get isMediumAlert => alertLevel == 'MEDIUM';
  bool get isLowAlert => alertLevel == 'LOW';

  @override
  String toString() {
    return 'DetectionResult(success: $success, detections: ${detections.length}, hasFire: $hasFire, hasSmoke: $hasSmoke, alertLevel: $alertLevel)';
  }
}

class Detection {
  final String className;
  final double confidence;
  final BoundingBox bbox;

  Detection({
    required this.className,
    required this.confidence,
    required this.bbox,
  });

  factory Detection.fromJson(Map<String, dynamic> json) {
    return Detection(
      className: json['class'] ?? '',
      confidence: (json['confidence'] ?? 0.0).toDouble(),
      bbox: BoundingBox.fromJson(json['bbox'] ?? {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'class': className,
      'confidence': confidence,
      'bbox': bbox.toJson(),
    };
  }

  bool get isFire => className.toLowerCase() == 'fire';
  bool get isSmoke => className.toLowerCase() == 'smoke';

  @override
  String toString() {
    return 'Detection(class: $className, confidence: ${confidence.toStringAsFixed(2)})';
  }
}

class BoundingBox {
  final double x1;
  final double y1;
  final double x2;
  final double y2;

  BoundingBox({
    required this.x1,
    required this.y1,
    required this.x2,
    required this.y2,
  });

  factory BoundingBox.fromJson(Map<String, dynamic> json) {
    return BoundingBox(
      x1: (json['x1'] ?? 0.0).toDouble(),
      y1: (json['y1'] ?? 0.0).toDouble(),
      x2: (json['x2'] ?? 0.0).toDouble(),
      y2: (json['y2'] ?? 0.0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {'x1': x1, 'y1': y1, 'x2': x2, 'y2': y2};
  }

  double get width => x2 - x1;
  double get height => y2 - y1;
  double get area => width * height;

  @override
  String toString() {
    return 'BoundingBox(x1: $x1, y1: $y1, x2: $x2, y2: $y2)';
  }
}
