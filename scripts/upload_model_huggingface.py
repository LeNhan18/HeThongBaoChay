#!/usr/bin/env python3
"""
Upload model YOLO lên Hugging Face Hub.
Chạy từ thư mục gốc: python scripts/upload_model_huggingface.py

Yêu cầu: pip install huggingface_hub
"""
import sys
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parent.parent

# Thư mục weights cần upload (không phải file .pt đơn lẻ)
WEIGHTS_FOLDER = (
    PROJECT_ROOT
    / "training_results_20251125_021040"
    / "advanced_fire_smoke_yolo11s"
    / "weights"
)
REPO_ID = "LeNhan18/YOLOV11FIRESMOKE"
REPO_TYPE = "model"


def main():
    try:
        from huggingface_hub import login, upload_folder
    except ImportError:
        print("❌ Cần cài đặt: pip install huggingface_hub")
        sys.exit(1)

    if not WEIGHTS_FOLDER.exists():
        print(f"❌ Không tìm thấy thư mục: {WEIGHTS_FOLDER}")
        print("   Hãy train model trước khi upload.")
        sys.exit(1)

    print("🔐 Đăng nhập Hugging Face...")
    login()

    print(f"📤 Đang upload thư mục: {WEIGHTS_FOLDER}")
    print(f"   → Repo: {REPO_ID}")
    url = upload_folder(
        folder_path=str(WEIGHTS_FOLDER),
        repo_id=REPO_ID,
        repo_type=REPO_TYPE,
    )
    print(f"✅ Upload thành công: {url}")


if __name__ == "__main__":
    main()
