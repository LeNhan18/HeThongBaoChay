#!/usr/bin/env python3
"""
Script đơn giản để train YOLOv8 phát hiện lửa và khói
Chỉ sử dụng ultralytics cơ bản
"""

import os
import sys
from pathlib import Path

try:
    from ultralytics import YOLO
    print("Ultralytics đã được import thành công.")
except ImportError as e:
    print(f"Lỗi import Ultralytics: {e}")
    sys.exit(1)

def simple_train():
    """Train YOLOv8 với cấu hình đơn giản"""
    
    # Kiểm tra dữ liệu
    data_path = "data/data.yaml"
    if not os.path.exists(data_path):
        print(f" Không tìm thấy file dữ liệu: {data_path}")
        return
    
    print(f" Tìm thấy file dữ liệu: {data_path}")
    
    # Tạo model
    print("🔧 Khởi tạo model YOLOv8n...")
    model = YOLO('yolov8n.pt')  # Load pretrained model
    
    # Training parameters
    train_params = {
        'data': data_path,
        'epochs': 50,  # Giảm epochs để test nhanh
        'imgsz': 640,
        'batch': 8,    # Batch size nhỏ để tránh memory error
        'device': 'cpu',  # Dùng CPU để tránh CUDA issues
        'workers': 2,
        'patience': 10,
        'save': True,
        'save_period': 10,
        'plots': True,
        'verbose': True
    }
    
    print("🚀 Bắt đầu training...")
    print(f"Parameters: {train_params}")
    
    try:
        # Train model
        results = model.train(**train_params)
        
        print(" Training hoàn thành!")
        print(f"Results saved to: {results.save_dir}")
        
        # Validate model
        print(" Đang validate model...")
        metrics = model.val()
        
        print(" Metrics:")
        print(f"mAP50: {metrics.box.map50:.4f}")
        print(f"mAP50-95: {metrics.box.map:.4f}")
        
        return results
        
    except Exception as e:
        print(f" Lỗi trong quá trình training: {e}")
        return None

def test_model():
    """Test model với một vài images"""
    try:
        # Load best model
        best_model_path = "runs/detect/train/weights/best.pt"
        if os.path.exists(best_model_path):
            model = YOLO(best_model_path)
            print(f" Loaded model: {best_model_path}")
            
            # Test với test images
            test_dir = "data/test/images"
            if os.path.exists(test_dir):
                test_images = list(Path(test_dir).glob("*.jpg"))[:5]  # Test 5 images
                
                for img_path in test_images:
                    results = model(str(img_path))
                    print(f"Tested: {img_path.name}")
                    
                    # Save results
                    for r in results:
                        r.save(filename=f"test_result_{img_path.name}")
                        
                print(" Test hoàn thành!")
            else:
                print(f"Không tìm thấy thư mục test: {test_dir}")
        else:
            print(f"Không tìm thấy model: {best_model_path}")
            
    except Exception as e:
        print(f" Lỗi khi test model: {e}")

if __name__ == "__main__":
    print(" YOLOv8 Fire & Smoke Detection Training")
    print("=" * 50)
    
    # Train model
    results = simple_train()
    
    if results:
        print("\n" + "=" * 50)
        print(" Testing model...")
        test_model()
    
    print("\n Script hoàn thành!")