import io
import os
import time
import tempfile
import shutil
import logging
import requests
from datetime import datetime
from typing import List, Dict, Any, Optional
from collections import deque
import cv2
import numpy as np
from fastapi import FastAPI, File, UploadFile, HTTPException, Query
from fastapi.responses import StreamingResponse, JSONResponse
from fastapi.middleware.cors import CORSMiddleware
from ultralytics import YOLO
import firebase_admin
from firebase_admin import credentials, messaging

# =============================================================================
# == Configuration ============================================================
# =============================================================================

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
# Firebase Configuration
# ============================================================================

# Initialize Firebase Admin
FIREBASE_ENABLED = False
try:
    # Note: google-services.json is for client apps, not admin SDK
    # For admin SDK, we need a service account key
    firebase_key_path = r'e:\HeThongBaoChay\firebase-service-account.json'
    if os.path.exists(firebase_key_path):
        cred = credentials.Certificate(firebase_key_path)
        firebase_admin.initialize_app(cred)
        logger.info("🔥 Firebase Admin SDK initialized successfully")
        FIREBASE_ENABLED = True
    else:
        logger.warning("⚠️ Firebase service account key not found - Using mock notifications")
        FIREBASE_ENABLED = False
except Exception as e:
    logger.error(f"❌ Firebase initialization failed: {e} - Using mock notifications")
    FIREBASE_ENABLED = False

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

# Mobile alerts queue and FCM tokens
mobile_alerts: List[Dict] = []
fcm_tokens: List[str] = []  # Store FCM tokens from mobile apps

# Alert storage for real-time notifications
pending_alerts: List[Dict[str, Any]] = []
alert_counter: int = 0

