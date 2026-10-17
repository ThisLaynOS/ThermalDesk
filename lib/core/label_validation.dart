import 'package:barcode/barcode.dart';
import 'package:thermal_desk/models/label_job.dart';
import 'package:thermal_desk/models/label_profile.dart';

class LabelValidation {
  static String? templateBarcode(
    String? value,
    LabelTemplate template,
    LabelProfile profile,
  ) => !template.usesBarcode
      ? null
      : barcode(
          value,
          qr: template == LabelTemplate.qrCode,
          ean13: template == LabelTemplate.basic,
          qrCorrection: BarcodeQRCorrectionLevel.quartile,
          availableDots: profile.barcodeDotsFor(template),
        );

  static Barcode get code128 =>
      Barcode.code128(useCode128A: false, useCode128C: false);

  static int code128Modules(String data) {
    final bars = code128
        .make(data, width: 1, height: 1)
        .whereType<BarcodeBar>();
    final smallest = bars
        .map((b) => b.width)
        .where((w) => w > 0)
        .reduce((a, b) => a < b ? a : b);
    return (1 / smallest).round();
  }

  static int qrModules(
    String data, {
    BarcodeQRCorrectionLevel correction = BarcodeQRCorrectionLevel.low,
  }) {
    final cell = Barcode.qrCode(errorCorrectLevel: correction)
        .make(data, width: 1, height: 1)
        .whereType<BarcodeBar>()
        .first
        .height;
    return (1 / cell).round();
  }

  static String? barcode(
    String? value, {
    required bool qr,
    bool ean13 = false,
    BarcodeQRCorrectionLevel qrCorrection = BarcodeQRCorrectionLevel.low,
    double? availableDots,
  }) {
    final input = (value ?? '').trim();
    final text = input.isEmpty
        ? (qr ? 'https://exemplo.local' : '0000000000000')
        : input;
    if (text.contains('^') || text.contains('~')) {
      return 'Não use ^ ou ~ neste campo';
    }
    if (ean13) {
      if (!RegExp(r'^\d{12,13}$').hasMatch(text) ||
          !Barcode.ean13().isValid(text)) {
        return 'Informe um EAN-13 válido (12 dígitos ou 13 com verificador)';
      }
      if (availableDots != null && 113 > availableDots) {
        return 'O EAN-13 não cabe neste tamanho de etiqueta';
      }
      return null;
    }
    if (!qr && text.contains('>')) {
      return 'O caractere > é reservado no Code128 ZPL';
    }
    if (qr) {
      if (text.length > 1024) return 'Use até 1024 caracteres';
      try {
        final modules = qrModules(text, correction: qrCorrection);
        if (availableDots != null && modules > availableDots) {
          return 'O QR Code não cabe neste tamanho de etiqueta';
        }
      } catch (_) {
        return 'Conteúdo demasiado grande para um QR Code';
      }
    } else if (text.length > 80 || !code128.isValid(text)) {
      return 'Use até 80 caracteres ASCII válidos para Code128';
    }
    if (!qr &&
        availableDots != null &&
        code128Modules(text) + 10 > availableDots) {
      return 'O código de barras não cabe neste tamanho de etiqueta';
    }
    return null;
  }

  static String? price(String? value, {bool allowEmpty = false}) {
    final text = (value ?? '').trim().replaceFirst(
      RegExp(r'^R\$\s*', caseSensitive: false),
      '',
    );
    if (text.isEmpty && allowEmpty) return null;
    final valid = RegExp(
      r'^(?:\d+(?:[.,]\d{1,2})?|\d{1,3}(?:\.\d{3})+(?:,\d{1,2})?)$',
    );
    return valid.hasMatch(text) ? null : 'Informe um preço válido, como 0,00';
  }
}
