import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thermal_desk/models/label_job.dart';
import 'package:thermal_desk/models/label_profile.dart';
import 'package:thermal_desk/models/printer_config.dart';
import 'package:thermal_desk/services/thermaldesk_service.dart';
import 'package:thermal_desk/ui/widgets/zpl_local_preview.dart';

void main() {
  testWidgets(
    'Todos os templates desenham offline, incluindo acentos e campos invertidos',
    (tester) async {
      for (final template in LabelTemplate.values.where(
        (t) => t != LabelTemplate.custom,
      )) {
        final config = PrinterConfig.defaults.copyWith(
          dpi: 300,
          labelSize: '30x100mm (300dpi)',
        );
        final profile = LabelProfile.fromConfig(config);
        final zpl = const ThermalDeskService().buildZpl(
          title: 'Produto Exemplo — ação',
          barcode: '',
          subtitle: 'Item Genérico',
          template: template,
          cfg: config,
        );
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 120,
                height: 400,
                child: ZplLocalPreview(zpl: zpl, profile: profile),
              ),
            ),
          ),
        );
        await tester.pump();
        expect(tester.takeException(), isNull, reason: template.name);
      }
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
