import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class UserLibraryService {
  static const String _favoritesKey = 'shaghaf_favorites_v1';
  static const String _historyKey = 'shaghaf_watch_history_v1';
  static const String _customItemsKey = 'shaghaf_custom_items_v1';

  Future<Set<String>> loadFavoriteIds() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_favoritesKey) ?? const [];
    return list.toSet();
  }

  Future<Set<String>> toggleFavorite(String videoId) async {
    final prefs = await SharedPreferences.getInstance();
    final current = (prefs.getStringList(_favoritesKey) ?? const []).toSet();
    if (current.contains(videoId)) {
      current.remove(videoId);
    } else {
      current.add(videoId);
    }
    await prefs.setStringList(_favoritesKey, current.toList());
    return current;
  }

  Future<List<String>> loadHistoryIds() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_historyKey) ?? const [];
  }

  Future<List<String>> recordWatch(String videoId) async {
    final prefs = await SharedPreferences.getInstance();
    final current = List<String>.from(prefs.getStringList(_historyKey) ?? const []);
    current.remove(videoId);
    current.insert(0, videoId);
    if (current.length > 50) {
      current.removeRange(50, current.length);
    }
    await prefs.setStringList(_historyKey, current);
    return current;
  }

  Future<List>> loadCustomItems() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_customItemsKey);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded.whereType>().toList();
    } catch (_) {
      return const [];
    }
  }

  Future<List>> addCustomItem(
    Map<String, dynamic> item,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final current = List>.from(await loadCustomItems());
    current.insert(0, item);
    await prefs.setString(_customItemsKey, jsonEncode(current));
    return current;
  }
}
