import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';

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
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isSmallScreen = screenWidth < 400;
    final isTablet = screenWidth > 600;

    return Column(
      children: [
        // Action buttons with responsive layout
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(isTablet ? 24 : 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withOpacity(0.25),
                Colors.white.withOpacity(0.1),
                Colors.white.withOpacity(0.05),
              ],
            ),
            borderRadius: BorderRadius.circular(isTablet ? 28 : 24),
            border: Border.all(
              color: Colors.white.withOpacity(0.3),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child:
              isSmallScreen
                  ? Column(
                    children: [
                      _buildActionButton(
                        context: context,
                        icon: Icons.image_rounded,
                        label: 'Chọn Ảnh',
                        gradient: [Colors.blue[400]!, Colors.blue[600]!],
                        onPressed: isProcessing ? null : onPickImage,
                        isFullWidth: true,
                      ),
                      SizedBox(height: 16),
                      _buildActionButton(
                        context: context,
                        icon: Icons.videocam_rounded,
                        label: 'Chọn Video',
                        gradient: [Colors.purple[400]!, Colors.purple[600]!],
                        onPressed: isProcessing ? null : onPickVideo,
                        isFullWidth: true,
                      ),
                    ],
                  )
                  : Row(
                    children: [
                      Expanded(
                        child: _buildActionButton(
                          context: context,
                          icon: Icons.image_rounded,
                          label: 'Chọn Ảnh',
                          gradient: [Colors.blue[400]!, Colors.blue[600]!],
                          onPressed: isProcessing ? null : onPickImage,
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: _buildActionButton(
                          context: context,
                          icon: Icons.videocam_rounded,
                          label: 'Chọn Video',
                          gradient: [Colors.purple[400]!, Colors.purple[600]!],
                          onPressed: isProcessing ? null : onPickVideo,
                        ),
                      ),
                    ],
                  ),
        ),

        SizedBox(height: isTablet ? 28 : 24),

        // Predict button
        _buildActionButton(
          context: context,
          icon:
              isProcessing ? Icons.hourglass_empty : Icons.psychology_outlined,
          label: isProcessing ? 'Đang xử lý...' : 'Dự đoán AI',
          gradient: [Colors.orange[400]!, Colors.deepOrange[600]!],
          onPressed: isProcessing ? null : onPredict,
          isFullWidth: true,
          isMainAction: true,
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required BuildContext context,
    required IconData icon,
    required String label,
    required List<Color> gradient,
    required VoidCallback? onPressed,
    bool isFullWidth = false,
    bool isMainAction = false,
  }) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 400;
    final isTablet = screenWidth > 600;

    return Container(
          width: isFullWidth ? double.infinity : null,
          height:
              isMainAction
                  ? (isTablet ? 60 : 56)
                  : (isTablet ? 140 : (isSmallScreen ? 120 : 130)),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors:
                  onPressed != null
                      ? [
                        gradient[0].withOpacity(0.9),
                        gradient[1].withOpacity(0.7),
                        gradient[0].withOpacity(0.5),
                      ]
                      : [
                        Colors.grey.withOpacity(0.4),
                        Colors.grey.withOpacity(0.2),
                        Colors.grey.withOpacity(0.1),
                      ],
            ),
            borderRadius: BorderRadius.circular(isTablet ? 22 : 20),
            boxShadow:
                onPressed != null
                    ? [
                      BoxShadow(
                        color: gradient[0].withOpacity(0.4),
                        blurRadius: 15,
                        offset: Offset(0, 6),
                      ),
                      BoxShadow(
                        color: gradient[1].withOpacity(0.2),
                        blurRadius: 25,
                        offset: Offset(0, 12),
                      ),
                    ]
                    : [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.2),
                        blurRadius: 8,
                        offset: Offset(0, 3),
                      ),
                    ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onPressed,
              borderRadius: BorderRadius.circular(isTablet ? 22 : 20),
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isTablet ? 20 : 16,
                  vertical: isMainAction ? 0 : (isTablet ? 16 : 12),
                ),
                child:
                    isMainAction
                        ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (isProcessing)
                              SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            else
                              Container(
                                padding: EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white.withOpacity(0.2),
                                ),
                                child: Icon(
                                  icon,
                                  size: isTablet ? 24 : 20,
                                  color: Colors.white,
                                ),
                              ),
                            SizedBox(width: 12),
                            Text(
                              label,
                              style: GoogleFonts.inter(
                                fontSize: isTablet ? 17 : 15,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        )
                        : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: EdgeInsets.all(isTablet ? 12 : 10),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withOpacity(0.2),
                              ),
                              child: Icon(
                                icon,
                                size: isTablet ? 40 : (isSmallScreen ? 32 : 36),
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(height: isTablet ? 16 : 12),
                            Text(
                              label,
                              style: GoogleFonts.inter(
                                fontSize:
                                    isTablet ? 16 : (isSmallScreen ? 14 : 15),
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                                letterSpacing: 0.5,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
              ),
            ),
          ),
        )
        .animate()
        .fadeIn(duration: 300.ms)
        .scale(begin: Offset(0.95, 0.95), end: Offset(1, 1), duration: 200.ms);
  }
}
