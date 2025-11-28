"""
Fire and Smoke Detection API

Real-time detection system using YOLOv11 model for identifying fire and smoke in images,
videos, and camera streams. Provides REST API endpoints for image classification, video
analysis, and live streaming detection.

Features:
- Image-based fire/smoke detection with confidence threshold control
- Video file processing with frame-by-frame analysis
- Real-time camera streaming with MJPEG output
- JSON responses with detailed detection information
- CORS support for cross-origin requests
- Comprehensive error handling and logging
"""

import io
import os
import time
import tempfile
import shutil
import logging
from datetime import datetime
from typing import List, Dict, Any, Optional
from collections import deque

import cv2
import numpy as np
from fastapi import FastAPI, File, UploadFile, HTTPException, Query
from fastapi.responses import StreamingResponse, JSONResponse
from fastapi.middleware.cors import CORSMiddleware
from ultralytics import YOLO

# ============================================================================
# Configuration
# ============================================================================

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

MODEL_PATH = r'e:\HeThongBaoChay\training_results_20251125_021040\advanced_fire_smoke_yolo11s\weights\best.pt'

API_TITLE = "Fire and Smoke Detection API"
API_VERSION = "2.0"
DEFAULT_CONFIDENCE = 0.25

CAMERA_WIDTH = 640
CAMERA_HEIGHT = 480
CAMERA_FPS = 30

# ============================================================================
# Global State
# ============================================================================

model: Optional[YOLO] = None
camera_active: bool = False
detection_results: deque = deque(maxlen=100)
camera_stats: Dict[str, Any] = {
    "frames": 0,
    "detections": 0,
    "start_time": None
}

# ============================================================================
# Model Loading
# ============================================================================

def load_model() -> Optional[YOLO]:
    """Load YOLO model from disk with error handling."""
    try:
        if not os.path.exists(MODEL_PATH):
            logger.error(f"Model file not found: {MODEL_PATH}")
            return None
        
        loaded_model = YOLO(MODEL_PATH)
        logger.info("Model loaded successfully")
        return loaded_model
    
    except Exception as e:
        logger.error(f"Failed to load model: {e}")
        return None

model = load_model()

# ============================================================================
# FastAPI Application
# ============================================================================

app = FastAPI(title=API_TITLE, version=API_VERSION)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ============================================================================
# Utility Functions
# ============================================================================

def validate_model_loaded() -> None:
    """Raise exception if model is not loaded."""
    if model is None:
        raise HTTPException(
            status_code=500,
            detail="Model is not loaded"
        )

def read_image_bytes(file_content: bytes) -> Optional[np.ndarray]:
    """Decode image from bytes."""
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
    """Extract detection data from YOLO inference result."""
    detections = []
    
    if result.boxes is None or len(result.boxes) == 0:
        return detections
    
    for box in result.boxes:
        class_id = int(box.cls[0])
        confidence = float(box.conf[0])
        class_name = model.names[class_id]
        bbox = box.xyxy[0].tolist()
        
        detection = {
            "class": class_name,
            "confidence": round(confidence, 4),
            "bbox": {
                "x1": round(bbox[0], 2),
                "y1": round(bbox[1], 2),
                "x2": round(bbox[2], 2),
                "y2": round(bbox[3], 2)
            }
        }
        detections.append(detection)
    
    return detections

def encode_image_to_jpeg(image: np.ndarray) -> bytes:
    """Encode OpenCV image to JPEG bytes."""
    _, buffer = cv2.imencode('.jpg', image)
    return buffer.tobytes()

def count_detections_by_class(detections: List[Dict]) -> Dict[str, int]:
    """Count detections grouped by class."""
    counts = {"fire": 0, "smoke": 0}
    for detection in detections:
        class_name = detection["class"].lower()
        if class_name in counts:
            counts[class_name] += 1
    return counts

# ============================================================================
# Root and Health Endpoints
# ============================================================================

