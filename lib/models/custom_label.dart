import 'dart:convert';
import 'dart:math' as math;

import 'package:thermal_desk/core/label_validation.dart';
import 'package:thermal_desk/models/label_profile.dart';
import 'package:uuid/uuid.dart';

enum LabelElementType { text, barcode, qr, box, line }

extension LabelElementTypeName on LabelElementType {
  String get label => switch (this) {
    LabelElementType.text => 'Texto',
    LabelElementType.barcode => 'Código de barras',
    LabelElementType.qr => 'QR Code',
    LabelElementType.box => 'Caixa',
    LabelElementType.line => 'Linha',
  };
  bool get hasContent =>
      this == LabelElementType.text ||
      this == LabelElementType.barcode ||
      this == LabelElementType.qr;
}

/// Coordenadas físicas em mm: o modelo pode ser usado em diferentes DPIs.
class LabelElement {
  final String id, content, fieldName, alignment;
  final LabelElementType type;
  final double x, y, width, height, fontSize, thickness;
  final bool editable;

  const LabelElement({
    required this.id,
    required this.type,
    this.x = 2,
    this.y = 2,
    this.width = 40,
    this.height = 6,
    this.content = '',
    this.fieldName = '',
    this.editable = false,
    this.fontSize = 4,
    this.thickness = .3,
    this.alignment = 'L',
  });

  LabelElement copyWith({
    String? id,
    String? content,
    String? fieldName,
    String? alignment,
    double? x,
    double? y,
    double? width,
    double? height,
    double? fontSize,
    double? thickness,
    bool? editable,
  }) => LabelElement(
    id: id ?? this.id,
    type: type,
    x: x ?? this.x,
    y: y ?? this.y,
    width: width ?? this.width,
    height: height ?? this.height,
    content: content ?? this.content,
    fieldName: fieldName ?? this.fieldName,
    fontSize: fontSize ?? this.fontSize,
    thickness: thickness ?? this.thickness,
    alignment: alignment ?? this.alignment,
    editable: editable ?? this.editable,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.name,
    'x': x,
    'y': y,
    'width': width,
    'height': height,
    'content': content,
    'fieldName': fieldName,
    'editable': editable,
    'fontSize': fontSize,
    'thickness': thickness,
    'alignment': alignment,
  };

  factory LabelElement.fromJson(Map<String, dynamic> j) {
    final type = LabelElementType.values
        .where((v) => v.name == j['type'])
        .firstOrNull;
    if (type == null) {
      throw const FormatException('Tipo de elemento desconhecido.');
    }
    if (j['editable'] is! bool || !['L', 'C', 'R'].contains(j['alignment'])) {
      throw const FormatException('Propriedades do elemento inválidas.');
    }
    return LabelElement(
      id: _string(j, 'id', 80),
      type: type,
      x: _number(j, 'x', 0, 300),
      y: _number(j, 'y', 0, 300),
      width: _number(j, 'width', .2, 300),
      height: _number(j, 'height', .2, 300),
      fontSize: _number(j, 'fontSize', 1, 40),
      thickness: _number(j, 'thickness', .1, 10),
      content: _string(j, 'content', 1024, empty: true),
      fieldName: _string(j, 'fieldName', 60, empty: true),
      editable: j['editable'] as bool,
      alignment: j['alignment'] as String,
    );
  }
}

class CustomLabel {
  static const format = 'thermaldesk.label';
  static const version = 1;
  static const maxBytes = 256 * 1024;
  static const maxElements = 50;
  final String id, name;
  final double widthMm, heightMm;
  final List<LabelElement> elements;

  CustomLabel({
    required this.id,
    required this.name,
    required this.widthMm,
    required this.heightMm,
    required List<LabelElement> elements,
  }) : elements = List.unmodifiable(elements);

  factory CustomLabel.blank() => CustomLabel(
    id: const Uuid().v4(),
    name: 'Minha etiqueta',
    widthMm: 60,
    heightMm: 40,
    elements: [],
  );

