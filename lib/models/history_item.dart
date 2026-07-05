import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class HistoryItem {
  final int date;
  final int total;
  final int normal;
  final int cavity;
  final int prosthesis;

  HistoryItem({
    required this.date,
    required this.total,
    required this.normal,
    required this.cavity,
    required this.prosthesis,
  });

  Map<String, dynamic> toJson() => {
        'date': date,
        'total': total,
        'normal': normal,
        'cavity': cavity,
        'prosthesis': prosthesis,
      };

  factory HistoryItem.fromJson(Map<String, dynamic> json) => HistoryItem(
        date: json['date'],
        total: json['total'],
        normal: json['normal'],
        cavity: json['cavity'],
        prosthesis: json['prosthesis'],
      );
}

class HistoryManager {
  static const String _key = 'oral_exam_history';

  static Future<List<HistoryItem>> getHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final String? data = prefs.getString(_key);
    if (data == null) return [];
    
    final List<dynamic> jsonList = jsonDecode(data);
    return jsonList.map((json) => HistoryItem.fromJson(json)).toList();
  }

  static Future<void> saveHistory(HistoryItem item) async {
    final prefs = await SharedPreferences.getInstance();
    final List<HistoryItem> currentList = await getHistory();
    currentList.insert(0, item);
    final String encoded = jsonEncode(currentList.map((e) => e.toJson()).toList());
    await prefs.setString(_key, encoded);
  }

  static Future<void> clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
