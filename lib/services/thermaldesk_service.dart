import 'dart:async';

import 'package:thermal_desk/core/label_validation.dart';

import 'dart:math' as math;
import 'dart:convert';

import 'package:thermal_desk/models/label_profile.dart';

import 'dart:io';

import 'package:thermal_desk/core/constants.dart';
import 'package:thermal_desk/models/label_job.dart';
import 'package:thermal_desk/models/printer_config.dart';

sealed class ThermalDeskResult<T> {
  const ThermalDeskResult();
}

final class ThermalDeskSuccess<T> extends ThermalDeskResult<T> {
  final T value;
  const ThermalDeskSuccess(this.value);
}

final class ThermalDeskFailure<T> extends ThermalDeskResult<T> {
  final String message;
  const ThermalDeskFailure(this.message);
}

class ThermalDeskService {
  const ThermalDeskService();

  Future<ThermalDeskResult<bool>> testConnection(PrinterConfig cfg) async {
    if (cfg.connectionError case final String message) {
      return ThermalDeskFailure(message);
    }
    Socket? socket;
    try {
      socket = await Socket.connect(
        cfg.ip.trim(),
        cfg.port,
        timeout: AppConstants.connectionTimeout,
      );
      return const ThermalDeskSuccess(true);
    } on TimeoutException {
      return const ThermalDeskFailure('Tempo de conexão excedido.');
    } on SocketException catch (e) {
      return ThermalDeskFailure('Falha de conexão: ${e.message}');
    } catch (_) {
      return const ThermalDeskFailure('Não foi possível testar a impressora.');
    } finally {
      socket?.destroy();
    }
  }

  Future<ThermalDeskResult<bool>> sendZpl(PrinterConfig cfg, String zpl) async {
    if (cfg.connectionError case final String message) {
      return ThermalDeskFailure(message);
    }
    if (zpl.trim().isEmpty) {
      return const ThermalDeskFailure('A etiqueta está vazia.');
    }
    Socket? socket;
    try {
      socket = await Socket.connect(
        cfg.ip.trim(),
        cfg.port,
        timeout: AppConstants.connectionTimeout,
      );
      socket.add(utf8.encode(zpl));
      await socket.flush().timeout(AppConstants.sendTimeout);
      await socket.close().timeout(AppConstants.sendTimeout);
      return const ThermalDeskSuccess(true);
    } on TimeoutException {
      return const ThermalDeskFailure(
        'Tempo de envio excedido. Verifique a impressora.',
      );
    } on SocketException catch (e) {
      return ThermalDeskFailure('Falha de conexão: ${e.message}');
    } catch (_) {
      return const ThermalDeskFailure('Não foi possível enviar a etiqueta.');
    } finally {
      socket?.destroy();
    }
  }

  String buildZpl({
    required String title,
    required String barcode,
    required String subtitle,
    required LabelTemplate template,
    required PrinterConfig cfg,
    String? previousPrice,
    String? newPrice,
    String? expiryDate,
    int copies = 1,
  }) {
    final safeTitle = _sanitize(title);
    final safeSubtitle = _sanitize(subtitle);
    final safeBarcode = _sanitize(barcode).isEmpty
        ? (template == LabelTemplate.qrCode
              ? 'https://exemplo.local'
              : '0000000000000')
        : _sanitize(barcode);
    final safePreviousPrice = _price(previousPrice ?? '').isEmpty
        ? '0,00'
        : _price(previousPrice ?? '');
    final safeNewPrice = _price(newPrice ?? '').isEmpty
        ? '0,00'
        : _price(newPrice ?? '');
    final safeExpiryDate = _sanitize(expiryDate ?? '').isEmpty
        ? ''
        : _sanitize(expiryDate ?? '');
    final safeCopies = copies < 1 ? 1 : copies;

    final zpl = switch (template) {
      LabelTemplate.basic => _buildBasic(safeTitle, safeBarcode),
      LabelTemplate.custom => throw ArgumentError(
        'Use o modelo personalizado para gerar ZPL.',
      ),
      LabelTemplate.product => _buildProduct(
        safeTitle,
        safeBarcode,
        safeSubtitle,
      ),
      LabelTemplate.address => _buildAddress(safeTitle, safeSubtitle),
      LabelTemplate.shipping => _buildShipping(
        safeTitle,
        safeBarcode,
        safeSubtitle,
      ),
      LabelTemplate.inventory => _buildInventory(
        safeTitle,
        safeBarcode,
        safeSubtitle,
      ),
      LabelTemplate.priceTag => _buildPriceTag(
        safeTitle,
        safeBarcode,
        _price(safeSubtitle).isEmpty ? '0,00' : _price(safeSubtitle),
      ),
      LabelTemplate.qrCode => _buildQrCode(
        safeTitle,
        safeBarcode,
        safeSubtitle,
      ),
      LabelTemplate.cable => _buildCable(safeTitle, safeBarcode),
      LabelTemplate.promoShelf => _buildPromoShelf(
        safeTitle,
        safeBarcode,
        safePreviousPrice,
        safeNewPrice,
        safeCopies,
      ),
      LabelTemplate.promoExpiry => _buildPromoExpiry(
        safeTitle,
        safeBarcode,
        safePreviousPrice,
        safeNewPrice,
        safeExpiryDate,
        safeCopies,
      ),
    };
    return _applyProfile(
      zpl,
      cfg,
      promotional:
          template == LabelTemplate.promoShelf ||
          template == LabelTemplate.promoExpiry,
    );
  }

