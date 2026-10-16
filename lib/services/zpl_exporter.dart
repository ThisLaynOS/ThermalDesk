import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:thermal_desk/ui/widgets/modern_snackbar.dart';

/// Utilitário para exportar arquivos ZPL
class ZplExporter {
  static final _dateFormat = DateFormat('yyyyMMdd_HHmmss_SSS');

  static String safeFilename(String value) {
    var name = value
        .replaceAll('\\', '/')
        .split('/')
        .last
        .replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1f]'), '_')
        .trim();
    if (name.isEmpty || name == '.' || name == '..') name = 'etiqueta';
    if (!name.toLowerCase().endsWith('.zpl')) name = '$name.zpl';
    return name;
  }

  /// Copia ZPL para área de transferência
  static Future<void> copyToClipboard(BuildContext context, String zpl) async {
    await Clipboard.setData(ClipboardData(text: zpl));
    if (context.mounted) {
      ModernSnackbar.show(
        context,
        message: 'ZPL copiado para a área de transferência',
        type: SnackType.info,
      );
    }
  }

  /// Salva ZPL como arquivo (Desktop only)
  static Future<void> saveToFile(
    BuildContext context,
    String zpl, {
    String? filename,
  }) async {
    try {
      // Gerar nome de arquivo
      final timestamp = _dateFormat.format(DateTime.now());
      final name = safeFilename(filename ?? 'etiqueta_$timestamp.zpl');

      // No Windows/Desktop, salvar em Documents
      if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
        final home =
            Platform.environment['USERPROFILE'] ??
            Platform.environment['HOME'] ??
            '.';
        final documentsPath = '$home/Documents/ThermalDesk';

        // Criar pasta se não existir
        final dir = Directory(documentsPath);
        if (!await dir.exists()) {
          await dir.create(recursive: true);
        }

        // Salvar arquivo
        final file = File('$documentsPath/$name');
        await file.writeAsString(zpl);

        if (context.mounted) {
          ModernSnackbar.success(context, 'Salvo em: $documentsPath/$name');
        }
      } else {
        // Mobile: apenas copiar
        await copyToClipboard(context, zpl);
      }
    } catch (e) {
      if (context.mounted) {
        ModernSnackbar.error(context, 'Erro ao salvar: $e');
      }
    }
  }

  /// Exporta múltiplos ZPLs como um único arquivo
  static Future<void> exportBatch(
    BuildContext context,
    List<String> zpls, {
    String? filename,
  }) async {
    final combined = zpls.join('\n\n');
    final timestamp = _dateFormat.format(DateTime.now());
    await saveToFile(
      context,
      combined,
      filename: filename ?? 'lote_$timestamp.zpl',
    );
  }
}

/// Dialog para mostrar e exportar ZPL
class ZplViewerDialog extends StatelessWidget {
  final String zpl;
  final String? title;

  const ZplViewerDialog({super.key, required this.zpl, this.title});

  static Future<void> show(BuildContext context, String zpl, {String? title}) {
    return showDialog(
      context: context,
      builder: (_) => ZplViewerDialog(zpl: zpl, title: title),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.code),
          const SizedBox(width: 8),
          Text(title ?? 'Código ZPL'),
        ],
      ),
      content: SizedBox(
        width: 500,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              constraints: const BoxConstraints(maxHeight: 300),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: colorScheme.outlineVariant),
              ),
              child: SingleChildScrollView(
                child: SelectableText(
                  zpl,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    color: colorScheme.onSurface,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${zpl.length} caracteres',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                Row(
                  children: [
                    OutlinedButton.icon(
                      icon: const Icon(Icons.copy, size: 18),
                      label: const Text('Copiar'),
                      onPressed: () =>
                          ZplExporter.copyToClipboard(context, zpl),
                    ),
                    const SizedBox(width: 8),
                    if (Platform.isWindows ||
                        Platform.isLinux ||
                        Platform.isMacOS)
                      FilledButton.icon(
                        icon: const Icon(Icons.save_alt, size: 18),
                        label: const Text('Salvar'),
                        onPressed: () => ZplExporter.saveToFile(context, zpl),
                      ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Fechar'),
        ),
      ],
    );
  }
}
