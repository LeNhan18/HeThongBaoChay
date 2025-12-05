#!/usr/bin/env python3
"""
Test script specifically for checking bounding box drawing in video analysis
"""

import requests
import cv2
import os
import tempfile
from pathlib import Path

def test_video_with_bounding_box():
    """Test video analysis and check if bounding boxes are drawn properly."""
    
    print("🎥 Testing Video Analysis with Bounding Box Detection")
    print("=" * 60)
    
    # API endpoint
    base_url = "http://localhost:8000"
    
    # Check if API is running
    try:
        response = requests.get(f"{base_url}/health", timeout=5)
        if response.status_code != 200:
            print("❌ API is not running. Start with: python main.py")
            return
        print("✅ API is running")
    except:
        print("❌ Cannot connect to API. Make sure to run: python main.py")
        return
    
    # Find a test video file
    video_extensions = ['*.mp4', '*.avi', '*.mov', '*.mkv']
    test_video = None
    
    # Search in common directories
    search_dirs = [
        ".",  # Current directory
        "data",
        "test_videos",
        "../test_videos"
    ]
    
    for search_dir in search_dirs:
        if os.path.exists(search_dir):
            for ext in video_extensions:
                video_files = list(Path(search_dir).glob(ext))
                if video_files:
                    test_video = str(video_files[0])
                    break
            if test_video:
                break
    
    if not test_video:
        print("⚠️ No test video found. Creating a simple test video...")
        test_video = create_test_video()
    
    print(f"📹 Using video file: {test_video}")
    print(f"📊 File size: {os.path.getsize(test_video) / (1024*1024):.2f} MB")
    
    # Analyze original video properties
    cap = cv2.VideoCapture(test_video)
    if cap.isOpened():
        total_frames = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))
        fps = cap.get(cv2.CAP_PROP_FPS)
        width = int(cap.get(cv2.CAP_PROP_FRAME_WIDTH))
        height = int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT))
        duration = total_frames / fps if fps > 0 else 0
        
        print(f"📐 Video properties:")
        print(f"   Resolution: {width}x{height}")
        print(f"   FPS: {fps:.2f}")
        print(f"   Total frames: {total_frames}")
        print(f"   Duration: {duration:.2f} seconds")
        cap.release()
    
    # Send to API for analysis
    print("\n🔍 Sending video for fire/smoke detection...")
    
    try:
        with open(test_video, 'rb') as video_file:
            files = {'file': (os.path.basename(test_video), video_file, 'video/mp4')}
            params = {'confidence': 0.25}
            
            print("⏳ Processing video... (this may take a while)")
            response = requests.post(
                f"{base_url}/analyze_video/",
                files=files,
                params=params,
                timeout=300,  # 5 minutes timeout
                stream=True
            )
            
            if response.status_code == 200:
                # Save the result video
                timestamp = int(time.time())
                output_file = f"analyzed_video_{timestamp}.mp4"
                
                print(f"💾 Saving analyzed video to: {output_file}")
                
                with open(output_file, 'wb') as f:
                    for chunk in response.iter_content(chunk_size=8192):
                        f.write(chunk)
                
                # Check headers for detection statistics
                headers = response.headers
                frames_processed = headers.get('X-Frames-Processed', '0')
                total_detections = headers.get('X-Detections-Total', '0')
                fire_count = headers.get('X-Fire-Count', '0')
                smoke_count = headers.get('X-Smoke-Count', '0')
                processing_time = headers.get('X-Processing-Time', '0s')
                
                print(f"\n📈 Analysis Results:")
                print(f"   Frames processed: {frames_processed}")
                print(f"   Total detections: {total_detections}")
                print(f"   🔥 Fire detections: {fire_count}")
                print(f"   💨 Smoke detections: {smoke_count}")
                print(f"   ⏱️ Processing time: {processing_time}")
                
                # Analyze the output video to check if bounding boxes are present
                print(f"\n🔍 Checking output video for bounding boxes...")
                check_bounding_boxes_in_video(output_file)
                
                print(f"\n✅ Video analysis complete!")
                print(f"📹 Original video: {test_video}")
                print(f"🎯 Analyzed video: {output_file}")
                print(f"\n💡 To view the result:")
                print(f"   - Open {output_file} in a video player")
                print(f"   - Look for red/blue bounding boxes around detected objects")
                print(f"   - Vietnamese labels should appear on detected fire/smoke")
                
            else:
                print(f"❌ API Error: {response.status_code}")
                print(f"📝 Response: {response.text[:500]}...")
                
    except requests.exceptions.Timeout:
        print("⏰ Request timed out. Video might be too large or processing is slow.")
    except Exception as e:
        print(f"❌ Error during analysis: {e}")

