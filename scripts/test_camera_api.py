#!/usr/bin/env python3
"""
Test kết nối ESP32-CAM và chạy detection real-time (chế độ hiển thị local).
Chạy từ thư mục gốc: python scripts/test_camera_api.py
"""
import sys
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(PROJECT_ROOT))

import cv2
from ultralytics import YOLO
import numpy as np
import time
from datetime import datetime
import requests
import json

# ======================
# CONFIG - Cập nhật IP của bạn
# ======================
ESP32_IP = "172.20.10.12"     # IP ESP32-CAM
BACKEND_URL = "http://172.20.10.5:8000"
MODEL_PATH = PROJECT_ROOT / "training_results_20251125_021040" / "advanced_fire_smoke_yolo11s" / "weights" / "best.pt"
CONF_THRESHOLD = 0.25

STREAM_URL = f"http://{ESP32_IP}:81/stream"

# Notification settings
NOTIFICATION_COOLDOWN = 3
last_notification_time = 0
fire_detection_count = 0

# Label tiếng Việt
label_vn = {
    "fire": "🔥 LỬA",
    "smoke": "💨 KHÓI"
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
        print(f"⏳ Cooldown: {remaining:.1f}s còn lại trước thông báo tiếp")
        return False

    try:
        alert_data = {
            "source": "ESP32-CAM Live Detection",
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
            global fire_detection_count
            fire_detection_count += 1
            print(f"📢 THÔNG BÁO #{fire_detection_count}: Lửa={fire_count}, Khói={smoke_count}")
            return True
        else:
            print(f"❌ Lỗi gửi thông báo: {response.status_code}")
            return False

    except Exception as e:
        print(f"❌ Lỗi kết nối backend: {e}")
        return False

# ======================
# MAIN
# ======================
print("📦 Đang tải mô hình YOLO...")
model = YOLO(str(MODEL_PATH))
print("✅ Đã tải model!")
print("📋 Model classes:", model.names)

print(f"\n📡 Đang kết nối ESP32-CAM: {STREAM_URL}")
cap = cv2.VideoCapture(STREAM_URL)

if not cap.isOpened():
    print("❌ Không kết nối được ESP32-CAM. Kiểm tra lại IP!")
    sys.exit(1)

print("✅ Bắt đầu REAL-TIME FIRE/SMOKE DETECTION...")
print("💡 Nhấn Q để thoát.\n")

fps_time = time.time()
frame_count = 0

while True:
    ret, frame = cap.read()
    if not ret:
        print("⚠️ Không đọc được frame, chờ ESP32...")
        time.sleep(0.1)
        continue

    frame_count += 1
    results = model(frame, conf=CONF_THRESHOLD, verbose=False)
    boxes = results[0].boxes
    annotated = frame.copy()

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

            if class_name == "fire":
                fire_count += 1
            elif class_name == "smoke":
                smoke_count += 1

            if conf > highest_confidence:
                highest_confidence = conf

            color = (0, 0, 255) if class_name == "fire" else (255, 165, 0)
            cv2.rectangle(annotated, (x1, y1), (x2, y2), color, 2)

            text = f"{vn_label} {conf*100:.1f}%"
            t_size = cv2.getTextSize(text, cv2.FONT_HERSHEY_SIMPLEX, 0.6, 2)[0]
            cv2.rectangle(annotated, (x1, y1 - 25), (x1 + t_size[0] + 8, y1), color, -1)
            cv2.putText(
                annotated, text, (x1 + 4, y1 - 5),
                cv2.FONT_HERSHEY_SIMPLEX, 0.6, (255, 255, 255), 2
            )
            print(f"[{datetime.now().strftime('%H:%M:%S')}] {vn_label} - {conf:.2%}")

    if fire_count > 0:
        send_fire_alert(fire_count, smoke_count, highest_confidence)

    elapsed = time.time() - fps_time
    if elapsed >= 1:
        fps = frame_count / elapsed
        fps_time = time.time()
        frame_count = 0
    else:
        fps = 0

    cv2.putText(annotated, f"FPS: {fps:.1f}", (10, 25),
                cv2.FONT_HERSHEY_SIMPLEX, 0.7, (0, 255, 0), 2)

    cv2.imshow("ESP32 Live YOLO Detection", annotated)

    if cv2.waitKey(1) & 0xFF == ord('q'):
        break

cap.release()
cv2.destroyAllWindows()
