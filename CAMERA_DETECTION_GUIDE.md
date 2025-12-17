# Tính Năng Phát Hiện Lửa Real-time trên Camera Điện Thoại

## Tổng Quan

Tính năng mới này cho phép bạn sử dụng camera điện thoại để phát hiện lửa và khói trong thời gian thực. Hệ thống sử dụng mô hình YOLO đã được huấn luyện để nhận diện các đối tượng nguy hiểm và đưa ra cảnh báo kịp thời.

## Các Tính Năng Chính

### 🔥 Phát Hiện Real-time
- Quét liên tục khung hình từ camera
- Nhận diện lửa và khói với độ chính xác cao
- Hiển thị kết quả ngay lập tức trên màn hình

### 🎯 Hệ Thống Cảnh Báo Thông Minh
- **CẢNH BÁO CAO (HIGH)**: Khi phát hiện lửa - màu đỏ
- **CẢNH BÁO TRUNG BÌNH (MEDIUM)**: Khi phát hiện khói - màu cam
- **AN TOÀN (LOW)**: Không phát hiện nguy hiểm - màu xanh

### 📊 Thống Kê Chi Tiết
- Số khung hình đã xử lý
- Tổng số phát hiện
- Thời gian hoạt động
- Lịch sử các phát hiện gần đây

### 🔄 Tính Năng Nâng Cao
- Chuyển đổi giữa camera trước/sau
- Tạm dừng/tiếp tục phát hiện
- Hiển thị bounding box với confidence score
- Giao diện tiếng Việt thân thiện

## Cách Sử Dụng

### 1. Khởi Động API Server

Trước tiên, chạy server Python:

```bash
# Di chuyển đến thư mục dự án
cd /path/to/HeThongBaoChay

# Cài đặt dependencies (nếu chưa có)
pip install -r requirements.txt

# Chạy API server
python main.py
```

Server sẽ chạy tại `http://localhost:8000`

### 2. Cấu Hình Flutter App

Cập nhật địa chỉ IP trong file `app/lib/constants.dart`:

```dart
// Thay localhost bằng IP máy tính chạy server
const String API_BASE_URL = 'http://192.168.1.100:8000';
```

### 3. Cài Đặt Dependencies Flutter

```bash
cd app
flutter pub get
```

### 4. Chạy Ứng Dụng

```bash
flutter run
```

### 5. Sử Dụng Tính Năng

1. **Mở ứng dụng** và đăng nhập
2. **Nhấn nút "Phát Hiện Lửa"** ở giữa màn hình chính
3. **Cấp quyền camera** khi được yêu cầu
4. **Nhấn "BẮT ĐẦU"** để bắt đầu phát hiện
5. **Hướng camera** vào các khu vực cần giám sát
6. **Quan sát kết quả** trên màn hình

## Cấu Trúc Code Mới

### Backend (Python)

#### `main.py` - API Endpoints mới:
- `/mobile/camera/detect`: Phát hiện từ ảnh mobile
- `/mobile/camera/detect_with_image`: Trả về ảnh đã annotation

### Frontend (Flutter)

#### `screens/camera_detection_screen.dart`
- Màn hình chính cho tính năng camera detection
- Xử lý camera preview và hiển thị kết quả
- Giao diện điều khiển và thống kê

#### `services/camera_detection_service.dart`
- Service kết nối với API backend
- Upload ảnh và nhận kết quả phát hiện
- Xử lý lỗi và timeout

#### `models/detection_result.dart`
- Model dữ liệu cho kết quả phát hiện
- Chứa thông tin bounding box, confidence score
- Xử lý parsing JSON từ API

## API Documentation

### POST `/mobile/camera/detect`

**Mô tả**: Phát hiện lửa và khói từ ảnh camera mobile

**Parameters**:
- `file`: Multipart file (ảnh từ camera)
- `confidence`: Float (0-1, mặc định 0.25)

**Response**:
```json
{
  "success": true,
  "timestamp": "2024-12-05T10:30:00",
  "detections": [
    {
      "class": "fire",
      "confidence": 0.85,
      "bbox": {
        "x1": 100,
        "y1": 150,
        "x2": 200,
        "y2": 250
      }
    }
  ],
  "detection_count": {
    "fire": 1,
    "smoke": 0
  },
  "has_fire": true,
  "has_smoke": false,
  "alert_level": "HIGH",
  "message": "🔥 CẢNH BÁO: Phát hiện 1 điểm lửa!"
}
```

## Troubleshooting

### Lỗi Kết Nối API
```
Không thể kết nối đến server
```
**Giải pháp**:
1. Kiểm tra server Python có đang chạy không
2. Cập nhật đúng IP address trong `constants.dart`
3. Kiểm tra firewall và network

### Lỗi Camera
```
Cần cấp quyền camera
```
**Giải pháp**:
1. Vào Settings > Apps > Your App > Permissions
2. Bật quyền Camera
3. Restart app

### Phát Hiện Chậm
**Nguyên nhân**: Kết nối mạng chậm hoặc ảnh quá lớn
**Giải pháp**:
1. Giảm resolution camera trong code
2. Tăng interval giữa các lần detect
3. Tối ưu mạng WiFi

## Tối Ưu Hiệu Suất

### Cấu Hình Camera
```dart
// Trong camera_detection_screen.dart
_cameraController = CameraController(
  _cameras![_currentCameraIndex],
  ResolutionPreset.medium, // Thay đổi thành low nếu muốn nhanh hơn
  enableAudio: false,
  imageFormatGroup: ImageFormatGroup.jpeg,
);
```

### Tần Suất Phát Hiện
```dart
// Điều chỉnh interval trong _startDetection()
Timer.periodic(const Duration(milliseconds: 500), (timer) {
  // Tăng thành 1000ms nếu muốn ít tải hơn
  _processFrame();
});
```

## Mở Rộng Tương Lai

1. **Lưu Video Cảnh Báo**: Ghi lại video khi phát hiện lửa
2. **Push Notification**: Thông báo ngay cả khi app ở background
3. **Cloud Storage**: Lưu trữ ảnh/video phát hiện lên cloud
4. **Multiple Camera**: Hỗ trợ nhiều camera cùng lúc
5. **AI Enhancement**: Cải thiện độ chính xác model

## Liên Hệ Support

Nếu gặp vấn đề kỹ thuật, vui lòng:
1. Kiểm tra logs trong console
2. Chụp screenshot lỗi
3. Ghi lại steps to reproduce
4. Liên hệ team phát triển

---

**Lưu ý**: Tính năng này yêu cầu model YOLO đã được train. Đảm bảo file model tại path đã được cấu hình trong `main.py`.