@app.get("/")
def root():
    """API information and available endpoints."""
    return {
        "title": API_TITLE,
        "version": API_VERSION,
        "status": "active",
        "endpoints": {
            "health": "/health/",
            "predict_image": "/predict/",
            "predict_json": "/predict_json/",
            "analyze_video": "/analyze_video/",
            "camera_start": "/camera/start/",
            "camera_stream": "/camera/stream/",
            "camera_stop": "/camera/stop/",
            "camera_stats": "/camera/stats/",
            "documentation": "/docs"
        }
    }

@app.get("/health/")
def health_check():
    """Check API and model status."""
    return {
        "status": "ok",
        "model_loaded": model is not None,
        "model_path": MODEL_PATH if model is not None else "Not loaded",
        "version": API_VERSION
    }

# ============================================================================
# Image Detection Endpoints
# ============================================================================

@app.post("/predict/")
def predict_image_with_annotation(
    file: UploadFile = File(...),
    confidence: float = Query(DEFAULT_CONFIDENCE, ge=0, le=1)
):
    """
    Detect fire and smoke in image and return annotated result.
    
    Args:
        file: Image file (JPG or PNG format)
        confidence: Detection confidence threshold (0-1), default 0.25
    
    Returns:
        JPEG image with detection bounding boxes drawn
        Headers include detection counts (X-Detections-Count, X-Fire-Count, X-Smoke-Count)
    """
    validate_model_loaded()
    
    if not file.filename.endswith(('.jpg', '.jpeg', '.png')):
        return JSONResponse(
            status_code=400,
            content={"error": "Unsupported format. Supported: JPG, PNG"}
        )
    
    try:
        contents = file.file.read()
        img = read_image_bytes(contents)
        
        if img is None:
            return JSONResponse(
                status_code=400,
                content={"error": "Failed to read image file"}
            )
        
        results = model(img, conf=confidence)
        result = results[0]
        detections = extract_detections(result)
        
        annotated_img = result.plot()
        img_bytes = encode_image_to_jpeg(annotated_img)
        
        fire_count = sum(1 for d in detections if d["class"] == "fire")
        smoke_count = sum(1 for d in detections if d["class"] == "smoke")
        
        return StreamingResponse(
            iter([img_bytes]),
            media_type="image/jpeg",
            headers={
                "X-Detections-Count": str(len(detections)),
                "X-Fire-Count": str(fire_count),
                "X-Smoke-Count": str(smoke_count)
            }
        )
        
    except Exception as e:
        logger.error(f"Error in predict_image_with_annotation: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/predict_json/")
def predict_image_json(
    file: UploadFile = File(...),
    confidence: float = Query(DEFAULT_CONFIDENCE, ge=0, le=1)
):
    """
    Detect fire and smoke in image and return JSON response only.
    
    Args:
        file: Image file (JPG or PNG format)
        confidence: Detection confidence threshold (0-1), default 0.25
    
    Returns:
        JSON object containing:
        - timestamp: ISO format timestamp
        - image_size: Image dimensions
        - detections: List of detected objects with bounding boxes
        - summary: Count of total, fire, and smoke detections
    """
    validate_model_loaded()
    
    if not file.filename.endswith(('.jpg', '.jpeg', '.png')):
        return JSONResponse(
            status_code=400,
            content={"error": "Unsupported format. Supported: JPG, PNG"}
        )
    
    try:
        contents = file.file.read()
        img = read_image_bytes(contents)
        
        if img is None:
            return JSONResponse(
                status_code=400,
                content={"error": "Failed to read image file"}
            )
        
        height, width = img.shape[:2]
        
        results = model(img, conf=confidence)
        result = results[0]
        detections = extract_detections(result)
        
        summary = count_detections_by_class(detections)
        summary["total"] = len(detections)
        
        return JSONResponse(content={
            "timestamp": datetime.now().isoformat(),
            "image_size": {"width": width, "height": height},
            "detections": detections,
            "summary": summary
        })
        
    except Exception as e:
        logger.error(f"Error in predict_image_json: {e}")
        raise HTTPException(status_code=500, detail=str(e))

