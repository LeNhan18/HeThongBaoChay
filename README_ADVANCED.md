# 🔥💨 Hệ Thống Báo Cháy Thông Minh - AI Fire & Smoke Detection

Dự án phát triển hệ thống báo cháy thông minh sử dụng YOLOv8 AI để phát hiện lửa và khói với độ chính xác cao.

## 🌟 Tính năng chính

- 🎯 **Phát hiện lửa và khói real-time** với YOLOv8
- 📱 **Mobile app Flutter** cho cảnh báo và giám sát
- 📊 **Dashboard analytics** với metrics chi tiết  
- ⚡ **Training tối ưu** với best practices
- 🔔 **Cảnh báo thông minh** qua nhiều kênh
- 📈 **Biểu đồ metrics** chi tiết và trực quan

## 📁 Cấu trúc dự án

```
HeThongBaoChay/
├── 📱 app/                     # Flutter mobile application
├── 📊 data/                    # Training dataset (YOLO format)
│   ├── train/images/           # Training images
│   ├── train/labels/           # Training labels  
│   ├── valid/images/           # Validation images
│   ├── valid/labels/           # Validation labels
│   ├── test/images/            # Test images
│   ├── test/labels/            # Test labels
│   └── data.yaml              # Dataset configuration
├── 🔧 install_requirements.py  # Advanced package installer
├── 🚀 train_yolo_model.py     # Advanced training script
├── ⚡ quick_train.py           # Quick training script
├── 🧪 simple_train.py         # Simple training script
├── 📊 check_data.py           # Data verification script
└── 📚 README.md               # This file
```

## 🚀 Bắt đầu nhanh

### 1. Cài đặt môi trường

```bash
# Cài đặt tất cả dependencies cần thiết
python install_requirements.py

# Hoặc cài đặt thủ công
pip install ultralytics torch torchvision matplotlib seaborn pandas numpy opencv-python albumentations optuna tensorboard
```

### 2. Kiểm tra dữ liệu

```bash
# Kiểm tra dataset trước khi training
python check_data.py
```

### 3. Chọn phương pháp training

#### 🏃‍♂️ Training nhanh (Khuyến nghị cho người mới)
```bash
python quick_train.py
```

#### 🔬 Training nâng cao (Cho chuyên gia)
```bash
python train_yolo_model.py
```

#### 📝 Training đơn giản (Cho việc học)
```bash
python simple_train.py
```

## 🎯 Các phương pháp training

### 🏃‍♂️ Quick Training (`quick_train.py`)
- ✅ Dễ sử dụng, setup tự động
- ✅ Best practices được tích hợp sẵn
- ✅ Batch size tự động tối ưu
- ✅ Biểu đồ metrics chi tiết
- ⏱️ Thời gian: 2-4 giờ

### 🔬 Advanced Training (`train_yolo_model.py`)
- 🚀 Hyperparameter optimization với Optuna
- 🔥 Mixed precision training
- 📊 TensorBoard integration
- 🎯 Ensemble model support
- 📈 Advanced data augmentation
- 🧠 Model performance analysis
- ⏱️ Thời gian: 4-8 giờ

### 📝 Simple Training (`simple_train.py`)
- 🎓 Dành cho học tập
- 📚 Code dễ hiểu
- 🔧 Cấu hình cơ bản
- ⏱️ Thời gian: 1-2 giờ

## 📊 Best Practices được áp dụng

### 🏗️ Model Architecture
- **YOLOv8s/m/l/x**: Tối ưu cho fire/smoke detection
- **Multi-scale training**: Tăng khả năng phát hiện đa kích thước
- **Model ensemble**: Kết hợp nhiều model để tăng độ chính xác

### 🔄 Data Augmentation
- **Geometric transforms**: Rotation, scaling, shearing
- **Color augmentation**: HSV adjustment, brightness/contrast
- **Weather effects**: Fog, sun flare, shadows (quan trọng cho fire/smoke)
- **Advanced techniques**: Mosaic, MixUp, CopyPaste

### ⚡ Training Optimization
- **AdamW optimizer**: Tối ưu cho computer vision
- **Cosine learning rate**: Smooth convergence
- **Mixed precision**: Faster training, less memory
- **Auto batch size**: Tự động tối ưu theo GPU memory
- **Early stopping**: Tránh overfitting

