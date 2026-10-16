import 'package:thermal_desk/models/label_job.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:thermal_desk/models/custom_label.dart';
import 'package:thermal_desk/models/printer_config.dart';
import 'package:thermal_desk/providers/custom_labels_provider.dart';
import 'package:thermal_desk/providers/history_provider.dart';
import 'package:thermal_desk/providers/printer_provider.dart';
import 'package:thermal_desk/services/template_files.dart';
import 'package:thermal_desk/services/thermaldesk_service.dart';
import 'package:thermal_desk/ui/designer/label_canvas.dart';
import 'package:thermal_desk/ui/designer/label_designer_page.dart';
import 'package:thermal_desk/ui/pages/template_picker_page.dart';
import 'package:thermal_desk/ui/widgets/zpl_local_preview.dart';

import 'custom_label_test.dart' show exampleLabel;

class FakeFiles extends TemplateFiles {
  CustomLabel? exported;
  String? zpl;
  @override
  Future<CustomLabel?> importLabel() async =>
      CustomLabel.decode(exampleLabel().encode(), newIdentity: true);
  @override
  Future<bool> exportLabel(CustomLabel label) async {
    exported = label;
    return true;
  }

  @override
  Future<bool> exportZpl(String name, String zpl) async {
    this.zpl = zpl;
    return true;
  }
}

class FakePrinter extends ThermalDeskService {
  String? zpl;
  PrinterConfig? config;
  @override
  Future<ThermalDeskResult<bool>> sendZpl(PrinterConfig cfg, String zpl) async {
    this.zpl = zpl;
    config = cfg;
    return const ThermalDeskSuccess(true);
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  Future<void> setup(
    WidgetTester tester,
    Widget page, {
    ProviderContainer? container,
    double width = 1280,
  }) async {
    tester.view.physicalSize = Size(width, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      container == null
          ? ProviderScope(child: MaterialApp(home: page))
          : UncontrolledProviderScope(
              container: container,
              child: MaterialApp(home: page),
            ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'Edição atualiza prévia; arrastar, redimensionar e desfazer alteram o modelo',
    (tester) async {
      await setup(tester, const LabelDesignerPage());
      await tester.tap(find.byKey(const ValueKey('add-text')));
      await tester.pumpAndSettle();
      LabelCanvas canvas() =>
          tester.widget<LabelCanvas>(find.byType(LabelCanvas));
      final before = canvas().label.elements.single;
      await tester.drag(
        find.byKey(ValueKey('canvas-${before.id}')),
        const Offset(90, 50),
      );
      await tester.pumpAndSettle();
      expect(canvas().label.elements.single.x, greaterThan(before.x));
      await tester.tap(find.byTooltip('Desfazer'));
      await tester.pumpAndSettle();
      expect(canvas().label.elements.single.x, before.x);
      await tester.drag(
        find.byKey(const ValueKey('resize-element')),
        const Offset(20, 20),
      );
      await tester.pumpAndSettle();
      expect(canvas().label.elements.single.width, greaterThan(before.width));
      final input = find.descendant(
        of: find.byKey(ValueKey('content-${before.id}')),
        matching: find.byType(TextFormField),
      );
      await tester.ensureVisible(input);
      await tester.enterText(input, 'Item Genérico');
      await tester.pump();
      expect(canvas().label.elements.single.content, 'Item Genérico');
      expect(
        tester.widget<ZplLocalPreview>(find.byType(ZplLocalPreview)).zpl,
        contains('_49_74_65_6D'),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Salvar cria template persistente e abre modo de uso', (
    tester,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await setup(tester, const LabelDesignerPage(), container: container);
    await tester.tap(find.byKey(const ValueKey('add-text')));
    await tester.pump();
    await tester.tap(find.byTooltip('Salvar template'));
    await tester.pumpAndSettle();
    expect(find.text('Preencher etiqueta'), findsOneWidget);
    final restarted = CustomLabelsNotifier();
    addTearDown(restarted.dispose);
    await restarted.ready;
    expect(restarted.state.requireValue.single.name, 'Minha etiqueta');
    expect(
      restarted.state.requireValue.single.elements.single.content,
      'Produto Exemplo',
    );
  });

  testWidgets(
    'Importar, revisar, salvar, voltar e exportar mantém o modelo editável',
    (tester) async {
      final files = FakeFiles();
      final container = ProviderContainer(
        overrides: [templateFilesProvider.overrideWithValue(files)],
      );
      addTearDown(container.dispose);
      await setup(
        tester,
        const TemplatePicker(showCustom: true),
        container: container,
      );
      await tester.tap(find.text('Importar modelo'));
      await tester.pumpAndSettle();
      expect(find.text('Designer de etiquetas'), findsOneWidget);
      expect(container.read(customLabelsProvider).requireValue, isEmpty);
      await tester.tap(find.byTooltip('Salvar template'));
      await tester.pumpAndSettle();
      final saved = container.read(customLabelsProvider).requireValue.single;
      expect(saved.id, isNot('example'));
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Minha etiqueta'), findsOneWidget);
      await tester.tap(find.byTooltip('Opções de Minha etiqueta'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Exportar modelo'));
      await tester.pumpAndSettle();
      expect(files.exported!.toJson(), saved.toJson());
    },
  );

  testWidgets(
    'Usar modelo imprime valores atuais e cópias sem mudar o template',
    (tester) async {
      final service = FakePrinter(), files = FakeFiles();
      final container = ProviderContainer(
        overrides: [
          thermalDeskServiceProvider.overrideWithValue(service),
          templateFilesProvider.overrideWithValue(files),
        ],
      );
      addTearDown(container.dispose);
      await container.read(printerConfigProvider.notifier).ready;
      await container
          .read(printerConfigProvider.notifier)
          .save(PrinterConfig.defaults.copyWith(ip: '::1', dpi: 300));
      await setup(
        tester,
        LabelDesignerPage(label: exampleLabel(), editing: false),
        container: container,
      );
      final title = find.descendant(
        of: find.byKey(const ValueKey('use-title')),
        matching: find.byType(TextFormField),
      );
      await tester.enterText(title, 'Item Genérico');
      await tester.pump();
      final copies = find.widgetWithText(TextFormField, 'Cópias (1–1000)');
      await tester.enterText(copies, '3');
      await tester.pump();
      final print = find.text('Imprimir etiqueta');
      await tester.ensureVisible(print);
      await tester.tap(print);
      await tester.pumpAndSettle();
      expect(service.zpl, contains('^PQ3'));
      expect(service.zpl, contains('_49_74_65_6D'));
      expect(service.config!.dpi, 300);
      expect(
        container.read(historyProvider).single.template.displayName,
        'Personalizado',
      );
      expect(
        tester
            .widget<LabelCanvas>(find.byType(LabelCanvas))
            .label
            .elements
            .first
            .content,
        'Produto Exemplo',
      );
      await tester.tap(find.byTooltip('Exportar etiqueta'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Exportar ZPL'));
      await tester.pumpAndSettle();
      expect(files.zpl, contains('_49_74_65_6D'));
    },
  );

  for (final width in [320.0, 600.0, 1280.0]) {
    for (final editing in [true, false]) {
      testWidgets(
        'Designer ${editing ? "editar" : "usar"} cabe em ${width.toInt()}px',
        (tester) async {
          await setup(
            tester,
            LabelDesignerPage(label: exampleLabel(), editing: editing),
            width: width,
          );
          expect(tester.takeException(), isNull);
          if (editing) {
            await tester.tap(find.byKey(const ValueKey('canvas-title')));
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
          }
          await tester.pumpWidget(const SizedBox());
        },
      );
    }
  }
}
