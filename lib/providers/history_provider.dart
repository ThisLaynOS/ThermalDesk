import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zebra_label_pro/models/label_job.dart';

final historyProvider =
    StateNotifierProvider<HistoryNotifier, List<LabelJob>>((ref) {
  return HistoryNotifier();
});

class HistoryNotifier extends StateNotifier<List<LabelJob>> {
  HistoryNotifier() : super([]) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList('label_history') ?? [];
    state = raw.map(LabelJob.fromJsonString).toList();
  }

  Future<void> add(LabelJob job) async {
    state = [job, ...state.take(99)];
    await _persist();
  }

  Future<void> remove(String id) async {
    state = state.where((j) => j.id != id).toList();
    await _persist();
  }

  Future<void> clear() async {
    state = [];
    await _persist();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
        'label_history', state.map((j) => j.toJsonString()).toList());
  }
}
