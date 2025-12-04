#!/usr/bin/env python3
"""
Test script for video analysis API
"""
import requests
import os

def test_video_analysis():
    # Video file path
    video_file = "Ghi màn hình 1 (online-video-cutter.com) (4).mp4"
    
    if not os.path.exists(video_file):
        print(f"Video file {video_file} not found!")
        return
    
    print(f"Testing video analysis with file: {video_file}")
    print(f"File size: {os.path.getsize(video_file) / (1024*1024):.2f} MB")
    
    # API endpoint
    url = "http://localhost:8000/analyze_video/"
    
    try:
        # Open file and send request
        with open(video_file, 'rb') as f:
            files = {'file': (video_file, f, 'video/mp4')}
            params = {'confidence': 0.25}
            
            print("Sending request to API...")
            response = requests.post(url, files=files, params=params, stream=True)
            
            if response.status_code == 200:
                # Save the result video
                output_file = "analyzed_o.mp4"
                with open(output_file, 'wb') as out_file:
                    for chunk in response.iter_content(chunk_size=8192):
                        out_file.write(chunk)
                
                print(f" Success! Analyzed video saved as: {output_file}")
                print(f"Output file size: {os.path.getsize(output_file) / (1024*1024):.2f} MB")
                
                # Print response headers
                headers = response.headers
                print("\n Processing Statistics:")
                print(f"- Frames processed: {headers.get('X-Frames-Processed', 'N/A')}")
                print(f"- Total detections: {headers.get('X-Detections-Total', 'N/A')}")
                print(f"- Processing time: {headers.get('X-Processing-Time', 'N/A')}")
                print(f"- Processing FPS: {headers.get('X-FPS', 'N/A')}")
                
            else:
                print(f" Error: {response.status_code}")
                print(f"Response: {response.text}")
                
    except requests.exceptions.ConnectionError:
        print(" Cannot connect to API. Make sure backend is running on http://localhost:8000")
    except Exception as e:
        print(f"Error: {e}")

if __name__ == "__main__":
    test_video_analysis()