#!/usr/bin/env python3
"""
Tạo logo cho Hệ Thống Báo Cháy
Lưu vào assets/images/logo.png
"""

from PIL import Image, ImageDraw, ImageFont
import os

def create_fire_logo(size=512):
    """
    Tạo logo với icon lửa và màu đỏ/cam phù hợp với theme cảnh báo cháy
    """
    # Tạo image với background trong suốt hoặc màu trắng
    img = Image.new('RGBA', (size, size), (255, 255, 255, 0))
    draw = ImageDraw.Draw(img)
    
    # Màu sắc
    red = (220, 53, 69)  # Màu đỏ cảnh báo
    orange = (255, 152, 0)  # Màu cam
    yellow = (255, 235, 59)  # Màu vàng
    dark_red = (183, 28, 28)  # Đỏ đậm
    
    # Vẽ background tròn với gradient đỏ
    center = size // 2
    radius = int(size * 0.45)
    
    # Background circle (màu đỏ)
    draw.ellipse(
        [(center - radius, center - radius), 
         (center + radius, center + radius)],
        fill=red,
        outline=dark_red,
        width=max(3, size // 128)
    )
    
    # Vẽ icon lửa (flame shape) - lớn hơn và đẹp hơn
    flame_size = int(size * 0.65)
    flame_x = center
    flame_y = center + int(size * 0.05)
    
    # Tạo hình ngọn lửa với nhiều lớp để có độ sâu
    # Lớp ngoài (vàng) - lớn nhất
    flame_points_outer = [
        (flame_x, flame_y - flame_size // 2),  # Đỉnh
        (flame_x - int(flame_size * 0.35), flame_y - int(flame_size * 0.15)),
        (flame_x - int(flame_size * 0.28), flame_y + int(flame_size * 0.25)),
        (flame_x - int(flame_size * 0.15), flame_y + int(flame_size * 0.4)),
        (flame_x, flame_y + int(flame_size * 0.45)),  # Giữa dưới
        (flame_x + int(flame_size * 0.15), flame_y + int(flame_size * 0.4)),
        (flame_x + int(flame_size * 0.28), flame_y + int(flame_size * 0.25)),
        (flame_x + int(flame_size * 0.35), flame_y - int(flame_size * 0.15)),
    ]
    draw.polygon(flame_points_outer, fill=yellow)
    
    # Lớp giữa (cam)
    flame_points_mid = [
        (flame_x, flame_y - int(flame_size * 0.42)),
        (flame_x - int(flame_size * 0.28), flame_y - int(flame_size * 0.12)),
        (flame_x - int(flame_size * 0.20), flame_y + int(flame_size * 0.20)),
        (flame_x - int(flame_size * 0.10), flame_y + int(flame_size * 0.32)),
        (flame_x, flame_y + int(flame_size * 0.35)),
        (flame_x + int(flame_size * 0.10), flame_y + int(flame_size * 0.32)),
        (flame_x + int(flame_size * 0.20), flame_y + int(flame_size * 0.20)),
        (flame_x + int(flame_size * 0.28), flame_y - int(flame_size * 0.12)),
    ]
    draw.polygon(flame_points_mid, fill=orange)
    
    # Lớp trong (đỏ)
    flame_points_inner = [
        (flame_x, flame_y - int(flame_size * 0.32)),
        (flame_x - int(flame_size * 0.18), flame_y - int(flame_size * 0.08)),
        (flame_x - int(flame_size * 0.12), flame_y + int(flame_size * 0.15)),
        (flame_x, flame_y + int(flame_size * 0.25)),
        (flame_x + int(flame_size * 0.12), flame_y + int(flame_size * 0.15)),
        (flame_x + int(flame_size * 0.18), flame_y - int(flame_size * 0.08)),
    ]
    draw.polygon(flame_points_inner, fill=red)
    
    # Thêm highlight (sáng) để tạo độ sâu
    highlight_size = int(size * 0.18)
    draw.ellipse(
        [(center - highlight_size // 2, center - highlight_size // 2 - int(size * 0.12)),
         (center + highlight_size // 2, center + highlight_size // 2 - int(size * 0.12))],
        fill=(255, 255, 255, 120)  # Trắng trong suốt
    )
    
    # Thêm sparkles nhỏ xung quanh
    sparkle_size = int(size * 0.03)
    sparkle_positions = [
        (center - int(radius * 0.7), center - int(radius * 0.7)),
        (center + int(radius * 0.7), center - int(radius * 0.6)),
        (center - int(radius * 0.6), center + int(radius * 0.7)),
    ]
    for pos in sparkle_positions:
        draw.ellipse(
            [(pos[0] - sparkle_size, pos[1] - sparkle_size),
             (pos[0] + sparkle_size, pos[1] + sparkle_size)],
            fill=(255, 255, 255, 180)
        )
    
    return img

def main():
    """Tạo logo và lưu vào assets/images/logo.png"""
    
    # Đường dẫn
    assets_dir = 'app/assets/images'
    logo_path = os.path.join(assets_dir, 'logo.png')
    
    # Tạo thư mục nếu chưa có
    os.makedirs(assets_dir, exist_ok=True)
    
    print("🔥 Đang tạo logo cho Hệ Thống Báo Cháy...")
    print(f"📁 Lưu vào: {logo_path}")
    
    # Tạo logo kích thước 512x512 (có thể scale sau)
    logo = create_fire_logo(512)
    
    # Lưu file
    logo.save(logo_path, 'PNG', optimize=True)
    
    print("✅ Hoàn thành! Logo đã được tạo:")
    print(f"   📍 {logo_path}")
    print(f"   📏 Kích thước: 512x512 pixels")
    print("\n💡 Logo sẽ hiển thị trong app khi bạn rebuild")

if __name__ == '__main__':
    try:
        main()
    except ImportError:
        print("❌ Lỗi: Cần cài đặt Pillow (PIL)")
        print("   Chạy: pip install Pillow")
    except Exception as e:
        print(f"❌ Lỗi: {e}")
        import traceback
        traceback.print_exc()

