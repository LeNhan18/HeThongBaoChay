"""Root và health endpoints."""
from datetime import datetime

from fastapi import APIRouter

import config
from api_state import model

router = APIRouter()


@router.get("/")
def root():
    """API info và danh sách endpoints."""
    return {
        "title": config.API_TITLE,
        "version": config.API_VERSION,
        "status": "active",
        "endpoints": {
            "health": "/health/",
            "predict_image": "/predict/",
            "analyze_video": "/analyze_video/",
            "camera_start": "/camera/start/",
            "camera_stream": "/camera/stream/",
            "camera_stop": "/camera/stop/",
            "mobile_camera_detect": "/mobile/camera/detect",
            "esp32_capture": "/esp32/capture",
            "esp32_capture_with_boxes": "/esp32/capture_with_boxes",
            "mobile_alerts": "/mobile/get_alerts",
            "predictions_history": "/predictions/history",
            "documentation": "/docs",
        },
    }


@router.get("/health/")
def health_check():
    """Kiểm tra API và model."""
    return {
        "status": "ok",
        "model_loaded": model is not None,
        "model_path": config.MODEL_PATH if model else "Not loaded",
        "version": config.API_VERSION,
    }


@router.get("/test/")
def test_connection():
    """Test kết nối mạng."""
    return {
        "message": "Connection successful!",
        "timestamp": datetime.now().isoformat(),
        "server_port": 8000,
    }


@router.get("/predictions/history")
def get_predictions_history():
    """Lấy lịch sử predictions (stub - trả về rỗng)."""
    return []
