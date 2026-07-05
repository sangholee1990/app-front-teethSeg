import 'package:flutter/material.dart';
import 'package:teeth_seg/theme/app_colors.dart';
import 'package:teeth_seg/models/history_item.dart';

class HomeScreen extends StatefulWidget {
  final VoidCallback onStartCapture;

  const HomeScreen({super.key, required this.onStartCapture});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int totalScans = 0;
  int totalCavities = 0;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final history = await HistoryManager.getHistory();
    int cavities = 0;
    for (var item in history) {
      cavities += item.cavity;
    }
    setState(() {
      totalScans = history.length;
      totalCavities = cavities;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.slate50,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 90),
        children: [
          _buildHeader(),
          _buildDashboard(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'AI 구강검진',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    '치아 관리, 지금 시작해 보세요.',
                    style: TextStyle(
                      color: AppColors.slate800,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
              // Container(
              //   width: 48,
              //   height: 48,
              //   decoration: const BoxDecoration(
              //     color: AppColors.sky50,
              //     shape: BoxShape.circle,
              //   ),
              //   child: const Icon(
              //     Icons.sentiment_satisfied_alt_rounded,
              //     color: AppColors.sky500,
              //     size: 32,
              //   ),
              // ),
            ],
          ),
          const SizedBox(height: 24),
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.sky500, Color(0xFF2563eb)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: AppColors.sky200.withOpacity(0.5),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Stack(
              children: [
                Positioned(
                  right: -10,
                  bottom: -20,
                  child: Icon(
                    Icons.health_and_safety_rounded,
                    size: 120,
                    color: Colors.white.withOpacity(0.15),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '스마트 AI 분석',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        '사진 한 장으로 빠르게\n충치와 보철물을 확인합니다.',
                        style: TextStyle(
                          color: AppColors.sky100,
                          fontSize: 14,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: widget.onStartCapture,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF2563eb),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                          elevation: 2,
                        ),
                        child: const Text(
                          '검진 시작하기',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboard() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '나의 검진 요약',
            style: TextStyle(
              color: AppColors.slate800,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: const [
                      BoxShadow(color: Color(0x05000000), blurRadius: 10)
                    ],
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.history_rounded, color: AppColors.sky500, size: 32),
                      const SizedBox(height: 8),
                      const Text('총 검진 횟수', style: TextStyle(color: AppColors.slate500, fontSize: 12, fontWeight: FontWeight.w500)),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text('$totalScans', style: const TextStyle(color: AppColors.slate800, fontSize: 24, fontWeight: FontWeight.bold)),
                          const Text('회', style: TextStyle(color: AppColors.slate500, fontSize: 14)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: const [
                      BoxShadow(color: Color(0x05000000), blurRadius: 10)
                    ],
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.warning_rounded, color: AppColors.red400, size: 32),
                      const SizedBox(height: 8),
                      const Text('발견된 주의(충치)', style: TextStyle(color: AppColors.slate500, fontSize: 12, fontWeight: FontWeight.w500)),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text('$totalCavities', style: const TextStyle(color: AppColors.slate800, fontSize: 24, fontWeight: FontWeight.bold)),
                          const Text('건', style: TextStyle(color: AppColors.slate500, fontSize: 14)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.amber50,
              border: Border.all(color: AppColors.amber100),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.tips_and_updates_rounded, color: AppColors.amber500),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text('정기 검진 가이드', style: TextStyle(color: AppColors.amber800, fontSize: 14, fontWeight: FontWeight.bold)),
                      SizedBox(height: 4),
                      Text(
                        '개인정보 입력 없이 기기에 안전하게 저장됩니다. 주기적으로 치아 사진을 촬영하여 상태 변화를 기록해 보세요.',
                        style: TextStyle(color: AppColors.amber700, fontSize: 12, height: 1.5),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
