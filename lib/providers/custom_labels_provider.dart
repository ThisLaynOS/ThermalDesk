import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:thermal_desk/models/custom_label.dart';

final customLabelsProvider =
    StateNotifierProvider<CustomLabelsNotifier, AsyncValue<List<CustomLabel>>>(
      (ref) => CustomLabelsNotifier(),
    );

class CustomLabelsNotifier
    extends StateNotifier<AsyncValue<List<CustomLabel>>> {
  static const storageKey = 'custom_labels_v1';
  late final Future<void> ready;
  Future<void> _pending = Future.value();
  int skippedRecords = 0;
  CustomLabelsNotifier() : super(const AsyncLoading()) {
    ready = _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final labels = <CustomLabel>[];
      for (final raw in prefs.getStringList(storageKey) ?? <String>[]) {
        try {
          final label = CustomLabel.decode(raw);
          if (labels.any((l) => l.id == label.id)) {
            skippedRecords++;
            continue;
          }
          labels.add(label);
        } catch (_) {
          skippedRecords++;
        }
      }
      if (mounted) state = AsyncData(labels);
    } catch (e, stack) {
      if (mounted) state = AsyncError(e, stack);
    }
  }

  Future<void> save(CustomLabel label) => _mutate((labels) {
    // Mesmo contrato para modelos criados no editor e importados.
    final checked = CustomLabel.decode(label.encode());
    if (labels.length >= 100 && !labels.any((l) => l.id == checked.id)) {
      throw const FormatException(
        'Limite de 100 templates. Exporte ou remova um para continuar.',
      );
    }
    return [checked, ...labels.where((l) => l.id != checked.id)];
  });
  Future<void> remove(String id) =>
      _mutate((labels) => labels.where((l) => l.id != id).toList());

  Future<void> _mutate(List<CustomLabel> Function(List<CustomLabel>) change) {
    _pending = _pending.catchError((_) {}).then((_) async {
      await ready;
      if (!mounted) return;
      if (state.hasError) {
        throw StateError('Não foi possível ler os templates salvos.');
      }
      final next = change(state.requireValue);
      final prefs = await SharedPreferences.getInstance();
      if (!await prefs.setStringList(
        storageKey,
        next.map((l) => l.encode()).toList(),
      )) {
        throw StateError('Não foi possível salvar o template.');
      }
      if (mounted) state = AsyncData(next);
    });
    return _pending;
  }
}
