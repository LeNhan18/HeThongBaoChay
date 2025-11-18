"""
Script kiểm tra dữ liệu trước khi training YOLOv8
"""

import os
import yaml
import matplotlib.pyplot as plt
import cv2
import numpy as np
from collections import Counter
import random

def check_data_structure():
    """Kiểm tra cấu trúc dữ liệu"""
    print("🔍 KIỂM TRA CẤU TRÚC DỮ LIỆU")
    print("=" * 50)
    
    # Kiểm tra file data.yaml
    data_yaml_path = "data/data.yaml"
    if not os.path.exists(data_yaml_path):
        print("❌ Không tìm thấy file data/data.yaml")
        return False
    
    with open(data_yaml_path, 'r') as f:
        data_config = yaml.safe_load(f)
    
    print(f"📄 File config: {data_yaml_path}")
    print(f"🏷️  Classes: {data_config['names']}")
    print(f"🔢 Số classes: {data_config['nc']}")
    
    # Kiểm tra các thư mục
    base_dir = os.path.dirname(data_yaml_path)
    
    for split in ['train', 'val', 'test']:
        if split in data_config:
            # Thư mục images
            img_dir = os.path.join(base_dir, data_config[split])
            if not os.path.exists(img_dir):
                img_dir = os.path.join(base_dir, split, 'images')
            
            # Thư mục labels
            label_dir = img_dir.replace('images', 'labels')
            
            if os.path.exists(img_dir) and os.path.exists(label_dir):
                img_files = [f for f in os.listdir(img_dir) if f.lower().endswith(('.jpg', '.jpeg', '.png'))]
                label_files = [f for f in os.listdir(label_dir) if f.endswith('.txt')]
                
                print(f"📁 {split.upper()}:")
                print(f"   📸 Images: {len(img_files)} files")
                print(f"   🏷️  Labels: {len(label_files)} files")
                
                # Kiểm tra sự tương ứng
                img_names = {os.path.splitext(f)[0] for f in img_files}
                label_names = {os.path.splitext(f)[0] for f in label_files}
                
                missing_labels = img_names - label_names
                missing_images = label_names - img_names
                
                if missing_labels:
                    print(f"   ⚠️  Thiếu labels: {len(missing_labels)} files")
                if missing_images:
                    print(f"   ⚠️  Thiếu images: {len(missing_images)} files")
                
                if not missing_labels and not missing_images:
                    print(f"   ✅ Dữ liệu {split} đồng bộ hoàn hảo!")
            else:
                print(f"❌ Không tìm thấy thư mục {split}")
    
    return True

def analyze_labels():
    """Phân tích nhãn dữ liệu"""
    print("\n📊 PHÂN TÍCH NHÃN DỮ LIỆU")
    print("=" * 50)
    
    class_counts = Counter()
    bbox_sizes = []
    
    # Phân tích từng split
    for split in ['train', 'valid', 'test']:
        label_dir = f"data/{split}/labels"
        if not os.path.exists(label_dir):
            continue
        
        print(f"📁 Phân tích {split}...")
        
        split_class_counts = Counter()
        split_bbox_sizes = []
        
        for label_file in os.listdir(label_dir):
            if not label_file.endswith('.txt'):
                continue
            
            label_path = os.path.join(label_dir, label_file)
            
            try:
                with open(label_path, 'r') as f:
                    lines = f.readlines()
                
                for line in lines:
                    parts = line.strip().split()
                    if len(parts) >= 5:
                        class_id = int(parts[0])
                        width = float(parts[3])
                        height = float(parts[4])
                        
                        class_counts[class_id] += 1
                        split_class_counts[class_id] += 1
                        bbox_sizes.append((width, height))
                        split_bbox_sizes.append((width, height))
            
            except Exception as e:
                print(f"   ⚠️ Lỗi đọc file {label_file}: {e}")
        
        # In thống kê cho split này
        if split_class_counts:
            total_objects = sum(split_class_counts.values())
            print(f"   📊 Tổng objects: {total_objects}")
            for class_id, count in split_class_counts.items():
                class_name = "Fire" if class_id == 0 else "Smoke"
                percentage = (count / total_objects) * 100
                print(f"   🏷️  {class_name}: {count} ({percentage:.1f}%)")
    
    # Thống kê tổng
    print(f"\n📈 THỐNG KÊ TỔNG:")
    total_objects = sum(class_counts.values())
    print(f"   📊 Tổng objects: {total_objects}")
    
    class_names = {0: "Fire", 1: "Smoke"}
    for class_id, count in class_counts.items():
        class_name = class_names.get(class_id, f"Class_{class_id}")
        percentage = (count / total_objects) * 100
        print(f"   🏷️  {class_name}: {count} ({percentage:.1f}%)")
    
    # Phân tích kích thước bbox
    if bbox_sizes:
        widths = [size[0] for size in bbox_sizes]
        heights = [size[1] for size in bbox_sizes]
        
        print(f"\n📏 PHÂN TÍCH KÍCH THƯỚC BBOX:")
        print(f"   📐 Width - Min: {min(widths):.4f}, Max: {max(widths):.4f}, Mean: {np.mean(widths):.4f}")
        print(f"   📐 Height - Min: {min(heights):.4f}, Max: {max(heights):.4f}, Mean: {np.mean(heights):.4f}")
    
    return class_counts, bbox_sizes

