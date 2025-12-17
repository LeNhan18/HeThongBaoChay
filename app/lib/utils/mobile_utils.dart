import 'dart:typed_data';

String createImageUrl(Uint8List bytes) {
  // On mobile platforms, we can't create blob URLs
  // Return empty string to indicate demo mode should be used
  return '';
}

void revokeImageUrl(String url) {
  // No-op on mobile platforms
}
