import 'package:barcode/barcode.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:thermal_desk/core/label_validation.dart';
import 'package:thermal_desk/core/zpl_graphic.dart';
import 'package:thermal_desk/models/label_job.dart';
import 'package:thermal_desk/models/label_profile.dart';
import 'package:thermal_desk/models/printer_config.dart';
import 'package:thermal_desk/providers/history_provider.dart';
import 'package:thermal_desk/providers/printer_provider.dart';
import 'package:thermal_desk/services/thermaldesk_service.dart';
import 'package:thermal_desk/ui/home_page.dart';
import 'package:thermal_desk/ui/widgets/printer_form_card.dart';
import 'package:thermal_desk/ui/widgets/zpl_local_preview.dart';

class RecordingPrinter extends ThermalDeskService {
  final sent = <String>[];
  @override
  Future<ThermalDeskResult<bool>> sendZpl(PrinterConfig cfg, String zpl) async {
    sent.add(zpl);
    return const ThermalDeskSuccess(true);
  }
}

void main() {
  const service = ThermalDeskService();
  final config = PrinterConfig.defaults.copyWith(
    dpi: 200,
    labelSize: '30x100mm (200dpi)',
  );
  String build(
    LabelTemplate template, {
    String detail = '17/10/2026',
    PrinterConfig? cfg,
  }) => service.buildZpl(
    title: 'Produto A',
    barcode: '7891234567895',
    subtitle: '42',
    detail: detail,
    template: template,
    cfg: cfg ?? config,
  );

  test('Campos dos desenhos recebem os dados de cada template', () {
    expect(build(LabelTemplate.address), contains('^FDProduto A^FS'));
    expect(build(LabelTemplate.address), contains('^FDRemetente: 42^FS'));
    expect(
      build(LabelTemplate.shipping),
      contains('^FDRASTREIO: 7891234567895^FS'),
    );
    expect(build(LabelTemplate.inventory), contains('^FD42^FS'));
    expect(build(LabelTemplate.inventory), contains('^FD17/10/2026^FS'));
    final qr = build(LabelTemplate.qrCode, detail: 'SKU-42');
    expect(qr, contains('^FDQA,7891234567895^FS'));
    expect(qr, contains('^FD42^FS'));
    expect(qr, contains('^FDCÓD: SKU-42^FS'));
    final cable = build(LabelTemplate.cable);
    expect(cable, contains('^FDID: 42^FS'));
    expect(RegExp(r'\^FDProduto A\^FS').allMatches(cable).length, 6);
    expect(RegExp(r'\^FD7891234567895\^FS').allMatches(cable).length, 6);
  });

  test('Escala parte de 240x800 e preserva coordenadas e ícones', () {
    final native = build(LabelTemplate.address);
    expect(native, contains('^FO100,25^A0R,34,34^FB750,2,0,L'));
    expect(native, contains('^GFA,72,72,3,'));
    final highDpi = build(
      LabelTemplate.address,
      cfg: config.copyWith(dpi: 300, labelSize: '30x100mm (300dpi)'),
    );
    expect(highDpi, contains('^FO150,38^A0R,51,51^FB1125,2,0,L'));
    expect(highDpi, contains('^GFA,180,180,5,'));
    expect(highDpi, contains('^PW360'));
    expect(highDpi, contains('^LL1200'));
  });

  test(
    'EAN valida o verificador e envia os 12 dígitos de dados ao firmware',
    () {
      final profile = LabelProfile.fromConfig(config);
      expect(
        LabelValidation.templateBarcode(
          '7891234567895',
          LabelTemplate.basic,
          profile,
        ),
        isNull,
      );
      expect(
        LabelValidation.templateBarcode(
          '789123456789',
          LabelTemplate.basic,
          profile,
        ),
        isNull,
      );
      for (final bad in ['ABC123', '7891234567890', '123']) {
        expect(
          LabelValidation.templateBarcode(bad, LabelTemplate.basic, profile),
          isNotNull,
        );
      }
      expect(
        LabelValidation.templateBarcode(
          'ABC123',
          LabelTemplate.shipping,
          profile,
        ),
        isNull,
      );
      final zpl = build(LabelTemplate.basic);
      expect(zpl, contains('^BER,93,N,N^FD789123456789^FS'));
      expect(zpl, contains('^FD7891234567895^FS'));
    },
  );

  test(
    'QR com correção Q cabe antes da divisória, mesmo com conteúdo longo',
    () {
      final data = 'https://exemplo.local/${'abc' * 80}';
      final zpl = service.buildZpl(
        title: 'QR',
        barcode: data,
        subtitle: '',
        template: LabelTemplate.qrCode,
        cfg: config,
      );
      final match = RegExp(r'\^FO(\d+),(\d+)\^BQN,2,(\d+)').firstMatch(zpl)!;
      final extent =
          LabelValidation.qrModules(
            data,
            correction: BarcodeQRCorrectionLevel.quartile,
          ) *
          int.parse(match[3]!);
      expect(int.parse(match[1]!) + extent, lessThanOrEqualTo(224 - 8));
      expect(int.parse(match[2]!) + extent, lessThanOrEqualTo(195 - 8));
    },
  );

  test(
    'Dados extras são sanitizados e o histórico antigo continua legível',
    () {
      final zpl = build(LabelTemplate.qrCode, detail: 'SKU^XZ~JA');
      expect(RegExp(r'\^XZ').allMatches(zpl).length, 1);
      expect(zpl, isNot(contains('~JA')));
      final json = LabelJob(
        id: 'a',
        sentAt: DateTime(2026),
        title: 'QR',
        barcode: 'url',
        subtitle: 'desc',
        detail: 'SKU-42',
        template: LabelTemplate.qrCode,
        success: true,
        zpl: zpl,
      ).toJson();
      expect(LabelJob.fromJson(json).detail, 'SKU-42');
      json.remove('detail');
      expect(LabelJob.fromJson(json).detail, isEmpty);
    },
  );

  test(
    'Decodifica gráficos comprimidos e escala pixels sem perder o desenho',
    () {
      final graphic = ZplGraphic.decode(6, 2, 'HF,:!');
      expect(graphic.bytes, [255, 0, 255, 0, 255, 255]);
      final enlarged = graphic.scaled(2);
      expect(enlarged.width, 32);
      expect(enlarged.height, 6);
      expect(enlarged.pixel(15, 0), isTrue);
      expect(enlarged.pixel(16, 0), isFalse);
      expect(enlarged.pixel(31, 5), isTrue);
    },
  );

  for (final template in [LabelTemplate.inventory, LabelTemplate.qrCode]) {
    testWidgets(
      '${template.name}: formulário, prévia, envio e histórico usam os mesmos dados',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        final printer = RecordingPrinter();
        final container = ProviderContainer(
          overrides: [thermalDeskServiceProvider.overrideWithValue(printer)],
        );
        addTearDown(container.dispose);
        await container
            .read(printerConfigProvider.notifier)
            .save(config.copyWith(ip: '127.0.0.1'));
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(home: HomePage()),
          ),
        );
        await tester.pumpAndSettle();
        tester
            .widget<PrinterFormCard>(find.byType(PrinterFormCard))
            .onTemplateChange(template);
        await tester.pumpAndSettle();
        Future<void> fill(String label, String value) async {
          final field = find.byWidgetPredicate(
            (w) => w is TextField && w.decoration?.labelText == label,
          );
          await tester.ensureVisible(field);
          await tester.enterText(field, value);
          await tester.pump();
        }

        await fill(template.titleLabel, 'Produto integrado');
        await fill(
          template.barcodeLabel,
          template == LabelTemplate.qrCode
              ? 'https://exemplo.local/item'
              : 'ABC-123',
        );
        await fill(
          template.subtitleLabel,
          template == LabelTemplate.inventory ? '24' : 'Descrição do produto',
        );
        final detail = template == LabelTemplate.inventory
            ? '17/10/2026'
            : 'SKU-24';
        await fill(template.detailLabel!, detail);
        final preview = tester
            .widget<ZplLocalPreview>(find.byType(ZplLocalPreview))
            .zpl;
        expect(preview, contains(detail));
        tester.widget<PrinterFormCard>(find.byType(PrinterFormCard)).onPrint();
        await tester.pumpAndSettle();
        expect(printer.sent, [preview]);
        expect(container.read(historyProvider).single.zpl, preview);
        expect(container.read(historyProvider).single.detail, detail);
        final prefs = await SharedPreferences.getInstance();
        expect(
          LabelJob.fromJsonString(prefs.getStringList('label_history')!.single)
              .detail,
          detail,
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}
