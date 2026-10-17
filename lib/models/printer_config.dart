import 'dart:convert';
import 'dart:io';

import 'package:thermal_desk/core/constants.dart';

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
    labelSize: '30x100mm (203dpi)',
    isDefault: true,
  );

  static String? validateIp(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Informe o IP da impressora';
    }
    if (InternetAddress.tryParse(value.trim()) == null) {
      return 'Informe um endereço IP válido';
    }
    return null;
  }

  static String? validatePort(String? value) {
    final port = int.tryParse(value?.trim() ?? '');
    return port == null || port < 1 || port > 65535
        ? 'A porta deve estar entre 1 e 65535'
        : null;
  }

  String? get connectionError =>
      validateIp(ip) ?? validatePort(port.toString());

  PrinterConfig copyWith({
    String? id,
    String? name,
    String? ip,
    int? port,
    int? dpi,
    String? labelSize,
    bool? isDefault,
  }) => PrinterConfig(
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

  factory PrinterConfig.fromJson(Map<String, dynamic> json) {
    final storedDpi = json['dpi'];
    final dpi = [200, 203, 300].contains(storedDpi) ? storedDpi as int : 203;
    final storedSize = json['labelSize'] as String? ?? defaults.labelSize;
    // Normaliza nomes antigos pelo tamanho físico, preservando a mídia salva.
    final dimensions = storedSize.split(' ').first;
    final size = AppConstants.labelSizeForDpi(
      AppConstants.labelSizes.keys.any((key) => key.startsWith('$dimensions '))
          ? storedSize
          : defaults.labelSize,
      dpi,
    );
    return PrinterConfig(
      id: json['id'] as String? ?? 'default',
      name: json['name'] as String? ?? 'Impressora',
      ip: (json['ip'] as String? ?? '').trim(),
      port: json['port'] as int? ?? AppConstants.defaultPort,
      dpi: dpi,
      labelSize: size,
      isDefault: json['isDefault'] as bool? ?? false,
    );
  }

  String toJsonString() => jsonEncode(toJson());
  factory PrinterConfig.fromJsonString(String s) =>
      PrinterConfig.fromJson(jsonDecode(s) as Map<String, dynamic>);
}
