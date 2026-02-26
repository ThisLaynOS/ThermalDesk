import 'dart:convert';

class PrinterConfig {
  final String id;
  final String name;
  final String ip;
  final int port;
  final int dpi;
  final String labelSize;
  final bool isDefault;

  const PrinterConfig({
    required this.id,
    required this.name,
    required this.ip,
    required this.port,
    required this.dpi,
    required this.labelSize,
    this.isDefault = false,
  });

  static const defaults = PrinterConfig(
    id: 'default',
    name: 'Impressora Principal',
    ip: '',
    port: 9100,
    dpi: 203,
    labelSize: '30x100mm (203dpi S4M)',
    isDefault: true,
  );

  PrinterConfig copyWith({
    String? id,
    String? name,
    String? ip,
    int? port,
    int? dpi,
    String? labelSize,
    bool? isDefault,
  }) =>
      PrinterConfig(
        id: id ?? this.id,
        name: name ?? this.name,
        ip: ip ?? this.ip,
        port: port ?? this.port,
        dpi: dpi ?? this.dpi,
        labelSize: labelSize ?? this.labelSize,
        isDefault: isDefault ?? this.isDefault,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'ip': ip,
        'port': port,
        'dpi': dpi,
        'labelSize': labelSize,
        'isDefault': isDefault,
      };

  factory PrinterConfig.fromJson(Map<String, dynamic> json) => PrinterConfig(
        id: json['id'] as String? ?? 'default',
        name: json['name'] as String? ?? 'Impressora',
        ip: json['ip'] as String? ?? '',
        port: json['port'] as int? ?? 9100,
        dpi: json['dpi'] as int? ?? 203,
        labelSize: json['labelSize'] as String? ?? '30x100mm (203dpi S4M)',
        isDefault: json['isDefault'] as bool? ?? false,
      );

  String toJsonString() => jsonEncode(toJson());
  factory PrinterConfig.fromJsonString(String s) =>
      PrinterConfig.fromJson(jsonDecode(s) as Map<String, dynamic>);
}
