"""ESP32-CAM endpoints."""
import logging
from typing import Optional

import requests
from fastapi import APIRouter, HTTPException, Query
from fastapi.responses import JSONResponse, StreamingResponse

import config
from api_state import model
from services.detection import (
    count_detections_by_class,
    encode_image_to_jpeg,
    extract_detections,
    filter_false_positives_fire,
    get_alert_level,
    get_detection_message,
    plot_with_vietnamese_labels,
    read_image_bytes,
)
from services.fire_tracker import validate_ip_address

logger = logging.getLogger(__name__)
router = APIRouter()


async def _esp32_capture_helper(
    esp32_ip: str,
    confidence: float,
    return_image: bool = False,
) -> tuple[Optional[object], list, dict]:
    """Capture từ ESP32 và chạy detection. Trả về (annotated_img?, detections, detection_count)."""
    validate_ip_address(esp32_ip)
    resp = requests.get(
        f"http://{esp32_ip}/capture",
        headers={"Accept": "image/jpeg"},
        timeout=10,
    )
    if resp.status_code != 200:
        raise HTTPException(status_code=400, detail=f"ESP32 capture failed: {resp.status_code}")

    img = read_image_bytes(resp.content)
    if img is None:
        raise HTTPException(status_code=400, detail="Invalid image from ESP32")

    results = model(img, conf=confidence, verbose=False)
    result = results[0]
    detections = extract_detections(result)
    detections = filter_false_positives_fire(detections, img)
    detection_count = count_detections_by_class(detections)

    annotated = None
    if return_image:
        annotated = plot_with_vietnamese_labels(result, img)

    return annotated, detections, detection_count


@router.post("/esp32/capture")
async def esp32_capture(
    esp32_ip: str = Query(..., regex=r"^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$"),
    confidence: float = Query(config.DEFAULT_CONFIDENCE, ge=0, le=1),
):
    """Capture ESP32 và trả về JSON kết quả."""
    if model is None:
        raise HTTPException(status_code=500, detail="Model is not loaded")
    try:
        _, detections, dc = await _esp32_capture_helper(esp32_ip, confidence, return_image=False)
        max_conf = max((d["confidence"] for d in detections), default=0.0)
        return JSONResponse(content={
            "timestamp": __import__("datetime").datetime.now().isoformat(),
            "esp32_ip": esp32_ip,
            "fire_detected": dc["fire"] > 0 or dc["smoke"] > 0,
            "confidence": max_conf,
            "detections": detections,
            "fire_count": dc["fire"],
            "smoke_count": dc["smoke"],
            "total_detections": len(detections),
            "alert_level": get_alert_level(dc),
            "message": get_detection_message(dc),
            "has_bounding_boxes": len(detections) > 0,
        })
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"ESP32 capture error: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/esp32/capture_with_boxes")
async def esp32_capture_with_boxes(
    esp32_ip: str = Query(..., regex=r"^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$"),
    confidence: float = Query(config.DEFAULT_CONFIDENCE, ge=0, le=1),
):
    """Capture ESP32 và trả về ảnh có bounding boxes."""
    if model is None:
        raise HTTPException(status_code=500, detail="Model is not loaded")
    try:
        annotated, detections, dc = await _esp32_capture_helper(esp32_ip, confidence, return_image=True)
        if annotated is None:
            raise HTTPException(status_code=500, detail="Failed to generate image")
        from datetime import datetime
        import io
        return StreamingResponse(
            io.BytesIO(encode_image_to_jpeg(annotated)),
            media_type="image/jpeg",
            headers={
                "X-ESP32-IP": esp32_ip,
                "X-Detection-Count": str(len(detections)),
                "X-Fire-Count": str(dc["fire"]),
                "X-Smoke-Count": str(dc["smoke"]),
                "X-Alert-Level": get_alert_level(dc),
                "X-Timestamp": datetime.now().isoformat(),
            },
        )
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"ESP32 capture_with_boxes error: {e}")
        raise HTTPException(status_code=500, detail=str(e))
