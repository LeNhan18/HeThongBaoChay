import io
from fastapi import FastAPI, File, UploadFile
from fastapi.responses import StreamingResponse
from ultralytics import YOLO
import cv2
import os
import time
import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns
import tempfile
import shutil
import io
from fastapi import FastAPI, File, UploadFile, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from ultralytics import YOLO
import numpy as np
import logging

# Cấu hình logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = FastAPI(title="Fire Detection API",version="1.0")
# Cấu hình CORS (Quan trọng )
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Cho phép tất cả các nguồn (có thể tùy chỉnh theo nhu cầu)
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

model_path = r'e:\HeThongBaoChay\training_results_20251125_021040\advanced_fire_smoke_yolo11s\weights\best.pt'
model = YOLO(model_path)

try:
    model = YOLO(model_path)
    logger.info("Tải model thành công!")
except Exception as e:
    logger.error(f"Lỗi khi tải model: {e}")
    model = None
@app.get("/")
def root():
    return {"message": "Fire Detection API is running."}

@app.post("/predict/")
def predict_fire(file: UploadFile = File(...)):
    if not file.filename.endswith(('.jpg', '.jpeg', '.png')):
        raise HTTPException(status_code=400, detail="Unsupported file type. Please upload an image file.")
    image_data = file.file.read()
    np_arr = np.frombuffer(image_data, np.uint8)
    img = cv2.imdecode(np_arr, cv2.IMREAD_COLOR)
    results = model(img)
    annotated_img = results[0].plot()
    _, img_encoded = cv2.imencode('.jpg', annotated_img)
    return StreamingResponse(io.BytesIO(img_encoded.tobytes()), media_type="image/jpeg")
@app.post("/analyze_video/")
async def analyze_video(file: UploadFile = File(...)):
    if not file.filename.endswith(('.mp4', '.avi', '.mov')):
        return {"error": "Unsupported file type. Please upload a video file."}
    temp_dir = tempfile.mkdtemp()
    input_video_path = os.path.join(temp_dir, file.filename)
    with open(input_video_path, "wb") as buffer:
        shutil.copyfileobj(file.file, buffer)
    cap = cv2.VideoCapture(input_video_path)
    if not cap.isOpened():
        shutil.rmtree(temp_dir)
        return {"error": "Could not open the video file."}
    frame_width = int(cap.get(cv2.CAP_PROP_FRAME_WIDTH))
    frame_height = int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT))
    fps = int(cap.get(cv2.CAP_PROP_FPS))
    output_video_path = os.path.join(temp_dir, f"result_{file.filename}")
    fourcc = cv2.VideoWriter_fourcc(*'mp4v')
    out = cv2.VideoWriter(output_video_path, fourcc, fps, (frame_width, frame_height))
    frame_count = 0
    start_time = time.time()
    while True:
        ret, frame = cap.read()
        if not ret:
            break
        results = model(frame)
        annotated_frame = results[0].plot()
        out.write(annotated_frame)
        frame_count += 1
    cap.release()
    out.release()
    end_time = time.time()
    processing_time = end_time - start_time
    print(f"Processed {frame_count} frames in {processing_time:.2f} seconds.")
    def iterfile():
        with open(output_video_path, mode="rb") as video_file:
            yield from video_file
        shutil.rmtree(temp_dir)
    return StreamingResponse(iterfile(), media_type="video/mp4")

