# Thư mục Models

Thư mục này dùng để lưu model đã train (tùy chọn).

## Sử dụng

Sau khi train xong, copy file `best.pt` vào đây nếu muốn version control:

```
training_results_YYYYMMDD_HHMMSS/advanced_fire_smoke_yolo11s/weights/best.pt
→ copy to models/best.pt
```

Hoặc cấu hình `MODEL_PATH` trong `main.py` trỏ tới đường dẫn training results.

**Lưu ý:** File `.pt` thường rất lớn (vài chục MB). Nên thêm `models/*.pt` vào `.gitignore` nếu không muốn commit.
