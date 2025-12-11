#!/usr/bin/env python3
"""
ESP32-CAM Fire Detection Test Script
Test ESP32-CAM integration with YOLO fire detection model
"""

import requests
import cv2
import numpy as np
import time
import os
from pathlib import Path
from ultralytics import YOLO
import matplotlib.pyplot as plt
from datetime import datetime

class ESP32CameraTest:
    def __init__(self, esp32_ip="192.168.1.30", model_path="training_results_20251125_021040/advanced_fire_smoke_yolo11s/weights/best.pt"):
        """
        Initialize ESP32-CAM tester
        
        Args:
            esp32_ip (str): IP address of ESP32-CAM
            model_path (str): Path to YOLO model file
        """
        self.esp32_ip = esp32_ip
        self.base_url = f"http://{esp32_ip}"
        self.model_path = model_path
        self.model = None
        self.session = requests.Session()
        
        print(f"🔥 ESP32-CAM Fire Detection Tester")
        print(f"📷 ESP32 IP: {esp32_ip}")
        print(f"🤖 Model: {model_path}")
        print("=" * 60)
    
    def load_model(self):
        """Load YOLO model"""
        try:
            print("📦 Loading YOLO model...")
            self.model = YOLO(self.model_path)
            print(" Model loaded successfully!")
            return True
        except Exception as e:
            print(f"❌ Failed to load model: {e}")
            return False
    
    def test_esp32_connection(self):
        """Test connection to ESP32-CAM"""
        try:
            print(f"🔌 Testing ESP32-CAM connection to {self.base_url}...")
            response = self.session.get(self.base_url, timeout=5)
            
            if response.status_code == 200:
                print("✅ ESP32-CAM connection successful!")
                return True
            else:
                print(f"❌ ESP32-CAM returned status: {response.status_code}")
                return False
        except Exception as e:
            print(f"❌ Cannot connect to ESP32-CAM: {e}")
            print("💡 Make sure ESP32-CAM is on same network and powered on")
            return False
    
    def start_stream(self):
        """Start stream on ESP32-CAM"""
        try:
            print("▶️ Starting ESP32-CAM stream...")
            # Try different control endpoints
            endpoints = [
                "/control?var=stream&val=1",
                "/control?var=streamc&val=1", 
                "/stream_start",
                "/start_stream"
            ]
            
            for endpoint in endpoints:
                try:
                    response = self.session.get(f"{self.base_url}{endpoint}", timeout=3)
                    if response.status_code == 200:
                        print(f"✅ Stream started with endpoint: {endpoint}")
                        time.sleep(2)  # Wait for stream to initialize
                        return True
                except:
                    continue
            
            print("⚠️ Could not find stream start endpoint, stream may already be active")
            return True
            
        except Exception as e:
            print(f"❌ Failed to start stream: {e}")
            return False
    
    def capture_image(self):
        """Capture image from ESP32-CAM"""
        try:
            print("📸 Capturing image from ESP32-CAM...")
            
            # Try different capture endpoints
            endpoints = ["/capture", "/cam-hi.jpg", "/cam-lo.jpg", "/capture.jpg"]
            
            for endpoint in endpoints:
                try:
                    response = self.session.get(f"{self.base_url}{endpoint}", timeout=10)
                    if response.status_code == 200 and len(response.content) > 1000:
                        # Convert bytes to opencv image
                        nparr = np.frombuffer(response.content, np.uint8)
                        img = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
                        
                        if img is not None:
                            print(f"✅ Image captured successfully! ({len(response.content)} bytes)")
                            print(f"📐 Image size: {img.shape}")
                            return img, response.content
                        
                except Exception as e:
                    print(f"   Trying {endpoint}... failed: {e}")
                    continue
            
            print("❌ Failed to capture image from any endpoint")
            return None, None
            
        except Exception as e:
            print(f"❌ Error capturing image: {e}")
            return None, None
    
    def detect_fire(self, image):
        """Run fire detection on image"""
        try:
            print("🔥 Running fire detection...")
            
            if self.model is None:
                print("❌ Model not loaded!")
                return None
            
            # Run inference
            results = self.model(image, conf=0.25)
            
            # Extract results
            detection_result = {
                'fire_detected': False,
                'fire_count': 0,
                'smoke_count': 0,
                'confidence': 0.0,
                'detections': []
            }
            
            for result in results:
                boxes = result.boxes
                if boxes is not None:
                    for box in boxes:
                        cls = int(box.cls[0])
                        conf = float(box.conf[0])
                        
                        # Assuming class 0 = fire, class 1 = smoke (adjust based on your model)
                        class_name = "fire" if cls == 0 else "smoke" if cls == 1 else f"class_{cls}"
                        
                        detection_result['detections'].append({
                            'class': class_name,
                            'confidence': conf,
                            'box': box.xyxy[0].tolist()
                        })
                        
                        if class_name == "fire":
                            detection_result['fire_count'] += 1
                            detection_result['fire_detected'] = True
                        elif class_name == "smoke":
                            detection_result['smoke_count'] += 1
                            detection_result['fire_detected'] = True
                        
                        detection_result['confidence'] = max(detection_result['confidence'], conf)
            
            print(f"🔍 Detection Results:")
            print(f"   Fire detected: {detection_result['fire_detected']}")
            print(f"   Fire count: {detection_result['fire_count']}")
            print(f"   Smoke count: {detection_result['smoke_count']}")
            print(f"   Max confidence: {detection_result['confidence']:.2f}")
            
            return detection_result, results
            
        except Exception as e:
            print(f"❌ Error in fire detection: {e}")
            return None, None
    
    def save_results(self, image, results, detection_result):
        """Save detection results with annotations"""
        try:
            timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
            
            # Create results directory
            results_dir = Path("esp32_results")
            results_dir.mkdir(exist_ok=True)
            
            # Save original image
            original_path = results_dir / f"esp32_original_{timestamp}.jpg"
            cv2.imwrite(str(original_path), image)
            
            # Save annotated image
            if results is not None and len(results) > 0:
                annotated_img = results[0].plot()
                annotated_path = results_dir / f"esp32_detected_{timestamp}.jpg"
                cv2.imwrite(str(annotated_path), annotated_img)
                print(f"💾 Saved annotated image: {annotated_path}")
            
            print(f"💾 Saved original image: {original_path}")
            
            return str(original_path)
            
        except Exception as e:
            print(f"❌ Error saving results: {e}")
            return None
    
    def run_single_test(self):
        """Run single image capture and detection test"""
        print("\n🚀 Running Single Test...")
        print("-" * 40)
        
        # 1. Test connection
        if not self.test_esp32_connection():
            return False
        
        # 2. Load model
        if not self.load_model():
            return False
        
        # 3. Start stream
        self.start_stream()
        
        # 4. Capture image
        image, image_bytes = self.capture_image()
        if image is None:
            return False
        
        # 5. Run detection
        detection_result, results = self.detect_fire(image)
        if detection_result is None:
            return False
        
        # 6. Save results
        saved_path = self.save_results(image, results, detection_result)
        
        # 7. Display summary
        print(f"\n📋 Test Summary:")
        print(f"   ✅ ESP32-CAM connection: OK")
        print(f"   ✅ Image capture: OK ({image.shape})")
        print(f"   ✅ Fire detection: OK")
        print(f"   🔥 Fire detected: {'YES' if detection_result['fire_detected'] else 'NO'}")
        print(f"   📊 Confidence: {detection_result['confidence']:.2f}")
        if saved_path:
            print(f"   💾 Results saved: {saved_path}")
        
        return True
    
    def run_continuous_test(self, interval=3, max_tests=10):
        """Run continuous monitoring test"""
        print(f"\n🔄 Running Continuous Test...")
        print(f"   Interval: {interval} seconds")
        print(f"   Max tests: {max_tests}")
        print("-" * 40)
        
        # Setup
        if not self.test_esp32_connection():
            return False
        
        if not self.load_model():
            return False
            
        self.start_stream()
        
        fire_detected_count = 0
        
        for i in range(max_tests):
            print(f"\n📸 Test {i+1}/{max_tests}")
            
            # Capture and analyze
            image, _ = self.capture_image()
            if image is not None:
                detection_result, results = self.detect_fire(image)
                if detection_result and detection_result['fire_detected']:
                    fire_detected_count += 1
                    print("🚨 FIRE ALERT!")
                    self.save_results(image, results, detection_result)
                else:
                    print("✅ No fire detected")
            
            if i < max_tests - 1:  # Don't sleep on last iteration
                time.sleep(interval)
        
        print(f"\n📊 Continuous Test Results:")
        print(f"   Total tests: {max_tests}")
        print(f"   Fire detections: {fire_detected_count}")
        print(f"   Detection rate: {fire_detected_count/max_tests*100:.1f}%")
        
        return True


def main():
    """Main function to run ESP32-CAM tests"""
    print("🔥 ESP32-CAM Fire Detection Test")
    print("Choose test mode:")
    print("1. Single test (capture once)")
    print("2. Continuous monitoring") 
    print("3. Custom ESP32 IP")
    
    choice = input("Enter choice (1-3): ").strip()
    
    esp32_ip = "192.168.1.30"  # Default IP
    
    if choice == "3":
        esp32_ip = input("Enter ESP32-CAM IP address: ").strip()
        if not esp32_ip:
            esp32_ip = "192.168.1.30"
    
    # Initialize tester
    tester = ESP32CameraTest(esp32_ip=esp32_ip)
    
    if choice == "1" or choice == "3":
        tester.run_single_test()
    elif choice == "2":
        interval = input("Enter capture interval in seconds (default: 3): ").strip()
        max_tests = input("Enter max number of tests (default: 10): ").strip()
        
        interval = int(interval) if interval.isdigit() else 3
        max_tests = int(max_tests) if max_tests.isdigit() else 10
        
        tester.run_continuous_test(interval=interval, max_tests=max_tests)
    else:
        print("Invalid choice")


if __name__ == "__main__":
    main()