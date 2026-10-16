import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:thermal_desk/core/constants.dart';
import 'package:thermal_desk/models/label_job.dart';

final historyProvider = StateNotifierProvider<HistoryNotifier, List<LabelJob>>(
  (ref) => HistoryNotifier(),
);

class HistoryNotifier extends StateNotifier<List<LabelJob>> {
  late final Future<void> _ready;
  Future<void> _pending = Future.value();
  HistoryNotifier() : super([]) {
    _ready = _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final jobs = <LabelJob>[];
    for (final raw in prefs.getStringList('label_history') ?? <String>[]) {
      try {
        jobs.add(LabelJob.fromJsonString(raw));
      } catch (_) {
        /* Ignora só o registo inválido. */
      }
    }
    if (mounted) state = jobs.take(AppConstants.maxHistoryItems).toList();
  }

  Future<void> add(LabelJob job) async {
    await _ready;
    if (!mounted) return;
    state = [job, ...state].take(AppConstants.maxHistoryItems).toList();
    await _persist();
  }

  Future<void> remove(String id) async {
    await _ready;
    if (!mounted) return;
    state = state.where((j) => j.id != id).toList();
    await _persist();
  }

  Future<void> clear() async {
    await _ready;
    if (!mounted) return;
    state = [];
    await _persist();
  }

  Future<void> _persist() {
    final snapshot = state.map((job) => job.toJsonString()).toList();
    _pending = _pending.catchError((_) {}).then((_) async {
      final prefs = await SharedPreferences.getInstance();
      if (!await prefs.setStringList('label_history', snapshot)) {
        throw StateError('Não foi possível guardar o histórico.');
      }
    });
    return _pending;
  }
}
