import 'package:barcode/barcode.dart';

class LabelValidation {
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

  static int qrModules(String data) {
    final cell = Barcode.qrCode()
        .make(data, width: 1, height: 1)
        .whereType<BarcodeBar>()
        .first
        .height;
    return (1 / cell).round();
  }

  static String? barcode(
    String? value, {
    required bool qr,
    double? availableDots,
  }) {
    final input = (value ?? '').trim();
    final text = input.isEmpty
        ? (qr ? 'https://exemplo.local' : '0000000000000')
        : input;
    if (text.contains('^') || text.contains('~')) {
      return 'Não use ^ ou ~ neste campo';
    }
    if (!qr && text.contains('>')) {
      return 'O caractere > é reservado no Code128 ZPL';
    }
    if (qr) {
      if (text.length > 1024) return 'Use até 1024 caracteres';
      try {
        final modules = qrModules(text);
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
