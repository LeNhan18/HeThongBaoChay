"""Detection utilities - xử lý ảnh và YOLO."""
import logging
from typing import Any, Dict, List, Optional

import cv2
import numpy as np

import config
from api_state import model

logger = logging.getLogger(__name__)


def read_image_bytes(file_content: bytes) -> Optional[np.ndarray]:
    """Decode image từ bytes."""
    try:
        nparr = np.frombuffer(file_content, np.uint8)
        img = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
        if img is None:
            raise ValueError("Failed to decode image")
        return img
    except Exception as e:
        logger.error(f"Failed to read image: {e}")
        return None


def extract_detections(result) -> List[Dict[str, Any]]:
    """Trích xuất detections từ YOLO result."""
    detections = []
    if result.boxes is None or len(result.boxes) == 0:
        return detections

    for box in result.boxes:
        class_id = int(box.cls[0])
        confidence = float(box.conf[0])
        class_name = model.names[class_id]
        bbox = box.xyxy[0].tolist()
        detections.append({
            "class": class_name,
            "confidence": round(confidence, 4),
            "bbox": {
                "x1": round(bbox[0], 2),
                "y1": round(bbox[1], 2),
                "x2": round(bbox[2], 2),
                "y2": round(bbox[3], 2),
            },
        })
    return detections


def encode_image_to_jpeg(image: np.ndarray) -> bytes:
    """Encode OpenCV image sang JPEG bytes."""
    _, buffer = cv2.imencode(".jpg", image)
    return buffer.tobytes()


def count_detections_by_class(detections: List[Dict]) -> Dict[str, int]:
    """Đếm detections theo class."""
    counts = {"fire": 0, "smoke": 0}
    for d in detections:
        cn = d["class"].lower()
        if cn in counts:
            counts[cn] += 1
    return counts


def filter_false_positives_fire(
    detections: List[Dict[str, Any]], img: np.ndarray
) -> List[Dict[str, Any]]:
    """Lọc false positives (bóng đèn đỏ, đèn giao thông, ...)."""
    if not detections or img is None:
        return detections

    filtered = []
    h, w = img.shape[:2]
    img_area = w * h

    for d in detections:
        if d["class"].lower() != "fire":
            filtered.append(d)
            continue

        bbox = d["bbox"]
        x1, y1, x2, y2 = bbox["x1"], bbox["y1"], bbox["x2"], bbox["y2"]
        area = (x2 - x1) * (y2 - y1)

        if area < img_area * 0.001 or area > img_area * 0.5:
            continue
        if y1 < h * 0.1 and (y2 - y1) < h * 0.15 and d["confidence"] < 0.6:
            continue
        if d["confidence"] < 0.3:
            continue

        filtered.append(d)
    return filtered


def plot_with_vietnamese_labels(result, img: np.ndarray) -> np.ndarray:
    """Vẽ bounding boxes với label tiếng Việt."""
    annotated = img.copy()
    if result.boxes is None or len(result.boxes) == 0:
        return annotated

    for i, box in enumerate(result.boxes):
        x1, y1, x2, y2 = [int(v) for v in box.xyxy[0].tolist()]
        class_id = int(box.cls[0])
        confidence = float(box.conf[0])
        class_en = model.names[class_id]
        class_vi = config.VIETNAMESE_LABELS.get(class_en.lower(), class_en)

        color = (0, 0, 255) if class_en.lower() == "fire" else (255, 0, 0)
        text_color = (255, 255, 255)
        thickness = max(2, int((img.shape[0] + img.shape[1]) / 600))

        cv2.rectangle(annotated, (x1, y1), (x2, y2), color, thickness)
        cs = thickness * 3
        cv2.rectangle(annotated, (x1, y1), (x1 + cs, y1 + cs), color, -1)
        cv2.rectangle(annotated, (x2 - cs, y1), (x2, y1 + cs), color, -1)
        cv2.rectangle(annotated, (x1, y2 - cs), (x1 + cs, y2), color, -1)
        cv2.rectangle(annotated, (x2 - cs, y2 - cs), (x2, y2), color, -1)

        label = f"{class_vi} {confidence * 100:.1f}%"
        font_scale = max(0.6, min(1.2, (img.shape[0] + img.shape[1]) / 1500))
        (tw, th), bl = cv2.getTextSize(label, cv2.FONT_HERSHEY_DUPLEX, font_scale, max(1, thickness // 2))
        ly = max(y1 - 10, th + 10)

        pts = np.array([
            [x1, ly - th - 5], [x1 + tw + 10, ly - th - 5],
            [x1 + tw + 10, ly + bl + 5], [x1, ly + bl + 5]
        ], np.int32)
        overlay = annotated.copy()
        cv2.fillPoly(overlay, [pts], color)
        cv2.addWeighted(overlay, 0.8, annotated, 0.2, 0, annotated)
        cv2.putText(annotated, label, (x1 + 5, ly), cv2.FONT_HERSHEY_DUPLEX, font_scale, text_color, max(1, thickness // 2), cv2.LINE_AA)

    return annotated


def get_alert_level(detection_count: Dict[str, int]) -> str:
    """Xác định mức cảnh báo."""
    if detection_count["fire"] > 0:
        return "HIGH"
    if detection_count["smoke"] > 0:
        return "MEDIUM"
    return "LOW"


def get_detection_message(detection_count: Dict[str, int]) -> str:
    """Thông báo tiếng Việt theo detection."""
    f, s = detection_count["fire"], detection_count["smoke"]
    if f > 0 and s > 0:
        return f" CẢNH BÁO: Phát hiện {f} điểm lửa và {s} điểm khói!"
    if f > 0:
        return f" CẢNH BÁO: Phát hiện {f} điểm lửa!"
    if s > 0:
        return f" CẢNH BÁO: Phát hiện {s} điểm khói!"
    return "Không phát hiện lửa hoặc khói"
