// lib/services/history_service.dart
import 'package:shared_preferences/shared_preferences.dart';

class HistoryService {
  static const _key = 'search_history';
  static const _maxCount = 8;

  /// 读取历史记录
  Future<List<String>> load() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_key) ?? [];
  }

  /// 添加一条记录（自动去重、置顶、限长）
  Future<List<String>> add(String query) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_key) ?? [];
    list.remove(query); // 去重
    list.insert(0, query); // 置顶
    if (list.length > _maxCount) list.removeLast(); // 限长
    await prefs.setStringList(_key, list);
    return list;
  }

  /// 删除单条记录
  Future<List<String>> remove(String query) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_key) ?? [];
    list.remove(query);
    await prefs.setStringList(_key, list);
    return list;
  }

  /// 清空所有历史
  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
