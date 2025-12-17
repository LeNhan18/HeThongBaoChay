from ultralytics import YOLO
import cv2
import os
import time


def main():
    # --- 1. CẤU HÌNH ---
    # Đường dẫn model (giữ nguyên)
    model_path = r'e:\HeThongBaoChay\training_results_20251125_021040\advanced_fire_smoke_yolo11s\weights\best.pt'

    if not os.path.exists(model_path):
        print(f" Lỗi: Không tìm thấy model tại: {model_path}")
        return

    print(f" Đang tải model từ: {model_path}...")
    try:
        model = YOLO(model_path)
        print(" Tải model thành công!")
    except Exception as e:
        print(f" Lỗi khi tải model: {e}")
        return

    # --- 2. VÒNG LẶP CHÍNH ---
    while True:
        print("\n" + "=" * 50)
        video_path = input("🎥 Nhập đường dẫn file VIDEO để test (nhập 'q' để thoát): ").strip()

        if video_path.lower() == 'q':
            print(" Đã thoát chương trình.")
            break

        video_path = video_path.strip('"').strip("'")

        if not os.path.exists(video_path):
            print(f" File không tồn tại: {video_path}")
            continue

        # --- 3. XỬ LÝ VIDEO ---
        cap = cv2.VideoCapture(video_path)
        if not cap.isOpened():
            print(" Không thể mở file video.")
            continue

        frame_width = int(cap.get(cv2.CAP_PROP_FRAME_WIDTH))
        frame_height = int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT))
        fps = int(cap.get(cv2.CAP_PROP_FPS))

        base_name = os.path.splitext(os.path.basename(video_path))[0]
        output_path = f"{base_name}_result.mp4"

        fourcc = cv2.VideoWriter_fourcc(*'mp4v')
        out = cv2.VideoWriter(output_path, fourcc, fps, (frame_width, frame_height))

        print(f" Đang xử lý... (Chế độ an toàn: Tự tắt cửa sổ nếu lỗi OpenCV Headless)")
        print(f" Kết quả sẽ được lưu tại: {os.path.abspath(output_path)}")

        frame_count = 0
        start_time = time.time()

        # Cờ kiểm soát hiển thị cửa sổ
        can_show_window = True

        while cap.isOpened():
            ret, frame = cap.read()
            if not ret:
                break

            frame_count += 1
            if frame_count % 30 == 0:
                print(f" Đang xử lý frame {frame_count}...", end='\r')

            # DỰ ĐOÁN
            results = model.predict(frame, conf=0.4, iou=0.5, verbose=False)
            annotated_frame = results[0].plot()

            # Ghi video (Luôn chạy được)
            out.write(annotated_frame)

            # Hiển thị (CÓ TRY-CATCH ĐỂ CHỐNG CRASH)
            if can_show_window:
                try:
                    # Resize cho dễ nhìn trên màn hình laptop
                    display_frame = cv2.resize(annotated_frame, (1020, 600))
                    cv2.imshow("YOLOv8 Fire Detection", display_frame)

                    if cv2.waitKey(1) & 0xFF == ord('q'):
                        print("\n Đã dừng xử lý video.")
                        break
                except cv2.error:
                    print("\nPHÁT HIỆN LỖI: Thư viện OpenCV của bạn là bản 'headless' (không có giao diện).")
                    print(" Chương trình sẽ tự động chuyển sang chế độ CHẠY NGẦM.")
                    print(" Vui lòng đợi xử lý xong và mở file video kết quả để xem.")
                    can_show_window = False  # Tắt hẳn tính năng hiển thị để không lỗi các frame sau
        cap.release()
        out.release()
        try:
            cv2.destroyAllWindows()
        except:
            pass
        duration = time.time() - start_time
        print(f"\n Hoàn tất! Đã xử lý {frame_count} frames trong {duration:.2f} giây.")
        print(f" File kết quả: {output_path}")
if __name__ == "__main__":
    main()