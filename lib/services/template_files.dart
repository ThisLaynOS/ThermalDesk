import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:thermal_desk/models/custom_label.dart';

final templateFilesProvider = Provider((ref) => const TemplateFiles());

class TemplateFiles {
  const TemplateFiles();

  Future<CustomLabel?> importLabel() async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['json'],
      dialogTitle: 'Importar template ThermalDesk',
    );
    if (file == null) return null;
    final size = await file.length();
    if (size != null && size > CustomLabel.maxBytes) {
      throw const FormatException('O arquivo excede 256 KB.');
    }
    final bytes = BytesBuilder(copy: false);
    await for (final part in file.readAsByteStream()) {
      if (bytes.length + part.length > CustomLabel.maxBytes) {
        throw const FormatException('O arquivo excede 256 KB.');
      }
      bytes.add(part);
    }
    return CustomLabel.decode(
      utf8.decode(bytes.takeBytes()),
      newIdentity: true,
    );
  }

  Future<bool> exportLabel(CustomLabel label) =>
      _save(label.name, '.thermaldesk.json', label.encode());
  Future<bool> exportZpl(String name, String zpl) => _save(name, '.zpl', zpl);

  Future<bool> _save(String name, String extension, String content) async {
    final safe = name
        .replaceAll(RegExp(r'[^\p{L}\p{N}_ -]', unicode: true), '_')
        .trim();
    final file = await FilePicker.saveFile(
      fileName: '${safe.isEmpty ? 'etiqueta' : safe}$extension',
      dialogTitle: 'Exportar etiqueta',
      bytes: Uint8List.fromList(utf8.encode(content)),
      type: FileType.custom,
      allowedExtensions: [extension.split('.').last],
    );
    return file != null;
  }
}
