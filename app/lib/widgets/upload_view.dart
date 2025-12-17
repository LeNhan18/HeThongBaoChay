import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';

class UploadView extends StatefulWidget {
  final VoidCallback? onPickImage;
  final VoidCallback? onPickVideo;
  final VoidCallback? onPredict;
  final bool isProcessing;

  const UploadView({
    Key? key,
    this.onPickImage,
    this.onPickVideo,
    this.onPredict,
    this.isProcessing = false,
  }) : super(key: key);

  @override
  _UploadViewState createState() => _UploadViewState();
}

class _UploadViewState extends State<UploadView> with TickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _showImageSourceDialog() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.black.withOpacity(0.8),
                Colors.grey.shade900.withOpacity(0.9),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
            boxShadow: [
              BoxShadow(
                color: Colors.cyan.withOpacity(0.3),
                blurRadius: 15,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 50,
                height: 5,
                margin: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2.5),
                ),
              ),
              Padding(
                padding: EdgeInsets.all(isTablet ? 32 : 20),
                child: Column(
                  children: [
                    Text(
                      'Chọn nguồn ảnh',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.orbitron(
                        fontSize: isTablet ? 22 : 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        height: 1.2,
                      ),
                    ),
                    SizedBox(height: isTablet ? 25 : 20),
                    Row(
                      children: [
                        Expanded(
                          child: _buildSourceButton(
                            icon: Icons.camera_alt,
                            label: 'Camera',
                            onTap: () {
                              Navigator.pop(context);
                              widget.onPickImage?.call();
                            },
                            isTablet: isTablet,
                          ),
                        ),
                        SizedBox(width: isTablet ? 20 : 15),
                        Expanded(
                          child: _buildSourceButton(
                            icon: Icons.photo_library,
                            label: 'Thư viện',
                            onTap: () {
                              Navigator.pop(context);
                              widget.onPickImage?.call();
                            },
                            isTablet: isTablet,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: isTablet ? 20 : 15),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSourceButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required bool isTablet,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [const Color(0xFF667eea), const Color(0xFF764ba2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF667eea).withOpacity(0.3),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(15),
          child: Container(
            padding: EdgeInsets.symmetric(
              vertical: isTablet ? 20 : 15,
              horizontal: isTablet ? 20 : 15,
            ),
            child: Column(
              children: [
                Icon(icon, color: Colors.white, size: isTablet ? 32 : 24),
                SizedBox(height: isTablet ? 12 : 8),
                Text(
                  label,
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: isTablet ? 16 : 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ).animate().fadeIn(delay: 100.ms).scale(delay: 150.ms);
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final screenWidth = screenSize.width;
    final isTablet = screenWidth > 600;
    final isMobile = screenWidth < 400;

    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF0f0c29),
            const Color(0xFF302b63),
            const Color(0xFF24243e),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 12 : (isTablet ? 32 : 16),
          vertical: isMobile ? 12 : (isTablet ? 20 : 16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Header
            Container(
              margin: EdgeInsets.only(bottom: isTablet ? 40 : 30),
              child: ShaderMask(
                shaderCallback: (Rect bounds) {
                  return LinearGradient(
                    colors: [const Color(0xFF00f2fe), const Color(0xFF4facfe)],
                  ).createShader(bounds);
                },
                child: Text(
                  'AI Fire Detector',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.orbitron(
                    fontSize: isMobile ? 24 : (isTablet ? 32 : 28),
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    height: 1.2,
                  ),
                ),
              ),
            ).animate().fadeIn(delay: 200.ms).slideY(begin: -0.3),

            // Upload Area
            Container(
              width: double.infinity,
              constraints: BoxConstraints(
                maxWidth: isTablet ? 600 : double.infinity,
                minHeight: isTablet ? 350 : 280,
              ),
              margin: EdgeInsets.only(bottom: isTablet ? 30 : 20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.white.withOpacity(0.1),
                    Colors.white.withOpacity(0.05),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.white.withOpacity(0.2),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF4facfe).withOpacity(0.2),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: _buildUploadPrompt(isTablet, isMobile),
            ).animate().fadeIn(delay: 400.ms).scale(delay: 500.ms),

            // Action Buttons
            _buildActionButtons(isTablet, isMobile),
          ],
        ),
      ),
    );
  }

  Widget _buildUploadPrompt(bool isTablet, bool isMobile) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _showImageSourceDialog,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: isTablet ? 40 : 30,
            vertical: isTablet ? 50 : 40,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  return Transform.scale(
                    scale: 1.0 + (_pulseController.value * 0.1),
                    child: Container(
                      padding: EdgeInsets.all(isTablet ? 24 : 20),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFF667eea),
                            const Color(0xFF764ba2),
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF667eea).withOpacity(0.4),
                            blurRadius: 15,
                            spreadRadius: 3,
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.cloud_upload,
                        size: isTablet ? 64 : 48,
                        color: Colors.white,
                      ),
                    ),
                  );
                },
              ),
              SizedBox(height: isTablet ? 30 : 20),
              Text(
                'Chọn ảnh để phân tích',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: isTablet ? 20 : 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                  height: 1.3,
                ),
              ),
              SizedBox(height: isTablet ? 20 : 15),
              Text(
                'Chạm để chọn từ camera\nhoặc thư viện ảnh',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: isTablet ? 16 : 14,
                  color: Colors.grey.shade300,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButtons(bool isTablet, bool isMobile) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          constraints: BoxConstraints(
            maxWidth: isTablet ? 400 : double.infinity,
          ),
          child: ElevatedButton(
            onPressed: widget.isProcessing ? null : widget.onPredict,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              padding: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
            ),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [const Color(0xFF00f2fe), const Color(0xFF4facfe)],
                ),
                borderRadius: BorderRadius.circular(15),
              ),
              padding: EdgeInsets.symmetric(
                vertical: isTablet ? 18 : 15,
                horizontal: isTablet ? 32 : 24,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (widget.isProcessing) ...[
                    SizedBox(
                      width: isTablet ? 24 : 20,
                      height: isTablet ? 24 : 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                    SizedBox(width: isTablet ? 12 : 10),
                  ] else ...[
                    Icon(
                      Icons.analytics,
                      color: Colors.white,
                      size: isTablet ? 24 : 20,
                    ),
                    SizedBox(width: isTablet ? 12 : 10),
                  ],
                  Text(
                    widget.isProcessing ? 'Đang phân tích...' : 'Phân tích ảnh',
                    style: GoogleFonts.inter(
                      fontSize: isTablet ? 18 : 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ).animate().fadeIn(delay: 600.ms).slideY(begin: 0.3),
        SizedBox(height: isTablet ? 24 : 18),
        Container(
          width: double.infinity,
          constraints: BoxConstraints(
            maxWidth: isTablet ? 400 : double.infinity,
          ),
          child: OutlinedButton(
            onPressed: _showImageSourceDialog,
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: const Color(0xFF667eea), width: 2),
              padding: EdgeInsets.symmetric(
                vertical: isTablet ? 18 : 15,
                horizontal: isTablet ? 32 : 24,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.add_photo_alternate,
                  color: const Color(0xFF667eea),
                  size: isTablet ? 24 : 20,
                ),
                SizedBox(width: isTablet ? 12 : 10),
                Text(
                  'Chọn ảnh',
                  style: GoogleFonts.inter(
                    fontSize: isTablet ? 18 : 16,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF667eea),
                  ),
                ),
              ],
            ),
          ),
        ).animate().fadeIn(delay: 800.ms).slideY(begin: 0.3),
        SizedBox(height: isTablet ? 15 : 12),
        Container(
          width: double.infinity,
          constraints: BoxConstraints(
            maxWidth: isTablet ? 400 : double.infinity,
          ),
          child: OutlinedButton(
            onPressed: widget.onPickVideo,
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: const Color(0xFF764ba2), width: 2),
              padding: EdgeInsets.symmetric(
                vertical: isTablet ? 18 : 15,
                horizontal: isTablet ? 32 : 24,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.video_library,
                  color: const Color(0xFF764ba2),
                  size: isTablet ? 24 : 20,
                ),
                SizedBox(width: isTablet ? 12 : 10),
                Text(
                  'Chọn video',
                  style: GoogleFonts.inter(
                    fontSize: isTablet ? 18 : 16,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF764ba2),
                  ),
                ),
              ],
            ),
          ),
        ).animate().fadeIn(delay: 1000.ms).slideY(begin: 0.3),
      ],
    );
  }
}
