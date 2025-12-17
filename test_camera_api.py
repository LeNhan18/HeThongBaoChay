#!/usr/bin/env python3
import cv2
from ultralytics import YOLO
import numpy as np
import time
from datetime import datetime
import requests
import json

# ======================
# CONFIG
# ======================
ESP32_IP = "172.20.10.2"     # IP ESP32-CAM
BACKEND_URL = "http://172.20.10.5:8000"  # Backend server
MODEL_PATH = "training_results_20251125_021040/advanced_fire_smoke_yolo11s/weights/best.pt"        # model YOLO của bạn
CONF_THRESHOLD = 0.25

STREAM_URL = f"http://{ESP32_IP}:81/stream"

# Notification settings
NOTIFICATION_COOLDOWN = 3  # seconds between notifications (thông báo mỗi 10s khi có lửa liên tục)
last_notification_time = 0
fire_detection_count = 0

# Label tiếng Việt
label_vn = {
    "fire": " LỬA",
    "smoke": " KHÓI"
}

# ======================
# NOTIFICATION FUNCTIONS
# ======================
def send_fire_alert(fire_count, smoke_count, confidence):
    """Gửi cảnh báo lửa đến backend để chuyển tiếp đến app"""
    global last_notification_time
    
    current_time = time.time()
    time_since_last = current_time - last_notification_time

    if time_since_last < NOTIFICATION_COOLDOWN:
        remaining = NOTIFICATION_COOLDOWN - time_since_last
        print(f" Cooldown: {remaining:.1f}s còn lại trước thông báo tiếp")
        return False
    
    try:
        alert_data = {
            "source": "ESP32-CAM Live Detection",
            "esp32_ip": ESP32_IP,
            "fire_count": fire_count,
            "smoke_count": smoke_count,
            "confidence": confidence,
            "timestamp": datetime.now().isoformat(),
            "message": f" CẢNH BÁO: Phát hiện {fire_count} điểm lửa, {smoke_count} điểm khói từ ESP32-CAM!"
        }
        
        response = requests.post(
            f"{BACKEND_URL}/mobile/send_alert",
            json=alert_data,
            timeout=5
        )
        
        if response.status_code == 200:
            last_notification_time = current_time
            global fire_detection_count
            fire_detection_count += 1
            print(f" THÔNG BÁO #{fire_detection_count}: Lửa={fire_count}, Khói={smoke_count}")
            return True
        else:
            print(f" Lỗi gửi thông báo: {response.status_code}")
            return False
            
    except Exception as e:
        print(f" Lỗi kết nối backend: {e}")
        return False

# ======================
# LOAD YOLO MODEL
# ======================
print(" Đang tải mô hình YOLO...")
model = YOLO(MODEL_PATH)
print(" Đã tải model!")

print("Model classes:", model.names)

# ======================
# MỞ LUỒNG VIDEO ESP32
# ======================
print(f" Đang kết nối ESP32-CAM: {STREAM_URL}")
cap = cv2.VideoCapture(STREAM_URL)

if not cap.isOpened():
    print(" Không kết nối được ESP32-CAM. Kiểm tra lại IP!")
    exit()

print(" Bắt đầu REAL-TIME FIRE/SMOKE DETECTION...")
print("Nhấn Q để thoát.")

fps_time = time.time()
frame_count = 0

# ======================
# VÒNG LẶP CHÍNH
# ======================
while True:
    ret, frame = cap.read()
    if not ret:
        print("Không đọc được frame, chờ ESP32...")
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
    highest_confidence = 0
    
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

            # Màu theo lớp
            color = (0, 0, 255) if class_name == "fire" else (255, 165, 0)

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
    # FPS
    # ======================
    elapsed = time.time() - fps_time
    if elapsed >= 1:
        fps = frame_count / elapsed
        fps_time = time.time()
        frame_count = 0
    else:
        fps = 0

    cv2.putText(annotated, f"FPS: {fps:.1f}", (10, 25),
                cv2.FONT_HERSHEY_SIMPLEX, 0.7, (0, 255, 0), 2)

    # ======================
    # HIỂN THỊ VIDEO
    # ======================
    cv2.imshow("ESP32 Live YOLO Detection", annotated)

    key = cv2.waitKey(1)
    if key & 0xFF == ord('q'):
        break

cap.release()
cv2.destroyAllWindows()