  String _applyProfile(
    String zpl,
    PrinterConfig cfg, {
    required bool promotional,
  }) {
    final profile = LabelProfile.fromConfig(cfg);
    final scale = math.min(
      profile.width / (promotional ? 240 : 400),
      profile.height / (promotional ? 800 : 240),
    );
    int dot(String? value) =>
        math.max(1, ((int.tryParse(value ?? '') ?? 0) * scale).round());
    var output = zpl.replaceAll(RegExp(r'\^PW\d+|\^LL\d+'), '');
    output = output.replaceAllMapped(
      RegExp(r'\^FO(\d+),(\d+)'),
      (m) =>
          '^FO${((int.parse(m[1]!) * scale).round())},${((int.parse(m[2]!) * scale).round())}',
    );
    output = output.replaceAllMapped(
      RegExp(r'\^A0([NR]),(\d+),(\d+)'),
      (m) => '^A0${m[1]},${dot(m[2])},${dot(m[3])}',
    );
    output = output.replaceAllMapped(
      RegExp(r'\^FB(\d+),(\d+),[^,]*,?([LCRJ]?)'),
      (m) => '^FB${dot(m[1])},${m[2]},0,${m[3]!.isEmpty ? 'L' : m[3]}',
    );
    output = output.replaceAllMapped(
      RegExp(r'\^BC([NR]),(\d+)'),
      (m) => '^BC${m[1]},${dot(m[2])}',
    );
    output = output.replaceAllMapped(
      RegExp(r'\^BY(\d+),([^,]+),(\d+)'),
      (m) => '^BY${dot(m[1])},${m[2]},${dot(m[3])}',
    );
    output = output.replaceAllMapped(
      RegExp(r'\^GB(\d+),(\d+),(\d+)'),
      (m) => '^GB${dot(m[1])},${dot(m[2])},${dot(m[3])}',
    );
    output = output.replaceAllMapped(
      RegExp(r'\^BQN,2,(\d+)'),
      (m) => '^BQN,2,${dot(m[1]).clamp(1, 10)}',
    );
    output = output.replaceAllMapped(
      RegExp(r'\^FO(\d+),(\d+)\^BQN,2,(\d+)\^FDLA,([^\^]*)'),
      (match) {
        var module = int.parse(match[3]!);
        try {
          final available = math.min(
            profile.width - int.parse(match[1]!) - 8,
            profile.height - int.parse(match[2]!) - 8,
          );
          module = math
              .min(
                module,
                (available / LabelValidation.qrModules(match[4]!.trimRight()))
                    .floor(),
              )
              .clamp(1, 10);
        } catch (_) {
          module = 1;
        }
        return '^FO${match[1]},${match[2]}^BQN,2,$module^FDLA,${match[4]}';
      },
    );
    output = output.replaceAllMapped(
      RegExp(
        r'\^FO(\d+),(\d+)(?:\^BY(\d+),([^,]+),(\d+))?\^BC([NR]),(\d+),([YN]),([YN]),([YN])\^FD([^\^]*)\^FS',
      ),
      (m) {
        var module = m[3] == null
            ? math.max(1, (2 * scale).round())
            : int.parse(m[3]!);
        try {
          final available =
              (m[6] == 'R'
                  ? profile.height - int.parse(m[2]!)
                  : profile.width - int.parse(m[1]!)) -
              8;
          final modules =
              LabelValidation.code128Modules(m[11]!.trimRight()) + 10;
          module = math.min(module, (available / modules).floor()).clamp(1, 10);
        } catch (_) {
          module = 1;
        }
        return '^FO${m[1]},${m[2]}^BY$module,${m[4] ?? '2'},${m[7]}'
            '^BC${m[6]},${m[7]},${m[8]},${m[9]},${m[10]}^FD${m[11]}^FS';
      },
    );
    return output.replaceFirst(
      '^XA',
      '^XA\n^PW${profile.width}\n^LL${profile.height}\n^BY${math.max(1, (2 * scale).round())},2,${math.max(1, (90 * scale).round())}',
    );
  }

  String _price(String value) =>
      _sanitize(value)
          .replaceFirst(RegExp(r'^R\$\s*', caseSensitive: false), '');

  String _sanitize(String s) =>
      s.replaceAll(RegExp(r'[\^~\x00-\x1f\x7f]'), ' ').trim();

  String _buildBasic(String title, String barcode) =>
      '''
^XA
^MNY
^CI28
^FO20,15^A0N,36,36^FD$title^FS
^FO20,65^BCN,90,Y,N,N^FD$barcode^FS
^XZ'''
          .trim();

