import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zebra_label_pro/models/printer_config.dart';
import 'package:zebra_label_pro/services/zebra_service.dart';

final zebraServiceProvider = Provider((_) => const ZebraService());

// Provider para a impressora atualmente selecionada
final printerConfigProvider =
    StateNotifierProvider<PrinterConfigNotifier, PrinterConfig>((ref) {
  return PrinterConfigNotifier(ref);
});

// Provider para lista de todas as impressoras salvas
final savedPrintersProvider =
    StateNotifierProvider<SavedPrintersNotifier, List<PrinterConfig>>((ref) {
  return SavedPrintersNotifier();
});

class PrinterConfigNotifier extends StateNotifier<PrinterConfig> {
  final Ref ref;
  
  PrinterConfigNotifier(this.ref) : super(PrinterConfig.defaults) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('printer_config');
    if (raw != null) {
      try {
        state = PrinterConfig.fromJsonString(raw);
      } catch (_) {
        // Migração de configuração antiga sem id/name
        final oldJson = jsonDecode(raw) as Map<String, dynamic>;
        state = PrinterConfig(
          id: 'migrated',
          name: 'Impressora Principal',
          ip: oldJson['ip'] as String? ?? '',
          port: oldJson['port'] as int? ?? 9100,
          dpi: oldJson['dpi'] as int? ?? 203,
          labelSize: oldJson['labelSize'] as String? ?? '30x100mm (203dpi S4M)',
          isDefault: true,
        );
        await save(state);
      }
    }
  }

  Future<void> save(PrinterConfig cfg) async {
    state = cfg;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('printer_config', cfg.toJsonString());
  }
  
  Future<void> selectPrinter(PrinterConfig printer) async {
    await save(printer);
  }
}

class SavedPrintersNotifier extends StateNotifier<List<PrinterConfig>> {
  SavedPrintersNotifier() : super([]) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList('saved_printers');
    if (raw != null) {
      state = raw.map((s) => PrinterConfig.fromJsonString(s)).toList();
    }
    if (state.isEmpty) {
      state = [PrinterConfig.defaults];
      await _save();
    }
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      'saved_printers',
      state.map((p) => p.toJsonString()).toList(),
    );
  }

  Future<void> add(PrinterConfig printer) async {
    state = [...state, printer];
    await _save();
  }

  Future<void> update(PrinterConfig printer) async {
    state = [
      for (final p in state)
        if (p.id == printer.id) printer else p,
    ];
    await _save();
  }

  Future<void> remove(String id) async {
    if (state.length <= 1) return; // Manter pelo menos uma
    state = state.where((p) => p.id != id).toList();
    await _save();
  }

  Future<void> setDefault(String id) async {
    state = [
      for (final p in state)
        p.copyWith(isDefault: p.id == id),
    ];
    await _save();
  }
}

// Connection test state
enum ConnStatus { idle, testing, connected, failed }

final connStatusProvider = StateProvider<ConnStatus>((_) => ConnStatus.idle);
final sendingProvider = StateProvider<bool>((_) => false);
