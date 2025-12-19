import io
import os
import time
import tempfile
import shutil
import logging
import requests
import ipaddress
from datetime import datetime, timedelta
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

# Model path - can be overridden by environment variable
MODEL_PATH = os.getenv(
    'MODEL_PATH',
    r'e:\HeThongBaoChay\training_results_20251125_021040\advanced_fire_smoke_yolo11s\weights\best.pt'
)

API_TITLE = "Fire and Smoke Detection API"
API_VERSION = "2.0"
DEFAULT_CONFIDENCE = 0.45  # Tăng từ 0.25 lên 0.45 để giảm false positives (bóng đèn đỏ)

# File size limits
MAX_IMAGE_SIZE = 10 * 1024 * 1024  # 10MB
MAX_VIDEO_SIZE = 100 * 1024 * 1024  # 100MB

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
        logger.info(" Firebase Admin SDK initialized successfully")
        FIREBASE_ENABLED = True
    else:
        logger.warning(" Firebase service account key not found - Using mock notifications")
        FIREBASE_ENABLED = False
except Exception as e:
    logger.error(f" Firebase initialization failed: {e} - Using mock notifications")
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

# Fire duration tracking - TÍNH NĂNG MỚI
fire_duration_tracker: Dict[str, Dict[str, Any]] = {}  # {esp32_ip: {"start_time": datetime, "last_fire_time": datetime, "duration_seconds": float}}
FIRE_DURATION_THRESHOLD = 30  # 30 giây

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

def validate_file_size(file_size: int, max_size: int, file_type: str = "file") -> None:
    """Validate file size."""
    if file_size > max_size:
        max_size_mb = max_size / (1024 * 1024)
        raise HTTPException(
            status_code=413,
            detail=f"{file_type.capitalize()} too large. Maximum size: {max_size_mb:.1f}MB"
        )

def validate_ip_address(ip: str) -> None:
    """Validate IP address format."""
    try:
        ipaddress.ip_address(ip)
    except ValueError:
        raise HTTPException(
            status_code=400,
            detail=f"Invalid IP address format: {ip}"
        )

def track_fire_duration(esp32_ip: str, fire_count: int, smoke_count: int) -> Dict[str, Any]:
    """
    Track thời gian cháy liên tục của ESP32
    Returns: {
        "is_long_fire": bool,
        "duration_seconds": float,
        "show_location": bool
    }
    """
    global fire_duration_tracker
    
    current_time = datetime.now()
    has_fire = fire_count > 0 or smoke_count > 0
    
    if esp32_ip not in fire_duration_tracker:
        fire_duration_tracker[esp32_ip] = {
            "start_time": None,
            "last_fire_time": None,
            "duration_seconds": 0.0
        }
    
    tracker = fire_duration_tracker[esp32_ip]
    
    if has_fire:
        # Có lửa/khói
        if tracker["start_time"] is None:
            # Bắt đầu track
            tracker["start_time"] = current_time
            tracker["last_fire_time"] = current_time
            tracker["duration_seconds"] = 0.0
            logger.info(f"🔥 Fire tracking STARTED for ESP32 {esp32_ip}")
        else:
            # Đang track, cập nhật duration
            elapsed = (current_time - tracker["start_time"]).total_seconds()
            tracker["duration_seconds"] = elapsed
            tracker["last_fire_time"] = current_time
            
            if elapsed >= FIRE_DURATION_THRESHOLD:
                logger.warning(f"🚨 LONG FIRE DETECTED: ESP32 {esp32_ip} - {elapsed:.1f}s >= {FIRE_DURATION_THRESHOLD}s")
                return {
                    "is_long_fire": True,
                    "duration_seconds": elapsed,
                    "show_location": True
                }
    else:
        # Không có lửa/khói nữa -> reset
        if tracker["start_time"] is not None:
            duration = tracker["duration_seconds"]
            logger.info(f"✅ Fire tracking RESET for ESP32 {esp32_ip} (lasted {duration:.1f}s)")
            tracker["start_time"] = None
            tracker["last_fire_time"] = None
            tracker["duration_seconds"] = 0.0
    
    return {
        "is_long_fire": False,
        "duration_seconds": tracker["duration_seconds"],
        "show_location": False
    }

