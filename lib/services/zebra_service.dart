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
  }) {
    final size = AppConstants.labelSizes[cfg.labelSize] ??
        (w: 400, h: 240, dpi: 200);

    final safeTitle = _sanitize(title);
    final safeSubtitle = _sanitize(subtitle);
    final safeBarcode = barcode.trim().isEmpty ? '0000000000000' : barcode.trim();
    final pw = size.w;
    final ll = size.h;
    final isLongLabel = ll >= pw * 2;

    return switch (template) {
      LabelTemplate.basic => isLongLabel
          ? _buildBasicLong(safeTitle, safeBarcode, pw, ll)
          : _buildBasic(safeTitle, safeBarcode, pw, ll),
      LabelTemplate.product => isLongLabel
          ? _buildProductLong(safeTitle, safeBarcode, safeSubtitle, pw, ll)
          : _buildProduct(safeTitle, safeBarcode, safeSubtitle, pw, ll),
      LabelTemplate.address => isLongLabel
          ? _buildAddressLong(safeTitle, safeSubtitle, pw, ll)
          : _buildAddress(safeTitle, safeSubtitle, pw, ll),
      LabelTemplate.shipping => isLongLabel
          ? _buildShippingLong(safeTitle, safeBarcode, safeSubtitle, pw, ll)
          : _buildShipping(safeTitle, safeBarcode, safeSubtitle, pw, ll),
      LabelTemplate.inventory => isLongLabel
          ? _buildInventoryLong(safeTitle, safeBarcode, safeSubtitle, pw, ll)
          : _buildInventory(safeTitle, safeBarcode, safeSubtitle, pw, ll),
      LabelTemplate.priceTag => isLongLabel
          ? _buildPriceTagLong(safeTitle, safeBarcode, safeSubtitle, pw, ll)
          : _buildPriceTag(safeTitle, safeBarcode, safeSubtitle, pw, ll),
      LabelTemplate.qrCode => isLongLabel
          ? _buildQrCodeLong(safeTitle, safeBarcode, safeSubtitle, pw, ll)
          : _buildQrCode(safeTitle, safeBarcode, safeSubtitle, pw, ll),
      LabelTemplate.cable => isLongLabel
          ? _buildCableLong(safeTitle, safeBarcode, pw, ll)
          : _buildCable(safeTitle, safeBarcode, pw, ll),
    };
  }

  String _sanitize(String s) => s.replaceAll('^', '').replaceAll('~', '').trim();

  String _buildBasic(String title, String barcode, int pw, int ll) => '''
^XA
^PW$pw
^LL$ll
^CI28
^FO20,15^A0N,36,36^FD$title^FS
^FO20,65^BCN,90,Y,N,N^FD$barcode^FS
^XZ'''.trim();

  // Layout para etiquetas longas/verticais (30x100mm)
  // Usa ^FWR para rotacionar todo o conteúdo 90° - texto fica horizontal para leitura
  String _buildBasicLong(String title, String barcode, int pw, int ll) {
    // Com rotação 90°: a largura visual vira ll, altura visual vira pw
    final barcodeWidth = (ll * 0.5).toInt().clamp(100, 400);
    return '''
^XA
^PW$pw
^LL$ll
^CI28
^FWR
^FO${pw - 50},20^A0R,32,32^FB${ll - 40},2,,L^FD$title^FS
^FO${pw - 120},20^BCR,70,Y,N,N^FD$barcode^FS
^FWN
^XZ'''.trim();
  }

  String _buildProduct(String title, String barcode, String subtitle, int pw, int ll) => '''
^XA
^PW$pw
^LL$ll
^CI28
^FO20,12^A0N,30,30^FB${pw - 40},2,,L^FD$title^FS
^FO20,58^A0N,22,22^FD$subtitle^FS
^FO20,90^BCN,80,Y,N,N^FD$barcode^FS
^XZ'''.trim();

  String _buildProductLong(
    String title,
    String barcode,
    String subtitle,
    int pw,
    int ll,
  ) {
    // Com rotação 90°: conteúdo fica horizontal para leitura natural
    return '''
^XA
^PW$pw
^LL$ll
^CI28
^FWR
^FO${pw - 40},15^A0R,28,28^FB${ll - 30},2,,L^FD$title^FS
^FO${pw - 70},15^A0R,20,20^FB${ll - 30},2,,L^FD$subtitle^FS
^FO${pw - 150},15^BCR,60,Y,N,N^FD$barcode^FS
^FWN
^XZ'''.trim();
  }

  String _buildAddress(String name, String address, int pw, int ll) => '''
^XA
^PW$pw
^LL$ll
^CI28
^FO20,15^A0N,28,28^FDDe: $name^FS
^FO20,55^A0N,22,22^FB${pw - 40},4,,L^FD$address^FS
^XZ'''.trim();

  String _buildAddressLong(String name, String address, int pw, int ll) => '''
^XA
^PW$pw
^LL$ll
^CI28
^FWR
^FO${pw - 35},15^A0R,26,26^FB${ll - 30},2,,L^FDDe: $name^FS
^FO${pw - 70},15^A0R,20,20^FB${ll - 30},6,,L^FD$address^FS
^FO30,15^A0R,14,14^FB${ll - 30},1,,L^FDRemetente: Zebra Label Pro^FS
^FWN
^XZ'''.trim();

  String _buildShipping(String title, String barcode, String ref, int pw, int ll) => '''
^XA
^PW$pw
^LL$ll
^CI28
^FO20,10^A0N,26,26^FD$title^FS
^FO20,44^A0N,20,20^FDRef: $ref^FS
^FO20,76^BCN,100,Y,N,N^FD$barcode^FS
^XZ'''.trim();

  String _buildShippingLong(String title, String barcode, String ref, int pw, int ll) {
    // Rotacionado 90° para leitura horizontal
    return '''
^XA
^PW$pw
^LL$ll
^CI28
^FWR
^FO${pw - 30},15^A0R,18,18^FDENVIO^FS
^FO${pw - 55},15^A0R,26,26^FB${ll - 30},2,,L^FD$title^FS
^FO${pw - 85},15^A0R,16,16^FB${ll - 30},1,,L^FDRef: $ref^FS
^FO${pw - 180},15^BCR,70,Y,N,N^FD$barcode^FS
^FWN
^XZ'''.trim();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // TEMPLATE: INVENTÁRIO - Para controle de estoque
  // ══════════════════════════════════════════════════════════════════════════
  
  String _buildInventory(String title, String barcode, String location, int pw, int ll) => '''
^XA
^PW$pw
^LL$ll
^CI28
^FO20,8^A0N,24,24^FB${pw - 40},2,,L^FD$title^FS
^FO20,45^A0N,18,18^FDLoc: $location^FS
^FO20,70^BCN,70,Y,N,N^FD$barcode^FS
^FO${pw - 80},8^A0N,16,16^FD#INV^FS
^XZ'''.trim();

  String _buildInventoryLong(String title, String barcode, String location, int pw, int ll) {
    // Rotacionado 90° para leitura horizontal
    return '''
^XA
^PW$pw
^LL$ll
^CI28
^FWR
^FO${pw - 30},15^A0R,14,14^FDINVENTARIO^FS
^FO${pw - 55},15^A0R,24,24^FB${ll - 30},2,,L^FD$title^FS
^FO${pw - 85},15^A0R,16,16^FB${ll - 30},1,,L^FDLocal: $location^FS
^FO${pw - 170},15^BCR,65,Y,N,N^FD$barcode^FS
^FWN
^XZ'''.trim();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // TEMPLATE: PREÇO - Etiqueta de preço para gôndola
  // ══════════════════════════════════════════════════════════════════════════
  
  String _buildPriceTag(String product, String barcode, String price, int pw, int ll) => '''
^XA
^PW$pw
^LL$ll
^CI28
^FO20,8^A0N,22,22^FB${pw - 40},2,,L^FD$product^FS
^FO20,50^A0N,40,40^FDR\$ $price^FS
^FO20,100^BCN,60,Y,N,N^FD$barcode^FS
^XZ'''.trim();

  String _buildPriceTagLong(String product, String barcode, String price, int pw, int ll) {
    // Rotacionado 90° para leitura horizontal
    return '''
^XA
^PW$pw
^LL$ll
^CI28
^FWR
^FO${pw - 35},15^A0R,22,22^FB${ll - 30},2,,C^FD$product^FS
^FO${(pw ~/ 2) + 20},15^A0R,48,48^FB${ll - 30},1,,C^FDR\$ $price^FS
^FO60,15^BCR,50,Y,N,N^FD$barcode^FS
^FWN
^XZ'''.trim();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // TEMPLATE: QR CODE - com texto informativo
  // ══════════════════════════════════════════════════════════════════════════
  
  String _buildQrCode(String title, String data, String subtitle, int pw, int ll) {
    final qrSize = (ll - 60).clamp(80, pw - 40);
    return '''
^XA
^PW$pw
^LL$ll
^CI28
^FO20,8^A0N,20,20^FB${pw - qrSize - 50},2,,L^FD$title^FS
^FO20,40^A0N,16,16^FB${pw - qrSize - 50},3,,L^FD$subtitle^FS
^FO${pw - qrSize - 15},${(ll - qrSize) ~/ 2}^BQN,2,${qrSize ~/ 10}^FDLA,$data^FS
^XZ'''.trim();
  }

  String _buildQrCodeLong(String title, String data, String subtitle, int pw, int ll) {
    // Rotacionado 90° para leitura horizontal
    // QR Code não precisa rotacionar, funciona em qualquer orientação
    final qrSize = (pw - 40).clamp(60, 150);
    return '''
^XA
^PW$pw
^LL$ll
^CI28
^FWR
^FO${pw - 35},20^A0R,22,22^FB${ll - qrSize - 60},2,,L^FD$title^FS
^FO${pw - 65},20^A0R,16,16^FB${ll - qrSize - 60},3,,L^FD$subtitle^FS
^FWN
^FO${(pw - qrSize) ~/ 2},${ll - qrSize - 30}^BQN,2,${qrSize ~/ 10}^FDLA,$data^FS
^FWR
^FO30,20^A0R,12,12^FB${ll - 40},1,,L^FD$data^FS
^FWN
^XZ'''.trim();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // TEMPLATE: CABO/FIO - Identificação de cabos com texto repetido
  // ══════════════════════════════════════════════════════════════════════════
  
  String _buildCable(String label, String code, int pw, int ll) => '''
^XA
^PW$pw
^LL$ll
^CI28
^FO15,10^A0N,24,24^FB${pw - 30},1,,C^FD$label^FS
^FO15,45^A0N,18,18^FB${pw - 30},1,,C^FD$code^FS
^FO10,70^GB${pw - 20},2,2^FS
^FO15,85^A0N,24,24^FB${pw - 30},1,,C^FD$label^FS
^FO15,120^A0N,18,18^FB${pw - 30},1,,C^FD$code^FS
^XZ'''.trim();

  String _buildCableLong(String label, String code, int pw, int ll) {
    // Rotacionado 90° - repete a identificação ao longo do comprimento
    // Útil para enrolar em cabos e fios
    final repeatCount = (ll ~/ 150).clamp(2, 6);
    final spacing = ll ~/ repeatCount;
    
    var zpl = '''
^XA
^PW$pw
^LL$ll
^CI28
^FWR''';
    
    for (var i = 0; i < repeatCount; i++) {
      final y = 20 + (i * spacing);
      final x = pw - 35;
      zpl += '''

^FO$x,$y^A0R,22,22^FB${spacing - 40},1,,L^FD$label^FS
^FO${x - 30},$y^A0R,16,16^FB${spacing - 40},1,,L^FD$code^FS''';
      if (i < repeatCount - 1) {
        final lineY = y + spacing - 10;
        zpl += '''

^FO30,$lineY^GB${pw - 60},1,1^FS''';
      }
    }
    
    zpl += '''

^FWN
^XZ''';
    return zpl.trim();
  }
}
