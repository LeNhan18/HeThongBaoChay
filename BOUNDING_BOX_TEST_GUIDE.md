# 🎥 Test Bounding Box Video Analysis

Script để test chức năng phân tích video với bounding box trong Flutter app.

## 🔧 Setup và Test

### 1. Khởi động Backend API
```bash
cd e:\HeThongBaoChay
python main.py
```

### 2. Chạy Flutter App
```bash
cd e:\HeThongBaoChay\app
flutter run
```

### 3. Test Video Analysis với Bounding Box

#### Trong Flutter App:
1. **Mở app** → Đăng nhập
2. **Tab "Dự Đoán"** 
3. **Chọn "Chọn Video"**
4. **Upload video test** (có lửa/khói nếu có)
5. **Nhấn "Phân Tích Ngay"**
6. **Chờ xử lý** (console sẽ hiển thị logs chi tiết)
7. **Xem kết quả**:
   - Video player hiển thị video với bounding boxes
   - Thông tin chi tiết về detections
   - Badge hiển thị số lượng fire/smoke
   - Indicator rõ ràng về bounding boxes

## 🎯 Những gì đã được cải thiện:

### Backend (Python):
- ✅ **Custom plot function**: Sử dụng `plot_with_vietnamese_labels()` thay vì `result.plot()`
- ✅ **Enhanced bounding boxes**: Khung to hơn, màu rõ ràng hơn, corner markers
- ✅ **Vietnamese labels**: Hiển thị "Lửa" và "Khói" thay vì "fire" và "smoke"
- ✅ **Better colors**: Đỏ cho lửa, xanh cho khói (BGR format)
- ✅ **Anti-aliasing**: Text smooth hơn với cv2.LINE_AA
- ✅ **Debug logging**: Thêm logs để track việc vẽ bounding box

### Frontend (Flutter):
- ✅ **Enhanced logging**: Console logs chi tiết về video analysis
- ✅ **Bounding box indicator**: Widget riêng hiển thị thông tin về bounding boxes
- ✅ **Fire/Smoke badges**: Hiển thị số lượng phát hiện cụ thể
- ✅ **Visual feedback**: Indicator màu xanh khi video có bounding boxes
- ✅ **Better error handling**: Messages rõ ràng khi có lỗi
- ✅ **Success notifications**: Thông báo chi tiết khi phân tích thành công

## 🔍 Debug Information

### Trong Flutter Console:
```
🎥 Video Analysis Results:
   Frames processed: 150
   Total detections: 5
   Fire detections: 2
   Smoke detections: 3
   Processing time: 12.5s
   Response size: 15728640 bytes

📁 Saved annotated video to: /data/user/0/.../annotated_video_1733123456789.mp4
✅ Video file exists: true, size: 15.00 MB

✅ Result video with bounding boxes initialized
```

### Trong Python Console:
```
INFO:__main__:Drawing 2 detections on frame
INFO:__main__:Processing video: test.mp4 (150 frames)
INFO:__main__:Using XVID codec for output
```

## 🎨 Visual Features:

### Bounding Boxes trên Video:
- 🔴 **Lửa**: Khung đỏ với label "Lửa XX.X%"
- 🔵 **Khói**: Khung xanh với label "Khói XX.X%" 
- ⬛ **Corner markers**: Markers ở 4 góc để dễ nhìn
- 🎯 **Semi-transparent background**: Label có background trong suốt
- 📏 **Adaptive thickness**: Độ dày khung tùy theo kích thước video

### UI trong Flutter:
- 🟢 **Green indicator**: "Video có Bounding Boxes"
- 🏷️ **Detection badges**: Số lượng lửa/khói cụ thể
- 📊 **Frame statistics**: Số khung hình đã phân tích
- ℹ️ **Info box**: Chú thích về màu sắc bounding box

## 🐛 Troubleshooting:

### Video không có bounding box:
1. **Check console logs** - xem có detection không
2. **Confidence threshold** - thử giảm xuống 0.1
3. **Video content** - đảm bảo có lửa/khói thật
4. **Model path** - kiểm tra model đã load đúng

### Lỗi phổ biến:
- **"Video file exists: false"** → API không trả về video
- **"Processing time: 0s"** → Lỗi trong backend processing  
- **No detections** → Video không có fire/smoke hoặc confidence thấp

## 📝 Expected Output:

### Khi có detection:
```
✅ Video phân tích hoàn tất với 5 phát hiện! 🔥 Lửa: 2, 💨 Khói: 3
```

### Khi không có detection:
```
🎥 Video không có phát hiện
Không có lửa hoặc khói được phát hiện trong video này
```

---

## 🎉 Summary

Bây giờ chức năng phân tích video Flutter đã:
1. ✅ **Hiển thị bounding boxes** trên video kết quả
2. ✅ **Labels tiếng Việt** rõ ràng  
3. ✅ **UI indicators** thông báo về bounding boxes
4. ✅ **Detailed statistics** về detections
5. ✅ **Better visual feedback** cho user experience

**Hệ thống hoạt động hoàn chỉnh!** 🔥📱