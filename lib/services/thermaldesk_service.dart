import 'dart:async';

import 'package:barcode/barcode.dart';
import 'package:intl/intl.dart';
import 'package:thermal_desk/core/zpl_graphic.dart';

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
    String detail = '',
    required LabelTemplate template,
    required PrinterConfig cfg,
  }) {
    final safeTitle = _sanitize(title);
    final safeSubtitle = _sanitize(subtitle);
    final safeBarcode = _sanitize(barcode).isEmpty
        ? (template == LabelTemplate.qrCode
              ? 'https://exemplo.local'
              : '0000000000000')
        : _sanitize(barcode);

    final zpl = switch (template) {
      LabelTemplate.basic => _buildBasic(safeTitle, safeBarcode),
      LabelTemplate.custom => throw ArgumentError(
        'Use o modelo personalizado para gerar ZPL.',
      ),
      LabelTemplate.address => _buildAddress(safeTitle, safeSubtitle),
      LabelTemplate.shipping => _buildShipping(safeTitle, safeBarcode),
      LabelTemplate.inventory => _buildInventory(
        safeTitle,
        safeBarcode,
        safeSubtitle,
        _sanitize(detail).isEmpty
            ? DateFormat('dd/MM/yyyy').format(DateTime.now())
            : _sanitize(detail),
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
        _sanitize(detail),
      ),
      LabelTemplate.cable => _buildCable(safeTitle, safeBarcode, safeSubtitle),
    };
    return _applyProfile(zpl, cfg, template);
  }

  String _applyProfile(String zpl, PrinterConfig cfg, LabelTemplate template) {
    final profile = LabelProfile.fromConfig(cfg);
    final scale = profile.templateScale(template);
    int dot(String? value) =>
        math.max(1, ((int.tryParse(value ?? '') ?? 0) * scale).round());
    var output = zpl.replaceAll(RegExp(r'^\^FX.*$', multiLine: true), '');
    output = output.replaceAll(RegExp(r'\^PW\d+|\^LL\d+'), '');
    output = output.replaceAllMapped(
      RegExp(r'\^GFA,(\d+),(\d+),(\d+),([^\^]*)'),
      (m) => ZplGraphic.decode(
        int.parse(m[2]!),
        int.parse(m[3]!),
        m[4]!,
      ).scaled(scale).toZpl(),
    );
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
      RegExp(r'\^B([CE])([NR]),(\d+)'),
      (m) => '^B${m[1]}${m[2]},${dot(m[3])}',
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
      RegExp(r'\^FO(\d+),(\d+)\^BQN,2,(\d+)\^FD([LMQH])A,([^\^]*)'),
      (match) {
        var module = int.parse(match[3]!);
        try {
          final available = math.min(
            (224 * scale).round() - int.parse(match[1]!) - 8,
            (195 * scale).round() - int.parse(match[2]!) - 8,
          );
          module = math
              .min(
                module,
                (available /
                        LabelValidation.qrModules(
                          match[5]!.trimRight(),
                          correction: BarcodeQRCorrectionLevel.quartile,
                        ))
                    .floor(),
              )
              .clamp(1, 10);
        } catch (_) {
          module = 1;
        }
        return '^FO${match[1]},${match[2]}^BQN,2,$module^FD${match[4]}A,${match[5]}';
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
    output = output.replaceAllMapped(
      RegExp(
        r'\^FO(\d+),(\d+)\^BY(\d+),([^,]+),(\d+)\^BE([NR]),(\d+),([YN]),([YN])\^FD([^\^]*)\^FS',
      ),
      (m) {
        final available =
            (m[6] == 'R'
                ? profile.height - int.parse(m[2]!)
                : profile.width - int.parse(m[1]!)) -
            8;
        final module = math
            .min(int.parse(m[3]!), (available / 113).floor())
            .clamp(1, 10);
        // EAN-13 firmware calculates the check digit from the first 12 digits.
        final data = m[10]!.trimRight();
        final payload = data.length == 13 ? data.substring(0, 12) : data;
        return '^FO${m[1]},${m[2]}^BY$module,${m[4]},${m[7]}^BE${m[6]},${m[7]},${m[8]},${m[9]}^FD$payload^FS';
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
^CI28
^PW240
^LL800
^LH0,0
^LS0
^FWN

^FX Nome do produto
^FO110,25^A0R,22,22^FB600,2,0,L^FD$title^FS

^FX Ícone (24x24 rotacionado) + código
^FO168,16^FWR^GFA,72,72,3,,:::::G3GFGDGFGEGC:::::::::G3J0GCG3GFGDGFGEGC,:::::^FS

^FX Código
^FO133,39^A0R,28,28^FB600,2,0,L^FD$barcode^FS

^FX Barcode com moldura (se quiser moldura, ^GB...^FS antes)
^FO8,25^BY6,2,15^BER,93,N,N^FD$barcode^FS

^PQ1,0,1,N
^XZ'''
          .trim();

  String _buildAddress(String name, String address) =>
      '''
^XA
^CI28
^PW240
^LL800
^LH0,0
^LS0
^FWN

^FX --- Ícone de Localização (24x24 preenchido, rodado 90° horário) ---
^FO187,25^GFA,72,72,3,000000000000000000000000003F0000FFC001FFE003FFF007FFF00FF3F81FE1F83FE1F83FE1F81FE1F80FF3F807FFF003FFF001FFE000FFC0003F00000000000000000000000000^FS

^FX --- Cabeçalho: DESTINATÁRIO (alinhado abaixo do ícone) ---
^FO186,54^A0R,22,22^FDDESTINATÁRIO^FS

^FX --- Título do Produto (fonte maior em destaque, com suporte a 2 linhas) ---
^FO100,25^A0R,34,34^FB750,2,0,L^FD$name^FS

^FX --- Linha Divisória Vertical (substitui o código de barras) ---
^FO50,25^GB2,750,2^FS

^FX --- Texto do Remetente (à esquerda da linha divisória) ---
^FO20,25^A0R,20,20^FDRemetente: $address^FS

^PQ1,0,1,N
^XZ'''
          .trim();

  String _buildShipping(String title, String barcode) =>
      '''
^XA
^CI28
^PW240
^LL800
^LH0,0
^LS0
^FWN

^FX --- Ícone de Caminhão (24x24 preenchido, rotacionado 90° horário) ---
^FO195,25^GFA,72,72,3,00000001FFE001FFF007FFF00FFFF00CFFF00CFFF00FFFF007FFF001FFF001FFF001FFF001FFF001FFF001FFF007FFF00FFFF00CE3000CE3000FE70007EE0001FC0001F800000000^FS

^FX --- Cabeçalho: ENVIO (alinhado logo após o ícone) ---
^FO196,58^A0R,22,22^FDENVIO^FS

^FX --- Título do Produto (em destaque) ---
^FO148,25^A0R,32,32^FB750,1,0,L^FD$title^FS

^FX --- Caixa de Rastreio (borda retangular + texto interno) ---
^FO105,25^GB34,265,2^FS
^FO113,35^A0R,20,20^FDRASTREIO: $barcode^FS

^FX --- Código de Barras com numeração visível à esquerda ---
^FO35,25^BY4,2,55^BCR,55,Y,N,N^FD$barcode^FS

^PQ1,0,1,N
^XZ'''
          .trim();

  // ══════════════════════════════════════════════════════════════════════════
  // TEMPLATE: INVENTÁRIO - Para controle de estoque
  // ══════════════════════════════════════════════════════════════════════════

  String _buildInventory(
    String title,
    String barcode,
    String quantity,
    String date,
  ) =>
      '''
^XA
^CI28
^PW240
^LL800
^LH0,0
^LS0
^FWN

^FX --- Ícone do Leitor / Beep (24x24 rotacionado 90° horário) ---
^FO195,25^GFA,72,72,3,0000000000000000000FC0E03FF3F0303F18300E183E06181FE61801FE1800FE1800F61800F6180007180001D80000F80000300000000000000006D80006D8000CCC000CCC000000^FS

^FX --- Cabeçalho: INVENTÁRIO (alinhado logo após o ícone) ---
^FO196,58^A0R,22,22^FDINVENTÁRIO^FS

^FX --- Data no canto inferior (alinhada na mesma coluna do cabeçalho) ---
^FO196,650^A0R,20,20^FD$date^FS

^FX --- Título do Produto (em destaque) ---
^FO128,25^A0R,34,34^FB750,2,0,L^FD$title^FS


^FX --- Quantidade do Produto (em destaque) ---
^FO100,25^A0R,34,34^FB750,2,0,L^FD$quantity^FS

^FX --- Código de Barras (mais largo, ocupando a lateral esquerda) ---
^FO50,25^BY6,2,75^BCR,75,Y,N,N^FD$barcode^FS

^PQ1,0,1,N
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

  String _buildQrCode(String title, String data, String subtitle, String code) {
    return '''
^XA
^CI28
^PW240
^LL800
^LH0,0
^LS0
^FWN

^FX --- Moldura Externa Suave (Opcional - dá acabamento à etiqueta) ---
^FO8,10^GB224,780,2,B,1^FS

^FX --- QR Code no Topo (Centrado) ---
^FO56,30^BQN,2,6^FDQA,$data^FS

^FX --- Linha Divisória Horizontal (Separa o QR Code dos dados) ---
^FO20,195^GB200,2,2^FS

^FX --- Ícone de Mini QR Code (24x24 rodado 90° horário) + Cabeçalho ---
^FO187,215^GFA,72,72,3,FE03F8820208BA82E8BA82E8BA82E8820208FE03F80000003B8FF02908403A8B500208002B8FF0000000FE02A8820080BA03A0BA00A8BA02E8820200FE03B8000000000000000000^FS
^FO185,248^A0R,20,20^FDQR CODE^FS

^FX --- Título do Produto (Fonte maior e bem destacada, até 2 linhas) ---
^FO110,215^A0R,32,32^FB555,2,0,L^FD$title^FS

^FO120,215^A0R,22,22^FD$subtitle^FS

^FX --- Badge / Caixa de Código Numérico (Na lateral esquerda) ---
^FO30,215^GB40,320,2,B,1^FS
^FO40,230^A0R,22,22^FDCÓD: $code^FS

^PQ1,0,1,N
^XZ'''
        .trim();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // TEMPLATE: CABO/FIO - Identificação de cabos com texto repetido
  // ══════════════════════════════════════════════════════════════════════════

  String _buildCable(String title, String code, String id) =>
      '''
^XA
^CI28
^PW240
^LL800
^LH0,0
^LS0
^FWN

^FX --- TOPO: Tarja Preta com Ícone de Cabo + Cabeçalho ---
^FO15,15^GB210,36,36^FS
^FO24,21^FR^GFA,72,72,3,000000007E00007E0000DB0000DB0003FFC007FFE007FFE007FFE003FF8001FF00007E00003C00003C00003C00003C00003C00003C00007E00007E00003C00003C00003C00000000^FS
^FO77,24^FR^A0N,22,22^FDCABO / FIO^FS

^FX --- Subtítulo com o Código/ID Principal ---
^FO15,58^GB210,28,2^FS
^FO20,64^A0N,18,18^FB200,1,0,C^FDID: ${id.isEmpty ? code : id}^FS

^FX --- BLOCO 1 (Repetição para envolver o cabo) ---
^FO20,115^A0N,26,26^FB200,2,0,C^FD$title^FS
^FO20,175^A0N,18,18^FB200,1,0,C^FD$code^FS
^FO25,205^GB190,1,1^FS

^FX --- BLOCO 2 ---
^FO20,230^A0N,26,26^FB200,2,0,C^FD$title^FS
^FO20,290^A0N,18,18^FB200,1,0,C^FD$code^FS
^FO25,320^GB190,1,1^FS

^FX --- BLOCO 3 ---
^FO20,345^A0N,26,26^FB200,2,0,C^FD$title^FS
^FO20,405^A0N,18,18^FB200,1,0,C^FD$code^FS
^FO25,435^GB190,1,1^FS

^FX --- BLOCO 4 ---
^FO20,460^A0N,26,26^FB200,2,0,C^FD$title^FS
^FO20,520^A0N,18,18^FB200,1,0,C^FD$code^FS
^FO25,550^GB190,1,1^FS

^FX --- BLOCO 5 ---
^FO20,575^A0N,26,26^FB200,2,0,C^FD$title^FS
^FO20,635^A0N,18,18^FB200,1,0,C^FD$code^FS
^FO25,665^GB190,1,1^FS

^FX --- BLOCO 6 (Final da volta) ---
^FO20,690^A0N,26,26^FB200,2,0,C^FD$title^FS
^FO20,750^A0N,18,18^FB200,1,0,C^FD$code^FS

^PQ1,0,1,N
^XZ'''
          .trim();
}
