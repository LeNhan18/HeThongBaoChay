#!/usr/bin/env python3
"""
ESP32-CAM Live Detection Server với Flask
Serve video frames với YOLO detection cho Flutter app
"""
import cv2
from ultralytics import YOLO
import numpy as np
import time
from datetime import datetime
import requests
import json
from flask import Flask, Response, jsonify
from threading import Thread
import threading

# ======================
# CONFIG
# ======================
ESP32_IP = "172.20.10.2"     # IP ESP32-CAM
BACKEND_URL = "http://172.20.10.5:8000"  # Backend server
MODEL_PATH = "training_results_20251125_021040/advanced_fire_smoke_yolo11s/weights/best.pt"
CONF_THRESHOLD = 0.25
STREAM_URL = f"http://{ESP32_IP}:81/stream"

# Flask server config
FLASK_HOST = "0.0.0.0"  # Cho phép kết nối từ mọi IP
FLASK_PORT = 5000       # Port cho HTTP server

# Notification settings
NOTIFICATION_COOLDOWN = 3  # seconds between notifications
last_notification_time = 0
fire_detection_count = 0

# Label tiếng Việt
label_vn = {
    "fire": "🔥 LỬA",
    "smoke": "💨 KHÓI"
}

# Global variables cho frame hiện tại
current_frame = None
current_detections = {
    "fire_count": 0,
    "smoke_count": 0,
    "confidence": 0.0,
    "fps": 0.0,
    "timestamp": ""
}
frame_lock = threading.Lock()
is_running = True

# ======================
# FLASK APP
# ======================
app = Flask(__name__)

@app.route('/frame')
def get_frame():
    """Endpoint để Flutter app lấy frame hiện tại với bounding boxes"""
    global current_frame, current_detections
    
    with frame_lock:
        if current_frame is None:
            return Response(
                json.dumps({"error": "No frame available"}),
                status=404,
                mimetype='application/json'
            )
        
        # Encode frame thành JPEG với chất lượng tốt
        ret, buffer = cv2.imencode('.jpg', current_frame, [cv2.IMWRITE_JPEG_QUALITY, 90])
        if not ret:
            return Response(
                json.dumps({"error": "Failed to encode frame"}),
                status=500,
                mimetype='application/json'
            )
        
        # Trả về image với headers chứa thông tin detection
        return Response(
            buffer.tobytes(),
            mimetype='image/jpeg',
            headers={
                'X-Fire-Count': str(current_detections['fire_count']),
                'X-Smoke-Count': str(current_detections['smoke_count']),
                'X-Confidence': str(current_detections['confidence']),
                'X-FPS': str(current_detections['fps']),
                'X-Timestamp': current_detections['timestamp'],
                'Cache-Control': 'no-cache, no-store, must-revalidate',
                'Pragma': 'no-cache',
                'Expires': '0'
            }
        )

@app.route('/status')
def get_status():
    """Endpoint để lấy thông tin trạng thái detection"""
    global current_detections, is_running
    return jsonify({
        "status": "running" if is_running else "stopped",
        "fire_count": current_detections['fire_count'],
        "smoke_count": current_detections['smoke_count'],
        "confidence": current_detections['confidence'],
        "fps": current_detections['fps'],
        "timestamp": current_detections['timestamp'],
        "esp32_ip": ESP32_IP,
        "stream_url": STREAM_URL
    })

@app.route('/health')
def health_check():
    """Health check endpoint"""
    return jsonify({"status": "healthy", "service": "ESP32-CAM Detection Server"})

# ======================
# NOTIFICATION FUNCTIONS
# ======================
def send_fire_alert(fire_count, smoke_count, confidence):
    """Gửi cảnh báo lửa đến backend để chuyển tiếp đến app"""
    global last_notification_time, fire_detection_count
    
    current_time = time.time()
    time_since_last = current_time - last_notification_time

    if time_since_last < NOTIFICATION_COOLDOWN:
        remaining = NOTIFICATION_COOLDOWN - time_since_last
        print(f"⏳ Cooldown: {remaining:.1f}s còn lại trước thông báo tiếp")
        return False
    
    try:
        alert_data = {
            "source": "ESP32-CAM Live Detection (Flask Server)",
            "esp32_ip": ESP32_IP,
            "fire_count": fire_count,
            "smoke_count": smoke_count,
            "confidence": confidence,
            "timestamp": datetime.now().isoformat(),
            "message": f"🚨 CẢNH BÁO: Phát hiện {fire_count} điểm lửa, {smoke_count} điểm khói từ ESP32-CAM!"
        }
        
        response = requests.post(
            f"{BACKEND_URL}/mobile/send_alert",
            json=alert_data,
            timeout=5
        )
        
        if response.status_code == 200:
            last_notification_time = current_time
            fire_detection_count += 1
            print(f"📢 THÔNG BÁO #{fire_detection_count}: Lửa={fire_count}, Khói={smoke_count}, Confidence={confidence:.2%}")
            return True
        else:
            print(f"❌ Lỗi gửi thông báo: {response.status_code}")
            return False
            
    except Exception as e:
        print(f"❌ Lỗi kết nối backend: {e}")
        return False