def create_test_video():
    """Create a simple test video with colored rectangles (simulating fire/smoke)."""
    import time
    
    output_path = f"test_video_{int(time.time())}.mp4"
    
    # Video properties
    width, height = 640, 480
    fps = 10
    duration = 5  # seconds
    total_frames = fps * duration
    
    # Create video writer
    fourcc = cv2.VideoWriter_fourcc(*'mp4v')
    out = cv2.VideoWriter(output_path, fourcc, fps, (width, height))
    
    print(f"🎬 Creating test video: {output_path}")
    
    for frame_num in range(total_frames):
        # Create a black frame
        frame = np.zeros((height, width, 3), dtype=np.uint8)
        
        # Add some moving colored rectangles that might trigger detection
        # Red rectangle (might be detected as fire)
        x1 = 50 + (frame_num * 5) % 200
        y1 = 100
        cv2.rectangle(frame, (x1, y1), (x1 + 80, y1 + 60), (0, 0, 255), -1)
        
        # Gray rectangle (might be detected as smoke)  
        x2 = 300 + (frame_num * 3) % 150
        y2 = 200
        cv2.rectangle(frame, (x2, y2), (x2 + 100, y2 + 80), (128, 128, 128), -1)
        
        # Add frame number
        cv2.putText(frame, f"Frame {frame_num + 1}/{total_frames}", 
                   (10, 30), cv2.FONT_HERSHEY_SIMPLEX, 0.7, (255, 255, 255), 2)
        
        out.write(frame)
    
    out.release()
    print(f"✅ Test video created: {output_path}")
    return output_path

def check_bounding_boxes_in_video(video_path):
    """Check if the analyzed video contains visible bounding boxes."""
    
    cap = cv2.VideoCapture(video_path)
    if not cap.isOpened():
        print("❌ Cannot open analyzed video")
        return
    
    total_frames = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))
    frames_to_check = min(10, total_frames)  # Check first 10 frames
    
    print(f"🔍 Checking {frames_to_check} frames for bounding boxes...")
    
    frames_with_annotations = 0
    
    for i in range(frames_to_check):
        ret, frame = cap.read()
        if not ret:
            break
        
        # Simple heuristic: check if frame has colored rectangles (potential bounding boxes)
        # Look for red pixels (fire detection boxes)
        red_pixels = np.sum((frame[:, :, 2] > 200) & (frame[:, :, 0] < 100) & (frame[:, :, 1] < 100))
        
        # Look for blue pixels (smoke detection boxes)
        blue_pixels = np.sum((frame[:, :, 0] > 200) & (frame[:, :, 1] < 100) & (frame[:, :, 2] < 100))
        
        if red_pixels > 100 or blue_pixels > 100:  # Threshold for detecting annotation colors
            frames_with_annotations += 1
            print(f"   Frame {i+1}: Found potential bounding box annotations")
    
    cap.release()
    
    if frames_with_annotations > 0:
        print(f"✅ Found bounding box annotations in {frames_with_annotations}/{frames_to_check} frames")
        print("🎯 Bounding boxes are being drawn correctly!")
    else:
        print("⚠️ No obvious bounding box annotations detected")
        print("   This could mean:")
        print("   - No fire/smoke was detected in the video")
        print("   - Detection confidence threshold is too high")
        print("   - There might be an issue with the annotation function")

if __name__ == "__main__":
    import time
    import numpy as np
    
    test_video_with_bounding_box()