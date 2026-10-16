import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:thermal_desk/models/label_job.dart';
import 'package:thermal_desk/models/label_profile.dart';
import 'package:thermal_desk/models/printer_config.dart';
import 'package:thermal_desk/providers/preview_provider.dart';
import 'package:thermal_desk/providers/printer_provider.dart';
import 'package:thermal_desk/services/labelary_service.dart';
import 'package:thermal_desk/ui/widgets/preview_card.dart';
import 'package:thermal_desk/ui/widgets/zpl_local_preview.dart';

class ControlledPreview extends LabelaryService {
  final requests = <Completer<LabelaryResult<List<int>>>>[];
  final profiles = <LabelProfile>[];
  @override
  Future<LabelaryResult<List<int>>> renderZpl(
    String zpl, {
    required LabelProfile profile,
  }) {
    profiles.add(profile);
    final completer = Completer<LabelaryResult<List<int>>>();
    requests.add(completer);
    return completer.future;
  }
}

void main() {
  testWidgets(
    'Prévia local acompanha campos e configuração; online ignora respostas antigas',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final service = ControlledPreview();
      addTearDown(service.close);
      final controllers = List.generate(3, (_) => TextEditingController());
      addTearDown(() {
        for (final c in controllers) {
          c.dispose();
        }
      });
      final container = ProviderContainer(
        overrides: [labelaryServiceProvider.overrideWithValue(service)],
      );
      addTearDown(container.dispose);
      Widget screen(LabelTemplate template) => UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: PreviewCard(
                titleCtrl: controllers[0],
                barcodeCtrl: controllers[1],
                subtitleCtrl: controllers[2],
                template: template,
                onCopyZpl: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpWidget(screen(LabelTemplate.basic));
      await tester.pumpAndSettle();
      expect(service.requests, isEmpty);
      controllers[0].text = 'Produto Exemplo';
      await tester.pump();
      expect(
        tester.widget<ZplLocalPreview>(find.byType(ZplLocalPreview)).zpl,
        contains('Produto Exemplo'),
      );
      await tester.ensureVisible(find.byTooltip('Ampliar prévia'));
      await tester.tap(find.byTooltip('Ampliar prévia'));
      await tester.pump();
      expect(
        tester
            .widget<InteractiveViewer>(find.byType(InteractiveViewer))
            .transformationController!
            .value
            .getMaxScaleOnAxis(),
        greaterThan(1),
      );
      await tester.tap(find.byTooltip('Girar apenas a prévia'));
      await tester.pump();
      expect(
        tester
            .widget<InteractiveViewer>(find.byType(InteractiveViewer))
            .transformationController!
            .value
            .getMaxScaleOnAxis(),
        1,
      );
      expect(service.requests, isEmpty);
      await tester.ensureVisible(find.byType(SwitchListTile));
      await tester.tap(find.byType(Switch));
      await tester.pump(const Duration(milliseconds: 650));
      expect(service.requests.length, 1);
      controllers[0].text = 'Item Genérico';
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 650));
      expect(service.requests.length, 2);
      service.requests[1].complete(const LabelaryFailure('Erro atual'));
      await tester.pump();
      final png = base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aHmsAAAAASUVORK5CYII=',
      );
      service.requests[0].complete(LabelarySuccess(png));
      await tester.pump();
      expect(find.byKey(const ValueKey('online-preview')), findsNothing);
      expect(find.text('Erro atual'), findsOneWidget);
      await container
          .read(printerConfigProvider.notifier)
          .save(
            PrinterConfig.defaults.copyWith(
              dpi: 300,
              labelSize: '50x30mm (300dpi)',
            ),
          );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 650));
      expect(service.profiles.last.dpi, 300);
      expect(service.profiles.last.width, 600);
      await tester.pumpWidget(screen(LabelTemplate.qrCode));
      await tester.pump(const Duration(milliseconds: 650));
      expect(
        tester.widget<ZplLocalPreview>(find.byType(ZplLocalPreview)).zpl,
        contains('^BQN'),
      );
      await tester.pumpWidget(const SizedBox.shrink());
      for (final pending in service.requests.where((c) => !c.isCompleted)) {
        pending.complete(const LabelaryFailure('ignorado'));
      }
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
  );
}
