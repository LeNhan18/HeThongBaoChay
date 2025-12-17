import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

class ModernCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double? height;
  final double? width;
  final List<Color>? gradientColors;
  final bool glowEffect;
  final Color? borderColor;
  final double borderRadius;

  const ModernCard({
    super.key,
    required this.child,
    this.padding,
    this.height,
    this.width,
    this.gradientColors,
    this.glowEffect = false,
    this.borderColor,
    this.borderRadius = 20,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      padding: padding ?? EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors:
              gradientColors ??
              [
                Colors.white.withOpacity(0.25),
                Colors.white.withOpacity(0.1),
                Colors.white.withOpacity(0.05),
              ],
        ),
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: borderColor ?? Colors.white.withOpacity(0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
          if (glowEffect)
            BoxShadow(
              color: (borderColor ?? Colors.cyan).withOpacity(0.3),
              blurRadius: 30,
              offset: Offset(0, 0),
            ),
        ],
      ),
      child: child,
    );
  }
}

class NeonButton extends StatelessWidget {
  final String text;
  final IconData? icon;
  final VoidCallback? onPressed;
  final List<Color> gradientColors;
  final double height;
  final double? width;
  final bool isLoading;

  const NeonButton({
    super.key,
    required this.text,
    this.icon,
    this.onPressed,
    required this.gradientColors,
    this.height = 56,
    this.width,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors:
                  onPressed != null
                      ? [
                        gradientColors[0].withOpacity(0.9),
                        gradientColors[1].withOpacity(0.7),
                        gradientColors[0].withOpacity(0.5),
                      ]
                      : [
                        Colors.grey.withOpacity(0.3),
                        Colors.grey.withOpacity(0.2),
                      ],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow:
                onPressed != null
                    ? [
                      BoxShadow(
                        color: gradientColors[0].withOpacity(0.4),
                        blurRadius: 15,
                        offset: Offset(0, 6),
                      ),
                      BoxShadow(
                        color: gradientColors[1].withOpacity(0.2),
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
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (isLoading)
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    else if (icon != null) ...[
                      Container(
                        padding: EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.2),
                        ),
                        child: Icon(icon, size: 20, color: Colors.white),
                      ),
                      SizedBox(width: 12),
                    ],
                    Text(
                      text,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
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

class StatusIndicator extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool isActive;
  final VoidCallback? onTap;

  const StatusIndicator({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.isActive,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ModernCard(
        gradientColors:
            isActive
                ? [Colors.green.withOpacity(0.2), Colors.teal.withOpacity(0.1)]
                : [Colors.red.withOpacity(0.2), Colors.pink.withOpacity(0.1)],
        borderColor:
            isActive
                ? Colors.green.withOpacity(0.4)
                : Colors.red.withOpacity(0.4),
        glowEffect: isActive,
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors:
                      isActive
                          ? [
                            Colors.green.withOpacity(0.3),
                            Colors.green.withOpacity(0.1),
                          ]
                          : [
                            Colors.red.withOpacity(0.3),
                            Colors.red.withOpacity(0.1),
                          ],
                ),
              ),
              child: Icon(
                icon,
                color: isActive ? Colors.green : Colors.red,
                size: 24,
              ),
            ),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.bold,
                      color: isActive ? Colors.green[700] : Colors.red[700],
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 600.ms).slideX();
  }
}

class FloatingGradientBackground extends StatelessWidget {
  final Widget child;

  const FloatingGradientBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Animated background orbs
        Positioned(
          top: -50,
          left: -50,
          child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      Color(0xFF667eea).withOpacity(0.3),
                      Colors.transparent,
                    ],
                  ),
                ),
              )
              .animate(onPlay: (controller) => controller.repeat(reverse: true))
              .moveX(
                begin: -20,
                end: 20,
                duration: 4000.ms,
                curve: Curves.easeInOut,
              ),
        ),
        Positioned(
          bottom: -100,
          right: -100,
          child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      Color(0xFFf093fb).withOpacity(0.2),
                      Colors.transparent,
                    ],
                  ),
                ),
              )
              .animate(onPlay: (controller) => controller.repeat(reverse: true))
              .moveY(
                begin: -30,
                end: 30,
                duration: 6000.ms,
                curve: Curves.easeInOut,
              ),
        ),
        Positioned(
          top: 200,
          right: -50,
          child: Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      Color(0xFF4facfe).withOpacity(0.25),
                      Colors.transparent,
                    ],
                  ),
                ),
              )
              .animate(onPlay: (controller) => controller.repeat(reverse: true))
              .scale(
                begin: Offset(1, 1),
                end: Offset(1.2, 1.2),
                duration: 3000.ms,
              ),
        ),
        // Main content
        child,
      ],
    );
  }
}

// Particle effect widget
class ParticleField extends StatefulWidget {
  final int particleCount;
  final Color particleColor;

  const ParticleField({
    super.key,
    this.particleCount = 20,
    this.particleColor = Colors.white,
  });

  @override
  State<ParticleField> createState() => _ParticleFieldState();
}

class _ParticleFieldState extends State<ParticleField>
    with TickerProviderStateMixin {
  late List<AnimationController> _controllers;
  late List<Animation<double>> _animations;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(
      widget.particleCount,
      (index) => AnimationController(
        duration: Duration(milliseconds: 2000 + (index * 100)),
        vsync: this,
      ),
    );
    _animations =
        _controllers.map((controller) {
          return Tween<double>(begin: 0, end: 1).animate(
            CurvedAnimation(parent: controller, curve: Curves.easeInOut),
          );
        }).toList();

    for (var controller in _controllers) {
      controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: List.generate(widget.particleCount, (index) {
        return AnimatedBuilder(
          animation: _animations[index],
          builder: (context, child) {
            return Positioned(
              left: (index * 37.0) % MediaQuery.of(context).size.width,
              top:
                  _animations[index].value * MediaQuery.of(context).size.height,
              child: Container(
                width: 2,
                height: 2,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.particleColor.withOpacity(0.6),
                ),
              ),
            );
          },
        );
      }),
    );
  }
}
