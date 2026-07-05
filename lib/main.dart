import 'package:flutter/material.dart';
import 'package:convex_bottom_bar/convex_bottom_bar.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:ui';
import 'theme/app_colors.dart';
import 'utils/logger.dart';
import 'screens/home_screen.dart';
import 'screens/history_screen.dart';
import 'screens/capture_screen.dart';

Future<void> main() async {
  try {
    await dotenv.load(fileName: "assets/config/local.env");
  } catch (e) {
    logger.e("설정 정보 실패, $e");
  }

  runApp(MaterialApp(
    title: 'AI 구강검진',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      fontFamily: 'PretendardGOV',
    ),
    home: const MainScreen(),
  ));
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  void _navigateToTab(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      HomeScreen(onStartCapture: () => _navigateToTab(1)),
      CaptureScreen(onSave: () => _navigateToTab(2)),
      HistoryScreen(onStartCapture: () => _navigateToTab(1)),
    ];

    return Container(
      color: const Color(0xFFcbd5e1), // slate-300 (외부 배경)
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 480),
          decoration: const BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: Color(0x26000000), // 0.15 opacity black
                blurRadius: 25,
              ),
            ],
          ),
          child: Scaffold(
            backgroundColor: AppColors.slate50,
            extendBody: false, // Prevents SnackBar from overlapping with ConvexAppBar
            body: pages[_selectedIndex],
            bottomNavigationBar: Padding(
              padding: const EdgeInsets.only(top: 40.0), // Adds transparent space for the center button, pushing SnackBar higher
              child: ConvexAppBar(
                style: TabStyle.fixedCircle,
                backgroundColor: Colors.white,
                activeColor: AppColors.primary,
                color: AppColors.slate400,
                elevation: 10,
                height: 65,
                items: const [
                  TabItem(icon: Icons.home_rounded, title: '홈'),
                  TabItem(icon: Icons.camera_alt_rounded, title: '캡처'),
                  TabItem(icon: Icons.history_rounded, title: '이력'),
                ],
                initialActiveIndex: _selectedIndex,
                onTap: (int i) {
                  setState(() {
                    _selectedIndex = i;
                  });
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
