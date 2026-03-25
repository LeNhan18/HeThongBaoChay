# ESP32-CAM Flask Stream Server

Server Python để stream video từ ESP32-CAM với YOLO detection lên Flutter app.

## 📋 Yêu cầu

```bash
pip install flask opencv-python ultralytics requests numpy
```

## 🚀 Cách sử dụng

### 1. Cấu hình

Mở file `scripts/esp32_flask_stream_server.py` và cập nhật các thông tin:

```python
ESP32_IP = "172.20.10.2"     # IP của ESP32-CAM
BACKEND_URL = "http://172.20.10.5:8000"  # Backend server
MODEL_PATH = "training_results_20251125_021040/advanced_fire_smoke_yolo11s/weights/best.pt"
FLASK_PORT = 5000            # Port cho Flask server
```

### 2. Chạy server

```bash
python scripts/esp32_flask_stream_server.py
```

Server sẽ:
- Tải mô hình YOLO
- Kết nối với ESP32-CAM
- Khởi động Flask server tại port 5000
- Xử lý video và detection real-time
- Serve frames qua HTTP endpoint

### 3. Lấy IP máy của bạn

**Windows:**
```bash
ipconfig
```
Tìm `IPv4 Address` (ví dụ: `172.20.10.5`)

**Linux/Mac:**
```bash
ifconfig
# hoặc
ip addr show
```

### 4. Cấu hình Flutter app

Trong `mock_api_service.dart`, camera đã được cấu hình sẵn:

```dart
{
  'id': '5',
  'name': 'ESP32-CAM Live Detection',
  'status': 'online',
  'type': 'esp32',
  'ip': '172.20.10.5',  // ⚠️ Cập nhật IP máy của bạn ở đây
  'port': '5000',
}
```

## 📡 API Endpoints

### GET `/frame`
Lấy frame hiện tại với bounding boxes

**Response:**
- Content-Type: `image/jpeg`
- Headers:
  - `X-Fire-Count`: Số điểm lửa phát hiện
  - `X-Smoke-Count`: Số điểm khói phát hiện
  - `X-Confidence`: Độ tin cậy cao nhất
  - `X-FPS`: FPS hiện tại
  - `X-Timestamp`: Thời gian

**Ví dụ:**
```
http://172.20.10.5:5000/frame
```

### GET `/status`
Lấy thông tin trạng thái detection

**Response:**
```json
{
  "status": "running",
  "fire_count": 2,
  "smoke_count": 1,
  "confidence": 0.85,
  "fps": 15.5,
  "timestamp": "2025-01-20 14:30:00",
  "esp32_ip": "172.20.10.2",
  "stream_url": "http://172.20.10.2:81/stream"
}
```

### GET `/health`
Health check endpoint

**Response:**
```json
{
  "status": "healthy",
  "service": "ESP32-CAM Detection Server"
}
```

## 🔧 Troubleshooting

### Không kết nối được ESP32-CAM

1. Kiểm tra IP ESP32-CAM đúng chưa
2. Đảm bảo ESP32-CAM đang chạy stream tại port 81
3. Kiểm tra kết nối mạng

### Flutter app không hiển thị video

1. Kiểm tra IP máy trong `mock_api_service.dart` đúng chưa
2. Đảm bảo Flask server đang chạy
3. Kiểm tra firewall không chặn port 5000
4. Test endpoint trong browser: `http://YOUR_IP:5000/frame`

### Model không tải được

1. Kiểm tra đường dẫn `MODEL_PATH` đúng chưa
2. Đảm bảo file model tồn tại
3. Kiểm tra quyền đọc file

## 📱 Sử dụng trong Flutter

1. Mở app Flutter
2. Vào tab "Giám Sát"
3. Chọn camera "ESP32-CAM Live Detection"
4. App sẽ tự động kết nối và hiển thị stream với bounding boxes

## 🛑 Dừng server

Nhấn `Ctrl+C` để dừng server an toàn.

## 📝 Ghi chú

- Server tự động refresh frames mỗi giây
- Thông báo cảnh báo được gửi đến backend khi phát hiện lửa
- Cooldown 3 giây giữa các thông báo để tránh spam
- FPS và thông tin detection được hiển thị trên frame