def get_esp32_location(esp32_ip: str) -> Dict[str, Any]:
    """
    Lấy GPS location của ESP32 từ config hoặc environment variables
    """
    # Có thể lưu trong database hoặc config file
    # Tạm thời dùng environment variables hoặc default
    ip_key = esp32_ip.replace('.', '_')
    latitude = float(os.getenv(
        f"ESP32_{ip_key}_LATITUDE",
        os.getenv("ESP32_LATITUDE", "10.853912")
    ))  # Default: TP.HCM
    longitude = float(os.getenv(
        f"ESP32_{ip_key}_LONGITUDE",
        os.getenv("ESP32_LONGITUDE", "106.770743")
    ))
    
    return {
        "latitude": latitude,
        "longitude": longitude,
        "address": f"ESP32-CAM ({esp32_ip})"
    }

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

def filter_false_positives_fire(detections: List[Dict[str, Any]], img: np.ndarray) -> List[Dict[str, Any]]:
    """
    Filter false positives (như bóng đèn đỏ, đèn giao thông, v.v.)
    
    Args:
        detections: List of detection dictionaries
        img: Image array để phân tích
    
    Returns:
        Filtered list of detections
    """
    if not detections or img is None:
        return detections
    
    filtered = []
    img_height, img_width = img.shape[:2]
    
    for detection in detections:
        # Chỉ filter các detection là "fire"
        if detection["class"].lower() != "fire":
            filtered.append(detection)
            continue
        
        bbox = detection["bbox"]
        x1, y1, x2, y2 = bbox["x1"], bbox["y1"], bbox["x2"], bbox["y2"]
        
        # Tính kích thước bounding box
        width = x2 - x1
        height = y2 - y1
        area = width * height
        img_area = img_width * img_height
        
        # Filter các detection quá nhỏ (có thể là noise)
        if area < img_area * 0.001:  # Nhỏ hơn 0.1% diện tích ảnh
            continue
        
        # Filter các detection quá lớn (có thể là false positive)
        if area > img_area * 0.5:  # Lớn hơn 50% diện tích ảnh
            continue
        
        # Filter các detection ở góc trên cùng (thường là đèn giao thông)
        if y1 < img_height * 0.1 and height < img_height * 0.15:
            # Kiểm tra thêm: nếu confidence thấp và ở góc trên thì skip
            if detection["confidence"] < 0.6:
                continue
        
        # Nếu confidence quá thấp thì skip
        if detection["confidence"] < 0.3:
            continue
        
        filtered.append(detection)
    
    return filtered

