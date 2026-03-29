"""Fire duration tracking và ESP32 location."""
import os
from datetime import datetime
from typing import Any, Dict

import logging
import ipaddress

from fastapi import HTTPException

import config

logger = logging.getLogger(__name__)

# Import state để sử dụng fire_duration_tracker
from api_state import fire_duration_tracker


def validate_ip_address(ip: str) -> None:
    """Validate format IP."""
    try:
        ipaddress.ip_address(ip)
    except ValueError:
        raise HTTPException(status_code=400, detail=f"Invalid IP address format: {ip}")


def track_fire_duration(esp32_ip: str, fire_count: int, smoke_count: int) -> Dict[str, Any]:
    """Track thời gian cháy liên tục. Trả về is_long_fire, duration_seconds, show_location."""
    current_time = datetime.now()
    has_fire = fire_count > 0 or smoke_count > 0

    if esp32_ip not in fire_duration_tracker:
        fire_duration_tracker[esp32_ip] = {
            "start_time": None,
            "last_fire_time": None,
            "duration_seconds": 0.0,
        }

    t = fire_duration_tracker[esp32_ip]

    if has_fire:
        if t["start_time"] is None:
            t["start_time"] = current_time
            t["last_fire_time"] = current_time
            t["duration_seconds"] = 0.0
            logger.info(f" Fire tracking STARTED for ESP32 {esp32_ip}")
        else:
            elapsed = (current_time - t["start_time"]).total_seconds()
            t["duration_seconds"] = elapsed
            t["last_fire_time"] = current_time
            if elapsed >= config.FIRE_DURATION_THRESHOLD:
                logger.warning(f" LONG FIRE: ESP32 {esp32_ip} - {elapsed:.1f}s")
                return {"is_long_fire": True, "duration_seconds": elapsed, "show_location": True}
    else:
        if t["start_time"] is not None:
            logger.info(f" Fire tracking RESET for ESP32 {esp32_ip}")
            t["start_time"] = None
            t["last_fire_time"] = None
            t["duration_seconds"] = 0.0

    return {"is_long_fire": False, "duration_seconds": t["duration_seconds"], "show_location": False}


def get_esp32_location(esp32_ip: str) -> Dict[str, Any]:
    """Lấy GPS của ESP32 từ env hoặc mặc định."""
    key = esp32_ip.replace(".", "_")
    lat = float(os.getenv(f"ESP32_{key}_LATITUDE", os.getenv("ESP32_LATITUDE", "10.84149")))
    lng = float(os.getenv(f"ESP32_{key}_LONGITUDE", os.getenv("ESP32_LONGITUDE", "106.78928")))
    return {
        "latitude": lat,
        "longitude": lng,
        "address": f"ESP32-CAM ({esp32_ip})",
    }
