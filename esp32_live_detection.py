#!/usr/bin/env python3
"""
ESP32-CAM Live Fire Detection with Real-time Bounding Box
Display ESP32-CAM stream with real-time YOLO fire detection overlay
"""

import cv2
import requests
import numpy as np
import time
from ultralytics import YOLO
from datetime import datetime
import threading
from queue import Queue

class ESP32LiveDetection:
    def __init__(self, esp32_ip="192.168.1.30"):
        """
        Initialize ESP32 Live Detection
        
        Args:
            esp32_ip (str): IP address of ESP32-CAM
        """
        self.esp32_ip = esp32_ip
        self.base_url = f"http://{esp32_ip}"
        self.capture_url = f"{self.base_url}/capture"
        self.stream_url = f"{self.base_url}:81/stream"  # Port 81 for stream
        
        # Model setup
        self.model_path = "training_results_20251125_021040/advanced_fire_smoke_yolo11s/weights/best.pt"
        self.model = None
        
        # Detection settings
        self.confidence_threshold = 0.25
        self.frame_queue = Queue(maxsize=5)
        self.latest_detections = []
        
        # Performance tracking
        self.frame_count = 0
        self.fps = 0
        self.start_time = time.time()
        
        # Vietnamese class labels
        self.vietnamese_labels = {
            "fire": "🔥 LỬA",
            "smoke": "💨 KHÓI"
        }
        
        print(f"🔥 ESP32-CAM Live Fire Detection")
        print(f"📷 ESP32 IP: {esp32_ip}")
        print(f"🎯 Stream URL: {self.stream_url}")
        print(f"📸 Capture URL: {self.capture_url}")
        print(f"🤖 Model: {self.model_path}")
        print("=" * 70)
    
    def load_model(self):
        """Load trained YOLO model"""
        try:
            print("📦 Loading trained fire detection model...")
            self.model = YOLO(self.model_path)
            print("✅ Model loaded successfully!")
            
            # Print model info
            print(f"📊 Model classes: {list(self.model.names.values())}")
            return True
        except Exception as e:
            print(f"❌ Failed to load model: {e}")
            return False
    
    def test_esp32_connection(self):
        """Test ESP32-CAM connection"""
        try:
            print(f"🔌 Testing ESP32-CAM connection...")
            
            # Test capture endpoint
            response = requests.get(self.capture_url, timeout=5)
            if response.status_code == 200:
                print("✅ ESP32-CAM capture endpoint working!")
                return True
            else:
                print(f" ESP32-CAM not responding: {response.status_code}")
                return False
                
        except Exception as e:
            print(f"❌ Connection failed: {e}")
            return False
    
    def capture_frame_from_esp32(self):
        """Capture single frame from ESP32-CAM"""
        try:
            response = requests.get(self.capture_url, timeout=3)
            if response.status_code == 200:
                # Convert bytes to numpy array
                nparr = np.frombuffer(response.content, np.uint8)
                frame = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
                return frame
            return None
        except Exception as e:
            print(f"❌ Frame capture error: {e}")
            return None
    
    def draw_vietnamese_detections(self, frame, results):
        """Draw bounding boxes with Vietnamese labels"""
        annotated_frame = frame.copy()
        detections = []
        
        if results[0].boxes is not None and len(results[0].boxes) > 0:
            for box in results[0].boxes:
                # Get coordinates and info
                x1, y1, x2, y2 = box.xyxy[0].cpu().numpy().astype(int)
                confidence = float(box.conf[0].cpu())
                class_id = int(box.cls[0].cpu())
                class_name = self.model.names[class_id]
                
                # Vietnamese label
                vn_label = self.vietnamese_labels.get(class_name.lower(), class_name.upper())
                
                # Color based on class
                if class_name.lower() == 'fire':
                    color = (0, 0, 255)  # Red for fire
                    text_color = (255, 255, 255)
                else:  # smoke
                    color = (255, 165, 0)  # Orange for smoke
                    text_color = (0, 0, 0)
                
                # Draw bounding box
                thickness = max(2, frame.shape[0] // 300)
                cv2.rectangle(annotated_frame, (x1, y1), (x2, y2), color, thickness)
                
                # Draw corner markers
                corner_size = thickness * 4
                cv2.rectangle(annotated_frame, (x1, y1), (x1 + corner_size, y1 + corner_size), color, -1)
                cv2.rectangle(annotated_frame, (x2 - corner_size, y1), (x2, y1 + corner_size), color, -1)
                cv2.rectangle(annotated_frame, (x1, y2 - corner_size), (x1 + corner_size, y2), color, -1)
                cv2.rectangle(annotated_frame, (x2 - corner_size, y2 - corner_size), (x2, y2), color, -1)
                
                # Label with confidence
                confidence_percent = confidence * 100
                label = f"{vn_label} {confidence_percent:.1f}%"
                
                # Calculate text size and position
                font_scale = max(0.6, min(1.0, frame.shape[0] / 800))
                font_thickness = max(1, thickness // 2)
                (text_width, text_height), baseline = cv2.getTextSize(
                    label, cv2.FONT_HERSHEY_DUPLEX, font_scale, font_thickness
                )
                
                # Position label
                label_y = y1 - 10
                if label_y - text_height < 0:
                    label_y = y1 + text_height + 15
                
                # Draw label background
                label_bg_points = np.array([
                    [x1, label_y - text_height - 8],
                    [x1 + text_width + 12, label_y - text_height - 8],
                    [x1 + text_width + 12, label_y + baseline + 8],
                    [x1, label_y + baseline + 8]
                ], np.int32)
                
                overlay = annotated_frame.copy()
                cv2.fillPoly(overlay, [label_bg_points], color)
                cv2.addWeighted(overlay, 0.8, annotated_frame, 0.2, 0, annotated_frame)
                
                # Draw text
                cv2.putText(
                    annotated_frame, 
                    label, 
                    (x1 + 6, label_y), 
                    cv2.FONT_HERSHEY_DUPLEX, 
                    font_scale, 
                    text_color, 
                    font_thickness,
                    cv2.LINE_AA
                )
                
                # Store detection info
                detections.append({
                    'class': class_name,
                    'confidence': confidence,
                    'bbox': (x1, y1, x2, y2),
                    'label_vn': vn_label
                })
        
        return annotated_frame, detections
    
    def draw_info_overlay(self, frame, detections):
        """Draw information overlay on frame"""
        # Calculate FPS
        current_time = time.time()
        elapsed = current_time - self.start_time
        if elapsed > 0:
            self.fps = self.frame_count / elapsed
        
        # Info text
        info_texts = [
            f"ESP32-CAM: {self.esp32_ip}",
            f"FPS: {self.fps:.1f}",
            f"Frame: {self.frame_count}",
            f"Detections: {len(detections)}",
            f"Confidence: >{self.confidence_threshold}"
        ]
        
        # Detection summary
        fire_count = sum(1 for d in detections if d['class'].lower() == 'fire')
        smoke_count = sum(1 for d in detections if d['class'].lower() == 'smoke')
        
        if fire_count > 0 or smoke_count > 0:
            status = f"🚨 CẢNH BÁO: Lửa:{fire_count} Khói:{smoke_count}"
            status_color = (0, 0, 255)  # Red
        else:
            status = "✅ AN TOÀN - Không phát hiện lửa"
            status_color = (0, 255, 0)  # Green
        
        info_texts.append(status)
        
        # Draw info panel
        panel_height = len(info_texts) * 25 + 20
        panel_width = 350
        
        # Semi-transparent background
        overlay = frame.copy()
        cv2.rectangle(overlay, (10, 10), (panel_width, panel_height), (0, 0, 0), -1)
        cv2.addWeighted(overlay, 0.7, frame, 0.3, 0, frame)
        
        # Draw border
        cv2.rectangle(frame, (10, 10), (panel_width, panel_height), (100, 100, 100), 2)
        
        # Draw info text
        y_offset = 35
        for i, text in enumerate(info_texts):
            if "CẢNH BÁO" in text:
                color = status_color
                font_weight = 2
            elif "AN TOÀN" in text:
                color = status_color
                font_weight = 2
            else:
                color = (255, 255, 255)
                font_weight = 1
            
            cv2.putText(
                frame, text, (20, y_offset), 
                cv2.FONT_HERSHEY_SIMPLEX, 0.6, color, font_weight, cv2.LINE_AA
            )
            y_offset += 25
        
        return frame
    
    def run_live_detection(self):
        """Run live detection with ESP32-CAM"""
        if not self.load_model():
            return False
        
        if not self.test_esp32_connection():
            print("❌ Cannot connect to ESP32-CAM. Please check:")
            print(f"   - ESP32-CAM is powered on")
            print(f"   - IP address {self.esp32_ip} is correct")
            print(f"   - Both devices are on same network")
            return False
        
        print("\n🚀 Starting Live Detection...")
        print("📝 Controls:")
        print("   - Press 'q' to quit")
        print("   - Press '+' to increase confidence")
        print("   - Press '-' to decrease confidence")
        print("   - Press 's' to save current frame")
        print("=" * 50)
        
        # Create window
        cv2.namedWindow('ESP32-CAM Fire Detection', cv2.WINDOW_NORMAL)
        cv2.resizeWindow('ESP32-CAM Fire Detection', 800, 600)
        
        self.start_time = time.time()
        save_count = 0
        
        while True:
            # Capture frame from ESP32
            frame = self.capture_frame_from_esp32()
            
            if frame is None:
                print("❌ Failed to capture frame, retrying...")
                time.sleep(0.1)
                continue
            
            self.frame_count += 1
            
            # Run detection
            try:
                results = self.model(frame, conf=self.confidence_threshold, verbose=False)
                
                # Draw detections
                annotated_frame, detections = self.draw_vietnamese_detections(frame, results)
                
                # Store latest detections
                self.latest_detections = detections
                
                # Draw info overlay
                display_frame = self.draw_info_overlay(annotated_frame, detections)
                
                # Display frame
                cv2.imshow('ESP32-CAM Fire Detection', display_frame)
                
                # Print detections if any
                if detections:
                    timestamp = datetime.now().strftime("%H:%M:%S")
                    for det in detections:
                        print(f"[{timestamp}] 🔥 {det['label_vn']} - {det['confidence']:.2%}")
                
            except Exception as e:
                print(f"❌ Detection error: {e}")
                cv2.imshow('ESP32-CAM Fire Detection', frame)
            
            # Handle key press
            key = cv2.waitKey(1) & 0xFF
            
            if key == ord('q'):
                print("👋 Stopping live detection...")
                break
            elif key == ord('+') or key == ord('='):
                self.confidence_threshold = min(0.9, self.confidence_threshold + 0.05)
                print(f"🎯 Confidence: {self.confidence_threshold:.2f}")
            elif key == ord('-'):
                self.confidence_threshold = max(0.1, self.confidence_threshold - 0.05)
                print(f"🎯 Confidence: {self.confidence_threshold:.2f}")
            elif key == ord('s'):
                save_count += 1
                filename = f"esp32_detection_{datetime.now().strftime('%Y%m%d_%H%M%S')}_{save_count:03d}.jpg"
                cv2.imwrite(filename, display_frame)
                print(f"💾 Saved: {filename}")
            
            # Small delay to prevent overwhelming ESP32
            time.sleep(0.05)  # ~20 FPS max
        
        cv2.destroyAllWindows()
        
        # Print final statistics
        total_time = time.time() - self.start_time
        avg_fps = self.frame_count / total_time if total_time > 0 else 0
        
        print("\n📊 Session Statistics:")
        print(f"   Total frames: {self.frame_count}")
        print(f"   Total time: {total_time:.1f}s")
        print(f"   Average FPS: {avg_fps:.1f}")
        print(f"   Final confidence: {self.confidence_threshold:.2f}")
        print("✅ Live detection completed!")
        
        return True

def main():
    """Main function"""
    print("🔥 ESP32-CAM Live Fire Detection")
    print("=" * 50)
    
    # Get ESP32 IP from user
    esp32_ip = input("Enter ESP32-CAM IP (default: 192.168.1.30): ").strip()
    if not esp32_ip:
        esp32_ip = "192.168.1.30"
    
    # Create and run live detection
    detector = ESP32LiveDetection(esp32_ip)
    detector.run_live_detection()

if __name__ == "__main__":
    main()