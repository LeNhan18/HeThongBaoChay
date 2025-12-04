import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'dashboard_screen.dart';
import 'alerts_screen.dart';
import 'predict_screen.dart';
import 'camera_detection_screen.dart';

class MainHomePage extends StatefulWidget {
  const MainHomePage({super.key});

  @override
  State<MainHomePage> createState() => _MainHomePageState();
}

class _MainHomePageState extends State<MainHomePage> {
  int _selectedIndex = 0;
  final AuthService _authService = AuthService();
  bool _isLoggingOut = false;

  final List<Widget> _screens = [
    const DashboardScreen(),
    const PredictScreen(),
    const AlertsScreen(),
  ];

  final List<String> _titles = [
    'Giám Sát Camera',
    'Dự Đoán',
    'Lịch Sử Cảnh Báo',
  ];

  Future<void> _showLogoutDialog() async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Xác nhận đăng xuất'),
          content: const Text('Bạn có chắc chắn muốn đăng xuất không?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Hủy'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Đăng xuất'),
              onPressed: () async {
                Navigator.of(context).pop();
                setState(() {
                  _isLoggingOut = true;
                });
                try {
                  await _authService.signOut();
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Lỗi đăng xuất: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                } finally {
                  if (mounted) {
                    setState(() {
                      _isLoggingOut = false;
                    });
                  }
                }
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _titles[_selectedIndex],
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        elevation: 2,
        actions: [
          _isLoggingOut
              ? const Padding(
                padding: EdgeInsets.all(16.0),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
              : IconButton(
                icon: const Icon(Icons.logout),
                onPressed: _showLogoutDialog,
                tooltip: 'Đăng xuất',
              ),
        ],
      ),
      body: _screens[_selectedIndex],
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => const CameraDetectionScreen(),
            ),
          );
        },
        icon: const Icon(Icons.camera_alt),
        label: const Text('Phát Hiện Lửa'),
        backgroundColor: Colors.deepOrange,
        foregroundColor: Colors.white,
        elevation: 4,
        tooltip: 'Mở camera phát hiện lửa real-time',
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          if (!_isLoggingOut) {
            setState(() {
              _selectedIndex = index;
            });
          }
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.videocam),
            activeIcon: Icon(Icons.videocam),
            label: 'Giám Sát',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.upload_file),
            activeIcon: Icon(Icons.upload_file),
            label: 'Dự Đoán',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.notification_important),
            activeIcon: Icon(Icons.notification_important),
            label: 'Cảnh Báo',
          ),
        ],
        selectedItemColor: Colors.deepOrange,
        unselectedItemColor: Colors.grey[600],
        backgroundColor: Colors.white,
        elevation: 8,
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w400),
      ),
    );
  }
}
