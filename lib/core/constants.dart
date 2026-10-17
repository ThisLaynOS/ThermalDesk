abstract class AppConstants {
  static const defaultPort = 9100;
  static const connectionTimeout = Duration(seconds: 3);
  static const sendTimeout = Duration(seconds: 5);
  static const maxHistoryItems = 100;

  // ZPL label sizes in dots
  // Perfil de 203 DPI (aproximadamente 8 dots/mm)
  // Para etiquetas compridas (30x100mm): w=largura física, h=comprimento físico
  // A rotação do conteúdo é feita automaticamente nos templates
  static const labelSizes = {
    '50x30mm (203dpi)': (w: 406, h: 243, dpi: 203),
    '50x30mm (200dpi)': (w: 400, h: 240, dpi: 200),
    '50x30mm (300dpi)': (w: 600, h: 360, dpi: 300),
    '30x100mm (203dpi)': (w: 243, h: 812, dpi: 203),
    '30x100mm (200dpi)': (w: 240, h: 800, dpi: 200),
    '30x100mm (300dpi)': (w: 360, h: 1200, dpi: 300),
    '100x50mm (203dpi)': (w: 812, h: 406, dpi: 203),
    '100x50mm (200dpi)': (w: 800, h: 400, dpi: 200),
    '100x50mm (300dpi)': (w: 1200, h: 600, dpi: 300),
    '102x152mm (203dpi)': (w: 827, h: 1234, dpi: 203),
    '102x152mm (200dpi)': (w: 816, h: 1218, dpi: 200),
    '102x152mm (300dpi)': (w: 1224, h: 1824, dpi: 300),
  };

  static String labelSizeForDpi(String current, int dpi) {
    final dimensions = current.split(' ').first;
    return labelSizes.entries
        .firstWhere(
          (e) => e.key.startsWith('$dimensions ') && e.value.dpi == dpi,
          orElse: () =>
              labelSizes.entries.firstWhere((e) => e.value.dpi == dpi),
        )
        .key;
  }

  static const barcodeTypes = [
    'Code128',
    'EAN13',
    'QRCode',
    'Code39',
    'DataMatrix',
  ];
}
