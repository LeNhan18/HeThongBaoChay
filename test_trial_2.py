from ultralytics import YOLO
import os
import cv2

def main():
    # Đường dẫn đến model best.pt của trial_2
    model_path = r'e:\HeThongBaoChay\training_results_20251121_213634\optuna_trials\trial_2\weights\best.pt'
    print(f"Đang tải model từ: {model_path}...")
    try:
        model = YOLO(model_path)
        print("Tải model thành công!")
    except Exception as e:
        print(f"Lỗi khi tải model: {e}")
        return
    while True:
        print("\n" + "="*50)
        img_path = input("Nhập đường dẫn file ảnh để test (nhập 'q' để thoát): ").strip()
        if img_path.lower() == 'q':
            print("Đã thoát chương trình.")
            break
        # Xử lý đường dẫn (bỏ dấu ngoặc kép nếu có)
        img_path = img_path.strip('"').strip("'")
        if not os.path.exists(img_path):
            print(f"Lỗi: File không tồn tại tại đường dẫn: {img_path}")
            continue
        try:
            print(f"Đang xử lý ảnh: {img_path}...")
            # Run inference
            # save=True sẽ lưu ảnh kết quả vào runs/detect/predict...
            # show=True sẽ hiển thị cửa sổ kết quả
            results = model.predict(source=img_path, save=True, show=True)
            print("Xử lý xong!")
            # In ra nơi lưu kết quả
            for r in results:
                print(f"Kết quả đã được lưu tại: {r.save_dir}")
        except Exception as e:
            print(f"Lỗi khi dự đoán: {e}")
if __name__ == "__main__":
    main()