# ============================================================================
# Video Analysis Endpoint
# ============================================================================

@app.post("/analyze_video/")
async def analyze_video_file(
    file: UploadFile = File(...),
    confidence: float = Query(DEFAULT_CONFIDENCE, ge=0, le=1)
):
    """
    Analyze video file for fire and smoke detection.
    
    Processes each frame with YOLO model and returns annotated video file.
    
    Args:
        file: Video file (MP4, AVI, MOV, or MKV format)
        confidence: Detection confidence threshold (0-1), default 0.25
    
    Returns:
        MP4 video with detection bounding boxes drawn on each frame
        Headers include processing statistics
    """
    validate_model_loaded()
    
    if not file.filename.endswith(('.mp4', '.avi', '.mov', '.mkv')):
        return JSONResponse(
            status_code=400,
            content={"error": "Unsupported format. Supported: MP4, AVI, MOV, MKV"}
        )
    
    temp_dir = tempfile.mkdtemp()
    
    try:
        input_path = os.path.join(temp_dir, file.filename)
        with open(input_path, "wb") as buffer:
            shutil.copyfileobj(file.file, buffer)
        
        cap = cv2.VideoCapture(input_path)
        if not cap.isOpened():
            raise HTTPException(status_code=400, detail="Failed to open video file")
        
        frame_width = int(cap.get(cv2.CAP_PROP_FRAME_WIDTH))
        frame_height = int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT))
        fps = int(cap.get(cv2.CAP_PROP_FPS))
        total_frames = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))
        
        output_path = os.path.join(temp_dir, f"result_{file.filename}")
        fourcc = cv2.VideoWriter_fourcc(*'mp4v')
        out = cv2.VideoWriter(output_path, fourcc, fps, (frame_width, frame_height))
        
        frame_count = 0
        detection_count = 0
        start_time = time.time()
        
        logger.info(f"Processing video: {file.filename} ({total_frames} frames)")
        
        while True:
            ret, frame = cap.read()
            if not ret:
                break
            
            results = model(frame, conf=confidence)
            annotated_frame = results[0].plot()
            out.write(annotated_frame)
            
            if results[0].boxes is not None:
                detection_count += len(results[0].boxes)
            
            frame_count += 1
            
            if frame_count % 30 == 0:
                logger.info(f"Processed {frame_count}/{total_frames} frames")
        
        cap.release()
        out.release()
        
        processing_time = time.time() - start_time
        fps_processed = frame_count / processing_time if processing_time > 0 else 0
        
        logger.info(f"Video processing completed: {frame_count} frames in {processing_time:.2f}s")
        logger.info(f"Total detections: {detection_count}")
        
        def iterfile():
            with open(output_path, mode="rb") as video_file:
                yield from video_file
            shutil.rmtree(temp_dir)
        
        return StreamingResponse(
            iterfile(),
            media_type="video/mp4",
            headers={
                "X-Frames-Processed": str(frame_count),
                "X-Detections-Total": str(detection_count),
                "X-Processing-Time": f"{processing_time:.2f}s",
                "X-FPS": f"{fps_processed:.2f}"
            }
        )
        
    except Exception as e:
        shutil.rmtree(temp_dir, ignore_errors=True)
        logger.error(f"Error in analyze_video_file: {e}")
        raise HTTPException(status_code=500, detail=str(e))

# ============================================================================
# Camera Streaming Endpoints
# ============================================================================

