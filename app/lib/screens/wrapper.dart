import 'package:flutter/material.dart';
import 'main_home_page.dart';

class Wrapper extends StatelessWidget {
  const Wrapper({super.key});

  @override
  Widget build(BuildContext context) {
    // Directly return MainHomePage since we removed Firebase Auth
    return const MainHomePage();
  }
}
