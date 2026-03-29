"""Global state cho API."""
from collections import deque
from typing import Any, Dict, List, Optional

# Model (load trong main)
model = None

# Camera streaming
camera_active: bool = False
camera_stats: Dict[str, Any] = {
    "frames": 0,
    "detections": 0,
    "start_time": None,
}

# Detection history
detection_results: deque = deque(maxlen=100)

# Mobile alerts
fcm_tokens: List[str] = []
pending_alerts: List[Dict[str, Any]] = []
alert_counter: int = 0

# Fire duration tracking
fire_duration_tracker: Dict[str, Dict[str, Any]] = {}
