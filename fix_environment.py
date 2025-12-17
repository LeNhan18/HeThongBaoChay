#!/usr/bin/env python3
"""
Script để sửa lỗi xung đột thư viện và cài đặt môi trường training YOLOv8
"""

import subprocess
import sys
import os

def run_command(command, description):
    """Chạy command và hiển thị kết quả"""
    print(f"\n{'='*60}")
    print(f"🔧 {description}")
    print(f"{'='*60}")
    print(f"Command: {command}")
    
    try:
        result = subprocess.run(command, shell=True, capture_output=True, text=True)
        if result.returncode == 0:
            print("✅ Success!")
            if result.stdout:
                print(result.stdout)
        else:
            print("❌ Error!")
            if result.stderr:
                print(result.stderr)
        return result.returncode == 0
    except Exception as e:
        print(f"❌ Exception: {e}")
        return False

def fix_environment():
    """Sửa lỗi môi trường và cài đặt lại thư viện"""
    
    print("🚀 Bắt đầu sửa lỗi môi trường Python...")
    
    # 1. Gỡ cài đặt numpy và pandas cũ
    print("\n📦 Gỡ cài đặt numpy và pandas cũ...")
    run_command("pip uninstall numpy pandas -y", "Gỡ numpy và pandas")
    
    # 2. Làm sạch cache pip
    run_command("pip cache purge", "Làm sạch cache pip")
    
    # 3. Cài đặt numpy trước
    print("\n📦 Cài đặt numpy version tương thích...")
    run_command("pip install numpy==1.24.3", "Cài đặt numpy 1.24.3")
    
    # 4. Cài đặt pandas tương thích
    print("\n📦 Cài đặt pandas version tương thích...")
    run_command("pip install pandas==2.0.3", "Cài đặt pandas 2.0.3")
    
    # 5. Cài đặt các thư viện cần thiết với version tương thích
    compatible_packages = [
        "matplotlib==3.7.2",
        "seaborn==0.12.2",
        "scikit-learn==1.3.0",
        "opencv-python==4.8.0.76",
        "pillow==10.0.0",
        "ultralytics==8.0.196",
        "torch==2.0.1",
        "torchvision==0.15.2",
        "tensorboard==2.13.0",
        "albumentations==1.3.1",
        "optuna==3.2.0",
        "pyyaml==6.0.1",
        "tqdm==4.65.0"
    ]
    
    print("\n📦 Cài đặt các thư viện ML...")
    for package in compatible_packages:
        run_command(f"pip install {package}", f"Cài đặt {package}")
    
    # 6. Kiểm tra cài đặt
    print("\n🔍 Kiểm tra cài đặt...")
    test_imports = [
        "import numpy as np; print(f'NumPy: {np.__version__}')",
        "import pandas as pd; print(f'Pandas: {pd.__version__}')",
        "import matplotlib; print(f'Matplotlib: {matplotlib.__version__}')",
        "import seaborn as sns; print(f'Seaborn: {sns.__version__}')",
        "import torch; print(f'PyTorch: {torch.__version__}')",
        "from ultralytics import YOLO; print('YOLOv8: OK')",
        "import cv2; print(f'OpenCV: {cv2.__version__}')"
    ]
    
    for test in test_imports:
        run_command(f'python -c "{test}"', f"Test: {test.split(';')[0]}")

if __name__ == "__main__":
    print("🔧 YOLOv8 Environment Fix Script")
    print("=" * 60)
    
    # Kiểm tra môi trường ảo
    if "VIRTUAL_ENV" not in os.environ:
        print("⚠️  Cảnh báo: Không phát hiện môi trường ảo!")
        print("Khuyến nghị kích hoạt venv trước:")
        print("   .\\venv\\Scripts\\Activate.ps1")
        response = input("\nTiếp tục anyway? (y/N): ")
        if response.lower() != 'y':
            sys.exit(1)
    
    fix_environment()
    
    print("\n" + "="*60)
    print("✅ Hoàn thành! Bây giờ bạn có thể chạy train_yolo_model.py")
    print("="*60)