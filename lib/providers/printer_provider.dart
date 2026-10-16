import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:thermal_desk/models/printer_config.dart';
import 'package:thermal_desk/services/thermaldesk_service.dart';

final thermalDeskServiceProvider = Provider((_) => const ThermalDeskService());

// Provider para a impressora atualmente selecionada
final printerConfigProvider =
    StateNotifierProvider<PrinterConfigNotifier, PrinterConfig>((ref) {
      return PrinterConfigNotifier(ref);
    });

// Provider para lista de todas as impressoras salvas
final savedPrintersProvider =
    StateNotifierProvider<SavedPrintersNotifier, List<PrinterConfig>>((ref) {
      return SavedPrintersNotifier(ref);
    });

class PrinterConfigNotifier extends StateNotifier<PrinterConfig> {
  final Ref ref;

  late final Future<void> ready;
  PrinterConfigNotifier(this.ref) : super(PrinterConfig.defaults) {
    ready = _load();
  }

  int _revision = 0;
  Future<void> _pending = Future.value();

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted || _revision != 0) return;
    final raw = prefs.getString('printer_config');
    if (raw != null) {
      try {
        state = PrinterConfig.fromJsonString(raw);
        return;
      } catch (_) {
        /* Usa a lista salva. */
      }
    }
    final printers = <PrinterConfig>[];
    for (final entry in prefs.getStringList('saved_printers') ?? <String>[]) {
      try {
        printers.add(PrinterConfig.fromJsonString(entry));
      } catch (_) {
        /* Ignora registos inválidos. */
      }
    }
    state =
        printers.where((p) => p.isDefault).firstOrNull ??
        printers.firstOrNull ??
        PrinterConfig.defaults;
  }

  Future<void> save(PrinterConfig cfg) async {
    _revision++;
    state = cfg;
    ref.read(connStatusProvider.notifier).state = ConnStatus.idle;
    _pending = _pending.catchError((_) {}).then((_) async {
      final prefs = await SharedPreferences.getInstance();
      if (!await prefs.setString('printer_config', cfg.toJsonString())) {
        throw StateError('Não foi possível guardar a impressora selecionada.');
      }
    });
    await _pending;
  }

  Future<void> selectPrinter(PrinterConfig printer) async {
    await save(printer);
  }
}

class SavedPrintersNotifier extends StateNotifier<List<PrinterConfig>> {
  late final Future<void> _ready;
  Future<void> _pending = Future.value();
  final Ref ref;
  SavedPrintersNotifier(this.ref) : super([PrinterConfig.defaults]) {
    _ready = _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList('saved_printers');
    final printers = <PrinterConfig>[];
    for (final entry in raw ?? <String>[]) {
      try {
        printers.add(PrinterConfig.fromJsonString(entry));
      } catch (_) {
        /* Preserva as restantes. */
      }
    }
    if (!mounted) return;
    state = printers.isEmpty ? [PrinterConfig.defaults] : printers;
  }

  Future<void> _save() {
    final snapshot = state.map((p) => p.toJsonString()).toList();
    _pending = _pending.catchError((_) {}).then((_) async {
      final prefs = await SharedPreferences.getInstance();
      if (!await prefs.setStringList('saved_printers', snapshot)) {
        throw StateError('Não foi possível guardar as impressoras.');
      }
    });
    return _pending;
  }

  Future<void> add(PrinterConfig printer) async {
    await _ready;
    if (!mounted) return;
    state = [...state, printer];
    await _save();
  }

  Future<void> update(PrinterConfig printer) async {
    await _ready;
    if (!mounted) return;
    state = [
      for (final p in state)
        if (p.id == printer.id) printer else p,
    ];
    await _save();
  }

  Future<void> remove(String id) async {
    await _ready;
    await ref.read(printerConfigProvider.notifier).ready;
    if (!mounted) return;
    if (state.length <= 1) return; // Manter pelo menos uma
    state = state.where((p) => p.id != id).toList();
    if (!state.any((p) => p.isDefault)) {
      state = [state.first.copyWith(isDefault: true), ...state.skip(1)];
    }
    if (ref.read(printerConfigProvider).id == id) {
      await ref
          .read(printerConfigProvider.notifier)
          .save(state.where((p) => p.isDefault).firstOrNull ?? state.first);
    }
    await _save();
  }

  Future<void> setDefault(String id) async {
    await _ready;
    if (!mounted) return;
    if (!state.any((p) => p.id == id)) return;
    state = [for (final p in state) p.copyWith(isDefault: p.id == id)];
    await _save();
  }
}

// Connection test state
enum ConnStatus { idle, testing, connected, failed }

final connStatusProvider = StateProvider<ConnStatus>((_) => ConnStatus.idle);
final sendingProvider = StateProvider<bool>((_) => false);
