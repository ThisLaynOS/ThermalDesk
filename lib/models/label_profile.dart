import 'dart:math' as math;

import 'package:thermal_desk/core/constants.dart';
import 'package:thermal_desk/models/printer_config.dart';
import 'package:thermal_desk/models/label_job.dart';

/// Área de impressão em dots, partilhada pelo ZPL e pelos previews.
class LabelProfile {
  final int width;
  final int height;
  final int dpi;

  const LabelProfile(this.width, this.height, this.dpi);

  factory LabelProfile.fromConfig(PrinterConfig config) {
    final dpi = [200, 203, 300].contains(config.dpi) ? config.dpi : 203;
    final dimensions = RegExp(r'^(\d+)x(\d+)mm').firstMatch(config.labelSize);
    final prefix = dimensions == null ? '30x100mm' : dimensions.group(0)!;
    final profile = AppConstants.labelSizes.entries
        .where(
          (entry) => entry.key.startsWith('$prefix ') && entry.value.dpi == dpi,
        )
        .firstOrNull;
    if (profile != null) {
      return LabelProfile(profile.value.w, profile.value.h, dpi);
    }
    final widthMm = int.parse(dimensions?.group(1) ?? '30');
    final heightMm = int.parse(dimensions?.group(2) ?? '100');
    return LabelProfile(
      (widthMm * dpi / 25.4).round(),
      (heightMm * dpi / 25.4).round(),
      dpi,
    );
  }

  double templateScale(LabelTemplate template) =>
      template == LabelTemplate.priceTag
      ? math.min(width / 400, height / 240)
      : math.min(width / 240, height / 800);

  double get availableQrDots {
    final scale = templateScale(LabelTemplate.qrCode);
    return math
        .min(
          (224 * scale).round() - (56 * scale).round() - 8,
          (195 * scale).round() - (30 * scale).round() - 8,
        )
        .toDouble();
  }

  double get availableBarcodeDots {
    final scale = math.min(width / 400, height / 240);
    return width - (20 * scale).round() - 8.0;
  }

  double barcodeDotsFor(LabelTemplate template) {
    if (template == LabelTemplate.priceTag) return availableBarcodeDots;
    if (template == LabelTemplate.qrCode) return availableQrDots;
    final scale = templateScale(template);
    return height - (25 * scale).round() - 8.0;
  }

  // A API suporta 8 e 12 dpmm; as dimensões em inches preservam os dots.
  int get previewDpmm => dpi == 300 ? 12 : 8;
  // Labelary usa DPI inteiro (203/304) e trunca o número de pixels.
  // A margem subpixel evita perder uma linha ao arredondar o URL.
  int get previewDpi => (previewDpmm * 25.4).floor();
  double get widthInches => (width + .01) / previewDpi;
  double get heightInches => (height + .01) / previewDpi;
  double get aspectRatio => width / height;
}
