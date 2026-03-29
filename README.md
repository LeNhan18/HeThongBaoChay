<div align="center">

![Logo](app/assets/images/logo.png)

# HeThongBaoChay - Hệ Thống Báo Cháy Thông Minh

Nền tảng phát hiện lửa và khói theo thời gian thực bằng YOLO, tích hợp FastAPI, Flutter và ESP32-CAM.

![Python](https://img.shields.io/badge/Python-3.10%2B-3776AB?style=for-the-badge&logo=python&logoColor=white)
![FastAPI](https://img.shields.io/badge/FastAPI-Backend-009688?style=for-the-badge&logo=fastapi&logoColor=white)
![Flutter](https://img.shields.io/badge/Flutter-Mobile-02569B?style=for-the-badge&logo=flutter&logoColor=white)
![YOLO](https://img.shields.io/badge/YOLOv11-Ultralytics-00D9FF?style=for-the-badge&logo=python&logoColor=white)
![ESP32](https://img.shields.io/badge/ESP32-CAM-E7352C?style=for-the-badge&logo=espressif&logoColor=white)

</div>

## Mục Lục

1. [Giới Thiệu](#giới-thiệu)
2. [Tính Năng Chính](#tính-năng-chính)
3. [Kiến Trúc Hệ Thống](#kiến-trúc-hệ-thống)
4. [Cấu Trúc Dự Án](#cấu-trúc-dự-án)
5. [Yêu Cầu Môi Trường](#yêu-cầu-môi-trường)
6. [Hướng Dẫn Cài Đặt Nhanh](#hướng-dẫn-cài-đặt-nhanh)
7. [Vận Hành Hệ Thống](#vận-hành-hệ-thống)
8. [Thông Số Kỹ Thuật](#thông-số-kỹ-thuật)
9. [Dữ Liệu và Xử Lý](#dữ-liệu-và-xử-lý)
10. [Đánh Giá Mô Hình](#đánh-giá-mô-hình)
11. [API Tổng Quan](#api-tổng-quan)
12. [ESP32-CAM và Firebase](#esp32-cam-và-firebase)
13. [Troubleshooting](#troubleshooting)
14. [Tài Liệu Liên Quan](#tài-liệu-liên-quan)

## Giới Thiệu

Dự án xây dựng hệ thống cảnh báo cháy thông minh với mục tiêu:

- Phát hiện lửa và khói theo thời gian thực từ camera điện thoại hoặc ESP32-CAM.
- Cung cấp API phân tích ảnh/video cho web, mobile và thiết bị IoT.
- Gửi cảnh báo tức thời lên ứng dụng Flutter qua Firebase Cloud Messaging.
- Theo dõi hiệu suất mô hình bằng mAP, Precision, Recall, F1-Score và Loss.

## Tính Năng Chính

- Phát hiện lửa/khói trên ảnh, video, camera stream và ESP32 stream.
- Trả kết quả dạng JSON hoặc ảnh/video đã vẽ bounding box.
- Cảnh báo theo mức độ nghiêm trọng (HIGH, MEDIUM, LOW).
- Theo dõi tiến trình huấn luyện bằng TensorBoard và biểu đồ trực quan.
- Ứng dụng Flutter hỗ trợ giám sát, cảnh báo và hiển thị thống kê.

## Kiến Trúc Hệ Thống

<div align="center">

![Kiến Trúc Hệ Thống](assets/images/z7354004843966_028e63c6bdfbd3e444d974b5a8ac2b02.jpg)


*Sơ đồ kiến trúc hệ thống báo cháy thông minnh*

</div>

Luồng dữ liệu chính:

```text
ESP32-CAM / Mobile Camera
            -> OpenCV + YOLO Inference
            -> FastAPI Backend
            -> Firebase Cloud Messaging
            -> Flutter Mobile App (Alert + Monitoring)
```

## Cấu Trúc Dự Án

```text
HeThongBaoChay/
|- main.py                      # Entry point FastAPI
|- config.py                    # Cấu hình hệ thống
|- api_state.py                 # Quản lý trạng thái runtime
|- requirements.txt
|- README.md
|
|- routers/                     # API routers
|  |- root.py
|  |- images.py
|  |- video.py
|  |- camera.py
|  |- esp32.py
|  |- mobile.py
|
|- services/                    # Business logic
|  |- detection.py
|  |- fire_tracker.py
|  |- notifications.py
|
|- scripts/                     # Script train/test/deploy tool
|  |- train_yolo_model.py
|  |- test_camera_api.py
|  |- esp32_flask_stream_server.py
|  |- upload_model_huggingface.py
|
|- app/                         # Flutter application
|- hardware/esp32/              # Firmware ESP32-CAM
|- docs/                        # Tài liệu bổ sung
|- notebooks/                   # Notebook huấn luyện
|- models/                      # Trọng số mô hình
|- report_images1/              # Biểu đồ kết quả training
```

## Yêu Cầu Môi Trường

- Python 3.10 trở lên
- Flutter SDK (nếu chạy app mobile)
- Android SDK hoặc thiết bị/emulator Android
- ESP32-CAM (tùy chọn, nếu dùng luồng camera IoT)
- GPU CUDA (khuyến nghị cho huấn luyện)

## Hướng Dẫn Cài Đặt Nhanh

### 1) Cài backend

```bash
python -m venv venv
.\venv\Scripts\Activate.ps1
pip install -r requirements.txt
```

### 2) Chạy API server

```bash
uvicorn main:app --host 0.0.0.0 --port 8000 --reload
```

API mặc định tại: http://localhost:8000

### 3) Chạy Flutter app

```bash
cd app
flutter pub get
flutter run
```

### 4) Kiểm tra ESP32 stream (tùy chọn)

```bash
python scripts/test_camera_api.py
```

## Thông Số Kỹ Thuật

### Backend (FastAPI)

| Thông số | Giá trị / Ghi chú |
|----------|-------------------|
| Phiên bản API | `2.0` (xem `config.py`) |
| Model mặc định | `training_results_*/advanced_fire_smoke_yolo11s/weights/best.pt` |
| Ghi đè đường dẫn model | Biến môi trường `MODEL_PATH` |
| Ngưỡng confidence mặc định | `0.45` (query param trên các endpoint inference) |
| Lớp đối tượng | `fire`, `smoke` (YOLO) |
| Giới hạn upload ảnh | 10 MB |
| Giới hạn upload video | 100 MB |
| Camera stream (PC) | 640×480 @ 30 FPS (cấu hình OpenCV) |
| Theo dõi cháy liên tục | Sau **30 giây** có lửa/khói → bật cờ vị trí (`FIRE_DURATION_THRESHOLD`) |
| Tọa độ ESP32 (tùy chọn) | `ESP32_LATITUDE`, `ESP32_LONGITUDE` hoặc `ESP32_<IP>_LATITUDE` / `LONGITUDE` |

### Flutter / client

| Thông số | Ghi chú |
|----------|---------|
| Cấu hình API | `app/lib/config/api_config.dart` (host theo nền tảng), `constants.dart` (URL cố định một số luồng) |
| Package | Xem `app/pubspec.yaml` |

### Huấn luyện (tham khảo `scripts/train_yolo_model.py`)

| Thông số | Ghi chú |
|----------|---------|
| Framework | Ultralytics YOLOv11 |
| Cấu hình dataset | `data/data.yaml` (đường dẫn tương đối từ thư mục gốc dự án) |
| Kết quả | Thư mục `training_results_YYYYMMDD_HHMMSS/` (thường không commit Git) |

## Dữ Liệu và Xử Lý

### Cấu trúc thư mục dataset (YOLO)

```text
data/
├── data.yaml              # train/val/test paths, số lớp, tên lớp
├── train/
│   ├── images/            # ảnh .jpg / .png
│   └── labels/            # mỗi ảnh một file .txt cùng tên (YOLO: class x_center y_center w h, chuẩn hóa 0–1)
├── valid/  (hoặc val/)
│   ├── images/
│   └── labels/
└── test/   (tùy chọn)
│   ├── images/
│   └── labels/
```

- **data.yaml** khai báo `path`, `train`, `val`, `test`, `nc` (số lớp), `names` (ví dụ `fire`, `smoke`).
- **Nhãn**: một dòng một object; class id bắt đầu từ 0; tọa độ trung tâm và kích thước bbox theo tỷ lệ so với chiều rộng/cao ảnh.

### Quy trình xử lý khi huấn luyện

1. Chuẩn bị ảnh và nhãn đúng cấu trúc trên.
2. Chạy `python scripts/train_yolo_model.py` từ thư mục gốc (script tự `chdir` về project root).
3. Ultralytics áp dụng augmentation và pipeline mặc định (flip, scale, v.v. tùy phiên bản).
4. Theo dõi bằng TensorBoard / biểu đồ trong `report_images1/` hoặc thư mục run.

### Xử lý khi suy luận (API)

| Bước | Mô tả |
|------|--------|
| Ảnh upload | Giải mã bằng OpenCV; suy luận YOLO; tùy chọn lọc false positive (vùng nhỏ/quá lớn, góc trên ảnh, confidence thấp) trong `services/detection.py`. |
| Video | Đọc từng frame; resize + pad về 640×640; suy luận; vẽ bbox; ghép lại video output. |
| ESP32 | GET `http://<esp32_ip>/capture` → bytes JPEG → giống pipeline ảnh. |
| Stream PC | MJPEG từ webcam qua OpenCV + cùng hàm vẽ nhãn tiếng Việt. |

**Lưu ý:** Endpoint `GET /predictions/history` hiện trả danh sách rỗng (stub); có thể mở rộng lưu lịch sử nếu cần.

## Vận Hành Hệ Thống

### Nhánh sử dụng trên mobile

1. Mở app và cấp quyền camera.
2. Vào tính năng phát hiện lửa/khói.
3. Bắt đầu suy luận thời gian thực.
4. Theo dõi cảnh báo và trạng thái detection.

### Nhánh sử dụng ESP32-CAM

1. Cấu hình WiFi trong firmware ESP32.
2. Nạp code vào ESP32-CAM.
3. Lấy IP từ Serial Monitor.
4. Cập nhật IP vào dịch vụ kết nối trong app/script.

## Đánh Giá Mô Hình

Phần này đã tích hợp các biểu đồ bạn cung cấp để phục vụ báo cáo và theo dõi chất lượng mô hình.

### Tổng quan chỉ số cuối quá trình train

- mAP@50: khoảng 78.3%
- mAP@50-95: khoảng 52%
- Precision: khoảng 0.55
- Recall: khoảng 0.55
- F1-Score: khoảng 0.55 (đỉnh ở epoch cuối)

### 1) Box Loss và Class Loss

![Loss Analysis](report_images1/Chart_1_Loss_Analysis.png)

Nhận xét nhanh:

- Train loss giảm đều, mô hình học ổn định.
- Validation loss giảm chậm và cao hơn train loss, cho thấy còn khoảng cách tổng quát hóa.

### 2) Hiệu suất mAP theo epoch

![mAP Performance](report_images1/Chart_2_mAP_Performance.png)

Nhận xét nhanh:

- mAP@50 tăng đều và đạt mức cao nhất ở giai đoạn cuối.
- mAP@50-95 tăng ổn định, phản ánh cải thiện ở ngưỡng IoU nghiêm ngặt.

### 3) Precision và Recall

![Precision Recall](report_images1/Chart_3_Precision_Recall.png)

Nhận xét nhanh:

- Precision và Recall hội tụ khá cân bằng quanh 0.55.
- Đường cong mượt, ít dao động mạnh ở nửa sau training.

### 4) F1-Score

![F1 Score](report_images1/Chart_4_F1_Score.png)

Nhận xét nhanh:

- F1 tăng liên tục và đạt cực đại ở epoch cuối.
- Mô hình vẫn còn xu hướng cải thiện nếu tối ưu thêm dữ liệu/hyperparameters.

### 5) Learning Rate Schedule

![Learning Rate](report_images1/Chart_5_Learning_Rate.png)

Nhận xét nhanh:

- Learning rate giảm dần theo lịch, giúp ổn định giai đoạn fine-tuning cuối.

## API Tổng Quan

Base URL: `http://localhost:8000` (Swagger: `/docs`)

### Ảnh / video / camera máy tính

| Phương thức | Đường dẫn | Mô tả |
|-------------|-----------|--------|
| GET | `/` | Thông tin API và danh sách endpoint |
| GET | `/health/` | Trạng thái server và model |
| GET | `/test/` | Kiểm tra kết nối |
| GET | `/predictions/history` | Lịch sử prediction (stub, có thể rỗng) |
| POST | `/predict/` | Upload ảnh → trả **JPEG** đã vẽ bbox |
| POST | `/predict_json/` | Upload ảnh → trả **JSON** detection |
| POST | `/analyze_video/` | Upload video → trả video đã annotate |
| POST | `/camera/start/` | Bật session camera |
| GET | `/camera/stream/` | MJPEG stream (gọi sau `/camera/start/`) |
| POST | `/camera/stop/` | Tắt camera |

### Mobile

| Phương thức | Đường dẫn | Mô tả |
|-------------|-----------|--------|
| POST | `/mobile/camera/detect` | Frame → JSON |
| POST | `/mobile/camera/detect_with_image` | Frame → JPEG có bbox |
| POST | `/mobile/register_fcm_token` | Đăng ký FCM token |
| POST | `/mobile/send_alert` | Nhận cảnh báo từ script/ESP32, đẩy FCM + hàng đợi alert |
| GET | `/mobile/get_alerts` | Lấy danh sách alert (`unread_only` tùy chọn) |
| POST | `/mobile/mark_alert_read` | Đánh dấu đã đọc |

### ESP32 (qua backend)

| Phương thức | Đường dẫn | Mô tả |
|-------------|-----------|--------|
| POST | `/esp32/capture` | Query `esp32_ip`, `confidence` → JSON |
| POST | `/esp32/capture_with_boxes` | Query `esp32_ip`, `confidence` → JPEG |

Ví dụ:

```bash
curl -X POST -F "file=@image.jpg" "http://localhost:8000/predict_json/?confidence=0.45"
```

## ESP32-CAM và Firebase

### ESP32-CAM

1. Mở file firmware tại hardware/esp32/ESP32_CAMERA_CODE.ino.
2. Khai báo SSID và password WiFi.
3. Upload firmware và kiểm tra IP qua Serial Monitor.

### Firebase Cloud Messaging

1. Tạo project trên Firebase Console.
2. Thêm Android app và tải file google-services.json.
3. Đặt file vào app/android/app/google-services.json.
4. Kiểm tra khởi tạo Firebase trong app Flutter.

## Troubleshooting

### Không kết nối được API

- Kiểm tra server đã chạy và đúng port 8000.
- Kiểm tra thiết bị mobile cùng mạng LAN với máy chủ.
- Cập nhật API base URL trong app Flutter theo IP máy chủ.

### Model không được nạp

- Kiểm tra đường dẫn model trong cấu hình runtime.
- Đảm bảo file weight tồn tại trong thư mục training results hoặc models.

### ESP32 không stream

- Kiểm tra nguồn cấp ổn định cho ESP32-CAM.
- Kiểm tra IP, WiFi và endpoint capture/stream.

### Huấn luyện chậm

- Dùng GPU CUDA nếu có.
- Giảm batch size hoặc ảnh đầu vào.
- Bật TensorBoard để theo dõi nghẽn hiệu năng.

## Tài Liệu Liên Quan

- [Tài liệu ESP32 Flask Stream](docs/ESP32_FLASK_SERVER.md)
- [Notebook train YOLO](notebooks/train_yolo_colab_vscode.ipynb)
- [README Flutter app](app/README.md)

## License

Dự án sử dụng giấy phép MIT.
