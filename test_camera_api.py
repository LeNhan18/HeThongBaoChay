#!/usr/bin/env python3
import cv2
from ultralytics import YOLO
import numpy as np
import time
from datetime import datetime

# ======================
# CONFIG
# ======================
ESP32_IP = "192.168.1.30"     # IP ESP32-CAM
MODEL_PATH = "training_results_20251125_021040/advanced_fire_smoke_yolo11s/weights/best.pt"        # model YOLO của bạn
CONF_THRESHOLD = 0.25

STREAM_URL = f"http://{ESP32_IP}:81/stream"

# Label tiếng Việt
label_vn = {
    "fire": "🔥 LỬA",
    "smoke": "💨 KHÓI"
}

# ======================
# LOAD YOLO MODEL
# ======================
print("📦 Đang tải mô hình YOLO...")
model = YOLO(MODEL_PATH)
print("✅ Đã tải model!")

print("Model classes:", model.names)

# ======================
# MỞ LUỒNG VIDEO ESP32
# ======================
print(f"📡 Đang kết nối ESP32-CAM: {STREAM_URL}")
cap = cv2.VideoCapture(STREAM_URL)

if not cap.isOpened():
    print("❌ Không kết nối được ESP32-CAM. Kiểm tra lại IP!")
    exit()

print("🔥 Bắt đầu REAL-TIME FIRE/SMOKE DETECTION...")
print("Nhấn Q để thoát.")

fps_time = time.time()
frame_count = 0

# ======================
# VÒNG LẶP CHÍNH
# ======================
while True:
    ret, frame = cap.read()
    if not ret:
        print("⚠ Không đọc được frame, chờ ESP32...")
        time.sleep(0.1)
        continue

    frame_count += 1

    # YOLO detect
    results = model(frame, conf=CONF_THRESHOLD, verbose=False)
    boxes = results[0].boxes

    # Dùng frame để vẽ
    annotated = frame.copy()

    # ======================
    # VẼ BOUNDING BOX
    # ======================
    if boxes is not None and len(boxes) > 0:
        for box in boxes:
            x1, y1, x2, y2 = box.xyxy[0].cpu().numpy().astype(int)
            conf = float(box.conf[0])
            cls = int(box.cls[0])

            class_name = model.names[cls].lower()
            vn_label = label_vn.get(class_name, class_name.upper())

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
