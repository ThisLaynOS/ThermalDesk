import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, bool>((ref) {
  return ThemeModeNotifier();
});

class ThemeModeNotifier extends StateNotifier<bool> {
  ThemeModeNotifier() : super(false) {
    _load();
  }

  int _revision = 0;

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted && _revision == 0) state = prefs.getBool('theme_dark') ?? false;
  }

  Future<void> toggle() async {
    _revision++;
    state = !state;
    final prefs = await SharedPreferences.getInstance();
    if (mounted) await prefs.setBool('theme_dark', state);
  }
}
