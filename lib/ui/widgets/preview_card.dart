import 'package:barcode_widget/barcode_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zebra_label_pro/core/responsive.dart';
import 'package:zebra_label_pro/models/label_job.dart';
import 'package:zebra_label_pro/providers/history_provider.dart';
import 'package:zebra_label_pro/providers/printer_provider.dart';

class PreviewCard extends ConsumerStatefulWidget {
  final TextEditingController titleCtrl;
  final TextEditingController barcodeCtrl;
  final TextEditingController subtitleCtrl;
  final LabelTemplate template;
  final VoidCallback onCopyZpl;

  const PreviewCard({
    super.key,
    required this.titleCtrl,
    required this.barcodeCtrl,
    required this.subtitleCtrl,
    required this.template,
    required this.onCopyZpl,
  });

  @override
  ConsumerState<PreviewCard> createState() => _PreviewCardState();
}

class _PreviewCardState extends ConsumerState<PreviewCard> {
  @override
  void initState() {
    super.initState();
    widget.titleCtrl.addListener(_rebuild);
    widget.barcodeCtrl.addListener(_rebuild);
    widget.subtitleCtrl.addListener(_rebuild);
  }

  void _rebuild() => setState(() {});

  @override
  void dispose() {
    widget.titleCtrl.removeListener(_rebuild);
    widget.barcodeCtrl.removeListener(_rebuild);
    widget.subtitleCtrl.removeListener(_rebuild);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final history = ref.watch(historyProvider);
    final cfg = ref.read(printerConfigProvider);
    final zpl = ref.read(zebraServiceProvider).buildZpl(
          title: widget.titleCtrl.text,
          barcode: widget.barcodeCtrl.text,
          subtitle: widget.subtitleCtrl.text,
          template: widget.template,
          cfg: cfg,
        );

    final isMobile = Responsive.isMobile(context);
    final cardPadding = Responsive.value(
      context: context,
      mobile: 14.0,
      tablet: 16.0,
      desktop: 20.0,
    );

    return Card(
      child: Padding(
        padding: EdgeInsets.all(cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header com template info
            Row(
              children: [
                _SectionLabel('Pré-visualização da etiqueta', isMobile: isMobile),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(widget.template.icon, size: 14, color: Theme.of(context).colorScheme.onPrimaryContainer),
                      const SizedBox(width: 4),
                      Text(
                        widget.template.displayName,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: isMobile ? 10 : 12),
            
            // Preview realista da etiqueta
            Center(
              child: _LabelPreview(
                titleCtrl: widget.titleCtrl,
                barcodeCtrl: widget.barcodeCtrl,
                subtitleCtrl: widget.subtitleCtrl,
                template: widget.template,
                labelSize: cfg.labelSize,
                isMobile: isMobile,
              ),
            ),
            SizedBox(height: isMobile ? 12 : 16),

            // ZPL expander
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: const Text('Ver código ZPL', style: TextStyle(fontWeight: FontWeight.w600)),
              leading: const Icon(Icons.code),
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SelectableText(
                    zpl,
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.tonalIcon(
                    icon: const Icon(Icons.copy, size: 16),
                    label: const Text('Copiar ZPL'),
                    onPressed: widget.onCopyZpl,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Divider(),
            const SizedBox(height: 8),

            // Recent history
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _SectionLabel('Últimas impressões', isMobile: isMobile),
                if (history.isNotEmpty)
                  TextButton.icon(
                    icon: Icon(Icons.delete_outline, size: isMobile ? 14 : 16),
                    label: Text('Limpar', style: TextStyle(fontSize: isMobile ? 12 : 14)),
                    onPressed: () => ref.read(historyProvider.notifier).clear(),
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                  ),
              ],
            ),
            SizedBox(height: isMobile ? 6 : 8),
            if (history.isEmpty)
              Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: isMobile ? 16 : 20),
                  child: Text('Nenhuma impressão recente',
                      style: TextStyle(color: Colors.grey.shade500, fontSize: isMobile ? 12 : 14)),
                ),
              )
            else
              ...history.take(isMobile ? 3 : 5).map((job) => _HistoryTile(job: job, isMobile: isMobile)),
          ],
        ),
      ),
    );
  }
}

/// Widget de preview realista da etiqueta
class _LabelPreview extends StatelessWidget {
  final TextEditingController titleCtrl;
  final TextEditingController barcodeCtrl;
  final TextEditingController subtitleCtrl;
  final LabelTemplate template;
  final String labelSize;
  final bool isMobile;