def plot_with_vietnamese_labels(result, img):
    """Custom plot function with Vietnamese labels and enhanced visualization."""
    # Make sure we have a copy to work with
    annotated_img = img.copy()
    
    if result.boxes is not None and len(result.boxes) > 0:
        logger.info(f"Drawing {len(result.boxes)} detections on frame")
        
        for i, box in enumerate(result.boxes):
            # Get coordinates
            # lấy toạ độ
            x1, y1, x2, y2 = box.xyxy[0].tolist() #x1,y1 top-left corner, x2,y2 bottom-right corner
            x1, y1, x2, y2 = int(x1), int(y1), int(x2), int(y2)
            
            # Get class info
            class_id = int(box.cls[0])
            confidence = float(box.conf[0])
            class_name_en = model.names[class_id]
            class_name_vi = VIETNAMESE_LABELS.get(class_name_en.lower(), class_name_en)
            
            # Enhanced colors for better visibility
            # Màu sắc nâng cao để dễ quan sát hơn
            if class_name_en.lower() == 'fire':
                color = (0, 0, 255)  # Red for fire (BGR format)
                text_color = (255, 255, 255)  # White text
            else:  # smoke
                color = (255, 0, 0)  # Blue for smoke (BGR format)
                text_color = (255, 255, 255)  # White text
            
            # Draw thicker bounding box for better visibility
            # Vẽ hộp giới hạn dày hơn để dễ quan sát hơn
            thickness = max(2, int((img.shape[0] + img.shape[1]) / 600))
            cv2.rectangle(annotated_img, (x1, y1), (x2, y2), color, thickness)
            
            # Draw filled corner markers for extra visibility
            # Vẽ các điểm đánh dấu góc được tô màu đầy đủ để dễ quan hát hơn
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
            # vẽ nền bán trong suốt để dễ nhìn chữ hơn

            label_bg_points = np.array([
                #Điểm 1 góc trái trên của nền label
                #x1 :căn trái theo bounding box
                #label_y - text_height -5 : chiều cao chữ + 5px padding phía trên text 5px
                [x1 ,label_y - text_height - 5],
                #Điểm 2 góc phải trên của nền label
                #x1 + text_width +10 : chiều rộng chữ + 10px padding phía phải text
                #label_y - text_height -5 : chiều cao chữ + 5px padding phía trên text
                [x1 +text_width + 10 ,label_y - text_height - 5],
                #Điểm 3 góc phải dưới của nền label
                #x1 + text_width +10 : chiều rộng chữ + 10px padding phía phải text
                #label_y + baseline +5 : chiều cao chữ + phần dưới chữ + 5px padding phía dưới text
                [x1 +text_width + 10 ,label_y + baseline + 5],
                #Điểm 4 góc trái dưới của nền label
                #x1 :căn trái theo bounding box
                #label_y + baseline +5 : chiều cao chữ + phần dưới chữ + 5px padding phía dưới text
                [x1 ,label_y + baseline + 5]
            ],np.int32)
            
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
            "analyze_video": "/analyze_video/",
            "camera_start": "/camera/start/",
            "camera_stream": "/camera/stream/",
            "camera_stop": "/camera/stop/",
            "mobile_camera_detect": "/mobile/camera/detect",
            "esp32_capture": "/esp32/capture",
            "esp32_capture_with_boxes": "/esp32/capture_with_boxes",
            "mobile_alerts": "/mobile/get_alerts",
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

MAX_SIZE = 1024 * 1024 * 10 # 10MB
@app.post("/predict/")
def predict_image_with_annotation(
    file: UploadFile = File(...),
    confidence: float = Query(DEFAULT_CONFIDENCE, ge=0, le=1)
):
    if file.size > MAX_SIZE:
        return JSONResponse(
            status_code=400,
            content={"error": "File size exceeds maximum allowed size of 10MB"}
        )

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
        
        # Áp dụng filter để loại bỏ false positives (bóng đèn đỏ, v.v.)
        detections = filter_false_positives_fire(detections, img)

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
        # Read file content first to check size
        file_content = file.file.read()
        validate_file_size(len(file_content), MAX_VIDEO_SIZE, "video")
        
        input_path = os.path.join(temp_dir, file.filename)
        with open(input_path, "wb") as buffer:
            buffer.write(file_content)
        
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
            
            # Resize frame to standard size for better AI detection
            # Keep aspect ratio and pad if necessary
            original_height, original_width = frame.shape[:2]
            target_size = 640  # YOLO standard input size
            
            # Calculate scaling factor to fit within target size
            scale = min(target_size / original_width, target_size / original_height)
            new_width = int(original_width * scale)
            new_height = int(original_height * scale)
            
            # Resize frame
            resized_frame = cv2.resize(frame, (new_width, new_height))
            
            # Create padded frame (black padding)
            padded_frame = np.zeros((target_size, target_size, 3), dtype=np.uint8)
            y_offset = (target_size - new_height) // 2
            x_offset = (target_size - new_width) // 2
            padded_frame[y_offset:y_offset+new_height, x_offset:x_offset+new_width] = resized_frame
            
            # Run detection on processed frame
            results = model(padded_frame, conf=confidence, verbose=False)
            
            # Use custom Vietnamese plot function on the processed frame
            annotated_frame = plot_with_vietnamese_labels(results[0], padded_frame)
            
            # Resize back to original video dimensions for output
            if annotated_frame.shape[:2] != (frame_height, frame_width):
                annotated_frame = cv2.resize(annotated_frame, (frame_width, frame_height))
            
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
            # Use Vietnamese labels for consistency
            annotated_frame = plot_with_vietnamese_labels(results[0], frame)
            
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
        
        # Áp dụng filter để loại bỏ false positives (bóng đèn đỏ, v.v.)
        detections = filter_false_positives_fire(detections, img)
        
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
        
        return JSONResponse(content={
            "success": True,
            "timestamp": detection_result["timestamp"],
            "detections": detections,
            "detection_count": detection_count,
            "total_detections": len(detections),
            "has_fire": detection_count["fire"] > 0,
            "has_smoke": detection_count["smoke"] > 0,
            "alert_level": get_alert_level(detection_count),
            "message": get_detection_message(detection_count)
        })
        
    except Exception as e:
        logger.error(f"Error in mobile camera detection: {e}")
        raise HTTPException(
            status_code=500,
            detail=f"Detection failed: {str(e)}"
        )


