import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:thermal_desk/models/label_job.dart';
import 'package:thermal_desk/models/printer_config.dart';
import 'package:thermal_desk/providers/history_provider.dart';
import 'package:thermal_desk/providers/printer_provider.dart';
import 'package:thermal_desk/providers/theme_provider.dart';

LabelJob job(String id) => LabelJob(
  id: id,
  sentAt: DateTime(2026),
  title: 'Produto Exemplo',
  barcode: '',
  subtitle: '',
  template: LabelTemplate.product,
  success: true,
  zpl: '^XA^XZ',
);

void main() {
  test('Histórico ignora registo corrompido e preserva gravações durante o carregamento', () async {
    SharedPreferences.setMockInitialValues({
      'label_history': ['invalid', job('old').toJsonString()],
    });
    final notifier = HistoryNotifier();
    addTearDown(notifier.dispose);
    await Future.wait([notifier.add(job('a')), notifier.add(job('b'))]);
    expect(notifier.state.map((j) => j.id), ['b', 'a', 'old']);
    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs
          .getStringList('label_history')!
          .map(LabelJob.fromJsonString)
          .map((j) => j.id),
      ['b', 'a', 'old'],
    );
  });
  test('Histórico limita o armazenamento a 100 trabalhos', () async {
    SharedPreferences.setMockInitialValues({
      'label_history': List.generate(100, (i) => job('$i').toJsonString()),
    });
    final notifier = HistoryNotifier();
    addTearDown(notifier.dispose);
    await notifier.add(job('new'));
    expect(notifier.state.length, 100);
    expect(notifier.state.first.id, 'new');
  });
  test('Configuração corrompida recupera a impressora padrão salva', () async {
    final printer = PrinterConfig.defaults.copyWith(
      id: 'saved',
      name: 'Item Genérico',
    );
    SharedPreferences.setMockInitialValues({
      'printer_config': 'invalid',
      'saved_printers': ['invalid', printer.toJsonString()],
    });
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(printerConfigProvider);
    await Future<void>.delayed(Duration.zero);
    expect(container.read(printerConfigProvider).id, 'saved');
  });
  test(
    'Remover impressora ativa seleciona outra e preserva uma padrão',
    () async {
      final a = PrinterConfig.defaults.copyWith(id: 'a');
      final b = PrinterConfig.defaults.copyWith(id: 'b', isDefault: false);
      SharedPreferences.setMockInitialValues({
        'printer_config': a.toJsonString(),
        'saved_printers': [a.toJsonString(), b.toJsonString()],
      });
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(printerConfigProvider);
      await container.read(savedPrintersProvider.notifier).remove('a');
      expect(container.read(savedPrintersProvider).single.id, 'b');
      expect(container.read(savedPrintersProvider).single.isDefault, isTrue);
      expect(container.read(printerConfigProvider).id, 'b');
    },
  );
  test('Notifiers podem ser descartados durante o carregamento', () async {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer();
    container.read(historyProvider);
    container.read(printerConfigProvider);
    container.read(savedPrintersProvider);
    container.read(themeModeProvider);
    container.dispose();
    await Future<void>.delayed(Duration.zero);
  });
}
