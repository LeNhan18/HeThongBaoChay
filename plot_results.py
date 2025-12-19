"""
Script để vẽ biểu đồ mAP theo style Chart_2_mAP_Performance.png
Hiển thị mAP50 và mAP50-95 theo epoch với nhãn tiếng Việt
"""

import pandas as pd
import matplotlib.pyplot as plt
import matplotlib
import os
import numpy as np

# Cấu hình font để hiển thị tiếng Việt
plt.rcParams['font.family'] = 'DejaVu Sans'
matplotlib.rcParams['axes.unicode_minus'] = False

# Đường dẫn đến file results.csv
file_path = 'results.csv'
output_file = 'Chart_2_mAP_Performance.png'

# Đọc dữ liệu
try:
    df = pd.read_csv(file_path)
    df.columns = df.columns.str.strip()
    print(f"✅ Đã đọc {len(df)} dòng dữ liệu từ {file_path}")
except Exception as e:
    print(f"❌ Lỗi khi đọc file CSV: {e}")
    exit(1)

# Tạo figure với kích thước phù hợp
fig, ax = plt.subplots(figsize=(12, 8))

# Vẽ đường mAP@50 (màu xanh lá)
if 'metrics/mAP50(B)' in df.columns:
    map50_values = df['metrics/mAP50(B)'].values
    epochs = df['epoch'].values
    
    # Vẽ đường với màu xanh lá
    line1 = ax.plot(epochs, map50_values, 
                    label='mAP@50 (Ngưỡng 0.5)',
                    color='#2ECC71',  # Màu xanh lá
                    linewidth=2.5,
                    marker='o',
                    markersize=5,
                    markerfacecolor='#2ECC71',
                    markeredgecolor='white',
                    markeredgewidth=1.5,
                    alpha=0.9)
    
    # Tìm giá trị cao nhất và epoch tương ứng
    max_idx = np.argmax(map50_values)
    max_value = map50_values[max_idx]
    max_epoch = epochs[max_idx]
    
    # Đánh dấu điểm cao nhất bằng điểm đỏ
    ax.plot(max_epoch, max_value, 
            marker='o', 
            markersize=10, 
            markerfacecolor='red',
            markeredgecolor='white',
            markeredgewidth=2,
            zorder=5)
    
    # Thêm annotation cho giá trị cao nhất
    ax.annotate(f'Max: {max_value*100:.1f}%',
                xy=(max_epoch, max_value),
                xytext=(max_epoch + 5, max_value + 0.02),
                fontsize=11,
                fontweight='bold',
                color='red',
                bbox=dict(boxstyle='round,pad=0.5', 
                         facecolor='white', 
                         edgecolor='red',
                         alpha=0.9),
                arrowprops=dict(arrowstyle='->', 
                              connectionstyle='arc3,rad=0.2',
                              color='red',
                              lw=1.5))

# Vẽ đường mAP@50-95 (màu cam)
if 'metrics/mAP50-95(B)' in df.columns:
    map50_95_values = df['metrics/mAP50-95(B)'].values
    
    # Vẽ đường với màu cam
    line2 = ax.plot(epochs, map50_95_values,
                    label='mAP@50-95 (Ngưỡng chặt)',
                    color='#E67E22',  # Màu cam
                    linewidth=2.5,
                    marker='s',
                    markersize=5,
                    markerfacecolor='#E67E22',
                    markeredgecolor='white',
                    markeredgewidth=1.5,
                    alpha=0.9)

# Thiết lập tiêu đề và nhãn (tiếng Việt)
ax.set_title('Hiệu suất mô hình (mAP) qua các Epoch', 
             fontsize=16, 
             fontweight='bold',
             pad=20)

ax.set_xlabel('Epochs', fontsize=12, fontweight='bold')
ax.set_ylabel('Độ chính xác (0.0 - 1.0)', fontsize=12, fontweight='bold')

# Thiết lập giới hạn trục
ax.set_xlim(0, max(epochs) + 5)
ax.set_ylim(0, max(max(map50_values), max(map50_95_values)) * 1.15)

# Thêm grid
ax.grid(True, alpha=0.3, linestyle='--', linewidth=0.8)

# Thêm legend ở góc dưới bên phải
ax.legend(loc='lower right', 
          fontsize=11,
          framealpha=0.9,
          fancybox=True,
          shadow=True)

# Định dạng số trên trục Y để hiển thị phần trăm dễ đọc hơn
ax.yaxis.set_major_formatter(plt.FuncFormatter(lambda y, _: f'{y:.2f}'))

# Thêm các đường ngang mốc quan trọng (tùy chọn)
ax.axhline(y=0.75, color='green', linestyle=':', linewidth=1, alpha=0.3)
ax.axhline(y=0.80, color='orange', linestyle=':', linewidth=1, alpha=0.3)

# Điều chỉnh layout
plt.tight_layout()

# Lưu biểu đồ với độ phân giải cao
plt.savefig(output_file, dpi=300, bbox_inches='tight', facecolor='white')
print(f"✅ Đã lưu biểu đồ vào: {output_file}")

# In thống kê
print("\n" + "="*60)
print("📊 THỐNG KÊ:")
print("="*60)
if 'metrics/mAP50(B)' in df.columns:
    final_map50 = df['metrics/mAP50(B)'].iloc[-1]
    max_map50 = df['metrics/mAP50(B)'].max()
    print(f"mAP@50 - Giá trị cuối: {final_map50:.4f} ({final_map50*100:.2f}%)")
    print(f"mAP@50 - Giá trị cao nhất: {max_map50:.4f} ({max_map50*100:.2f}%)")

if 'metrics/mAP50-95(B)' in df.columns:
    final_map50_95 = df['metrics/mAP50-95(B)'].iloc[-1]
    max_map50_95 = df['metrics/mAP50-95(B)'].max()
    print(f"mAP@50-95 - Giá trị cuối: {final_map50_95:.4f} ({final_map50_95*100:.2f}%)")
    print(f"mAP@50-95 - Giá trị cao nhất: {max_map50_95:.4f} ({max_map50_95*100:.2f}%)")
print("="*60)

# Hiển thị biểu đồ (nếu có GUI)
try:
    plt.show()
except:
    print("ℹ️  Không thể hiển thị biểu đồ (chạy trong môi trường không có GUI)")