def camera_feed_generator(camera_index: int = 0, confidence: float = DEFAULT_CONFIDENCE):
    """
    Generate MJPEG stream from camera with real-time detection.
    
    Continuously captures frames from camera, runs detection, and yields
    JPEG-encoded frames in MJPEG format for streaming.
    """
    global camera_active, detection_results, camera_stats
    
    cap = cv2.VideoCapture(camera_index)
    if not cap.isOpened():
        logger.error(f"Cannot open camera {camera_index}")
        return
    
    cap.set(cv2.CAP_PROP_FRAME_WIDTH, CAMERA_WIDTH)
    cap.set(cv2.CAP_PROP_FRAME_HEIGHT, CAMERA_HEIGHT)
    cap.set(cv2.CAP_PROP_FPS, CAMERA_FPS)
    
    camera_stats["start_time"] = time.time()
    camera_stats["frames"] = 0
    camera_stats["detections"] = 0
    
    try:
        while camera_active:
            ret, frame = cap.read()
            if not ret:
                logger.warning("Cannot read frame from camera")
                break
            
            results = model(frame, conf=confidence)
            annotated_frame = results[0].plot()
            
            if results[0].boxes is not None:
                num_detections = len(results[0].boxes)
                camera_stats["detections"] += num_detections
                
                detection_results.append({
                    "timestamp": datetime.now().isoformat(),
                    "count": num_detections,
                    "frame": camera_stats["frames"]
                })
            
            camera_stats["frames"] += 1
            
            frame_bytes = encode_image_to_jpeg(annotated_frame)
            
            yield (b'--frame\r\n'
                   b'Content-Type: image/jpeg\r\n'
                   b'Content-Length: ' + f'{len(frame_bytes)}'.encode() + b'\r\n\r\n' +
                   frame_bytes + b'\r\n')
    
    finally:
        cap.release()


@app.post("/camera/start/")
async def start_camera(camera_index: int = Query(0)):
    """
    Start camera streaming session.
    
    Args:
        camera_index: Camera device index (0 for default)
    
    Returns:
        JSON with status and stream URL
    """
    validate_model_loaded()
    
    global camera_active
    
    if camera_active:
        return JSONResponse(content={"status": "Camera already running"})
    
    camera_active = True
    logger.info(f"Camera {camera_index} started")
    
    return JSONResponse(content={
        "status": "Camera started",
        "camera_index": camera_index,
        "stream_url": f"/camera/stream/?camera_index={camera_index}"
    })


@app.get("/camera/stream/")
async def stream_camera(
    camera_index: int = Query(0),
    confidence: float = Query(DEFAULT_CONFIDENCE, ge=0, le=1)
):
    """
    Stream real-time camera feed with detection.
    
    Requires camera to be started with /camera/start/ endpoint first.
    
    Args:
        camera_index: Camera device index (0 for default)
        confidence: Detection confidence threshold (0-1)
    
    Returns:
        MJPEG stream (multipart/x-mixed-replace)
    """
    validate_model_loaded()
    
    if not camera_active:
        raise HTTPException(status_code=400, detail="Camera not active. Call /camera/start/ first")
    
    return StreamingResponse(
        camera_feed_generator(camera_index, confidence),
        media_type="multipart/x-mixed-replace; boundary=frame"
    )


@app.post("/camera/stop/")
async def stop_camera():
    """Stop camera streaming session."""
    global camera_active
    
    camera_active = False
    logger.info("Camera stopped")
    
    return JSONResponse(content={"status": "Camera stopped"})


@app.get("/camera/stats/")
async def get_camera_stats():
    """
    Get camera streaming statistics.
    
    Returns:
        JSON with session metrics including frames processed, detections,
        elapsed time, FPS, and recent detection history
    """
    if not camera_stats["start_time"]:
        return JSONResponse(content={"status": "Camera not started"})
    
    elapsed_time = time.time() - camera_stats["start_time"]
    fps = camera_stats["frames"] / elapsed_time if elapsed_time > 0 else 0
    avg_detections = camera_stats["detections"] / max(1, camera_stats["frames"])
    
    return JSONResponse(content={
        "active": camera_active,
        "frames_processed": camera_stats["frames"],
        "total_detections": camera_stats["detections"],
        "elapsed_time": f"{elapsed_time:.2f}s",
        "fps": f"{fps:.2f}",
        "avg_detections_per_frame": round(avg_detections, 3),
        "recent_detections": list(detection_results)
    })