import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_icon_snackbar/flutter_icon_snackbar.dart';
import 'package:teeth_seg/theme/app_colors.dart';
import 'package:teeth_seg/models/history_item.dart';

class HistoryScreen extends StatefulWidget {
  final VoidCallback onStartCapture;
  const HistoryScreen({super.key, required this.onStartCapture});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<HistoryItem> _history = [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final history = await HistoryManager.getHistory();
    setState(() {
      _history = history;
    });
  }

  Future<void> _clearHistory() async {
    await HistoryManager.clearHistory();
    _loadHistory();
    if (mounted) {
      IconSnackBar.show(
        context,
        snackBarType: SnackBarType.success,
        label: '모든 기록이 삭제되었습니다.',
        behavior: SnackBarBehavior.floating,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.slate50,
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(24, 48, 24, 16),
            decoration: const BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(color: Color(0x05000000), blurRadius: 4, offset: Offset(0, 2)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text('검진 이력', style: TextStyle(color: AppColors.slate800, fontSize: 20, fontWeight: FontWeight.bold)),
                SizedBox(height: 4),
                Text('로컬 저장소에 보관된 기록입니다.', style: TextStyle(color: AppColors.slate500, fontSize: 14)),
              ],
            ),
          ),
          Expanded(
            child: _history.isEmpty
                ? _buildEmptyState()
                : _buildList(),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.folder_open_rounded, size: 64, color: AppColors.slate400),
          const SizedBox(height: 16),
          const Text('저장된 검진 이력이 없습니다.', style: TextStyle(color: AppColors.slate500, fontWeight: FontWeight.w500)),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: widget.onStartCapture,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.sky100,
              foregroundColor: AppColors.sky600,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
            ),
            child: const Text('첫 검진 시작하기', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildList() {
    return ListView.builder(
      padding: const EdgeInsets.only(top: 16, left: 24, right: 24, bottom: 90),
      itemCount: _history.length + 1,
      itemBuilder: (context, index) {
        if (index == _history.length) {
          return Center(
            child: TextButton(
              onPressed: _clearHistory,
              child: const Text('모든 기록 삭제하기', style: TextStyle(color: AppColors.slate400, decoration: TextDecoration.underline)),
            ),
          );
        }

        final item = _history[index];
        final date = DateTime.fromMillisecondsSinceEpoch(item.date);
        final dateStr = DateFormat('yyyy.MM.dd HH:mm').format(date);
        
        IconData statusIcon = Icons.check_circle_rounded;
        Color statusColor = AppColors.green500;
        Color statusBg = AppColors.green50;
        
        if (item.cavity > 0) {
          statusIcon = Icons.warning_rounded;
          statusColor = AppColors.red500;
          statusBg = AppColors.red50;
        } else if (item.prosthesis > 0) {
          statusIcon = Icons.info_rounded;
          statusColor = AppColors.amber500;
          statusBg = AppColors.amber50;
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: const [BoxShadow(color: Color(0x05000000), blurRadius: 12)],
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(color: statusBg, shape: BoxShape.circle),
                child: Icon(statusIcon, color: statusColor),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(dateStr, style: const TextStyle(color: AppColors.slate800, fontSize: 14, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        _buildStat('정상', item.normal, AppColors.green600),
                        const SizedBox(width: 8),
                        _buildStat('충치', item.cavity, AppColors.red600),
                        const SizedBox(width: 8),
                        _buildStat('크랙', item.prosthesis, AppColors.amber600),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStat(String label, int value, Color color) {
    return Row(
      children: [
        Text('$label ', style: const TextStyle(color: AppColors.slate500, fontSize: 12, fontWeight: FontWeight.w500)),
        Text('$value', style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
      ],
    );
  }
}