### 📈 Monitoring & Evaluation
- **TensorBoard**: Real-time training monitoring
- **Comprehensive metrics**: mAP, Precision, Recall, F1-Score
- **Class-wise analysis**: Phân tích riêng cho Fire và Smoke
- **Performance visualization**: Biểu đồ chi tiết và trực quan

## 📊 Kết quả mong đợi

### 🎯 Performance Targets
- **mAP@0.5**: > 0.85
- **mAP@0.5:0.95**: > 0.70
- **Precision**: > 0.87
- **Recall**: > 0.83
- **F1-Score**: > 0.85

### 🔥 Fire Detection
- Phát hiện lửa từ xa
- Nhận diện các loại lửa khác nhau
- Hoạt động trong điều kiện ánh sáng khác nhau

### 💨 Smoke Detection  
- Phát hiện khói mỏng và khói đậm
- Phân biệt khói với sương mù/hơi nước
- Tracking chuyển động của khói

## 🛠️ Cấu hình nâng cao

### GPU Optimization
```python
# Trong code đã tối ưu:
torch.backends.cudnn.benchmark = True
torch.backends.cuda.matmul.allow_tf32 = True
```

### Custom Hyperparameters
```python
# Sửa trong file training:
hyperparams = {
    'lr0': 0.01,           # Learning rate
    'weight_decay': 0.0005, # Weight decay
    'momentum': 0.937,      # Momentum
    'box': 7.5,            # Box loss gain
    'cls': 0.5,            # Classification loss gain
}
```

## 📈 Monitoring Training

### TensorBoard
```bash
# Xem training progress real-time
tensorboard --logdir training_results_*/tensorboard
```

### Training Logs
- Training metrics được lưu trong `results.csv`
- Plots tự động trong thư mục `plots/`
- Model weights trong `weights/`

## 🚀 Deployment

### Model Export
```python
# Export sang các format khác nhau
model = YOLO('best.pt')
model.export(format='onnx')    # ONNX
model.export(format='engine')  # TensorRT
model.export(format='coreml')  # CoreML
```

### Inference
```python
# Sử dụng model đã train
model = YOLO('path/to/best.pt')
results = model('image.jpg')
results[0].show()
```

## 🔧 Troubleshooting

### 🚨 Lỗi thường gặp

1. **CUDA out of memory**
   ```bash
   # Giảm batch size hoặc image size
   batch_size = 8  # Thay vì 16
   img_size = 512  # Thay vì 640
   ```

2. **Dataset không tìm thấy**
   ```bash
   # Kiểm tra đường dẫn trong data.yaml
   python check_data.py
   ```

3. **Training chậm**
   ```bash
   # Kiểm tra GPU utilization
   nvidia-smi
   ```

### 💡 Tips tối ưu

- **GPU Memory**: Sử dụng mixed precision (`amp=True`)
- **Data Loading**: Increase `workers` parameter
- **Convergence**: Sử dụng `cos_lr=True` cho cosine learning rate
- **Overfitting**: Tăng data augmentation hoặc giảm model size

## 📞 Hỗ trợ

### 🆘 Báo lỗi
- Tạo issue trên GitHub với log chi tiết
- Kèm theo system info và error traceback

### 📚 Tài liệu tham khảo
- [YOLOv8 Documentation](https://docs.ultralytics.com/)
- [PyTorch Documentation](https://pytorch.org/docs/)
- [Object Detection Best Practices](https://github.com/ultralytics/ultralytics)

## 🏆 Contributors

- **AI Team**: Model development & optimization
- **Mobile Team**: Flutter app development  
- **DevOps Team**: Deployment & monitoring

## 📄 License

MIT License - Xem file LICENSE để biết thêm chi tiết.

---

## 🎯 Quick Start Commands

```bash
# 1. Setup
python install_requirements.py

# 2. Quick training (khuyến nghị)
python quick_train.py

# 3. Advanced training  
python train_yolo_model.py

# 4. Check results
ls -la training_results_*/

# 5. View TensorBoard
tensorboard --logdir training_results_*/tensorboard
```

**🔥 Happy Training! Chúc bạn có model fire & smoke detection tuyệt vời! 💨**