# ============================================================================
# ESP32-CAM Streaming Endpoints
# ============================================================================

async def _esp32_capture_helper(
    esp32_ip: str,
    confidence: float,
    return_image: bool = False
) -> tuple[Optional[np.ndarray], List[Dict[str, Any]], Dict[str, int]]:
    """
    Helper function to capture and analyze ESP32-CAM image.
    
    Args:
        esp32_ip: IP address of ESP32-CAM device
        confidence: Detection confidence threshold
        return_image: If True, return annotated image
    
    Returns:
        Tuple of (annotated_image or None, detections, detection_count)
    """
    # Validate IP address
    validate_ip_address(esp32_ip)
    
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
    
    # Áp dụng filter để loại bỏ false positives (bóng đèn đỏ, v.v.)
    detections = filter_false_positives_fire(detections, img)
    
    detection_count = count_detections_by_class(detections)
    
    # Return annotated image if requested
    annotated_img = None
    if return_image:
        annotated_img = plot_with_vietnamese_labels(result, img)
    
    return annotated_img, detections, detection_count


@app.post("/esp32/capture")
async def esp32_capture_and_analyze(
    esp32_ip: str = Query(..., regex=r'^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$'),
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
        _, detections, detection_count = await _esp32_capture_helper(
            esp32_ip, confidence, return_image=False
        )
        
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
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"ESP32 capture and analyze error: {e}")
        raise HTTPException(
            status_code=500,
            detail=f"ESP32 analysis failed: {str(e)}"
        )


@app.post("/esp32/capture_with_boxes")
async def esp32_capture_with_bounding_boxes(
    esp32_ip: str = Query(..., regex=r'^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$'),
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
        annotated_img, detections, detection_count = await _esp32_capture_helper(
            esp32_ip, confidence, return_image=True
        )
        
        if annotated_img is None:
            raise HTTPException(
                status_code=500,
                detail="Failed to generate annotated image"
            )
        
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
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"ESP32 capture with boxes error: {e}")
        raise HTTPException(
            status_code=500,
            detail=f"ESP32 bounding box analysis failed: {str(e)}"
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
        
        # ============================================================
        # TÍNH NĂNG MỚI: Track thời gian cháy và hiển thị vị trí
        # ============================================================
        fire_duration_info = track_fire_duration(esp32_ip, fire_count, smoke_count)
        show_location = fire_duration_info["show_location"]
        fire_duration_seconds = fire_duration_info["duration_seconds"]
        
        # Luôn lấy GPS location để hiển thị trong chi tiết cảnh báo
        location_data = get_esp32_location(esp32_ip)
        if show_location:
            logger.warning(f"📍 LOCATION ENABLED: ESP32 {esp32_ip} - Fire duration: {fire_duration_seconds:.1f}s")
        # ============================================================
        
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
            "read": False,
            # TÍNH NĂNG MỚI: Thông tin vị trí (luôn gửi tọa độ)
            "show_location": show_location,  # True nếu cháy >= 30s
            "fire_duration_seconds": fire_duration_seconds,
            "latitude": location_data["latitude"],
            "longitude": location_data["longitude"],
            "address": location_data["address"]
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