  CustomLabel copyWith({
    String? id,
    String? name,
    double? widthMm,
    double? heightMm,
    List<LabelElement>? elements,
  }) => CustomLabel(
    id: id ?? this.id,
    name: name ?? this.name,
    widthMm: widthMm ?? this.widthMm,
    heightMm: heightMm ?? this.heightMm,
    elements: elements ?? this.elements,
  );

  Map<String, dynamic> toJson() => {
    'format': format,
    'version': version,
    'id': id,
    'name': name,
    'widthMm': widthMm,
    'heightMm': heightMm,
    'elements': elements.map((e) => e.toJson()).toList(),
  };
  String encode() => const JsonEncoder.withIndent('  ').convert(toJson());

  /// Apenas um documento declarativo; nunca importa ZPL executável ou rede.
  factory CustomLabel.decode(String raw, {bool newIdentity = false}) {
    if (raw.length > maxBytes || utf8.encode(raw).length > maxBytes) {
      throw const FormatException('O arquivo excede 256 KB.');
    }
    try {
      final j = jsonDecode(raw);
      if (j is! Map<String, dynamic> ||
          j['format'] != format ||
          j['version'] != version) {
        throw const FormatException(
          'Use um modelo ThermalDesk versão 1 (.thermaldesk.json).',
        );
      }
      final entries = j['elements'];
      if (entries is! List || entries.length > maxElements) {
        throw const FormatException('Use até 50 elementos por etiqueta.');
      }
      final elements = entries
          .map((e) => LabelElement.fromJson(e as Map<String, dynamic>))
          .toList();
      if (elements.map((e) => e.id).toSet().length != elements.length) {
        throw const FormatException('Identificadores de elementos repetidos.');
      }
      final label = CustomLabel(
        id: _string(j, 'id', 80),
        name: _string(j, 'name', 80),
        widthMm: _number(j, 'widthMm', 10, 200),
        heightMm: _number(j, 'heightMm', 10, 300),
        elements: elements,
      );
      if (elements.any(
        (e) =>
            e.x + e.width > label.widthMm + .001 ||
            e.y + e.height > label.heightMm + .001,
      )) {
        throw const FormatException('Há elementos fora da etiqueta.');
      }
      return newIdentity ? label.copyWith(id: const Uuid().v4()) : label;
    } on FormatException {
      rethrow;
    } catch (_) {
      throw const FormatException('Arquivo de modelo inválido.');
    }
  }

  LabelProfile profile(int dpi) {
    if (![200, 203, 300].contains(dpi)) throw ArgumentError('DPI inválido');
    return LabelProfile(
      (widthMm * dpi / 25.4).round(),
      (heightMm * dpi / 25.4).round(),
      dpi,
    );
  }

  String valueOf(LabelElement element, Map<String, String> values) =>
      element.editable
      ? values[element.id] ?? element.content
      : element.content;

  List<String> issues(int dpi, {Map<String, String> values = const {}}) {
    final result = <String>[];
    if (name.trim().isEmpty) result.add('Dê um nome ao template.');
    if (elements.isEmpty) result.add('Adicione pelo menos um elemento.');
    final dots = dpi / 25.4;
    for (var i = 0; i < elements.length; i++) {
      final e = elements[i];
      final prefix = '${i + 1}. ${e.type.label}: ';
      final content = valueOf(e, values);
      if (e.x < 0 ||
          e.y < 0 ||
          e.x + e.width > widthMm + .001 ||
          e.y + e.height > heightMm + .001) {
        result.add('${prefix}fora dos limites da etiqueta.');
      }
      if (e.type.hasContent && content.trim().isEmpty) {
        result.add('${prefix}preencha o conteúdo.');
        continue;
      }
      if (content.length > 1024 ||
          RegExp(r'[\x00-\x1f\x7f]').hasMatch(content)) {
        result.add(
          '${prefix}use até 1024 caracteres, sem caracteres de controle.',
        );
        continue;
      }
      if (e.editable && e.fieldName.trim().isEmpty) {
        result.add('${prefix}dê um nome ao campo editável.');
      }
      if (e.type == LabelElementType.text && e.fontSize > e.height) {
        result.add('${prefix}a fonte é maior que a altura do texto.');
      }
      if (e.type == LabelElementType.box &&
          e.thickness > math.min(e.width, e.height) / 2) {
        result.add('${prefix}reduza a espessura da borda.');
      }
      if (e.type == LabelElementType.barcode || e.type == LabelElementType.qr) {
        final qr = e.type == LabelElementType.qr;
        final error = LabelValidation.barcode(content, qr: qr);
        if (error != null) {
          result.add('$prefix$error');
          continue;
        }
        final modules = qr
            ? LabelValidation.qrModules(content) + 8
            : LabelValidation.code128Modules(content) + 20;
        final available = qr ? math.min(e.width, e.height) : e.width;
        if ((available * dots).round() < modules) {
          result.add('${prefix}aumente o tamanho para este conteúdo.');
        }
        if (!qr && e.height < 6) {
          result.add('${prefix}use altura de pelo menos 6 mm.');
        }
      }
    }
    return result;
  }

