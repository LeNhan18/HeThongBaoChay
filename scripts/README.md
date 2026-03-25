# Scripts

Các script Python phụ trợ cho dự án. **Chạy từ thư mục gốc dự án** (`HeThongBaoChay/`).

## Danh sách Scripts

| Script | Mô tả |
|--------|-------|
| `esp32_flask_stream_server.py` | Server Flask stream video ESP32-CAM + YOLO detection cho Flutter app |
| `test_camera_api.py` | Test kết nối ESP32-CAM, hiển thị detection real-time trên màn hình |
| `train_yolo_model.py` | Training model YOLOv11 phát hiện lửa/khói (advanced) |
| `upload_model_huggingface.py` | Upload model đã train lên Hugging Face Hub |

## Cách chạy

```bash
# Từ thư mục HeThongBaoChay/
python scripts/test_camera_api.py
python scripts/esp32_flask_stream_server.py
python scripts/train_yolo_model.py
python scripts/upload_model_huggingface.py
```

## Cấu hình

- **ESP32 IP**: Sửa `ESP32_IP` trong `test_camera_api.py` hoặc `esp32_flask_stream_server.py`
- **Backend URL**: Sửa `BACKEND_URL` nếu backend chạy ở port/IP khác
- **Model path**: Mặc định dùng `training_results_20251125_021040/.../best.pt`
