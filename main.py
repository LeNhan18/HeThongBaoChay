"""
FastAPI Fire & Smoke Detection API
Chạy: uvicorn main:app --host 0.0.0.0 --port 8000 --reload
"""
import logging
import os

import firebase_admin
from firebase_admin import credentials
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from ultralytics import YOLO

import config
import api_state
from routers import root, images, video, camera, esp32, mobile
from services.notifications import set_firebase_enabled

# Logging
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
)
logger = logging.getLogger(__name__)

# Firebase
try:
    firebase_key = os.path.join(config.PROJECT_ROOT, "firebase-service-account.json")
    if os.path.exists(firebase_key):
        cred = credentials.Certificate(firebase_key)
        firebase_admin.initialize_app(cred)
        set_firebase_enabled(True)
        logger.info(" Firebase Admin SDK initialized")
    else:
        logger.warning("Firebase key not found - mock notifications")
except Exception as e:
    logger.error(f"Firebase init failed: {e}")

# Model
try:
    if os.path.exists(config.MODEL_PATH):
        api_state.model = YOLO(config.MODEL_PATH)
        logger.info(" Model loaded")
    else:
        logger.error(f"Model not found: {config.MODEL_PATH}")
except Exception as e:
    logger.error(f"Model load failed: {e}")

# App
app = FastAPI(title=config.API_TITLE, version=config.API_VERSION)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Routers
app.include_router(root.router)
app.include_router(images.router)
app.include_router(video.router)
app.include_router(camera.router)
app.include_router(esp32.router)
app.include_router(mobile.router)
