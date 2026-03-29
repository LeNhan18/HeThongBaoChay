"""Video analysis endpoint."""
import os
import shutil
import tempfile
import time
import logging

import cv2
import numpy as np
from fastapi import APIRouter, File, HTTPException, Query, UploadFile
from fastapi.responses import StreamingResponse

import config
from api_state import model
from services.detection import plot_with_vietnamese_labels, read_image_bytes

logger = logging.getLogger(__name__)
router = APIRouter()


def _validate_loaded():
    if model is None:
        raise HTTPException(status_code=500, detail="Model is not loaded")


def _validate_size(size: int):
    if size > config.MAX_VIDEO_SIZE:
        raise HTTPException(status_code=413, detail=f"Video quá lớn (max {config.MAX_VIDEO_SIZE // (1024*1024)}MB)")


@router.post("/analyze_video/")
def analyze_video_file(
    file: UploadFile = File(...),
    confidence: float = Query(config.DEFAULT_CONFIDENCE, ge=0, le=1),
):
    """Phân tích video frame-by-frame."""
    _validate_loaded()
    if not file.filename or not file.filename.lower().endswith((".mp4", ".avi", ".mov", ".mkv")):
        raise HTTPException(status_code=400, detail="Chỉ hỗ trợ MP4, AVI, MOV, MKV")

    temp_dir = tempfile.mkdtemp()
    try:
        content = file.file.read()
        _validate_size(len(content))

        input_path = os.path.join(temp_dir, file.filename)
        with open(input_path, "wb") as f:
            f.write(content)

        cap = cv2.VideoCapture(input_path)
        if not cap.isOpened():
            raise HTTPException(status_code=400, detail="Không mở được video")

        fw = int(cap.get(cv2.CAP_PROP_FRAME_WIDTH))
        fh = int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT))
        fps = int(cap.get(cv2.CAP_PROP_FPS))
        total = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))

        codecs = [("XVID", ".avi"), ("MJPG", ".avi"), ("mp4v", ".mp4")]
        out, output_path = None, None
        for codec, ext in codecs:
            try:
                p = os.path.join(temp_dir, f"result_{file.filename}").replace(".mp4", ext)
                fourcc = cv2.VideoWriter_fourcc(*codec)
                wo = cv2.VideoWriter(p, fourcc, fps, (fw, fh))
                if wo.isOpened():
                    out, output_path = wo, p
                    break
                wo.release()
            except Exception:
                pass

        if out is None or not out.isOpened():
            raise HTTPException(status_code=500, detail="Không tạo được video output")

        frame_count = detection_count = fire_count = smoke_count = 0
        start = time.time()

        while True:
            ret, frame = cap.read()
            if not ret:
                break

            h, w = frame.shape[:2]
            target = 640
            scale = min(target / w, target / h)
            nw, nh = int(w * scale), int(h * scale)
            resized = cv2.resize(frame, (nw, nh))
            padded = np.zeros((target, target, 3), dtype=np.uint8)
            yo, xo = (target - nh) // 2, (target - nw) // 2
            padded[yo : yo + nh, xo : xo + nw] = resized

            results = model(padded, conf=confidence, verbose=False)
            annotated = plot_with_vietnamese_labels(results[0], padded)
            if annotated.shape[:2] != (fh, fw):
                annotated = cv2.resize(annotated, (fw, fh))
            out.write(annotated)

            if results[0].boxes:
                for box in results[0].boxes:
                    detection_count += 1
                    cn = model.names[int(box.cls[0])].lower()
                    if cn == "fire":
                        fire_count += 1
                    elif cn == "smoke":
                        smoke_count += 1

            frame_count += 1
            if frame_count % 30 == 0:
                logger.info(f"Processed {frame_count}/{total} frames")

        cap.release()
        out.release()
        elapsed = time.time() - start

        def iterfile():
            if os.path.exists(output_path):
                with open(output_path, "rb") as vf:
                    yield from vf
            shutil.rmtree(temp_dir, ignore_errors=True)

        return StreamingResponse(
            iterfile(),
            media_type="video/mp4",
            headers={
                "X-Frames-Processed": str(frame_count),
                "X-Detections-Total": str(detection_count),
                "X-Fire-Count": str(fire_count),
                "X-Smoke-Count": str(smoke_count),
                "X-Processing-Time": f"{elapsed:.2f}s",
            },
        )
    except HTTPException:
        raise
    except Exception as e:
        shutil.rmtree(temp_dir, ignore_errors=True)
        logger.error(f"Video analysis error: {e}")
        raise HTTPException(status_code=500, detail=str(e))
