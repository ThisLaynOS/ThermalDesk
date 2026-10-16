import 'package:thermal_desk/core/label_validation.dart';
import 'package:thermal_desk/models/label_profile.dart';

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:thermal_desk/core/constants.dart';
import 'package:thermal_desk/models/label_job.dart';
import 'package:thermal_desk/models/printer_config.dart';
import 'package:thermal_desk/services/thermaldesk_service.dart';

void main() {
  const service = ThermalDeskService();
  const config = PrinterConfig.defaults;

  test('Todos os templates preservam UTF-8 e delimitadores ZPL', () {
    for (final template in LabelTemplate.values.where(
      (t) => t != LabelTemplate.custom,
    )) {
      final zpl = service.buildZpl(
        title: 'Produto Exemplo — ação',
        barcode: '0000000000000',
        subtitle: 'Item Genérico',
        template: template,
        cfg: config,
      );
      expect(zpl, startsWith('^XA'));
      expect(zpl, endsWith('^XZ'));
      expect(zpl, contains('^CI28'));
      expect(zpl, contains('Produto Exemplo — ação'));
    }
  });

  test('Predefinições genéricas e perfis de resolução disponíveis', () {
    expect(config.ip, isEmpty);
    expect(config.port, 9100);
    expect(
      AppConstants.labelSizes.values.map((s) => s.dpi).toSet(),
      containsAll([200, 203, 300]),
    );
    String build(LabelTemplate template) => service.buildZpl(
      title: 'Produto Exemplo',
      barcode: '',
      subtitle: '',
      template: template,
      cfg: config,
    );
    expect(build(LabelTemplate.product), contains('^BCN'));
    expect(build(LabelTemplate.product), contains('0000000000000'));
    expect(build(LabelTemplate.product), contains('^FB'));
    expect(build(LabelTemplate.qrCode), contains('https://exemplo.local'));
    expect(build(LabelTemplate.priceTag), contains(r'R$ 0,00'));
    expect(build(LabelTemplate.promoShelf), contains(r'Por R$ 0,00'));
  });

  test('Tamanho e resolução são aplicados ao ZPL de todos os templates', () {
    for (final entry in AppConstants.labelSizes.entries) {
      final cfg = config.copyWith(labelSize: entry.key, dpi: entry.value.dpi);
      for (final template in LabelTemplate.values.where(
        (t) => t != LabelTemplate.custom,
      )) {
        final zpl = service.buildZpl(
          title: 'Produto Exemplo',
          barcode: '',
          subtitle: '',
          template: template,
          cfg: cfg,
        );
        expect(zpl, contains('^PW${entry.value.w}'));
        expect(zpl, contains('^LL${entry.value.h}'));
        expect(RegExp(r'\^PW').allMatches(zpl).length, 1);
        expect(RegExp(r'\^LL').allMatches(zpl).length, 1);
      }
    }
  });

  test('Campos de código de barras não injetam comandos ZPL', () {
    final zpl = service.buildZpl(
      title: 'Item Genérico',
      barcode: 'ABC^XZ~JA',
      subtitle: '',
      template: LabelTemplate.product,
      cfg: config,
    );
    expect(RegExp(r'\^XZ').allMatches(zpl).length, 1);
    expect(zpl, isNot(contains('~JA')));
    final price = service.buildZpl(
      title: 'Item Genérico',
      barcode: '',
      subtitle: r'R$ 0,00',
      template: LabelTemplate.priceTag,
      cfg: config,
    );
    expect(price, contains(r'R$ 0,00'));
    expect(price, isNot(contains(r'R$ R$')));
  });

  test(
    'Destino inválido e envio vazio falham antes de abrir o socket',
    () async {
      expect(
        await service.sendZpl(config, '^XA^XZ'),
        isA<ThermalDeskFailure>(),
      );
      expect(PrinterConfig.validatePort('0'), isNotNull);
      expect(PrinterConfig.validatePort('65536'), isNotNull);
      expect(PrinterConfig.validatePort('9100'), isNull);
      expect(PrinterConfig.validateIp('invalid'), isNotNull);
    },
  );

  test(
    'Code128 cabe na etiqueta ou impede a impressão num perfil incompatível',
    () {
      const data = '0000000000000';
      for (final entry in AppConstants.labelSizes.entries) {
        final config = PrinterConfig.defaults.copyWith(
          labelSize: entry.key,
          dpi: entry.value.dpi,
        );
        final profile = LabelProfile.fromConfig(config);
        for (final template in LabelTemplate.values.where(
          (t) => t != LabelTemplate.custom,
        )) {
          final zpl = service.buildZpl(
            title: 'Produto Exemplo',
            barcode: data,
            subtitle: '',
            template: template,
            cfg: config,
          );
          for (final field in RegExp(
            r'\^FO(\d+),(\d+)\^BY(\d+),[^\^]*\^BC([NR])',
          ).allMatches(zpl)) {
            final start = int.parse(field[field[4] == 'R' ? 2 : 1]!);
            final max = field[4] == 'R' ? profile.height : profile.width;
            final extent =
                start +
                (LabelValidation.code128Modules(data) + 10) *
                    int.parse(field[3]!);
            if (extent > max) {
              expect(
                LabelValidation.barcode(
                  data,
                  qr: false,
                  availableDots: profile.availableBarcodeDots(
                    promotional:
                        template == LabelTemplate.promoShelf ||
                        template == LabelTemplate.promoExpiry,
                  ),
                ),
                isNotNull,
              );
            } else {
              expect(extent, lessThanOrEqualTo(max));
            }
          }
        }
      }
    },
  );

  test('Envio TCP usa o destino configurado e preserva bytes UTF-8', () async {
    final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(server.close);
    final received = server.first.then((socket) async {
      final bytes = await socket.fold<List<int>>(
        [],
        (data, chunk) => data..addAll(chunk),
      );
      socket.destroy();
      return bytes;
    });
    final destination = config.copyWith(
      ip: server.address.address,
      port: server.port,
    );
    const payload = '^XA^CI28^FDProduto Exemplo — ação^FS^XZ';
    final result = await service.sendZpl(destination, payload);
    expect(result, isA<ThermalDeskSuccess<bool>>());
    expect(
      await received.timeout(const Duration(seconds: 5)),
      utf8.encode(payload),
    );
  });
}
