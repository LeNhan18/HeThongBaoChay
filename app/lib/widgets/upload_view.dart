import 'package:flutter/material.dart';

class UploadView extends StatelessWidget {
  final bool isProcessing;
  final VoidCallback onPickImage;
  final VoidCallback onPickVideo;
  final VoidCallback onPredict;

  const UploadView({
    Key? key,
    required this.isProcessing,
    required this.onPickImage,
    required this.onPickVideo,
    required this.onPredict,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Action buttons with glassmorphism
        Row(
          children: [
            Expanded(
              child: _buildActionButton(
                icon: Icons.image_rounded,
                label: 'Chọn Ảnh',
                gradient: [Colors.blue[400]!, Colors.blue[600]!],
                onPressed: isProcessing ? null : onPickImage,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildActionButton(
                icon: Icons.videocam_rounded,
                label: 'Chọn Video',
                gradient: [Colors.purple[400]!, Colors.purple[600]!],
                onPressed: isProcessing ? null : onPickVideo,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required List<Color> gradient,
    required VoidCallback? onPressed,
  }) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: gradient),
        borderRadius: BorderRadius.circular(14),
        boxShadow:
            onPressed != null
                ? [
                  BoxShadow(
                    color: gradient[0].withOpacity(0.4),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
                : [],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onPressed,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
