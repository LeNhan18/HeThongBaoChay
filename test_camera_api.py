import requests
import time
import os
from pathlib import Path

def test_camera_detection_api():
    """Test the mobile camera detection API endpoints."""
    
    base_url = "http://localhost:8000"
    
    print("🔥 Testing Fire Detection API...")
    print("=" * 50)
    
    # Test health endpoint
    print("1. Testing health endpoint...")
    try:
        response = requests.get(f"{base_url}/health", timeout=5)
        if response.status_code == 200:
            print("   ✅ Health check passed")
        else:
            print(f"   ❌ Health check failed: {response.status_code}")
            return
    except Exception as e:
        print(f"   ❌ Cannot connect to API: {e}")
        print("   💡 Make sure to run: python main.py")
        return
    
    # Test root endpoint
    print("\n2. Testing root endpoint...")
    try:
        response = requests.get(f"{base_url}/", timeout=5)
        if response.status_code == 200:
            print("   ✅ Root endpoint accessible")
            data = response.json()
            print(f"   📝 API Title: {data.get('title', 'N/A')}")
        else:
            print(f"   ⚠️ Root endpoint issue: {response.status_code}")
    except Exception as e:
        print(f"   ❌ Root endpoint error: {e}")
    
    # Find test images
    print("\n3. Looking for test images...")
    test_dirs = [
        "data/test",
        "data/train", 
        "data/valid",
        "eiffel"
    ]
    
    test_image = None
    for test_dir in test_dirs:
        if os.path.exists(test_dir):
            for ext in ['*.jpg', '*.jpeg', '*.png']:
                image_files = list(Path(test_dir).glob(f"**/{ext}"))
                if image_files:
                    test_image = str(image_files[0])
                    break
            if test_image:
                break
    
    if not test_image:
        print("   ⚠️ No test images found. Creating a dummy request...")
        # We'll test with a small dummy file
        import tempfile
        with tempfile.NamedTemporaryFile(suffix='.jpg', delete=False) as f:
            # Create a minimal valid JPEG (just header bytes)
            f.write(b'\xff\xd8\xff\xe0\x00\x10JFIF\x00\x01\x01\x01\x00H\x00H\x00\x00\xff\xdb\x00C\x00')
            test_image = f.name
        print(f"   📁 Using dummy image: {test_image}")
    else:
        print(f"   📁 Found test image: {test_image}")
    
    # Test mobile detection endpoint
    print("\n4. Testing mobile camera detection...")
    try:
        with open(test_image, 'rb') as image_file:
            files = {'file': ('test.jpg', image_file, 'image/jpeg')}
            params = {'confidence': 0.25}
            
            start_time = time.time()
            response = requests.post(
                f"{base_url}/mobile/camera/detect",
                files=files,
                params=params,
                timeout=30
            )
            end_time = time.time()
            
            if response.status_code == 200:
                result = response.json()
                print("   ✅ Detection API working!")
                print(f"   ⏱️ Response time: {end_time - start_time:.2f}s")
                print(f"   🎯 Detections found: {result.get('total_detections', 0)}")
                print(f"   🔥 Fire detected: {result.get('has_fire', False)}")
                print(f"   💨 Smoke detected: {result.get('has_smoke', False)}")
                print(f"   🚨 Alert level: {result.get('alert_level', 'N/A')}")
                print(f"   💬 Message: {result.get('message', 'N/A')}")
                
                # Show detections details
                if result.get('detections'):
                    print("   📋 Detection details:")
                    for i, detection in enumerate(result['detections'][:3]):  # Show max 3
                        class_name = detection.get('class', 'unknown')
                        confidence = detection.get('confidence', 0)
                        print(f"      {i+1}. {class_name} ({confidence:.1%})")
                
            else:
                print(f"   ❌ Detection failed: {response.status_code}")
                print(f"   📝 Error: {response.text[:200]}...")
                
    except Exception as e:
        print(f"   ❌ Detection test error: {e}")
    
    # Test detection with image endpoint
    print("\n5. Testing detection with annotated image...")
    try:
        with open(test_image, 'rb') as image_file:
            files = {'file': ('test.jpg', image_file, 'image/jpeg')}
            params = {'confidence': 0.25}
            
            response = requests.post(
                f"{base_url}/mobile/camera/detect_with_image",
                files=files,
                params=params,
                timeout=30
            )
            
            if response.status_code == 200:
                print("   ✅ Annotated image API working!")
                print(f"   📦 Image size: {len(response.content)} bytes")
                
                # Check headers for detection info
                headers = response.headers
                fire_count = headers.get('X-Fire-Count', '0')
                smoke_count = headers.get('X-Smoke-Count', '0')
                alert_level = headers.get('X-Alert-Level', 'LOW')
                
                print(f"   🔥 Fire count: {fire_count}")
                print(f"   💨 Smoke count: {smoke_count}")
                print(f"   🚨 Alert level: {alert_level}")
                
            else:
                print(f"   ❌ Annotated image failed: {response.status_code}")
                
    except Exception as e:
        print(f"   ❌ Annotated image test error: {e}")
    
    # Performance summary
    print("\n" + "=" * 50)
    print("🎉 API Test Complete!")
    print("\n📱 Mobile App Setup:")
    print("1. Update IP in app/lib/constants.dart")
    print("2. Run: flutter pub get")
    print("3. Run: flutter run")
    print("4. Grant camera permission")
    print("5. Tap 'Phát Hiện Lửa' button")
    print("\n💡 Tips:")
    print("- Use good lighting for better detection")
    print("- Hold camera steady")
    print("- Point at fire/smoke sources for testing")
    
    # Clean up dummy file
    if test_image and 'tmp' in test_image:
        try:
            os.unlink(test_image)
        except:
            pass

if __name__ == "__main__":
    test_camera_detection_api()