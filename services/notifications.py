"""FCM và notification utilities."""
import logging
from typing import Dict, Optional

from firebase_admin import messaging

import api_state
from api_state import fcm_tokens

logger = logging.getLogger(__name__)

# FIREBASE_ENABLED set in main
FIREBASE_ENABLED = False


def set_firebase_enabled(enabled: bool):
    """Set Firebase enabled state (called from main)."""
    global FIREBASE_ENABLED
    FIREBASE_ENABLED = enabled


def send_fcm_notification(title: str, body: str, data: Optional[Dict[str, str]] = None) -> bool:
    """Gửi FCM push notification."""
    if not FIREBASE_ENABLED:
        logger.info(f" MOCK FCM: {title} - {body}")
        return True

    if not fcm_tokens:
        logger.warning("No FCM tokens registered")
        return False

    try:
        msg = messaging.MulticastMessage(
            notification=messaging.Notification(title=title, body=body),
            data=data or {},
            tokens=fcm_tokens,
        )
        resp = messaging.send_multicast(msg)
        logger.info(f" FCM sent: {resp.success_count} success, {resp.failure_count} failed")

        if resp.failure_count > 0:
            for idx, r in enumerate(resp.responses):
                if not r.success:
                    tok = fcm_tokens[idx]
                    if tok in fcm_tokens:
                        fcm_tokens.remove(tok)

        return resp.success_count > 0
    except Exception as e:
        logger.error(f"FCM send error: {e}")
        return False
