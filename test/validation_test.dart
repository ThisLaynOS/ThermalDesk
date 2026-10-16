import 'package:flutter_test/flutter_test.dart';
import 'package:thermal_desk/core/label_validation.dart';
import 'package:thermal_desk/models/label_job.dart';
import 'package:thermal_desk/models/label_profile.dart';
import 'package:thermal_desk/models/printer_config.dart';
import 'package:thermal_desk/services/thermaldesk_service.dart';
import 'package:thermal_desk/services/zpl_exporter.dart';

void main() {
  test('Preços válidos, casas decimais e valores obrigatórios', () {
    for (final value in ['0,00', r'R$ 0,00', '12.34', '1.234,56']) {
      expect(LabelValidation.price(value), isNull);
    }
    for (final value in ['', 'abc', '-1', '1,999', r'R$']) {
      expect(LabelValidation.price(value), isNotNull);
    }
    expect(LabelValidation.price('', allowEmpty: true), isNull);
  });
  test('Códigos têm limite e caracteres compatíveis com o template', () {
    expect(LabelValidation.barcode('ABC123', qr: false), isNull);
    expect(LabelValidation.barcode('ABC^XZ', qr: false), isNotNull);
    expect(LabelValidation.barcode('ação', qr: false), isNotNull);
    expect(
      LabelValidation.barcode('ação', qr: true, availableDots: 100),
      isNull,
    );
    expect(
      LabelValidation.barcode(
        'https://exemplo.local',
        qr: true,
        availableDots: 5,
      ),
      isNotNull,
    );
  });
  test('Perfil salvo é coerente e recupera DPI inválido', () {
    final config = PrinterConfig.fromJson({'dpi': 0, 'labelSize': 'invalid'});
    expect(config.dpi, 203);
    expect(LabelProfile.fromConfig(config).width, greaterThan(0));
    final resized = PrinterConfig.fromJson({
      'dpi': 300,
      'labelSize': PrinterConfig.defaults.labelSize,
    });
    expect(resized.labelSize, '30x100mm (300dpi)');
    expect(LabelProfile.fromConfig(resized).width, 360);
  });
  test('Exportação restringe o nome do ficheiro à pasta escolhida', () {
    expect(ZplExporter.safeFilename('../../example.zpl'), 'example.zpl');
    expect(ZplExporter.safeFilename(r'folder\example.zpl'), 'example.zpl');
    expect(ZplExporter.safeFilename(''), 'etiqueta.zpl');
    expect(ZplExporter.safeFilename('example'), 'example.zpl');
  });
  test('QR Code ajusta o módulo ao espaço disponível', () {
    final data = 'https://exemplo.local/${'item' * 50}';
    const config = PrinterConfig.defaults;
    final profile = LabelProfile.fromConfig(config);
    final zpl = const ThermalDeskService().buildZpl(
      title: 'Produto Exemplo',
      barcode: data,
      subtitle: '',
      template: LabelTemplate.qrCode,
      cfg: config,
    );
    final field = RegExp(r'\^FO(\d+),(\d+)\^BQN,2,(\d+)').firstMatch(zpl)!;
    final x = int.parse(field[1]!);
    final module = int.parse(field[3]!);
    expect(
      x + LabelValidation.qrModules(data) * module,
      lessThanOrEqualTo(profile.width),
    );
  });
}
