import 'dart:convert';
import 'dart:io';
import 'package:zebra_label_pro/core/constants.dart';
import 'package:zebra_label_pro/models/label_job.dart';
import 'package:zebra_label_pro/models/printer_config.dart';

sealed class ZebraResult<T> {
  const ZebraResult();
}

final class ZebraSuccess<T> extends ZebraResult<T> {
  final T value;
  const ZebraSuccess(this.value);
}

final class ZebraFailure<T> extends ZebraResult<T> {
  final String message;
  const ZebraFailure(this.message);
}

class ZebraService {
  const ZebraService();

  Future<ZebraResult<bool>> testConnection(PrinterConfig cfg) async {
    try {
      final socket = await Socket.connect(
        cfg.ip,
        cfg.port,
        timeout: AppConstants.connectionTimeout,
      );
      socket.destroy();
      return const ZebraSuccess(true);
    } on SocketException catch (e) {
      return ZebraFailure('Socket error: ${e.message}');
    } catch (e) {
      return ZebraFailure('Erro inesperado: $e');
    }
  }

  Future<ZebraResult<bool>> sendZpl(PrinterConfig cfg, String zpl) async {
    try {
      final socket = await Socket.connect(
        cfg.ip,
        cfg.port,
        timeout: AppConstants.sendTimeout,
      );
      socket.add(utf8.encode(zpl));
      await socket.flush();
      await socket.close();
      return const ZebraSuccess(true);
    } on SocketException catch (e) {
      return ZebraFailure('Falha de conexão: ${e.message}');
    } catch (e) {
      return ZebraFailure('Erro ao enviar ZPL: $e');
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
    final safeBarcode = barcode.trim().isEmpty ? '0000000000000' : barcode.trim();
    final safePreviousPrice = _sanitize(previousPrice ?? '').isEmpty
        ? '0,00'
        : _sanitize(previousPrice ?? '');
    final safeNewPrice = _sanitize(newPrice ?? '').isEmpty
        ? '0,00'
        : _sanitize(newPrice ?? '');
    final safeExpiryDate = _sanitize(expiryDate ?? '').isEmpty
      ? '03/2026'
      : _sanitize(expiryDate ?? '');
    final safeCopies = copies < 1 ? 1 : copies;

    return switch (template) {
      LabelTemplate.basic => _buildBasic(safeTitle, safeBarcode),
      LabelTemplate.product =>
        _buildProduct(safeTitle, safeBarcode, safeSubtitle),
      LabelTemplate.address => _buildAddress(safeTitle, safeSubtitle),
      LabelTemplate.shipping =>
        _buildShipping(safeTitle, safeBarcode, safeSubtitle),
      LabelTemplate.inventory =>
        _buildInventory(safeTitle, safeBarcode, safeSubtitle),
      LabelTemplate.priceTag =>
        _buildPriceTag(safeTitle, safeBarcode, safeSubtitle),
      LabelTemplate.qrCode =>
        _buildQrCode(safeTitle, safeBarcode, safeSubtitle),
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
  }

  String _sanitize(String s) => s.replaceAll('^', '').replaceAll('~', '').trim();

  String _buildBasic(String title, String barcode) => '''
^XA
^MNY
^CI28
^FO20,15^A0N,36,36^FD$title^FS
^FO20,65^BCN,90,Y,N,N^FD$barcode^FS
^XZ'''.trim();

  String _buildProduct(String title, String barcode, String subtitle) => '''
^XA
^MNY
^CI28
^FO20,12^A0N,30,30^FB360,2,,L^FD$title^FS
^FO20,58^A0N,22,22^FD$subtitle^FS
^FO20,90^BCN,80,Y,N,N^FD$barcode^FS
^XZ'''.trim();

  String _buildAddress(String name, String address) => '''
^XA
^MNY
^CI28
^FO20,15^A0N,28,28^FDDe: $name^FS
^FO20,55^A0N,22,22^FB360,4,,L^FD$address^FS
^XZ'''.trim();

  String _buildShipping(String title, String barcode, String ref) => '''
^XA
^MNY
^CI28
^FO20,10^A0N,26,26^FD$title^FS
^FO20,44^A0N,20,20^FDRef: $ref^FS
^FO20,76^BCN,100,Y,N,N^FD$barcode^FS
^XZ'''.trim();

  // ══════════════════════════════════════════════════════════════════════════
  // TEMPLATE: INVENTÁRIO - Para controle de estoque
  // ══════════════════════════════════════════════════════════════════════════
  
  String _buildInventory(String title, String barcode, String location) => '''
^XA
^MNY
^CI28
^FO20,8^A0N,24,24^FB360,2,,L^FD$title^FS
^FO20,45^A0N,18,18^FDLoc: $location^FS
^FO20,70^BCN,70,Y,N,N^FD$barcode^FS
^FO320,8^A0N,16,16^FD#INV^FS
^XZ'''.trim();

  // ══════════════════════════════════════════════════════════════════════════
  // TEMPLATE: PREÇO - Etiqueta de preço para gôndola
  // ══════════════════════════════════════════════════════════════════════════
  
  String _buildPriceTag(String product, String barcode, String price) => '''
^XA
^MNY
^CI28
^FO20,8^A0N,22,22^FB360,2,,L^FD$product^FS
^FO20,50^A0N,40,40^FDR\$ $price^FS
^FO20,100^BCN,60,Y,N,N^FD$barcode^FS
^XZ'''.trim();

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
^FO205,30^BQN,2,18^FDLA,$data^FS
^XZ'''.trim();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // TEMPLATE: CABO/FIO - Identificação de cabos com texto repetido
  // ══════════════════════════════════════════════════════════════════════════
  
  String _buildCable(String label, String code) => '''
^XA
^MNY
^CI28
^FO15,10^A0N,24,24^FB370,1,,C^FD$label^FS
^FO15,45^A0N,18,18^FB370,1,,C^FD$code^FS
^FO10,70^GB380,2,2^FS
^FO15,85^A0N,24,24^FB370,1,,C^FD$label^FS
^FO15,120^A0N,18,18^FB370,1,,C^FD$code^FS
^XZ'''.trim();

  String _buildPromoShelf(
    String product,
    String barcode,
    String previousPrice,
    String newPrice,
    int copies,
  ) => '''
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
^XZ'''.trim();

  String _buildPromoExpiry(
    String product,
    String barcode,
    String previousPrice,
    String newPrice,
    String expiryDate,
    int copies,
  ) => '''
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
^XZ'''.trim();
}