def visualize_sample_data():
    """Hiển thị một số ảnh mẫu với labels"""
    print("\n🖼️  HIỂN THỊ DỮ LIỆU MẪU")
    print("=" * 50)
    
    # Tìm thư mục train images
    train_img_dir = "data/train/images"
    train_label_dir = "data/train/labels"
    
    if not os.path.exists(train_img_dir) or not os.path.exists(train_label_dir):
        print("❌ Không tìm thấy thư mục train")
        return
    
    # Lấy ngẫu nhiên 6 ảnh
    img_files = [f for f in os.listdir(train_img_dir) if f.lower().endswith(('.jpg', '.jpeg', '.png'))]
    sample_files = random.sample(img_files, min(6, len(img_files)))
    
    fig, axes = plt.subplots(2, 3, figsize=(15, 10))
    fig.suptitle('🔥💨 Sample Training Data with Labels', fontsize=16, fontweight='bold')
    
    class_names = {0: "Fire", 1: "Smoke"}
    colors = {0: (255, 0, 0), 1: (0, 255, 255)}  # Red for Fire, Yellow for Smoke
    
    for idx, img_file in enumerate(sample_files):
        row = idx // 3
        col = idx % 3
        ax = axes[row, col]
        
        # Đọc ảnh
        img_path = os.path.join(train_img_dir, img_file)
        img = cv2.imread(img_path)
        img = cv2.cvtColor(img, cv2.COLOR_BGR2RGB)
        h, w = img.shape[:2]
        
        # Đọc labels
        label_file = os.path.splitext(img_file)[0] + '.txt'
        label_path = os.path.join(train_label_dir, label_file)
        
        if os.path.exists(label_path):
            with open(label_path, 'r') as f:
                lines = f.readlines()
            
            # Vẽ bounding boxes
            for line in lines:
                parts = line.strip().split()
                if len(parts) >= 5:
                    class_id = int(parts[0])
                    x_center = float(parts[1]) * w
                    y_center = float(parts[2]) * h
                    width = float(parts[3]) * w
                    height = float(parts[4]) * h
                    
                    # Tính toán góc
                    x1 = int(x_center - width/2)
                    y1 = int(y_center - height/2)
                    x2 = int(x_center + width/2)
                    y2 = int(y_center + height/2)
                    
                    # Vẽ rectangle
                    color = colors.get(class_id, (0, 255, 0))
                    cv2.rectangle(img, (x1, y1), (x2, y2), color, 2)
                    
                    # Vẽ label
                    label_text = class_names.get(class_id, f"Class_{class_id}")
                    cv2.putText(img, label_text, (x1, y1-10), 
                              cv2.FONT_HERSHEY_SIMPLEX, 0.7, color, 2)
        
        ax.imshow(img)
        ax.set_title(f'Sample {idx+1}')
        ax.axis('off')
    
    plt.tight_layout()
    plt.savefig('sample_data_visualization.png', dpi=300, bbox_inches='tight')
    plt.show()
    
    print("💾 Đã lưu visualization: sample_data_visualization.png")

def create_class_distribution_plot(class_counts):
    """Tạo biểu đồ phân bố classes"""
    print("\n📊 TẠO BIỂU ĐỒ PHÂN BỐ CLASSES")
    print("=" * 50)
    
    if not class_counts:
        print("❌ Không có dữ liệu class counts")
        return
    
    # Chuẩn bị dữ liệu
    class_names = {0: "Fire", 1: "Smoke"}
    labels = [class_names.get(class_id, f"Class_{class_id}") for class_id in class_counts.keys()]
    counts = list(class_counts.values())
    colors = ['#FF6B6B', '#4ECDC4']  # Red for Fire, Teal for Smoke
    
    # Tạo figure với 2 subplots
    fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(12, 5))
    fig.suptitle('🔥💨 Class Distribution Analysis', fontsize=16, fontweight='bold')
    
    # 1. Bar chart
    bars = ax1.bar(labels, counts, color=colors, alpha=0.8)
    ax1.set_title('📊 Object Count by Class')
    ax1.set_ylabel('Number of Objects')
    ax1.grid(True, alpha=0.3, axis='y')
    
    # Thêm giá trị lên bars
    for bar, count in zip(bars, counts):
        height = bar.get_height()
        ax1.text(bar.get_x() + bar.get_width()/2., height + max(counts)*0.01,
                f'{count}', ha='center', va='bottom', fontweight='bold')
    
    # 2. Pie chart
    wedges, texts, autotexts = ax2.pie(counts, labels=labels, colors=colors, autopct='%1.1f%%', 
                                      startangle=90, explode=(0.05, 0.05))
    ax2.set_title('🥧 Class Distribution Percentage')
    
    # Làm đẹp pie chart
    for autotext in autotexts:
        autotext.set_color('white')
        autotext.set_fontweight('bold')
    
    plt.tight_layout()
    plt.savefig('class_distribution.png', dpi=300, bbox_inches='tight')
    plt.show()
    
    print("💾 Đã lưu biểu đồ: class_distribution.png")

def main():
    """Hàm main để chạy tất cả kiểm tra"""
    print("🔥💨 YOLO FIRE & SMOKE DETECTION - DATA ANALYSIS")
    print("=" * 60)
    
    # 1. Kiểm tra cấu trúc dữ liệu
    if not check_data_structure():
        return
    
    # 2. Phân tích labels
    class_counts, bbox_sizes = analyze_labels()
    
    # 3. Tạo biểu đồ phân bố classes
    create_class_distribution_plot(class_counts)
    
    # 4. Hiển thị dữ liệu mẫu
    visualize_sample_data()
    
    print("\n🎉 Hoàn thành phân tích dữ liệu!")
    print("📝 Các file đã tạo:")
    print("   - sample_data_visualization.png")
    print("   - class_distribution.png")
    print("\n✅ Dữ liệu sẵn sàng cho training!")
    print("🚀 Chạy lệnh: python simple_train.py để bắt đầu training")

if __name__ == "__main__":
    main()