  String buildZpl(
    int dpi, {
    Map<String, String> values = const {},
    int copies = 1,
    bool validate = true,
  }) {
    final errors = issues(dpi, values: values);
    if (validate && errors.isNotEmpty) throw FormatException(errors.first);
    if (copies < 1 || copies > 1000) {
      throw const FormatException('Use de 1 a 1000 cópias.');
    }
    final p = profile(dpi), d = dpi / 25.4;
    int dot(double mm) => (mm * d).round();
    final out = StringBuffer(
      '^XA\n^CI28\n^PW${p.width}\n^LL${p.height}\n^LH0,0\n',
    );
    for (final e in elements) {
      final value = valueOf(e, values);
      var x = dot(e.x), y = dot(e.y);
      final w = dot(e.width), h = dot(e.height);
      final fd = utf8
          .encode(value)
          .map((b) => '_${b.toRadixString(16).padLeft(2, '0').toUpperCase()}')
          .join();
      switch (e.type) {
        case LabelElementType.text:
          final font = math.max(1, dot(e.fontSize));
          out.writeln(
            '^FO$x,$y^A0N,$font,$font^FB$w,${math.max(1, h ~/ font)},0,${e.alignment},0^FH_^FD$fd^FS',
          );
        case LabelElementType.barcode:
          try {
            final module = (w ~/ (LabelValidation.code128Modules(value) + 20))
                .clamp(1, 10);
            x += 10 * module;
            out.writeln(
              '^FO$x,$y^A0N,${dot(2.5)},${dot(2.5)}^BY$module,2^BCN,${math.max(1, h - dot(3.5))},Y,N,N^FH_^FD$fd^FS',
            );
          } catch (_) {
            /* Conteúdo inválido é sinalizado pela UI. */
          }
        case LabelElementType.qr:
          try {
            final module =
                (math.min(w, h) ~/ (LabelValidation.qrModules(value) + 8))
                    .clamp(1, 10);
            x += 4 * module;
            y += 4 * module;
            out.writeln('^FO$x,$y^BQN,2,$module^FH_^FDLA,$fd^FS');
          } catch (_) {
            /* Conteúdo inválido é sinalizado pela UI. */
          }
        case LabelElementType.box:
          out.writeln('^FO$x,$y^GB$w,$h,${math.max(1, dot(e.thickness))}^FS');
        case LabelElementType.line:
          out.writeln('^FO$x,$y^GB$w,$h,${math.max(w, h)}^FS');
      }
    }
    out.writeln('^PQ$copies\n^XZ');
    return out.toString();
  }
}

String _string(
  Map<String, dynamic> j,
  String key,
  int max, {
  bool empty = false,
}) {
  final value = j[key];
  if (value is! String ||
      value.length > max ||
      (!empty && value.trim().isEmpty) ||
      RegExp(r'[\x00-\x1f\x7f]').hasMatch(value)) {
    throw FormatException('Campo "$key" inválido.');
  }
  return value;
}

double _number(Map<String, dynamic> j, String key, double min, double max) {
  final value = j[key];
  if (value is! num || !value.isFinite || value < min || value > max) {
    throw FormatException('Medida "$key" inválida.');
  }
  return value.toDouble();
}