  String _buildProduct(String title, String barcode, String subtitle) =>
      '''
^XA
^MNY
^CI28
^FO20,12^A0N,30,30^FB360,2,,L^FD$title^FS
^FO20,58^A0N,22,22^FD$subtitle^FS
^FO20,90^BCN,80,Y,N,N^FD$barcode^FS
^XZ'''
          .trim();

  String _buildAddress(String name, String address) =>
      '''
^XA
^MNY
^CI28
^FO20,15^A0N,28,28^FDDe: $name^FS
^FO20,55^A0N,22,22^FB360,4,,L^FD$address^FS
^XZ'''
          .trim();

  String _buildShipping(String title, String barcode, String ref) =>
      '''
^XA
^MNY
^CI28
^FO20,10^A0N,26,26^FD$title^FS
^FO20,44^A0N,20,20^FDRef: $ref^FS
^FO20,76^BCN,100,Y,N,N^FD$barcode^FS
^XZ'''
          .trim();

  // ══════════════════════════════════════════════════════════════════════════
  // TEMPLATE: INVENTÁRIO - Para controle de estoque
  // ══════════════════════════════════════════════════════════════════════════

  String _buildInventory(String title, String barcode, String location) =>
      '''
^XA
^MNY
^CI28
^FO20,8^A0N,24,24^FB360,2,,L^FD$title^FS
^FO20,45^A0N,18,18^FDLoc: $location^FS
^FO20,70^BCN,70,Y,N,N^FD$barcode^FS
^FO320,8^A0N,16,16^FD#INV^FS
^XZ'''
          .trim();

  // ══════════════════════════════════════════════════════════════════════════
  // TEMPLATE: PREÇO - Etiqueta de preço para gôndola
  // ══════════════════════════════════════════════════════════════════════════

  String _buildPriceTag(String product, String barcode, String price) =>
      '''
^XA
^MNY
^CI28
^FO20,8^A0N,22,22^FB360,2,,L^FD$product^FS
^FO20,50^A0N,40,40^FDR\$ $price^FS
^FO20,100^BCN,60,Y,N,N^FD$barcode^FS
^XZ'''
          .trim();

  // ══════════════════════════════════════════════════════════════════════════
  // TEMPLATE: QR CODE - com texto informativo
  // ══════════════════════════════════════════════════════════════════════════

  String _buildQrCode(String title, String data, String subtitle) {
    return '''
^XA
^MNY
^CI28
^FO20,8^A0N,20,20^FB170,2,,L^FD$title^FS
^FO20,40^A0N,16,16^FB170,3,,L^FD$subtitle^FS
^FO205,30^BQN,2,4^FDLA,$data^FS
^XZ'''
        .trim();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // TEMPLATE: CABO/FIO - Identificação de cabos com texto repetido
  // ══════════════════════════════════════════════════════════════════════════

  String _buildCable(String label, String code) =>
      '''
^XA
^MNY
^CI28
^FO15,10^A0N,24,24^FB370,1,,C^FD$label^FS
^FO15,45^A0N,18,18^FB370,1,,C^FD$code^FS
^FO10,70^GB380,2,2^FS
^FO15,85^A0N,24,24^FB370,1,,C^FD$label^FS
^FO15,120^A0N,18,18^FB370,1,,C^FD$code^FS
^XZ'''
          .trim();

  String _buildPromoShelf(
    String product,
    String barcode,
    String previousPrice,
    String newPrice,
    int copies,
  ) =>
      '''
^XA
^CI28
^PW240
^LL800
^LH0,0
^LS0
^FWN
^FO110,40^A0R,28,28^FB600,2,0,L^FD$product^FS
^FO140,280^A0R,28,28^FB600,2,0,L^FDEAN: $barcode^FS
^FO18,40^A0R,60,60^FB600,1,0,L^FDDe R\$ $previousPrice^FS
^FO105,357^BY3,2,85^BCR,70,N,N,N^FD$barcode^FS
^FO5,340^GB100,400,100,B,0^FS
^FO15,369^A0R,60,60^FR^FDPor R\$ $newPrice^FS
^PQ$copies,0,1,N
^XZ'''
          .trim();

  String _buildPromoExpiry(
    String product,
    String barcode,
    String previousPrice,
    String newPrice,
    String expiryDate,
    int copies,
  ) =>
      '''
^XA
^CI28
^PW240
^LL800
^LH0,0
^LS0
^FWN
^FO110,40^A0R,28,28^FB600,2,0,L^FD$product^FS
^FO90,40^A0R,22,22^FB600,2,0,L^FDPROXIMO AO VENCIMENTO:^FS
^FO65,40^A0R,22,22^FB600,2,0,L^FD$expiryDate^FS
^FO140,280^A0R,28,28^FB600,2,0,L^FD$barcode^FS
^FO18,40^A0R,60,60^FB600,1,0,L^FDDe R\$ $previousPrice^FS
^FO105,357^BY3,2,85^BCR,17,N,N,N^FD$barcode^FS
^FO5,340^GB100,400,100,B,0^FS
^FO15,369^A0R,60,60^FR^FDPor R\$ $newPrice^FS
^PQ$copies,0,1,N
^XZ'''
          .trim();
}
