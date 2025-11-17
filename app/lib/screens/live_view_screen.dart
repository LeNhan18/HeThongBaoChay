import 'package:flutter/material.dart';
import '../models/camera.dart';

class LiveViewScreen extends StatelessWidget {
  final Camera camera;
  const LiveViewScreen({super.key, required this.camera});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(camera.name)),
      body: Center(
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: Image.network(
            camera.thumbnailUrl,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                color: Colors.grey[300],
                child: const Center(
                  child: Icon(Icons.error, size: 50, color: Colors.grey),
                ),
              );
            },
          ),
        ),
      ),
    );
    // TODO: This Image.network will later be replaced by a real video streaming widget
  }
}
