import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns
import os


def draw_report_charts(csv_path='E:\\HeThongBaoChay\\training_results_20251125_021040\\advanced_fire_smoke_yolo11s\\results.csv'):
    # 1. Kiểm tra file
    if not os.path.exists(csv_path):
        print(f" Không tìm thấy file {csv_path}. Hãy upload file results.csv lên.")
        return

    # 2. Đọc dữ liệu
    try:
        df = pd.read_csv(csv_path)
        # Xóa khoảng trắng thừa trong tên cột (YOLO thường bị lỗi này)
        df.columns = df.columns.str.strip()
        print("Đã đọc dữ liệu thành công!")
        print(f" Tổng số Epochs: {len(df)}")
    except Exception as e:
        print(f" Lỗi đọc file CSV: {e}")
        return

    # Tạo thư mục lưu ảnh
    output_dir = "report_images1"
    os.makedirs(output_dir, exist_ok=True)

    # Cấu hình giao diện biểu đồ (Style khoa học)
    sns.set_theme(style="whitegrid")
    plt.rcParams.update({'font.size': 12, 'font.family': 'sans-serif'})

    # ==========================================================================
    # BIỂU ĐỒ 1: HÀM MẤT MÁT (TRAIN vs VAL LOSS)
    # Biểu đồ này chứng minh mô hình KHÔNG bị Overfitting quá nặng
    # ==========================================================================
    fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(16, 6))

    # Box Loss
    ax1.plot(df['epoch'], df['train/box_loss'], label='Train Box Loss', color='blue', linewidth=2)
    ax1.plot(df['epoch'], df['val/box_loss'], label='Val Box Loss', color='red', linewidth=2, linestyle='--')
    ax1.set_title('Box Loss (Sai số vị trí khung)', fontweight='bold')
    ax1.set_xlabel('Epochs')
    ax1.set_ylabel('Loss Value')
    ax1.legend()
    ax1.grid(True, alpha=0.3)

    # Class Loss
    ax2.plot(df['epoch'], df['train/cls_loss'], label='Train Cls Loss', color='blue', linewidth=2)
    ax2.plot(df['epoch'], df['val/cls_loss'], label='Val Cls Loss', color='red', linewidth=2, linestyle='--')
    ax2.set_title('Class Loss (Sai số phân loại)', fontweight='bold')
    ax2.set_xlabel('Epochs')
    ax2.set_ylabel('Loss Value')
    ax2.legend()
    ax2.grid(True, alpha=0.3)

    plt.tight_layout()
    save_path = os.path.join(output_dir, "Chart_1_Loss_Analysis.png")
    plt.savefig(save_path, dpi=300)
    print(f" Đã lưu: {save_path}")
    plt.close()

    # ==========================================================================
    # BIỂU ĐỒ 2: ĐỘ CHÍNH XÁC mAP (Mean Average Precision)
    # Đây là biểu đồ quan trọng nhất để kết luận độ chính xác của đồ án
    # ==========================================================================
    plt.figure(figsize=(10, 6))
    plt.plot(df['epoch'], df['metrics/mAP50(B)'], label='mAP@50 (Ngưỡng 0.5)', color='green', linewidth=2.5)
    plt.plot(df['epoch'], df['metrics/mAP50-95(B)'], label='mAP@50-95 (Ngưỡng chặt)', color='orange', linewidth=2)

    # Đánh dấu điểm cao nhất
    max_map = df['metrics/mAP50(B)'].max()
    max_epoch = df['metrics/mAP50(B)'].idxmax() + 1
    plt.scatter(max_epoch, max_map, color='red', zorder=5)
    plt.annotate(f'Max: {max_map:.1%}', xy=(max_epoch, max_map), xytext=(max_epoch - 20, max_map - 0.1),
                 arrowprops=dict(facecolor='black', shrink=0.05))

    plt.title('Hiệu suất mô hình (mAP) qua các Epoch', fontweight='bold')
    plt.xlabel('Epochs')
    plt.ylabel('Độ chính xác (0.0 - 1.0)')
    plt.legend(loc='lower right')
    plt.grid(True, alpha=0.5)

    save_path = os.path.join(output_dir, "Chart_2_mAP_Performance.png")
    plt.savefig(save_path, dpi=300)
    print(f" Đã lưu: {save_path}")
    plt.close()

    # ==========================================================================
    # BIỂU ĐỒ 3: PRECISION & RECALL
    # Dùng để phân tích sự đánh đổi giữa độ nhạy và độ chính xác
    # ==========================================================================
    plt.figure(figsize=(10, 6))
    plt.plot(df['epoch'], df['metrics/precision(B)'], label='Precision (Độ chính xác)', color='purple', alpha=0.8)
    plt.plot(df['epoch'], df['metrics/recall(B)'], label='Recall (Độ nhạy)', color='teal', alpha=0.8)

    plt.title('Diễn biến Precision và Recall', fontweight='bold')
    plt.xlabel('Epochs')
    plt.ylabel('Giá trị (0.0 - 1.0)')
    plt.legend()
    plt.grid(True, alpha=0.5)

    save_path = os.path.join(output_dir, "Chart_3_Precision_Recall.png")
    plt.savefig(save_path, dpi=300)
    print(f" Đã lưu: {save_path}")
    plt.close()

    # ==========================================================================
    # Biểu đồ 4: F1 Score
    # F1 Score là chỉ số tổng hợp giữa Precision và Recall
    # ==========================================================================
    precision = df['metrics/precision(B)']
    recall = df['metrics/recall(B)']
    f1_score = 2 * (precision * recall) / (precision + recall + 1e-16)
    plt.figure(figsize=(10, 6))
    sns.lineplot(x=df['epoch'], y=f1_score, label='F1-Score', color='magenta', linewidth=2.5)

    # Đánh dấu F1 cao nhất
    max_f1 = f1_score.max()
    max_f1_epoch = f1_score.idxmax() + 1

    plt.scatter(max_f1_epoch, max_f1, color='red', s=50, zorder=5)
    plt.annotate(f'Max F1: {max_f1:.2f}\n(Epoch {max_f1_epoch})',
                 xy=(max_f1_epoch, max_f1),
                 xytext=(max_f1_epoch - 15, max_f1 - 0.1),
                 arrowprops=dict(facecolor='black', shrink=0.05),
                 fontsize=10, fontweight='bold', color='red')

    plt.title('Biểu đồ F1-Score qua các Epoch', fontweight='bold', fontsize=14)
    plt.xlabel('Epochs')
    plt.ylabel('F1-Score (0.0 - 1.0)')
    plt.legend()
    plt.grid(True, alpha=0.5)

    save_path4 = os.path.join(output_dir, 'Chart_4_F1_Score.png')
    plt.savefig(save_path4, dpi=300)
    print(f" Đã lưu biểu đồ 4: {save_path4}")
    plt.close()

    # ---------------------------------------------------------
    # BIỂU ĐỒ 5: LEARNING RATE
    # Mục đích: Kiểm tra chiến lược thay đổi tốc độ học
    # ---------------------------------------------------------
    plt.figure(figsize=(10, 6))
    # Thường có lr/pg0, lr/pg1, lr/pg2
    if 'lr/pg0' in df.columns:
        sns.lineplot(data=df, x='epoch', y='lr/pg0', label='Learning Rate (pg0)', color='brown')

    plt.title('Thay đổi Learning Rate theo thời gian', fontweight='bold', fontsize=14)
    plt.xlabel('Epochs')
    plt.ylabel('Learning Rate')
    plt.yscale('log')  # Dùng thang log để dễ nhìn sự thay đổi nhỏ
    plt.legend()
    plt.grid(True, alpha=0.5)

    save_path5 = os.path.join(output_dir, 'Chart_5_Learning_Rate.png')
    plt.savefig(save_path5, dpi=300)
    print(f" Đã lưu biểu đồ 5: {save_path5}")
    plt.close()

    print("\n TẤT CẢ BIỂU ĐỒ ĐÃ SẴN SÀNG ĐỂ CHÈN VÀO WORD!")
    print(f" Kiểm tra thư mục: {output_dir}")


if __name__ == "__main__":
    draw_report_charts()