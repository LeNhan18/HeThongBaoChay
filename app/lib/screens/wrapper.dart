import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'main_home_page.dart';

class Wrapper extends StatelessWidget {
  const Wrapper({super.key});

  @override
  Widget build(BuildContext context) {
    print('📱 Wrapper: Building...');
    
    // TEST: Hiển thị màn hình đơn giản trước để kiểm tra app có chạy không
    return Scaffold(
      backgroundColor: Colors.blue.shade50,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.local_fire_department, size: 80, color: Colors.red),
              SizedBox(height: 20),
              Text(
                'Hệ Thống Báo Cháy',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
              SizedBox(height: 40),
              ElevatedButton(
                onPressed: () {
                  print('📱 Button pressed, navigating to MainHomePage...');
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (context) {
                        try {
                          print('📱 Creating MainHomePage...');
                          return const MainHomePage();
                        } catch (e, stackTrace) {
                          print('❌ Error creating MainHomePage: $e');
                          print('Stack trace: $stackTrace');
                          return Scaffold(
                            body: Center(
                              child: Text('Lỗi: $e'),
                            ),
                          );
                        }
                      },
                    ),
                  );
                },
                child: Text('Vào ứng dụng'),
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
