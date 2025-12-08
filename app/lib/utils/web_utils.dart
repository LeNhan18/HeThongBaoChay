// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:typed_data';

String createImageUrl(Uint8List bytes) {
  final blob = html.Blob([bytes]);
  return html.Url.createObjectUrl(blob);
}

void revokeImageUrl(String url) {
  html.Url.revokeObjectUrl(url);
}