  const _LabelPreview({
    required this.titleCtrl,
    required this.barcodeCtrl,
    required this.subtitleCtrl,
    required this.template,
    required this.labelSize,
    required this.isMobile,
  });

  // Parse label size from config string (e.g., "50x30mm (203dpi S4M)" or "30x100mm Vertical (200dpi)")
  // Retorna (largura, altura) em mm para o preview visual
  (double width, double height) _parseLabelSize() {
    // Extrair dimensões do nome (formato: "WxHmm")
    final match = RegExp(r'(\d+)x(\d+)').firstMatch(labelSize);
    if (match != null) {
      final dim1 = double.parse(match.group(1)!);
      final dim2 = double.parse(match.group(2)!);
      
      // Verificar se é orientação específica
      final lowerName = labelSize.toLowerCase();
      
      if (lowerName.contains('vertical')) {
        // Vertical: primeiro número é largura, segundo é altura (etiqueta mais alta que larga)
        return (dim1, dim2);
      } else if (lowerName.contains('horizontal')) {
        // Horizontal: invertemos para ficar mais largo que alto
        return (dim2, dim1);
      } else {
        // Padrão: interpretar como LarguraxAltura
        // Para etiquetas como "50x30mm", 50 é largura, 30 é altura
        // Para etiquetas como "30x100mm", 30 é largura, 100 é altura
        return (dim1, dim2);
      }
    }
    return (100, 50); // default
  }

  // Determina se a etiqueta é vertical (mais alta que larga)
  bool _isVerticalLabel(double width, double height) => height > width;

