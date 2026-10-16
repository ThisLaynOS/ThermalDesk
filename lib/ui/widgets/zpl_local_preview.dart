import 'dart:math' as math;
import 'dart:convert';

import 'package:thermal_desk/core/label_validation.dart';

import 'package:barcode_widget/barcode_widget.dart';
import 'package:flutter/material.dart';
import 'package:thermal_desk/models/label_profile.dart';

/// Aproxima apenas os comandos emitidos pelo ThermalDesk. Não é um emulador ZPL.
/// Posições, textos e dimensões vêm do próprio ZPL, sem dados decorativos.
class ZplLocalPreview extends StatelessWidget {
  final String zpl;
  final LabelProfile profile;
  const ZplLocalPreview({super.key, required this.zpl, required this.profile});

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: ZplPreviewPainter(zpl, profile),
    child: const SizedBox.expand(),
  );
}

class ZplPreviewPainter extends CustomPainter {
  final String zpl;
  final LabelProfile profile;
  ZplPreviewPainter(this.zpl, this.profile);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, Paint()..color = Colors.white);
    canvas.scale(size.width / profile.width, size.height / profile.height);
    double x = 0, y = 0, fontSize = 24, fontWidth = 24, module = 2;
    double blockWidth = 0, barcodeHeight = 90;
    var maxLines = 1;
    var orientation = 'N', type = 'text';
    var inverse = false, drawBarcodeText = true;
    String? hexMarker;
    var alignment = TextAlign.left;
    for (final match in RegExp(r'\^([A-Z0-9]{2})([^\^]*)').allMatches(zpl)) {
      final command = match[1]!;
      var value = match[2]!.trimRight();
      final args = value.split(',');
      double number(int index, [double fallback = 0]) => index < args.length
          ? double.tryParse(args[index]) ?? fallback
          : fallback;
      switch (command) {
        case 'FO':
          x = number(0);
          y = number(1);
        case 'A0':
          orientation = args.first;
          fontSize = number(1, 24);
          fontWidth = number(2, fontSize);
        case 'FB':
          blockWidth = number(0);
          maxLines = number(1, 1).toInt();
          alignment = switch (args.length > 3 ? args[3] : 'L') {
            'C' => TextAlign.center,
            'R' => TextAlign.right,
            _ => TextAlign.left,
          };
        case 'BY':
          module = number(0, 2);
        case 'BC':
          type = 'barcode';
          orientation = args.first;
          barcodeHeight = number(1, 90);
          drawBarcodeText = args.length > 2 && args[2] == 'Y';
        case 'BQ':
          type = 'qr';
          orientation = args.first;
          module = number(2, 4);
        case 'FR':
          inverse = true;
        case 'FH':
          hexMarker = value.isEmpty ? '_' : value[0];
        case 'GB':
          final width = number(0), height = number(1), thickness = number(2, 1);
          final rect = Rect.fromLTWH(x, y, width, height);
          final filled = thickness >= math.min(width, height) / 2;
          canvas.drawRect(
            filled ? rect : rect.deflate(thickness / 2),
            Paint()
              ..color = Colors.black
              ..style = filled ? PaintingStyle.fill : PaintingStyle.stroke
              ..strokeWidth = thickness,
          );
        case 'FD':
          if (hexMarker != null) {
            final bytes = <int>[];
            for (var i = 0; i < value.length;) {
              final hex = value[i] == hexMarker && i + 2 < value.length
                  ? int.tryParse(value.substring(i + 1, i + 3), radix: 16)
                  : null;
              if (hex != null) {
                bytes.add(hex);
                i += 3;
              } else {
                bytes.addAll(utf8.encode(value[i]));
                i++;
              }
            }
            value = utf8.decode(bytes, allowMalformed: true);
          }
          canvas.save();
          canvas.translate(x, y);
          if (type == 'text') {
            final width = blockWidth > 0
                ? blockWidth
                : math.max(
                    1.0,
                    (orientation == 'R'
                        ? profile.height - y
                        : profile.width - x),
                  );
            final painter = TextPainter(
              text: TextSpan(
                text: value,
                style: TextStyle(
                  color: inverse ? Colors.white : Colors.black,
                  fontSize: fontSize,
                  height: 1,
                ),
              ),
              textDirection: TextDirection.ltr,
              textAlign: alignment,
              maxLines: math.max(1, maxLines),
              ellipsis: '…',
            )..layout(maxWidth: width);
            if (orientation == 'R') {
              canvas.translate(painter.height, 0);
              canvas.rotate(math.pi / 2);
            }
            // Fonte do firmware e fonte do sistema podem ter métricas diferentes.
            canvas.scale(fontWidth / math.max(1, fontSize), 1);
            painter.paint(canvas, Offset.zero);
            painter.dispose();
          } else {
            try {
              final data = type == 'qr' && value.startsWith('LA,')
                  ? value.substring(3)
                  : value;
              final barcode = type == 'qr'
                  ? Barcode.qrCode()
                  : LabelValidation.code128;
              final bars = barcode
                  .make(data, width: 1, height: 1)
                  .whereType<BarcodeBar>()
                  .toList();
              final unit = type == 'qr'
                  ? bars.first.height
                  : bars
                        .map((bar) => bar.width)
                        .where((w) => w > 0)
                        .reduce(math.min);
              final width = module / unit;
              final height = type == 'qr' ? width : barcodeHeight;
              if (orientation == 'R') {
                canvas.translate(height, 0);
                canvas.rotate(math.pi / 2);
              }
              for (final bar in bars.where((bar) => bar.black)) {
                canvas.drawRect(
                  Rect.fromLTWH(
                    bar.left * width,
                    bar.top * height,
                    bar.width * width,
                    bar.height * height,
                  ),
                  Paint()..color = Colors.black,
                );
              }
              if (type == 'barcode' && drawBarcodeText) {
                final painter = TextPainter(
                  text: TextSpan(
                    text: data,
                    style: const TextStyle(color: Colors.black, fontSize: 16),
                  ),
                  textDirection: TextDirection.ltr,
                )..layout(maxWidth: width);
                painter.paint(canvas, Offset(0, height + 2));
                painter.dispose();
              }
            } catch (_) {
              final painter = TextPainter(
                text: const TextSpan(
                  text: 'Código inválido',
                  style: TextStyle(color: Colors.red, fontSize: 14),
                ),
                textDirection: TextDirection.ltr,
              )..layout(maxWidth: math.max(1.0, profile.width - x));
              painter.paint(canvas, Offset.zero);
              painter.dispose();
            }
          }
          canvas.restore();
        case 'FS':
          blockWidth = 0;
          maxLines = 1;
          inverse = false;
          hexMarker = null;
          type = 'text';
          orientation = 'N';
          alignment = TextAlign.left;
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant ZplPreviewPainter oldDelegate) =>
      oldDelegate.zpl != zpl ||
      oldDelegate.profile.width != profile.width ||
      oldDelegate.profile.height != profile.height;
}
