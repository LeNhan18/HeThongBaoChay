"""Cấu hình ứng dụng API Fire & Smoke Detection."""
import os

# Paths
PROJECT_ROOT = os.path.dirname(os.path.abspath(__file__))
DEFAULT_MODEL_PATH = os.path.join(
    PROJECT_ROOT,
    "training_results_20251125_021040",
    "advanced_fire_smoke_yolo11s",
    "weights",
    "best.pt",
)
MODEL_PATH = os.getenv("MODEL_PATH", DEFAULT_MODEL_PATH)

# API
API_TITLE = "Fire and Smoke Detection API"
API_VERSION = "2.0"
DEFAULT_CONFIDENCE = 0.45

# File limits
MAX_IMAGE_SIZE = 10 * 1024 * 1024  # 10MB
MAX_VIDEO_SIZE = 100 * 1024 * 1024  # 100MB

# Camera
CAMERA_WIDTH = 640
CAMERA_HEIGHT = 480
CAMERA_FPS = 30

# Fire duration tracking
FIRE_DURATION_THRESHOLD = 30  # giây

# Labels
VIETNAMESE_LABELS = {"fire": "Lửa", "smoke": "Khói"}
