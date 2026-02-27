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
^MNY
^PW$pw
^LL$ll
^CI28
^FO20,15^A0N,36,36^FD$title^FS
^FO20,65^BCN,90,Y,N,N^FD$barcode^FS
^XZ'''.trim();

  // Layout para etiquetas 30x100mm (gôndola)
  // Rotação 90° - conteúdo ao longo dos 100mm de comprimento
  // Margens: 16 dots (~2mm) em cada lado
  String _buildBasicLong(String title, String barcode, int pw, int ll) {
    // pw=240 (30mm), ll=800 (100mm) a 200dpi
    // Área útil: 208 dots altura x 768 dots comprimento
    final marginY = 16;
    final usableLength = ll - (marginY * 2);
    return '''
^XA
^MNY
^PW$pw
^LL$ll
^CI28
^FWR
^FO${pw - 45},$marginY^A0R,36,36^FB$usableLength,2,,L^FD$title^FS
^FO${pw - 160},$marginY^BCR,90,Y,N,N^FD$barcode^FS
^FWN
^XZ'''.trim();
  }

  String _buildProduct(String title, String barcode, String subtitle, int pw, int ll) => '''
^XA
^MNY
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
    // Layout 30x100mm - Produto com descrição e código de barras
    final marginY = 16;
    final usableLength = ll - (marginY * 2);
    return '''
^XA
^MNY
^PW$pw
^LL$ll
^CI28
^FWR
^FO${pw - 40},$marginY^A0R,32,32^FB$usableLength,1,,L^FD$title^FS
^FO${pw - 75},$marginY^A0R,24,24^FB$usableLength,2,,L^FD$subtitle^FS
^FO${pw - 180},$marginY^BCR,80,Y,N,N^FD$barcode^FS
^FWN
^XZ'''.trim();
  }

  String _buildAddress(String name, String address, int pw, int ll) => '''
^XA
^MNY
^PW$pw
^LL$ll
^CI28
^FO20,15^A0N,28,28^FDDe: $name^FS
^FO20,55^A0N,22,22^FB${pw - 40},4,,L^FD$address^FS
^XZ'''.trim();

  String _buildAddressLong(String name, String address, int pw, int ll) {
    final marginY = 16;
    final usableLength = ll - (marginY * 2);
    return '''
^XA
^MNY
^PW$pw
^LL$ll
^CI28
^FWR
^FO${pw - 35},$marginY^A0R,28,28^FB$usableLength,1,,L^FDDe: $name^FS
^FO${pw - 75},$marginY^A0R,22,22^FB$usableLength,4,,L^FD$address^FS
^FO25,$marginY^A0R,14,14^FB$usableLength,1,,L^FDZebra Label Pro^FS
^FWN
^XZ'''.trim();
  }

  String _buildShipping(String title, String barcode, String ref, int pw, int ll) => '''
^XA
^MNY
^PW$pw
^LL$ll
^CI28
^FO20,10^A0N,26,26^FD$title^FS
^FO20,44^A0N,20,20^FDRef: $ref^FS
^FO20,76^BCN,100,Y,N,N^FD$barcode^FS
^XZ'''.trim();

  String _buildShippingLong(String title, String barcode, String ref, int pw, int ll) {
    // Layout 30x100mm - Etiqueta de envio
    final marginY = 16;
    final usableLength = ll - (marginY * 2);
    return '''
^XA
^MNY
^PW$pw
^LL$ll
^CI28
^FWR
^FO${pw - 28},$marginY^A0R,18,18^FDENVIO^FS
^FO${pw - 55},$marginY^A0R,28,28^FB$usableLength,1,,L^FD$title^FS
^FO${pw - 90},$marginY^A0R,20,20^FB$usableLength,1,,L^FDRef: $ref^FS
^FO${pw - 190},$marginY^BCR,80,Y,N,N^FD$barcode^FS
^FWN
^XZ'''.trim();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // TEMPLATE: INVENTÁRIO - Para controle de estoque
  // ══════════════════════════════════════════════════════════════════════════
  
  String _buildInventory(String title, String barcode, String location, int pw, int ll) => '''
^XA
^MNY
^PW$pw
^LL$ll
^CI28
^FO20,8^A0N,24,24^FB${pw - 40},2,,L^FD$title^FS
^FO20,45^A0N,18,18^FDLoc: $location^FS
^FO20,70^BCN,70,Y,N,N^FD$barcode^FS
^FO${pw - 80},8^A0N,16,16^FD#INV^FS
^XZ'''.trim();

  String _buildInventoryLong(String title, String barcode, String location, int pw, int ll) {
    // Layout 30x100mm - Inventário/Estoque
    final marginY = 16;
    final usableLength = ll - (marginY * 2);
    return '''
^XA
^MNY
^PW$pw
^LL$ll
^CI28
^FWR
^FO${pw - 28},$marginY^A0R,16,16^FDINVENTARIO^FS
^FO${pw - 55},$marginY^A0R,28,28^FB$usableLength,1,,L^FD$title^FS
^FO${pw - 90},$marginY^A0R,20,20^FB$usableLength,1,,L^FDLocal: $location^FS
^FO${pw - 185},$marginY^BCR,75,Y,N,N^FD$barcode^FS
^FWN
^XZ'''.trim();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // TEMPLATE: PREÇO - Etiqueta de preço para gôndola
  // ══════════════════════════════════════════════════════════════════════════
  
  String _buildPriceTag(String product, String barcode, String price, int pw, int ll) => '''
^XA
^MNY
^PW$pw
^LL$ll
^CI28
^FO20,8^A0N,22,22^FB${pw - 40},2,,L^FD$product^FS
^FO20,50^A0N,40,40^FDR\$ $price^FS
^FO20,100^BCN,60,Y,N,N^FD$barcode^FS
^XZ'''.trim();

  String _buildPriceTagLong(String product, String barcode, String price, int pw, int ll) {
    // Layout 30x100mm - GÔNDOLA DE SUPERMERCADO
    // Produto pequeno no topo, PREÇO GRANDE no centro, código de barras embaixo
    final marginY = 16;
    final usableLength = ll - (marginY * 2);
    // Calcula posição central para o preço
    final priceX = (pw ~/ 2) + 30; // Centro vertical
    return '''
^XA
^MNY
^PW$pw
^LL$ll
^CI28
^FWR
^FO${pw - 28},$marginY^A0R,22,22^FB$usableLength,1,,L^FD$product^FS
^FO$priceX,$marginY^A0R,28,28^FDR\$^FS
^FO$priceX,${marginY + 70}^A0R,80,80^FB${usableLength - 90},1,,L^FD$price^FS
^FO35,$marginY^BCR,50,N,N,N^FD$barcode^FS
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
^MNY
^PW$pw
^LL$ll
^CI28
^FO20,8^A0N,20,20^FB${pw - qrSize - 50},2,,L^FD$title^FS
^FO20,40^A0N,16,16^FB${pw - qrSize - 50},3,,L^FD$subtitle^FS
^FO${pw - qrSize - 15},${(ll - qrSize) ~/ 2}^BQN,2,${qrSize ~/ 10}^FDLA,$data^FS
^XZ'''.trim();
  }

  String _buildQrCodeLong(String title, String data, String subtitle, int pw, int ll) {
    // Layout 30x100mm - QR Code
    // Texto à esquerda, QR Code grande à direita
    final marginY = 16;
    final qrSize = pw - 60; // ~180 dots para QR
    final textWidth = ll - qrSize - marginY - 40;
    return '''
^XA
^MNY
^PW$pw
^LL$ll
^CI28
^FWR
^FO${pw - 35},$marginY^A0R,24,24^FB$textWidth,2,,L^FD$title^FS
^FO${pw - 75},$marginY^A0R,18,18^FB$textWidth,4,,L^FD$subtitle^FS
^FO25,$marginY^A0R,14,14^FB$textWidth,1,,L^FD$data^FS
^FWN
^FO${(pw - qrSize) ~/ 2},${ll - qrSize - marginY}^BQN,2,${(qrSize ~/ 12).clamp(4, 10)}^FDLA,$data^FS
^XZ'''.trim();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // TEMPLATE: CABO/FIO - Identificação de cabos com texto repetido
  // ══════════════════════════════════════════════════════════════════════════
  
  String _buildCable(String label, String code, int pw, int ll) => '''
^XA
^MNY
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
    // Layout 30x100mm - Identificação de cabos
    // Repete o texto ao longo do comprimento para enrolar em cabos
    final marginY = 16;
    final repeatCount = ((ll - marginY * 2) ~/ 160).clamp(2, 5);
    final spacing = (ll - marginY * 2) ~/ repeatCount;
    
    var zpl = '''
^XA
^MNY
^PW$pw
^LL$ll
^CI28
^FWR''';
    
    for (var i = 0; i < repeatCount; i++) {
      final y = marginY + (i * spacing);
      final x = pw - 40;
      zpl += '''

^FO$x,$y^A0R,26,26^FB${spacing - 30},1,,L^FD$label^FS
^FO${x - 35},$y^A0R,20,20^FB${spacing - 30},1,,L^FD$code^FS''';
      if (i < repeatCount - 1) {
        final lineY = y + spacing - 5;
        zpl += '''

^FO25,$lineY^GB${pw - 50},2,2^FS''';
      }
    }
    
    zpl += '''

^FWN
^XZ''';
    return zpl.trim();
  }
}
