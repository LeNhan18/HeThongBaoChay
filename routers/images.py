"""Image detection endpoints."""
import logging
from datetime import datetime

from fastapi import APIRouter, File, HTTPException, Query, UploadFile
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

logger = logging.getLogger(__name__)
router = APIRouter()

MAX_SIZE = config.MAX_IMAGE_SIZE


def _validate_loaded():
    if model is None:
        raise HTTPException(status_code=500, detail="Model is not loaded")


@router.post("/predict/")
def predict_image_with_annotation(
    file: UploadFile = File(...),
    confidence: float = Query(config.DEFAULT_CONFIDENCE, ge=0, le=1),
):
    """Predict từ ảnh, trả về ảnh đã vẽ bounding boxes."""
    if file.size and file.size > MAX_SIZE:
        return JSONResponse(status_code=400, content={"error": "File quá lớn (max 10MB)"})

    _validate_loaded()
    if not file.filename or not file.filename.lower().endswith((".jpg", ".jpeg", ".png")):
        return JSONResponse(status_code=400, content={"error": "Chỉ hỗ trợ JPG, PNG"})

    try:
        contents = file.file.read()
        img = read_image_bytes(contents)
        if img is None:
            return JSONResponse(status_code=400, content={"error": "Không đọc được ảnh"})

        results = model(img, conf=confidence, verbose=False)
        result = results[0]
        detections = extract_detections(result)
        detections = filter_false_positives_fire(detections, img)
        annotated = plot_with_vietnamese_labels(result, img)
        img_bytes = encode_image_to_jpeg(annotated)

        fire_count = sum(1 for d in detections if d["class"].lower() == "fire")
        smoke_count = sum(1 for d in detections if d["class"].lower() == "smoke")

        return StreamingResponse(
            iter([img_bytes]),
            media_type="image/jpeg",
            headers={
                "X-Detections-Count": str(len(detections)),
                "X-Fire-Count": str(fire_count),
                "X-Smoke-Count": str(smoke_count),
            },
        )
    except Exception as e:
        logger.error(f"predict error: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/predict_json/")
def predict_image_json(
    file: UploadFile = File(...),
    confidence: float = Query(config.DEFAULT_CONFIDENCE, ge=0, le=1),
):
    """Predict từ ảnh, trả về JSON."""
    if file.size and file.size > MAX_SIZE:
        return JSONResponse(status_code=400, content={"error": "File quá lớn (max 10MB)"})
    _validate_loaded()
    if not file.filename or not file.filename.lower().endswith((".jpg", ".jpeg", ".png")):
        return JSONResponse(status_code=400, content={"error": "Chỉ hỗ trợ JPG, PNG"})
    try:
        contents = file.file.read()
        img = read_image_bytes(contents)
        if img is None:
            return JSONResponse(status_code=400, content={"error": "Không đọc được ảnh"})
        results = model(img, conf=confidence, verbose=False)
        result = results[0]
        detections = extract_detections(result)
        detections = filter_false_positives_fire(detections, img)
        dc = count_detections_by_class(detections)
        return JSONResponse(content={
            "success": True,
            "timestamp": datetime.now().isoformat(),
            "detections": detections,
            "detection_count": dc,
            "has_fire": dc["fire"] > 0,
            "has_smoke": dc["smoke"] > 0,
            "alert_level": get_alert_level(dc),
            "message": get_detection_message(dc),
        })
    except Exception as e:
        logger.error(f"predict_json error: {e}")
        raise HTTPException(status_code=500, detail=str(e))
