# 🔥💨 YOLOv8 Fire & Smoke Detection Training
.\venv\Scripts\Activate.ps1                                                                                                  


Dự án training model YOLOv8 để phát hiện lửa và khói với các biểu đồ metrics chi tiết.

## 📋 Tổng quan

Dự án này sử dụng YOLOv8 (You Only Look Once version 8) để train model phát hiện lửa và khói trong hình ảnh. Bao gồm:
- Training model YOLOv8
- Vẽ các biểu đồ metrics chi tiết
- Phân tích dữ liệu training
- Đánh giá hiệu suất model

## 🗂️ Cấu trúc dữ liệu

```
data/
├── data.yaml           # File cấu hình YOLO
├── train/
│   ├── images/         # Ảnh training
│   └── labels/         # Labels training (YOLO format)
├── valid/
│   ├── images/         # Ảnh validation
│   └── labels/         # Labels validation
└── test/
    ├── images/         # Ảnh test
    └── labels/         # Labels test
```

## 🚀 Hướng dẫn sử dụng

### Bước 1: Cài đặt thư viện
```bash
python install_requirements.py
```

### Bước 2: Kiểm tra dữ liệu
```bash
python check_data.py
```
Script này sẽ:
- ✅ Kiểm tra cấu trúc dữ liệu
- 📊 Phân tích phân bố classes
- 🖼️ Hiển thị ảnh mẫu với labels
- 📈 Tạo biểu đồ thống kê

### Bước 3: Training model
```bash
python simple_train.py
```
Hoặc sử dụng script chi tiết hơn:
```bash
python train_yolo_model.py
```

## 📊 Các biểu đồ được tạo

### 1. Training Metrics
- **Loss curves**: Box loss, Classification loss, DFL loss
- **mAP curves**: mAP@0.5 và mAP@0.5:0.95
- **Precision & Recall**: Theo từng epoch
- **F1 Score**: Kết hợp precision và recall
- **Learning Rate**: Theo epoch

### 2. Data Analysis
- **Class Distribution**: Phân bố số lượng objects
- **Sample Visualization**: Ảnh mẫu với bounding boxes
- **Confusion Matrix**: Ma trận nhầm lẫn

## ⚙️ Cấu hình Training

### Model sizes có sẵn:
- `yolov8n.pt`: Nano (nhẹ nhất, nhanh nhất)
- `yolov8s.pt`: Small
- `yolov8m.pt`: Medium
- `yolov8l.pt`: Large
- `yolov8x.pt`: Extra Large (chính xác nhất)

### Tham số có thể điều chỉnh:
```python
# Trong simple_train.py
results = model.train(
    data='data/data.yaml',     # Đường dẫn config
    epochs=50,                 # Số epochs (50-200)
    imgsz=640,                # Kích thước ảnh
    batch=8,                  # Batch size (4-32)
    device='cuda',            # 'cuda' hoặc 'cpu'
    lr0=0.01,                 # Learning rate
    patience=15,              # Early stopping
)
```

## 📈 Đánh giá Model

### Metrics chính:
- **mAP@0.5**: Mean Average Precision ở threshold 0.5
- **mAP@0.5:0.95**: mAP trung bình từ 0.5 đến 0.95
- **Precision**: Độ chính xác
- **Recall**: Độ bao phủ
- **F1 Score**: Kết hợp precision và recall

### Kết quả mong đợi:
- mAP@0.5 > 0.7 (70%)
- mAP@0.5:0.95 > 0.4 (40%)
- Precision > 0.6 (60%)
- Recall > 0.6 (60%)

## 🔧 Khắc phục sự cố

### 1. Lỗi CUDA/GPU:
```bash
# Kiểm tra CUDA
python -c "import torch; print(torch.cuda.is_available())"
```

### 2. Thiếu bộ nhớ:
- Giảm `batch` size (4, 8, 16)
- Giảm `imgsz` (416, 480, 640)
- Sử dụng model nhỏ hơn (yolov8n)

### 3. Training chậm:
- Tăng `workers` (4, 8)
- Sử dụng GPU thay vì CPU
- Giảm số epochs ban đầu để test

## 📁 Kết quả Training

Sau khi training, các files sẽ được lưu trong:
```
runs/detect/fire_smoke_v1/
├── weights/
│   ├── best.pt         # Model tốt nhất
│   └── last.pt         # Model cuối cùng
├── results.csv         # Metrics theo epoch
├── confusion_matrix.png
├── F1_curve.png
├── PR_curve.png
├── P_curve.png
├── R_curve.png
└── val_batch0_labels.jpg
```

## 🧪 Test Model

```python
from ultralytics import YOLO

# Load model
model = YOLO('runs/detect/fire_smoke_v1/weights/best.pt')

# Predict
results = model('path/to/image.jpg')
results[0].show()  # Hiển thị kết quả
```

## 📚 Classes

- **Class 0**: Fire (Lửa) 🔥
- **Class 1**: Smoke (Khói) 💨

## 🎯 Tips để cải thiện model

1. **Tăng dữ liệu**: Thêm ảnh training đa dạng
2. **Data Augmentation**: Đã được tích hợp sẵn trong YOLOv8
3. **Hyperparameter tuning**: Điều chỉnh learning rate, batch size
4. **Transfer learning**: Sử dụng pre-trained weights
5. **Ensemble**: Kết hợp nhiều models

## 🤝 Contributing

1. Fork repository
2. Tạo feature branch
3. Commit changes
4. Push to branch
5. Create Pull Request

## 📄 License

MIT License - xem file LICENSE để biết thêm chi tiết.

## 📞 Liên hệ

- Email: your.email@example.com
- GitHub: https://github.com/yourusername

---

**Happy Training! 🔥💨**