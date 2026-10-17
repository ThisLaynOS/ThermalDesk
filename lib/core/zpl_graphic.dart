import 'dart:math' as math;

/// Bitmap ASCII de ^GFA, incluindo repetições e linhas comprimidas do ZPL.
class ZplGraphic {
  final int bytesPerRow;
  final List<int> bytes;

  const ZplGraphic(this.bytesPerRow, this.bytes);

  int get width => bytesPerRow * 8;
  int get height => bytes.length ~/ bytesPerRow;

  bool pixel(int x, int y) =>
      bytes[y * bytesPerRow + x ~/ 8] & (128 >> (x % 8)) != 0;

  factory ZplGraphic.decode(int byteCount, int bytesPerRow, String data) {
    final rowLength = bytesPerRow * 2;
    final limit = byteCount * 2;
    final hex = StringBuffer();
    var repeat = 0;
    var previousRow = '0' * rowLength;
    var row = '';
    void append(String value) {
      for (final char in value.split('')) {
        if (hex.length >= limit) break;
        hex.write(char);
        row += char;
        if (row.length == rowLength) {
          previousRow = row;
          row = '';
        }
      }
    }

    for (final char in data.trim().split('')) {
      if (hex.length >= limit) break;
      final code = char.codeUnitAt(0);
      if (code >= 71 && code <= 89) {
        repeat += code - 70;
      } else if (code >= 103 && code <= 122) {
        repeat += (code - 102) * 20;
      } else if (char == ':') {
        append(previousRow);
      } else if (char == ',' || char == '!') {
        append((char == ',' ? '0' : 'F') * (rowLength - row.length));
      } else if (RegExp(r'^[0-9A-Fa-f]$').hasMatch(char)) {
        append(char * math.min(math.max(1, repeat), limit - hex.length));
        repeat = 0;
      }
    }
    final padded = hex.toString().padRight(limit, '0');
    return ZplGraphic(bytesPerRow, [
      for (var i = 0; i < limit; i += 2)
        int.parse(padded.substring(i, i + 2), radix: 16),
    ]);
  }

  ZplGraphic scaled(double scale) {
    if (scale == 1) return this;
    final targetWidth = math.max(1, (width * scale).round());
    final targetHeight = math.max(1, (height * scale).round());
    final stride = (targetWidth + 7) ~/ 8;
    final result = List.filled(stride * targetHeight, 0);
    for (var y = 0; y < targetHeight; y++) {
      for (var x = 0; x < targetWidth; x++) {
        if (pixel(
          math.min(width - 1, (x / scale).floor()),
          math.min(height - 1, (y / scale).floor()),
        )) {
          result[y * stride + x ~/ 8] |= 128 >> (x % 8);
        }
      }
    }
    return ZplGraphic(stride, result);
  }

  String toZpl() =>
      '^GFA,${bytes.length},${bytes.length},$bytesPerRow,${bytes.map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase()).join()}';
}
