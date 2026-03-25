"""Mobile camera và alert endpoints."""
import logging
import time
from datetime import datetime

from fastapi import APIRouter, File, HTTPException, Query, UploadFile
from fastapi.responses import JSONResponse, StreamingResponse

import config
import api_state
import api_state
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
from services.fire_tracker import get_esp32_location, track_fire_duration
from services.notifications import send_fcm_notification

logger = logging.getLogger(__name__)
router = APIRouter()


@router.post("/mobile/camera/detect")
async def mobile_camera_detect(
    file: UploadFile = File(...),
    confidence: float = Query(config.DEFAULT_CONFIDENCE, ge=0, le=1),
):
    """Mobile gửi frame, nhận JSON detection."""
    if model is None:
        raise HTTPException(status_code=500, detail="Model is not loaded")
    try:
        content = await file.read()
        img = read_image_bytes(content)
        if img is None:
            raise HTTPException(status_code=400, detail="Invalid image")

        results = model(img, conf=confidence, verbose=False)
        result = results[0]
        detections = extract_detections(result)
        detections = filter_false_positives_fire(detections, img)
        dc = count_detections_by_class(detections)

        api_state.detection_results.append({
            "timestamp": datetime.now().isoformat(),
            "detections": detections,
            "count": dc,
        })
        api_state.camera_stats["frames"] += 1
        if api_state.camera_stats["start_time"] is None:
            api_state.camera_stats["start_time"] = time.time()

        return JSONResponse(content={
            "success": True,
            "timestamp": datetime.now().isoformat(),
            "detections": detections,
            "detection_count": dc,
            "total_detections": len(detections),
            "has_fire": dc["fire"] > 0,
            "has_smoke": dc["smoke"] > 0,
            "alert_level": get_alert_level(dc),
            "message": get_detection_message(dc),
        })
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Mobile detect error: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/mobile/camera/detect_with_image")
async def mobile_camera_detect_with_image(
    file: UploadFile = File(...),
    confidence: float = Query(config.DEFAULT_CONFIDENCE, ge=0, le=1),
):
    """Mobile gửi frame, nhận ảnh đã vẽ bounding boxes (JPEG)."""
    if model is None:
        raise HTTPException(status_code=500, detail="Model is not loaded")
    try:
        content = await file.read()
        img = read_image_bytes(content)
        if img is None:
            raise HTTPException(status_code=400, detail="Invalid image")

        results = model(img, conf=confidence, verbose=False)
        result = results[0]
        detections = extract_detections(result)
        detections = filter_false_positives_fire(detections, img)
        annotated = plot_with_vietnamese_labels(result, img)
        img_bytes = encode_image_to_jpeg(annotated)

        return StreamingResponse(
            iter([img_bytes]),
            media_type="image/jpeg",
        )
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Mobile detect_with_image error: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/mobile/register_fcm_token")
async def register_fcm_token(token_data: dict):
    """Đăng ký FCM token."""
    token = token_data.get("token")
    if not token:
        raise HTTPException(status_code=400, detail="FCM token is required")
    if token not in api_state.fcm_tokens:
        api_state.fcm_tokens.append(token)
        logger.info(f"📱 FCM token registered: {token[:20]}...")
    return {"status": "success", "message": "FCM token registered", "total_tokens": len(api_state.fcm_tokens)}


@router.post("/mobile/send_alert")
async def send_mobile_alert(alert_data: dict):
    """Nhận alert từ ESP32/script, gửi FCM và lưu vào queue."""
    try:
        fire_count = alert_data.get("fire_count", 0)
        smoke_count = alert_data.get("smoke_count", 0)
        esp32_ip = alert_data.get("esp32_ip", "unknown")
        confidence = alert_data.get("confidence", 0)
        message = alert_data.get("message", "Phát hiện lửa/khói")

        logger.warning(f"🔥 FIRE ALERT: Fire={fire_count}, Smoke={smoke_count}, ESP32={esp32_ip}")

        fd_info = track_fire_duration(esp32_ip, fire_count, smoke_count)
        show_location = fd_info["show_location"]
        duration = fd_info["duration_seconds"]
        location = get_esp32_location(esp32_ip)

        if show_location:
            logger.warning(f"📍 LOCATION: ESP32 {esp32_ip} - Duration: {duration:.1f}s")

        send_fcm_notification(
            title="🔥 CẢNH BÁO CHÁY!",
            body=f"Phát hiện {fire_count} lửa, {smoke_count} khói từ ESP32 ({esp32_ip})",
            data={
                "type": "fire_alert",
                "fire_count": str(fire_count),
                "smoke_count": str(smoke_count),
                "esp32_ip": esp32_ip,
                "confidence": f"{confidence:.2%}",
                "timestamp": datetime.now().isoformat(),
            },
        )

        api_state.alert_counter += 1
        alert = {
            "id": api_state.alert_counter,
            "title": "🔥 CẢNH BÁO CHÁY - Live Detection",
            "body": f"Phát hiện {fire_count} lửa, {smoke_count} khói từ ESP32 ({esp32_ip})",
            "fire_count": fire_count,
            "smoke_count": smoke_count,
            "confidence": confidence,
            "esp32_ip": esp32_ip,
            "source": alert_data.get("source", "Live Detection"),
            "timestamp": datetime.now().isoformat(),
            "vietnamese_message": message,
            "read": False,
            "show_location": show_location,
            "fire_duration_seconds": duration,
            "latitude": location["latitude"],
            "longitude": location["longitude"],
            "address": location["address"],
        }

        api_state.pending_alerts.append(alert)
        if len(api_state.pending_alerts) > 50:
            api_state.pending_alerts = api_state.pending_alerts[-50:]

        return JSONResponse(content={
            "status": "success",
            "message": "Alert received",
            "alert_id": api_state.alert_counter,
            "timestamp": datetime.now().isoformat(),
            "processed_alert": alert,
        }, status_code=200)
    except Exception as e:
        logger.error(f"send_alert error: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/mobile/get_alerts")
async def get_mobile_alerts(unread_only: bool = Query(False)):
    """Lấy danh sách alerts."""
    if unread_only:
        alerts = [a for a in api_state.pending_alerts if not a.get("read", False)]
    else:
        alerts = api_state.pending_alerts.copy()
    return JSONResponse(content={"status": "success", "count": len(alerts), "alerts": alerts}, status_code=200)


@router.post("/mobile/mark_alert_read")
async def mark_alert_read(request_data: dict):
    """Đánh dấu alert đã đọc."""
    aid = request_data.get("alert_id")
    if aid is None:
        raise HTTPException(status_code=400, detail="alert_id is required")
    for a in api_state.pending_alerts:
        if a["id"] == aid:
            a["read"] = True
            return JSONResponse(content={"status": "success", "message": f"Alert {aid} marked as read"})
    return JSONResponse(content={"status": "error", "message": f"Alert {aid} not found"}, status_code=404)