# ======================
# VIDEO PROCESSING THREAD
# ======================
def video_processing_thread():
    """Thread xử lý video và detection"""
    global current_frame, current_detections, is_running
    
    print("=" * 60)
    print("🚀 ESP32-CAM Live Detection Server")
    print("=" * 60)
    print("📦 Đang tải mô hình YOLO...")
    
    try:
        model = YOLO(MODEL_PATH)
        print("✅ Đã tải model thành công!")
        print(f"📋 Model classes: {model.names}")
    except Exception as e:
        print(f"❌ Lỗi tải model: {e}")
        is_running = False
        return

    print(f"\n📡 Đang kết nối ESP32-CAM: {STREAM_URL}")
    cap = cv2.VideoCapture(STREAM_URL)

    if not cap.isOpened():
        print(f"❌ Không kết nối được ESP32-CAM tại {STREAM_URL}")
        print("💡 Kiểm tra lại IP và đảm bảo ESP32-CAM đang chạy!")
        is_running = False
        return

    print("✅ Kết nối ESP32-CAM thành công!")
    print(f"\n🌐 Flask server chạy tại: http://{FLASK_HOST}:{FLASK_PORT}")
    print(f"📱 Flutter app có thể truy cập:")
    print(f"   - Frame: http://<YOUR_PC_IP>:{FLASK_PORT}/frame")
    print(f"   - Status: http://<YOUR_PC_IP>:{FLASK_PORT}/status")
    print(f"   - Health: http://<YOUR_PC_IP>:{FLASK_PORT}/health")
    print("\n" + "=" * 60)
    print("🎬 Bắt đầu REAL-TIME FIRE/SMOKE DETECTION...")
    print("=" * 60 + "\n")

    fps_time = time.time()
    frame_count = 0

    while is_running:
        ret, frame = cap.read()
        if not ret:
            print("⚠️  Không đọc được frame, chờ ESP32...")
            time.sleep(0.1)
            continue

        frame_count += 1

        # YOLO detect
        results = model(frame, conf=CONF_THRESHOLD, verbose=False)
        boxes = results[0].boxes

        # Dùng frame để vẽ
        annotated = frame.copy()

        # ======================
        # VẼ BOUNDING BOX & COUNT DETECTIONS
        # ======================
        fire_count = 0
        smoke_count = 0
        highest_confidence = 0.0
        
        if boxes is not None and len(boxes) > 0:
            for box in boxes:
                x1, y1, x2, y2 = box.xyxy[0].cpu().numpy().astype(int)
                conf = float(box.conf[0])
                cls = int(box.cls[0])

                class_name = model.names[cls].lower()
                vn_label = label_vn.get(class_name, class_name.upper())

                # Count detections
                if class_name == "fire":
                    fire_count += 1
                elif class_name == "smoke":
                    smoke_count += 1
                
                if conf > highest_confidence:
                    highest_confidence = conf

                # Màu theo lớp: Lửa = đỏ, Khói = cam
                color = (0, 0, 255) if class_name == "fire" else (0, 165, 255)

                # Vẽ bbox
                cv2.rectangle(annotated, (x1, y1), (x2, y2), color, 2)

                text = f"{vn_label} {conf*100:.1f}%"

                # Nền label
                t_size = cv2.getTextSize(text, cv2.FONT_HERSHEY_SIMPLEX, 0.6, 2)[0]
                cv2.rectangle(annotated, (x1, y1 - 25), (x1 + t_size[0] + 8, y1), color, -1)

                # Text
                cv2.putText(
                    annotated, text, (x1 + 4, y1 - 5),
                    cv2.FONT_HERSHEY_SIMPLEX, 0.6, (255, 255, 255), 2
                )

                # Log detection
                print(f"[{datetime.now().strftime('%H:%M:%S')}] {vn_label} - {conf:.2%}")

        # ======================
        # GỬI THÔNG BÁO KHI PHÁT HIỆN LỬA
        # ======================
        if fire_count > 0:
            send_fire_alert(fire_count, smoke_count, highest_confidence)

        # ======================
        # TÍNH FPS
        # ======================
        elapsed = time.time() - fps_time
        if elapsed >= 1:
            fps = frame_count / elapsed
            fps_time = time.time()
            frame_count = 0
        else:
            fps = 0

        # Vẽ FPS và thông tin lên frame
        cv2.putText(annotated, f"FPS: {fps:.1f}", (10, 25),
                    cv2.FONT_HERSHEY_SIMPLEX, 0.7, (0, 255, 0), 2)
        
        # Vẽ thông tin detection
        info_text = f"Fire: {fire_count} | Smoke: {smoke_count}"
        if fire_count > 0 or smoke_count > 0:
            cv2.putText(annotated, info_text, (10, 50),
                        cv2.FONT_HERSHEY_SIMPLEX, 0.6, (0, 0, 255), 2)

        # Cập nhật frame hiện tại (thay vì cv2.imshow)
        with frame_lock:
            current_frame = annotated
            current_detections = {
                "fire_count": fire_count,
                "smoke_count": smoke_count,
                "confidence": highest_confidence,
                "fps": fps,
                "timestamp": datetime.now().strftime('%Y-%m-%d %H:%M:%S')
            }

    # Cleanup
    cap.release()
    cv2.destroyAllWindows()
    print("\n🛑 Đã dừng video processing thread")

# ======================
# MAIN
# ======================
if __name__ == '__main__':
    try:
        # Khởi động thread xử lý video
        video_thread = Thread(target=video_processing_thread, daemon=True)
        video_thread.start()
        
        # Đợi một chút để thread khởi động
        time.sleep(2)
        
        # Khởi động Flask server
        print(f"\n🌐 Khởi động Flask server tại http://{FLASK_HOST}:{FLASK_PORT}")
        print("📱 Sẵn sàng nhận request từ Flutter app!")
        print("💡 Nhấn Ctrl+C để dừng server\n")
        
        app.run(host=FLASK_HOST, port=FLASK_PORT, debug=False, threaded=True, use_reloader=False)
        
    except KeyboardInterrupt:
        print("\n\n🛑 Đang dừng server...")
        is_running = False
        time.sleep(1)
        print("✅ Đã dừng server thành công!")
    except Exception as e:
        print(f"\n❌ Lỗi: {e}")
        is_running = False

