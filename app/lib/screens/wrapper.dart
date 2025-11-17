import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'main_home_page.dart';
import 'auth_screen.dart';

class Wrapper extends StatelessWidget {
  const Wrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasData) {
          return const MainHomePage();
        }

        return const AuthScreen();
      },
    );
  }
}