# Vietnamese class name mapping
VIETNAMESE_LABELS = {
    "fire": "Lửa",
    "smoke": "Khói"
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
# Utility Functions ==========================================================
# ============================================================================

def validate_model_loaded() -> None:
    """Raise exception if model is not loaded."""
    if model is None:
        raise HTTPException(
            status_code=500,
            detail="Model is not loaded"
        )

def read_image_bytes(file_content: bytes) -> Optional[np.ndarray]:

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

def plot_with_vietnamese_labels(result, img):
    """Custom plot function with Vietnamese labels and enhanced visualization."""
    import cv2
    
    # Make sure we have a copy to work with
    annotated_img = img.copy()
    
    if result.boxes is not None and len(result.boxes) > 0:
        logger.info(f"Drawing {len(result.boxes)} detections on frame")
        
        for i, box in enumerate(result.boxes):
            # Get coordinates
            x1, y1, x2, y2 = box.xyxy[0].tolist()
            x1, y1, x2, y2 = int(x1), int(y1), int(x2), int(y2)
            
            # Get class info
            class_id = int(box.cls[0])
            confidence = float(box.conf[0])
            class_name_en = model.names[class_id]
            class_name_vi = VIETNAMESE_LABELS.get(class_name_en.lower(), class_name_en)
            
            # Enhanced colors for better visibility
            if class_name_en.lower() == 'fire':
                color = (0, 0, 255)  # Red for fire (BGR format)
                text_color = (255, 255, 255)  # White text
            else:  # smoke
                color = (255, 0, 0)  # Blue for smoke (BGR format)
                text_color = (255, 255, 255)  # White text
            
            # Draw thicker bounding box for better visibility
            thickness = max(2, int((img.shape[0] + img.shape[1]) / 600))
            cv2.rectangle(annotated_img, (x1, y1), (x2, y2), color, thickness)
            
            # Draw filled corner markers for extra visibility
            corner_size = thickness * 3
            cv2.rectangle(annotated_img, (x1, y1), (x1 + corner_size, y1 + corner_size), color, -1)
            cv2.rectangle(annotated_img, (x2 - corner_size, y1), (x2, y1 + corner_size), color, -1)
            cv2.rectangle(annotated_img, (x1, y2 - corner_size), (x1 + corner_size, y2), color, -1)
            cv2.rectangle(annotated_img, (x2 - corner_size, y2 - corner_size), (x2, y2), color, -1)
            
            # Create label with Vietnamese text and confidence percentage
            confidence_percent = confidence * 100
            label = f"{class_name_vi} {confidence_percent:.1f}%"
            
            # Use larger font for better readability
            font_scale = max(0.6, min(1.2, (img.shape[0] + img.shape[1]) / 1500))
            font_thickness = max(1, thickness // 2)
            
            # Get text size for background
            (text_width, text_height), baseline = cv2.getTextSize(
                label, cv2.FONT_HERSHEY_DUPLEX, font_scale, font_thickness
            )
            
            # Position label above bounding box, but handle edge cases
            label_y = y1 - 10
            if label_y - text_height < 0:  # If too close to top, put label inside box
                label_y = y1 + text_height + 10
            
            # Draw semi-transparent background for better text visibility
            label_bg_points = np.array([
                [x1, label_y - text_height - 5],
                [x1 + text_width + 10, label_y - text_height - 5],
                [x1 + text_width + 10, label_y + baseline + 5],
                [x1, label_y + baseline + 5]
            ], np.int32)
            
            # Create overlay for transparency
            overlay = annotated_img.copy()
            cv2.fillPoly(overlay, [label_bg_points], color)
            cv2.addWeighted(overlay, 0.8, annotated_img, 0.2, 0, annotated_img)
            
            # Draw the text
            cv2.putText(
                annotated_img, 
                label, 
                (x1 + 5, label_y), 
                cv2.FONT_HERSHEY_DUPLEX, 
                font_scale, 
                text_color, 
                font_thickness,
                cv2.LINE_AA  # Anti-aliasing for smoother text
            )
            
            # Add detection number for debugging
            if logger.isEnabledFor(logging.DEBUG):
                debug_label = f"#{i+1}"
                cv2.putText(
                    annotated_img,
                    debug_label,
                    (x2 - 30, y1 + 20),
                    cv2.FONT_HERSHEY_SIMPLEX,
                    0.5,
                    (255, 255, 255),
                    1
                )
    else:
        logger.debug("No detections found in this frame")
    
    return annotated_img

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

@app.get("/test/")
def test_connection():
    """Simple test endpoint for debugging network connectivity."""
    logger.info("Test endpoint called")
    return {
        "message": "Connection successful!",
        "timestamp": datetime.now().isoformat(),
        "server_ip": "192.168.1.149",
        "server_port": 8000
    }

# ============================================================================
# ========= Image Detection Endpoints ========================================
# ============================================================================

@app.post("/predict/")
def predict_image_with_annotation(
    file: UploadFile = File(...),
    confidence: float = Query(DEFAULT_CONFIDENCE, ge=0, le=1)
):

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
        
        results = model(img, conf=confidence, verbose=False)

        result = results[0]

        detections = extract_detections(result)

        # Use custom Vietnamese plot function for consistent annotation
        annotated_img = plot_with_vietnamese_labels(result, img)
        
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
def analyze_video_file(
    file: UploadFile = File(...),
    confidence: float = Query(DEFAULT_CONFIDENCE, ge=0, le=1)
):

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
        
        # Try different codecs to ensure video creation works
        codecs = [('XVID', '.avi'), ('MJPG', '.avi'), ('mp4v', '.mp4')]
        out = None
        output_path = None
        
        for codec, ext in codecs:
            try:
                test_path = os.path.join(temp_dir, f"result_{file.filename}").replace('.mp4', ext)
                fourcc = cv2.VideoWriter_fourcc(*codec)
                test_out = cv2.VideoWriter(test_path, fourcc, fps, (frame_width, frame_height))
                
                if test_out.isOpened():
                    out = test_out
                    output_path = test_path
                    logger.info(f"Using {codec} codec for output")
                    break
                else:
                    test_out.release()
            except Exception as e:
                logger.warning(f"Failed to create VideoWriter with {codec}: {e}")
        
        if out is None or not out.isOpened():
            raise HTTPException(status_code=500, detail="Failed to create video writer with any codec")
            
        frame_count = 0
        detection_count = 0
        fire_count = 0
        smoke_count = 0
        start_time = time.time()
        
        logger.info(f"Processing video: {file.filename} ({total_frames} frames)")
        
        while True:
            ret, frame = cap.read()
            if not ret:
                break
            
            results = model(frame, conf=confidence, verbose=False)
            
            # Use custom Vietnamese plot function instead of default plot()
            annotated_frame = plot_with_vietnamese_labels(results[0], frame)
            
            out.write(annotated_frame)
            
            if results[0].boxes is not None:
                boxes = results[0].boxes
                detection_count += len(boxes)
                
                for box in boxes:
                    class_id = int(box.cls[0])
                    class_name = model.names[class_id]
                    if class_name.lower() == "fire":
                        fire_count += 1
                    elif class_name.lower() == "smoke":
                        smoke_count += 1
            
            frame_count += 1
            
            if frame_count % 30 == 0:
                logger.info(f"Processed {frame_count}/{total_frames} frames")
        
        cap.release()
        out.release()
        
        processing_time = time.time() - start_time
        fps_processed = frame_count / processing_time if processing_time > 0 else 0
        
        logger.info(f"Video processing completed: {frame_count} frames in {processing_time:.2f}s")
        logger.info(f"Total detections: {detection_count} (Fire: {fire_count}, Smoke: {smoke_count})")
        
        def iterfile():
            if not os.path.exists(output_path):
                logger.error(f"Output file not found: {output_path}")
                yield b"Video processing failed - output file not created"
                return
            
            try:
                with open(output_path, mode="rb") as video_file:
                    yield from video_file
            finally:
                shutil.rmtree(temp_dir)
        
        return StreamingResponse(
            iterfile(),
            media_type="video/mp4",
            headers={
                "X-Frames-Processed": str(frame_count),
                "X-Detections-Total": str(detection_count),
                "X-Fire-Count": str(fire_count),
                "X-Smoke-Count": str(smoke_count),
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
                   frame_bytes + b'\r\r\n')
    
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
        "camera_status": "online",
        "camera_index": camera_index,
        "stream_url": f"/camera/stream/?camera_index={camera_index}"
    })


@app.get("/camera/stream/")
async def stream_camera(
    camera_index: int = Query(0),
    confidence: float = Query(DEFAULT_CONFIDENCE, ge=0, le=1)
):
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

    return JSONResponse(content={
        "status": "Camera stopped",
        "camera_status": "offline"
    })


@app.get("/camera/stats/")
async def get_camera_stats():
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


# ============================================================================
# Mobile Camera Real-time Detection Endpoints
# ============================================================================

@app.post("/mobile/camera/detect")
async def mobile_camera_detect(
    file: UploadFile = File(...),
    confidence: float = Query(DEFAULT_CONFIDENCE, ge=0, le=1)
):
    """
    Endpoint for mobile camera real-time detection.
    Receives frame from mobile camera and returns detection results.
    """
    validate_model_loaded()
    
    try:
        # Read image from mobile camera
        file_content = await file.read()
        img = read_image_bytes(file_content)
        
        if img is None:
            raise HTTPException(
                status_code=400,
                detail="Invalid image format or corrupted image"
            )
        
        # Run detection
        results = model(img, conf=confidence, verbose=False)
        result = results[0]
        
        # Extract detections
        detections = extract_detections(result)
        detection_count = count_detections_by_class(detections)
        
        # Store detection result for analytics
        detection_result = {
            "timestamp": datetime.now().isoformat(),
            "detections": detections,
            "count": detection_count
        }
        detection_results.append(detection_result)
        
        # Update stats
        camera_stats["frames"] += 1
        camera_stats["detections"] += len(detections)
        if camera_stats["start_time"] is None:
            camera_stats["start_time"] = time.time()
        
        # Annotate image with Vietnamese labels
        annotated_img = plot_with_vietnamese_labels(result, img)
        
        # Encode annotated image
        annotated_bytes = encode_image_to_jpeg(annotated_img)
        
        return JSONResponse(content={
            "success": True,
            "timestamp": detection_result["timestamp"],
            "detections": detections,
            "detection_count": detection_count,
            "total_detections": len(detections),
            "has_fire": detection_count["fire"] > 0,
            "has_smoke": detection_count["smoke"] > 0,
            "alert_level": get_alert_level(detection_count),
            "message": get_detection_message(detection_count),
            "annotated_image_size": len(annotated_bytes)
        })
        
    except Exception as e:
        logger.error(f"Error in mobile camera detection: {e}")
        raise HTTPException(
            status_code=500,
            detail=f"Detection failed: {str(e)}"
        )


@app.post("/mobile/camera/detect_with_image")
async def mobile_camera_detect_with_image(
    file: UploadFile = File(...),
    confidence: float = Query(DEFAULT_CONFIDENCE, ge=0, le=1)
):
    """
    Mobile camera detection endpoint that returns annotated image.
    """
    validate_model_loaded()
    
    try:
        # Read image from mobile camera
        file_content = await file.read()
        img = read_image_bytes(file_content)
        
        if img is None:
            raise HTTPException(
                status_code=400,
                detail="Invalid image format or corrupted image"
            )
        
        # Run detection
        results = model(img, conf=confidence, verbose=False)
        result = results[0]
        
        # Extract detections
        detections = extract_detections(result)
        detection_count = count_detections_by_class(detections)
        
        # Annotate image with Vietnamese labels
        annotated_img = plot_with_vietnamese_labels(result, img)
        
        # Encode annotated image
        annotated_bytes = encode_image_to_jpeg(annotated_img)
        
        # Store detection result
        detection_result = {
            "timestamp": datetime.now().isoformat(),
            "detections": detections,
            "count": detection_count
        }
        detection_results.append(detection_result)
        
        # Return annotated image as response
        return StreamingResponse(
            io.BytesIO(annotated_bytes),
            media_type="image/jpeg",
            headers={
                "X-Detection-Count": str(len(detections)),
                "X-Fire-Count": str(detection_count["fire"]),
                "X-Smoke-Count": str(detection_count["smoke"]),
                "X-Alert-Level": get_alert_level(detection_count),
                "X-Has-Fire": str(detection_count["fire"] > 0),
                "X-Has-Smoke": str(detection_count["smoke"] > 0)
            }
        )
        
    except Exception as e:
        logger.error(f"Error in mobile camera detection with image: {e}")
        raise HTTPException(
            status_code=500,
            detail=f"Detection failed: {str(e)}"
        )


# ============================================================================
# ESP32-CAM Streaming Endpoints
# ============================================================================

@app.post("/esp32/connect")
async def esp32_connect(esp32_ip: str = Query(...)):
    """
    Test connection to ESP32-CAM device.
    
    Args:
        esp32_ip: IP address of ESP32-CAM device
    
    Returns:
        Connection status and device info
    """
    try:
        # Test ESP32 connection with timeout
        response = requests.get(
            f"http://{esp32_ip}/status",
            timeout=5
        )
        
        if response.status_code == 200:
            return JSONResponse(content={
                "status": "connected",
                "esp32_ip": esp32_ip,
                "device_status": "online",
                "message": "ESP32-CAM connected successfully"
            })
        else:
            return JSONResponse(
                status_code=400,
                content={
                    "status": "failed",
                    "esp32_ip": esp32_ip,
                    "device_status": "offline",
                    "message": "ESP32-CAM not responding"
                }
            )
    
    except Exception as e:
        logger.error(f"ESP32 connection error: {e}")
        return JSONResponse(
            status_code=500,
            content={
                "status": "error",
                "esp32_ip": esp32_ip,
                "device_status": "unknown",
                "message": f"Connection failed: {str(e)}"
            }
        )


@app.post("/esp32/capture")
async def esp32_capture_and_analyze(
    esp32_ip: str = Query(...),
    confidence: float = Query(DEFAULT_CONFIDENCE, ge=0, le=1)
):
    """
    Capture image from ESP32-CAM and analyze for fire/smoke detection.
    
    Args:
        esp32_ip: IP address of ESP32-CAM device
        confidence: Detection confidence threshold
    
    Returns:
        JSON with detection results and image analysis
    """
    validate_model_loaded()
    
    try:
        # Capture image from ESP32-CAM
        response = requests.get(
            f"http://{esp32_ip}/capture",
            headers={'Accept': 'image/jpeg'},
            timeout=10
        )
        
        if response.status_code != 200:
            raise HTTPException(
                status_code=400,
                detail=f"Failed to capture from ESP32-CAM: {response.status_code}"
            )
        
        # Process captured image
        img_bytes = response.content
        img = read_image_bytes(img_bytes)
        
        if img is None:
            raise HTTPException(
                status_code=400,
                detail="Invalid image data from ESP32-CAM"
            )
        
        # Run YOLO detection
        results = model(img, conf=confidence, verbose=False)
        result = results[0]
        
        # Extract detections
        detections = extract_detections(result)
        detection_count = count_detections_by_class(detections)
        
        # Calculate fire detection
        fire_detected = detection_count["fire"] > 0 or detection_count["smoke"] > 0
        max_confidence = max([d["confidence"] for d in detections]) if detections else 0.0
        
        return JSONResponse(content={
            "timestamp": datetime.now().isoformat(),
            "esp32_ip": esp32_ip,
            "fire_detected": fire_detected,
            "confidence": max_confidence,
            "detections": detections,
            "fire_count": detection_count["fire"],
            "smoke_count": detection_count["smoke"],
            "total_detections": len(detections),
            "alert_level": get_alert_level(detection_count),
            "message": get_detection_message(detection_count),
            "has_bounding_boxes": len(detections) > 0
        })
        
    except Exception as e:
        logger.error(f"ESP32 capture and analyze error: {e}")
        raise HTTPException(
            status_code=500,
            detail=f"ESP32 analysis failed: {str(e)}"
        )


@app.post("/esp32/capture_with_boxes")
async def esp32_capture_with_bounding_boxes(
    esp32_ip: str = Query(...),
    confidence: float = Query(DEFAULT_CONFIDENCE, ge=0, le=1)
):
    """
    Capture image from ESP32-CAM and return annotated image with bounding boxes.
    
    Args:
        esp32_ip: IP address of ESP32-CAM device
        confidence: Detection confidence threshold
    
    Returns:
        Annotated image with Vietnamese bounding boxes
    """
    validate_model_loaded()
    
    try:
        # Capture image from ESP32-CAM
        response = requests.get(
            f"http://{esp32_ip}/capture",
            headers={'Accept': 'image/jpeg'},
            timeout=10
        )
        
        if response.status_code != 200:
            raise HTTPException(
                status_code=400,
                detail=f"Failed to capture from ESP32-CAM: {response.status_code}"
            )
        
        # Process captured image
        img_bytes = response.content
        img = read_image_bytes(img_bytes)
        
        if img is None:
            raise HTTPException(
                status_code=400,
                detail="Invalid image data from ESP32-CAM"
            )
        
        # Run YOLO detection
        results = model(img, conf=confidence, verbose=False)
        result = results[0]
        
        # Extract detections
        detections = extract_detections(result)
        detection_count = count_detections_by_class(detections)
        
        # Annotate image with Vietnamese labels
        annotated_img = plot_with_vietnamese_labels(result, img)
        
        # Encode annotated image
        annotated_bytes = encode_image_to_jpeg(annotated_img)
        
        return StreamingResponse(
            io.BytesIO(annotated_bytes),
            media_type="image/jpeg",
            headers={
                "X-ESP32-IP": esp32_ip,
                "X-Detection-Count": str(len(detections)),
                "X-Fire-Count": str(detection_count["fire"]),
                "X-Smoke-Count": str(detection_count["smoke"]),
                "X-Alert-Level": get_alert_level(detection_count),
                "X-Has-Fire": str(detection_count["fire"] > 0),
                "X-Has-Smoke": str(detection_count["smoke"] > 0),
                "X-Max-Confidence": str(max([d["confidence"] for d in detections]) if detections else 0.0),
                "X-Timestamp": datetime.now().isoformat()
            }
        )
        
    except Exception as e:
        logger.error(f"ESP32 capture with boxes error: {e}")
        raise HTTPException(
            status_code=500,
            detail=f"ESP32 bounding box analysis failed: {str(e)}"
        )


@app.get("/esp32/stream")
async def esp32_stream_proxy(
    esp32_ip: str = Query(...),
    confidence: float = Query(DEFAULT_CONFIDENCE, ge=0, le=1)
):
    """
    Proxy ESP32-CAM stream - simple passthrough for now.
    
    Args:
        esp32_ip: IP address of ESP32-CAM device
        confidence: Detection confidence threshold (for future use)
    
    Returns:
        Streaming response from ESP32-CAM
    """
    
    def esp32_stream_generator():
        try:
            # Direct connection to ESP32 stream
            logger.info(f"Connecting to ESP32 stream: http://{esp32_ip}/stream")
            
            stream_response = requests.get(
                f"http://{esp32_ip}/stream",
                headers={'Accept': 'multipart/x-mixed-replace; boundary=frame'},
                stream=True,
                timeout=30
            )
            
            if stream_response.status_code != 200:
                logger.error(f"ESP32 stream failed with status: {stream_response.status_code}")
                yield b"--frame\r\nContent-Type: text/plain\r\n\r\nESP32 stream connection failed\r\n\r\n"
                return
            
            logger.info("ESP32 stream connected successfully")
            
            # Simply pass through the stream data
            for chunk in stream_response.iter_content(chunk_size=8192):
                if chunk:
                    yield chunk
                        
        except requests.exceptions.Timeout:
            logger.error(f"Timeout connecting to ESP32 at {esp32_ip}")
            yield b"--frame\r\nContent-Type: text/plain\r\n\r\nESP32 connection timeout\r\n\r\n"
        except requests.exceptions.ConnectionError:
            logger.error(f"Connection error to ESP32 at {esp32_ip}")
            yield b"--frame\r\nContent-Type: text/plain\r\n\r\nESP32 connection error\r\n\r\n"
        except Exception as e:
            logger.error(f"ESP32 stream error: {e}")
            yield b"--frame\r\nContent-Type: text/plain\r\n\r\nStream connection lost\r\n\r\n"
    
    return StreamingResponse(
        esp32_stream_generator(),
        media_type="multipart/x-mixed-replace; boundary=frame",
        headers={
            "Cache-Control": "no-cache, no-store, must-revalidate",
            "Pragma": "no-cache", 
            "Expires": "0",
            "Connection": "keep-alive"
        }
    )


def get_alert_level(detection_count: Dict[str, int]) -> str:
    """Determine alert level based on detections."""
    if detection_count["fire"] > 0:
        return "HIGH"  # Fire detected - highest priority
    elif detection_count["smoke"] > 0:
        return "MEDIUM"  # Smoke detected - medium priority
    else:
        return "LOW"  # No detection


def get_detection_message(detection_count: Dict[str, int]) -> str:
    """Get detection message in Vietnamese."""
    if detection_count["fire"] > 0 and detection_count["smoke"] > 0:
        return f" CẢNH BÁO: Phát hiện {detection_count['fire']} điểm lửa và {detection_count['smoke']} điểm khói!"
    elif detection_count["fire"] > 0:
        return f"CẢNH BÁO: Phát hiện {detection_count['fire']} điểm lửa!"
    elif detection_count["smoke"] > 0:
        return f"CẢNH BÁO: Phát hiện {detection_count['smoke']} điểm khói!"
    else:
        return "Không phát hiện lửa hoặc khói"


def send_fcm_notification(title: str, body: str, data: Dict[str, str] = None):
    """Send FCM push notification to all registered devices"""
    if not FIREBASE_ENABLED:
        # Mock notification for testing
        logger.info(f"📱 MOCK FCM: {title} - {body}")
        logger.info(f"📱 MOCK DATA: {data}")
        return True
        
    if not fcm_tokens:
        logger.warning("No FCM tokens registered")
        return False
    
    try:
        # Create the message
        message = messaging.MulticastMessage(
            notification=messaging.Notification(
                title=title,
                body=body,
            ),
            data=data or {},
            tokens=fcm_tokens,
        )
        
        # Send the message
        response = messaging.send_multicast(message)
        
        success_count = response.success_count
        failure_count = response.failure_count
        
        logger.info(f"📱 FCM sent: {success_count} success, {failure_count} failed")
        
        # Remove invalid tokens
        if response.failure_count > 0:
            failed_tokens = []
            for idx, resp in enumerate(response.responses):
                if not resp.success:
                    failed_tokens.append(fcm_tokens[idx])
                    logger.warning(f"Failed token: {resp.exception}")
            
            # Remove failed tokens
            for token in failed_tokens:
                if token in fcm_tokens:
                    fcm_tokens.remove(token)
        
        return success_count > 0
        
    except Exception as e:
        logger.error(f"FCM send error: {e}")
        return False


# =============================================================================
# Mobile Alert Endpoints
# =============================================================================

@app.post("/mobile/register_fcm_token")
async def register_fcm_token(token_data: dict):
    """Register FCM token for push notifications"""
    try:
        token = token_data.get('token')
        if not token:
            raise HTTPException(status_code=400, detail="FCM token is required")
        
        # Add token if not already exists
        if token not in fcm_tokens:
            fcm_tokens.append(token)
            logger.info(f"📱 New FCM token registered: {token[:20]}...")
        
        return {
            "status": "success",
            "message": "FCM token registered",
            "total_tokens": len(fcm_tokens)
        }
        
    except Exception as e:
        logger.error(f"Error registering FCM token: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/mobile/send_alert")
async def send_mobile_alert(alert_data: dict):
    """
    Receive alert from external scripts and forward as notification
    
    Args:
        alert_data: Dict containing alert information
    
    Returns:
        Success/failure response
    """
    global pending_alerts, alert_counter
    
    try:
        logger.info(f"Received alert from {alert_data.get('source', 'unknown')}")
        
        # Extract alert info
        fire_count = alert_data.get('fire_count', 0)
        smoke_count = alert_data.get('smoke_count', 0) 
        esp32_ip = alert_data.get('esp32_ip', 'unknown')
        confidence = alert_data.get('confidence', 0)
        message = alert_data.get('message', 'Phát hiện lửa/khói')
        
        # Log the alert
        logger.warning(f"🔥 FIRE ALERT: Fire={fire_count}, Smoke={smoke_count}, ESP32={esp32_ip}, Conf={confidence:.2%}")
        
        # Send FCM push notification
        fcm_title = "🔥 CẢNH BÁO CHÁY!"
        fcm_body = f"Phát hiện {fire_count} lửa, {smoke_count} khói từ ESP32-CAM ({esp32_ip})"
        fcm_data = {
            "type": "fire_alert",
            "fire_count": str(fire_count),
            "smoke_count": str(smoke_count),
            "esp32_ip": esp32_ip,
            "confidence": f"{confidence:.2%}",
            "timestamp": datetime.now().isoformat()
        }
        
        fcm_sent = send_fcm_notification(fcm_title, fcm_body, fcm_data)
        
        # Create alert for mobile app
        alert_counter += 1
        mobile_alert = {
            "id": alert_counter,
            "title": "🔥 CẢNH BÁO CHÁY - Live Detection",
            "body": f"Phát hiện {fire_count} lửa, {smoke_count} khói từ ESP32-CAM ({esp32_ip})",
            "fire_count": fire_count,
            "smoke_count": smoke_count,
            "confidence": confidence,
            "esp32_ip": esp32_ip,
            "source": alert_data.get('source', 'Live Detection'),
            "timestamp": datetime.now().isoformat(),
            "vietnamese_message": message,
            "read": False
        }
        
        # Add to pending alerts for app to fetch
        pending_alerts.append(mobile_alert)
        
        # Keep only last 50 alerts
        if len(pending_alerts) > 50:
            pending_alerts = pending_alerts[-50:]
        
        logger.info(f"📱 Alert added to mobile queue: ID={alert_counter}")
        
        response_data = {
            "status": "success",
            "message": "Alert received and queued for mobile app",
            "alert_id": alert_counter,
            "timestamp": datetime.now().isoformat(),
            "processed_alert": mobile_alert
        }
        
        return JSONResponse(content=response_data, status_code=200)
        
    except Exception as e:
        logger.error(f"Error processing alert: {e}")
        raise HTTPException(
            status_code=500, 
            detail=f"Failed to process alert: {str(e)}"
        )


@app.get("/mobile/get_alerts")
async def get_mobile_alerts(unread_only: bool = Query(False)):
    """
    Get pending alerts for mobile app
    
    Args:
        unread_only: If True, return only unread alerts
    
    Returns:
        List of alerts
    """
    global pending_alerts
    
    try:
        if unread_only:
            alerts = [alert for alert in pending_alerts if not alert.get('read', False)]
        else:
            alerts = pending_alerts.copy()
        
        return JSONResponse(content={
            "status": "success",
            "count": len(alerts),
            "alerts": alerts
        }, status_code=200)
        
    except Exception as e:
        logger.error(f"Error fetching alerts: {e}")
        raise HTTPException(
            status_code=500,
            detail=f"Failed to fetch alerts: {str(e)}"
        )


@app.post("/mobile/mark_alert_read")
async def mark_alert_read(request_data: dict):
    """
    Mark an alert as read
    
    Args:
        request_data: Dict containing alert_id to mark as read
    
    Returns:
        Success response
    """
    global pending_alerts
    
    try:
        alert_id = request_data.get('alert_id')
        if alert_id is None:
            raise HTTPException(status_code=400, detail="alert_id is required")
        
        for alert in pending_alerts:
            if alert['id'] == alert_id:
                alert['read'] = True
                logger.info(f"Alert {alert_id} marked as read")
                return JSONResponse(content={
                    "status": "success",
                    "message": f"Alert {alert_id} marked as read"
                }, status_code=200)
        
        return JSONResponse(content={
            "status": "error",
            "message": f"Alert {alert_id} not found"
        }, status_code=404)
        
    except Exception as e:
        logger.error(f"Error marking alert as read: {e}")
        raise HTTPException(
            status_code=500,
            detail=f"Failed to mark alert as read: {str(e)}"
        )

