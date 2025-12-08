import 'package:flutter/material.dart';
import '../widgets/modern_ui_components.dart';
import 'main_home_page.dart';

class Wrapper extends StatelessWidget {
  const Wrapper({super.key});

  @override
  Widget build(BuildContext context) {
    // Directly return MainHomePage with modern background
    return FloatingGradientBackground(
      child: Stack(
        children: [
          const ParticleField(particleCount: 15, particleColor: Colors.white),
          const MainHomePage(),
        ],
      ),
    );
  }
}
