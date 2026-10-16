import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:thermal_desk/models/printer_config.dart';
import 'package:thermal_desk/providers/printer_provider.dart';
import 'package:thermal_desk/services/thermaldesk_service.dart';
import 'package:thermal_desk/ui/pages/batch_print_page.dart';

class SlowPrinter extends ThermalDeskService {
  int calls = 0;
  final result = Completer<ThermalDeskResult<bool>>();
  @override
  Future<ThermalDeskResult<bool>> sendZpl(PrinterConfig cfg, String zpl) {
    calls++;
    return result.future;
  }
}

void main() {
  testWidgets(
    'Edição preserva cursor; parar e sair durante envio não inicia outra impressão',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final service = SlowPrinter();
      final container = ProviderContainer(
        overrides: [thermalDeskServiceProvider.overrideWithValue(service)],
      );
      addTearDown(container.dispose);
      await container
          .read(printerConfigProvider.notifier)
          .save(
            PrinterConfig.defaults.copyWith(
              ip: InternetAddress.loopbackIPv4.address,
            ),
          );
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: BatchPrintPage()),
        ),
      );
      await tester.pumpAndSettle();
      for (var i = 0; i < 2; i++) {
        await tester.tap(find.text('Adicionar'));
        await tester.pump();
        final field = find
            .byWidgetPredicate(
              (w) => w is TextField && w.decoration?.labelText == 'Título',
            )
            .at(i);
        await tester.ensureVisible(field);
        await tester.enterText(field, 'Item Genérico $i');
        await tester.pump();
        expect(
          tester.widget<TextField>(field).controller!.selection.baseOffset,
          'Item Genérico $i'.length,
        );
      }
      await tester.tap(find.text('Imprimir'));
      await tester.pump();
      expect(service.calls, 1);
      await tester.tap(find.text('Parar'));
      await tester.pump();
      final printButton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Imprimindo...'),
      );
      expect(printButton.onPressed, isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      service.result.complete(const ThermalDeskSuccess(true));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(service.calls, 1);
      expect(tester.takeException(), isNull);
    },
  );
}
