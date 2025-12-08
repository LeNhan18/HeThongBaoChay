import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ModernTheme {
  // Modern gradient colors
  static const List<Color> primaryGradient = [
    Color(0xFF667eea),
    Color(0xFF764ba2),
  ];

  static const List<Color> secondaryGradient = [
    Color(0xFFf093fb),
    Color(0xFFf5576c),
  ];

  static const List<Color> accentGradient = [
    Color(0xFF4facfe),
    Color(0xFF00f2fe),
  ];

  static const List<Color> successGradient = [
    Color(0xFF11998e),
    Color(0xFF38ef7d),
  ];

  static const List<Color> warningGradient = [
    Color(0xFFFFB75E),
    Color(0xFFED8F03),
  ];

  static const List<Color> dangerGradient = [
    Color(0xFFFF416C),
    Color(0xFFFF4B2B),
  ];

  // Background gradients
  static const List<Color> backgroundGradient = [
    Color(0xFF667eea),
    Color(0xFF764ba2),
    Color(0xFFf093fb),
    Color(0xFFf5576c),
    Color(0xFF4facfe),
  ];

  static const List<Color> darkBackgroundGradient = [
    Color(0xFF0F0F23),
    Color(0xFF1a1a2e),
    Color(0xFF16213e),
  ];

  // Text styles
  static TextStyle get headingStyle => GoogleFonts.orbitron(
    fontSize: 28,
    fontWeight: FontWeight.bold,
    letterSpacing: 1.2,
  );

  static TextStyle get titleStyle => GoogleFonts.inter(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.5,
  );

  static TextStyle get bodyStyle =>
      GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w400);

  static TextStyle get captionStyle => GoogleFonts.inter(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: Colors.grey[600],
  );

  // Shadow styles
  static List<BoxShadow> get softShadow => [
    BoxShadow(
      color: Colors.black.withOpacity(0.1),
      blurRadius: 20,
      offset: const Offset(0, 8),
    ),
  ];

  static List<BoxShadow> get glowShadow => [
    BoxShadow(
      color: Colors.cyan.withOpacity(0.3),
      blurRadius: 30,
      offset: const Offset(0, 0),
    ),
  ];

  // Glassmorphism decoration
  static BoxDecoration get glassmorphismDecoration => BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Colors.white.withOpacity(0.25),
        Colors.white.withOpacity(0.1),
        Colors.white.withOpacity(0.05),
      ],
    ),
    borderRadius: BorderRadius.circular(20),
    border: Border.all(color: Colors.white.withOpacity(0.3), width: 1.5),
    boxShadow: softShadow,
  );

  // Button decorations
  static BoxDecoration buttonDecoration(List<Color> colors) => BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        colors[0].withOpacity(0.9),
        colors[1].withOpacity(0.7),
        colors[0].withOpacity(0.5),
      ],
    ),
    borderRadius: BorderRadius.circular(16),
    boxShadow: [
      BoxShadow(
        color: colors[0].withOpacity(0.4),
        blurRadius: 15,
        offset: const Offset(0, 6),
      ),
      BoxShadow(
        color: colors[1].withOpacity(0.2),
        blurRadius: 25,
        offset: const Offset(0, 12),
      ),
    ],
  );

  // Status colors
  static const Color successColor = Color(0xFF11998e);
  static const Color warningColor = Color(0xFFFFB75E);
  static const Color dangerColor = Color(0xFFFF416C);
  static const Color infoColor = Color(0xFF4facfe);
}

// Animation constants
class AnimationConstants {
  static const Duration fastDuration = Duration(milliseconds: 200);
  static const Duration normalDuration = Duration(milliseconds: 300);
  static const Duration slowDuration = Duration(milliseconds: 600);
  static const Duration verySlowDuration = Duration(milliseconds: 1000);
}

// Size constants
class SizeConstants {
  static const double borderRadius = 20.0;
  static const double buttonHeight = 56.0;
  static const double cardPadding = 16.0;
  static const double sectionSpacing = 24.0;
}