  @override
  Widget build(BuildContext context) {
    final (labelWidth, labelHeight) = _parseLabelSize();
    final aspectRatio = labelWidth / labelHeight;
    final isVertical = _isVerticalLabel(labelWidth, labelHeight);
    
    // Calcular dimensões do preview mantendo proporção
    // Para etiquetas verticais, limitar a altura; para horizontais, limitar a largura
    final maxWidth = isMobile ? 300.0 : 360.0;
    final maxHeight = isMobile ? 220.0 : 280.0;
    final minWidth = isMobile ? 100.0 : 120.0;
    final minHeight = isMobile ? 60.0 : 80.0;
    
    double previewWidth;
    double previewHeight;
    
    if (isVertical) {
      // Etiqueta vertical: começar pela altura máxima
      previewHeight = maxHeight;
      previewWidth = previewHeight * aspectRatio;
      
      // Se largura ficou menor que o mínimo, ajustar
      if (previewWidth < minWidth) {
        previewWidth = minWidth;
        previewHeight = previewWidth / aspectRatio;
      }
      // Se largura ficou maior que o máximo, ajustar
      if (previewWidth > maxWidth) {
        previewWidth = maxWidth;
        previewHeight = previewWidth / aspectRatio;
      }
    } else {
      // Etiqueta horizontal: começar pela largura máxima
      previewWidth = maxWidth;
      previewHeight = previewWidth / aspectRatio;
      
      // Se altura ficou menor que o mínimo, ajustar
      if (previewHeight < minHeight) {
        previewHeight = minHeight;
        previewWidth = previewHeight * aspectRatio;
      }
      // Se altura ficou maior que o máximo, ajustar
      if (previewHeight > maxHeight) {
        previewHeight = maxHeight;
        previewWidth = previewHeight * aspectRatio;
      }
    }
    
    // Calcular escala aproximada (px por mm)
    final scale = previewWidth / labelWidth;

    final barcodeData = barcodeCtrl.text.trim().isEmpty ? '0000000000000' : barcodeCtrl.text.trim();
    final title = titleCtrl.text.isEmpty ? 'Título do Produto' : titleCtrl.text;
    final subtitle = subtitleCtrl.text;

    return Column(
      children: [
        // Indicador de tamanho da etiqueta com orientação
        Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isVertical ? Icons.crop_portrait : Icons.crop_landscape,
                size: 14,
                color: Colors.grey.shade600,
              ),
              const SizedBox(width: 4),
              Text(
                '${labelWidth.toInt()} × ${labelHeight.toInt()} mm',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 6),
              if (isVertical) ...[
                Icon(
                  Icons.rotate_90_degrees_cw,
                  size: 12,
                  color: Colors.grey.shade500,
                ),
                const SizedBox(width: 2),
              ],
              Text(
                isVertical ? 'conteúdo horizontal' : 'escala ${(scale * 100).toStringAsFixed(0)}%',
                style: TextStyle(
                  fontSize: 9,
                  color: Colors.grey.shade500,
                ),
              ),
            ],
          ),
        ),
        
        // Etiqueta com efeito de papel
        Container(
          width: previewWidth,
          height: previewHeight,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(2),
            border: Border.all(color: Colors.grey.shade400, width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 2,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Stack(
            children: [
              // Padrão de fundo sutil para simular textura de papel
              Positioned.fill(
                child: CustomPaint(
                  painter: _LabelBackgroundPainter(),
                ),
              ),
              // Conteúdo da etiqueta - rotacionado para horizontal se etiqueta for vertical
              Positioned.fill(
                child: isVertical
                    ? RotatedBox(
                        quarterTurns: 1, // Rotaciona 90° sentido horário
                        child: Padding(
                          padding: EdgeInsets.all(isMobile ? 6 : 10),
                          child: _buildTemplateContent(
                            context: context,
                            title: title,
                            subtitle: subtitle,
                            barcodeData: barcodeData,
                            // Inverter largura/altura para o conteúdo rotacionado
                            previewWidth: previewHeight,
                            previewHeight: previewWidth,
                          ),
                        ),
                      )
                    : Padding(
                        padding: EdgeInsets.all(isMobile ? 6 : 10),
                        child: _buildTemplateContent(
                          context: context,
                          title: title,
                          subtitle: subtitle,
                          barcodeData: barcodeData,
                          previewWidth: previewWidth,
                          previewHeight: previewHeight,
                        ),
                      ),
              ),
            ],
          ),
        ),
        
        // Legenda
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            'Preview aproximado • Layout pode variar na impressão',
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey.shade500,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTemplateContent({
    required BuildContext context,
    required String title,
    required String subtitle,
    required String barcodeData,
    required double previewWidth,
    required double previewHeight,
  }) {
    // Calcular altura proporcional do barcode baseado no preview
    final barcodeHeight = (previewHeight * 0.25).clamp(25.0, 55.0);
    
    switch (template) {
      case LabelTemplate.qrCode:
        return _buildQrCodeLayout(title, subtitle, barcodeData, previewWidth, previewHeight);
      case LabelTemplate.cable:
        return _buildCableLayout(title, barcodeData, previewHeight);
      case LabelTemplate.shipping:
        return _buildShippingLayout(title, subtitle, barcodeData, barcodeHeight);
      case LabelTemplate.address:
        return _buildAddressLayout(title, subtitle, previewHeight);
      case LabelTemplate.priceTag:
        return _buildPriceTagLayout(title, subtitle, barcodeData, previewHeight, barcodeHeight);
      case LabelTemplate.inventory:
        return _buildInventoryLayout(title, subtitle, barcodeData, barcodeHeight);
      case LabelTemplate.product:
        return _buildProductLayout(title, subtitle, barcodeData, barcodeHeight);
      case LabelTemplate.basic:
      default:
        return _buildBasicLayout(title, subtitle, barcodeData, barcodeHeight);
    }
  }

  Widget _buildBasicLayout(String title, String subtitle, String barcodeData, double barcodeHeight) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Flexible(
          flex: 0,
          child: Text(
            title,
            style: TextStyle(
              fontSize: isMobile ? 14 : 16,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (subtitle.isNotEmpty) ...[
          const SizedBox(height: 2),
          Flexible(
            flex: 0,
            child: Text(
              subtitle,
              style: TextStyle(fontSize: isMobile ? 10 : 11, color: Colors.black87),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
        const Spacer(),
        _buildBarcode(barcodeData, barcodeHeight),
      ],
    );
  }

  Widget _buildProductLayout(String title, String subtitle, String barcodeData, double barcodeHeight) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Linha superior com SKU simulado
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text(
                'SKU: ${barcodeData.length > 8 ? barcodeData.substring(0, 8) : barcodeData}',
                style: TextStyle(fontSize: isMobile ? 8 : 9, color: Colors.black54, fontFamily: 'monospace'),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              DateTime.now().toString().substring(0, 10),
              style: TextStyle(fontSize: isMobile ? 8 : 9, color: Colors.black54),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Flexible(
          flex: 0,
          child: Text(
            title,
            style: TextStyle(
              fontSize: isMobile ? 14 : 16,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (subtitle.isNotEmpty) ...[
          const SizedBox(height: 2),
          Flexible(
            flex: 0,
            child: Text(
              subtitle,
              style: TextStyle(fontSize: isMobile ? 10 : 11, color: Colors.black87),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
        const Spacer(),
        _buildBarcode(barcodeData, barcodeHeight),
      ],
    );
  }

  Widget _buildQrCodeLayout(String title, String subtitle, String barcodeData, double previewWidth, double previewHeight) {
    // Calcular tamanho do QR code proporcional ao preview
    final qrSize = (previewHeight * 0.6).clamp(40.0, 90.0);
    
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // QR Code
        SizedBox(
          width: qrSize,
          height: qrSize,
          child: BarcodeWidget(
            barcode: Barcode.qrCode(),
            data: barcodeData.isEmpty ? '0000000000000' : barcodeData,
            color: Colors.black,
          ),
        ),
        SizedBox(width: isMobile ? 8 : 12),
        // Info
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: isMobile ? 12 : 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (subtitle.isNotEmpty) ...[
                const SizedBox(height: 2),
                Flexible(
                  child: Text(
                    subtitle,
                    style: TextStyle(fontSize: isMobile ? 9 : 10, color: Colors.black87),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
              const SizedBox(height: 4),
              Text(
                barcodeData,
                style: TextStyle(
                  fontSize: isMobile ? 8 : 9,
                  color: Colors.black54,
                  fontFamily: 'monospace',
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCableLayout(String title, String barcodeData, double previewHeight) {
    // Layout para etiqueta de cabo (geralmente mais estreita/longa)
    final isCompact = previewHeight < 100;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Flexible(
          flex: 0,
          child: Text(
            title,
            style: TextStyle(
              fontSize: isMobile ? 10 : 12,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(height: 2),
        Expanded(
          child: BarcodeWidget(
            barcode: Barcode.code128(),
            data: barcodeData.isEmpty ? '0000000000000' : barcodeData,
            drawText: false,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 1),
        Text(
          barcodeData.length > 15 ? '${barcodeData.substring(0, 15)}...' : barcodeData,
          style: TextStyle(fontSize: isMobile ? 7 : 8, color: Colors.black, fontFamily: 'monospace'),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildShippingLayout(String title, String subtitle, String barcodeData, double barcodeHeight) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header com ícone de envio
        Row(
          children: [
            Icon(Icons.local_shipping, size: isMobile ? 12 : 14, color: Colors.black),
            const SizedBox(width: 4),
            Text(
              'ENVIO',
              style: TextStyle(
                fontSize: isMobile ? 8 : 9,
                fontWeight: FontWeight.bold,
                color: Colors.black,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Flexible(
          flex: 0,
          child: Text(
            title,
            style: TextStyle(
              fontSize: isMobile ? 12 : 14,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (subtitle.isNotEmpty) ...[
          const SizedBox(height: 2),
          Flexible(
            flex: 0,
            child: Text(
              subtitle,
              style: TextStyle(fontSize: isMobile ? 8 : 9, color: Colors.black87),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
        const Spacer(),
        // Tracking
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.black, width: 1),
          ),
          child: Text(
            'RASTREIO: ${barcodeData.length > 15 ? '${barcodeData.substring(0, 15)}...' : barcodeData}',
            style: TextStyle(fontSize: isMobile ? 7 : 8, fontWeight: FontWeight.bold, color: Colors.black),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(height: 2),
        _buildBarcode(barcodeData, barcodeHeight * 0.85),
      ],
    );
  }

  Widget _buildAddressLayout(String title, String subtitle, double previewHeight) {
    final isCompact = previewHeight < 120;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.location_on, size: isMobile ? 12 : 14, color: Colors.black),
            const SizedBox(width: 4),
            Text(
              'DESTINATÁRIO',
              style: TextStyle(
                fontSize: isMobile ? 8 : 9,
                fontWeight: FontWeight.bold,
                color: Colors.black,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
        SizedBox(height: isCompact ? 4 : 6),
        Flexible(
          flex: 0,
          child: Text(
            title,
            style: TextStyle(
              fontSize: isMobile ? 12 : 14,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
            maxLines: isCompact ? 1 : 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (subtitle.isNotEmpty) ...[
          const SizedBox(height: 2),
          Flexible(
            child: Text(
              subtitle,
              style: TextStyle(fontSize: isMobile ? 10 : 11, color: Colors.black87),
              maxLines: isCompact ? 2 : 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
        const Spacer(),
        Divider(color: Colors.grey.shade400, height: 1),
        const SizedBox(height: 2),
        Text(
          'Remetente: Zebra Label Pro',
          style: TextStyle(fontSize: isMobile ? 7 : 8, color: Colors.black54),
        ),
      ],
    );
  }

  Widget _buildPriceTagLayout(String title, String subtitle, String barcodeData, double previewHeight, double barcodeHeight) {
    final isCompact = previewHeight < 120;
    final priceSize = isCompact ? (isMobile ? 16.0 : 20.0) : (isMobile ? 22.0 : 28.0);
    
    return Column(
      children: [
        Flexible(
          flex: 0,
          child: Text(
            title,
            style: TextStyle(
              fontSize: isMobile ? 10 : 12,
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
            textAlign: TextAlign.center,
            maxLines: isCompact ? 1 : 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const Spacer(),
        // Preço grande
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            subtitle.isEmpty ? 'R\$ 0,00' : subtitle,
            style: TextStyle(
              fontSize: priceSize,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
        ),
        const Spacer(),
        _buildBarcode(barcodeData, barcodeHeight * 0.8),
      ],
    );
  }

  Widget _buildInventoryLayout(String title, String subtitle, String barcodeData, double barcodeHeight) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.warehouse, size: isMobile ? 10 : 12, color: Colors.black),
                  const SizedBox(width: 2),
                  Flexible(
                    child: Text(
                      'INVENTÁRIO',
                      style: TextStyle(
                        fontSize: isMobile ? 7 : 8,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                        letterSpacing: 1,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              DateTime.now().toString().substring(0, 10),
              style: TextStyle(fontSize: isMobile ? 7 : 8, color: Colors.black54),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Flexible(
          flex: 0,
          child: Text(
            title,
            style: TextStyle(
              fontSize: isMobile ? 12 : 14,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (subtitle.isNotEmpty) ...[
          const SizedBox(height: 2),
          Flexible(
            flex: 0,
            child: Row(
              children: [
                Icon(Icons.place, size: isMobile ? 9 : 10, color: Colors.black54),
                const SizedBox(width: 2),
                Expanded(
                  child: Text(
                    'Local: $subtitle',
                    style: TextStyle(fontSize: isMobile ? 8 : 9, color: Colors.black87),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
        const Spacer(),
        _buildBarcode(barcodeData, barcodeHeight),
      ],
    );
  }

  Widget _buildBarcode(String data, double height) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: height.clamp(20.0, 60.0),
          width: double.infinity,
          child: BarcodeWidget(
            barcode: Barcode.code128(),
            data: data.isEmpty ? '0000000000000' : data,
            drawText: false,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 1),
        Text(
          data.length > 20 ? '${data.substring(0, 20)}...' : data,
          style: TextStyle(
            fontSize: isMobile ? 8 : 9,
            color: Colors.black,
            fontFamily: 'monospace',
            letterSpacing: 0.5,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

/// Painter para simular textura de papel térmico
class _LabelBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Linhas sutis horizontais para simular papel térmico
    final paint = Paint()
      ..color = Colors.grey.withValues(alpha: 0.03)
      ..strokeWidth = 0.5;

    for (double y = 0; y < size.height; y += 3) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _SectionLabel extends StatelessWidget {
  final String text;
  final bool isMobile;
  const _SectionLabel(this.text, {this.isMobile = false});

  @override
  Widget build(BuildContext context) => Text(text,
      style: Theme.of(context)
          .textTheme
          .titleSmall
          ?.copyWith(
            fontWeight: FontWeight.bold,
            fontSize: isMobile ? 13 : null,
          ));
}

class _HistoryTile extends ConsumerWidget {
  final LabelJob job;
  final bool isMobile;
  const _HistoryTile({required this.job, this.isMobile = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      visualDensity: isMobile ? VisualDensity.compact : VisualDensity.standard,
      leading: Icon(
        job.success ? Icons.check_circle_outline : Icons.error_outline,
        color: job.success ? Colors.green : Colors.red,
        size: isMobile ? 18 : 20,
      ),
      title: Text(
        job.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: isMobile ? 13 : 14),
      ),
      subtitle: Text(
        '${job.template.displayName} · ${_fmt(job.sentAt)}',
        style: TextStyle(fontSize: isMobile ? 10 : 11),
      ),
      trailing: IconButton(
        icon: Icon(Icons.close, size: isMobile ? 14 : 16),
        onPressed: () => ref.read(historyProvider.notifier).remove(job.id),
        tooltip: 'Remover',
        visualDensity: VisualDensity.compact,
      ),
    );
  }

  String _fmt(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')} '
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
}
