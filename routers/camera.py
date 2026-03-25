"""Camera streaming endpoints."""
import logging
import time
from datetime import datetime

import cv2
from fastapi import APIRouter, HTTPException, Query
from fastapi.responses import JSONResponse, StreamingResponse

import config
import api_state
from api_state import camera_stats, detection_results, model
from services.detection import encode_image_to_jpeg, plot_with_vietnamese_labels

logger = logging.getLogger(__name__)
router = APIRouter()


def camera_feed_generator(camera_index: int = 0, confidence: float = config.DEFAULT_CONFIDENCE):
    """MJPEG stream generator."""
    cap = cv2.VideoCapture(camera_index)
    if not cap.isOpened():
        logger.error(f"Cannot open camera {camera_index}")
        return

    cap.set(cv2.CAP_PROP_FRAME_WIDTH, config.CAMERA_WIDTH)
    cap.set(cv2.CAP_PROP_FRAME_HEIGHT, config.CAMERA_HEIGHT)
    cap.set(cv2.CAP_PROP_FPS, config.CAMERA_FPS)

    camera_stats["start_time"] = time.time()
    camera_stats["frames"] = 0
    camera_stats["detections"] = 0

    try:
        while api_state.camera_active:
            ret, frame = cap.read()
            if not ret:
                break
            results = model(frame, conf=confidence)
            annotated = plot_with_vietnamese_labels(results[0], frame)
            if results[0].boxes:
                camera_stats["detections"] += len(results[0].boxes)
                detection_results.append({
                    "timestamp": datetime.now().isoformat(),
                    "count": len(results[0].boxes),
                    "frame": camera_stats["frames"],
                })
            camera_stats["frames"] += 1
            fb = encode_image_to_jpeg(annotated)
            yield b"--frame\r\nContent-Type: image/jpeg\r\nContent-Length: " + str(len(fb)).encode() + b"\r\n\r\n" + fb + b"\r\n"
    finally:
        cap.release()


@router.post("/camera/start/")
async def start_camera(camera_index: int = Query(0)):
    """Bắt đầu camera stream."""
    if model is None:
        raise HTTPException(status_code=500, detail="Model is not loaded")

    if api_state.camera_active:
        return JSONResponse(content={"status": "Camera already running"})
    api_state.camera_active = True
    return JSONResponse(content={
        "status": "Camera started",
        "camera_status": "online",
        "camera_index": camera_index,
        "stream_url": f"/camera/stream/?camera_index={camera_index}",
    })


@router.get("/camera/stream/")
async def stream_camera(
    camera_index: int = Query(0),
    confidence: float = Query(config.DEFAULT_CONFIDENCE, ge=0, le=1),
):
    """Stream camera với detection."""
    if model is None:
        raise HTTPException(status_code=500, detail="Model is not loaded")
    if not api_state.camera_active:
        raise HTTPException(status_code=400, detail="Gọi /camera/start/ trước")

    return StreamingResponse(
        camera_feed_generator(camera_index, confidence),
        media_type="multipart/x-mixed-replace; boundary=frame",
    )


@router.post("/camera/stop/")
async def stop_camera():
    """Dừng camera."""
    api_state.camera_active = False
    return JSONResponse(content={"status": "Camera stopped", "camera_status": "offline"})
