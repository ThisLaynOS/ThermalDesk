import 'package:thermal_desk/models/label_profile.dart';
import 'package:thermal_desk/core/label_validation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:thermal_desk/core/responsive.dart';
import 'package:thermal_desk/models/label_job.dart';
import 'package:thermal_desk/models/printer_config.dart';
import 'package:thermal_desk/providers/printer_provider.dart';
import 'package:thermal_desk/ui/pages/printers_page.dart';
import 'package:thermal_desk/ui/widgets/barcode_scanner_sheet.dart';

class PrinterFormCard extends ConsumerWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController titleCtrl;
  final TextEditingController barcodeCtrl;
  final TextEditingController subtitleCtrl;
  final TextEditingController? detailCtrl;
  final LabelTemplate selectedTemplate;
  final ValueChanged<LabelTemplate> onTemplateChange;
  final VoidCallback onTest;
  final VoidCallback onPrint;
  final VoidCallback onPickTemplate;

  const PrinterFormCard({
    super.key,
    required this.formKey,
    required this.titleCtrl,
    required this.barcodeCtrl,
    required this.subtitleCtrl,
    this.detailCtrl,
    required this.selectedTemplate,
    required this.onTemplateChange,
    required this.onTest,
    required this.onPrint,
    required this.onPickTemplate,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cfg = ref.watch(printerConfigProvider);
    final connStatus = ref.watch(connStatusProvider);
    final sending = ref.watch(sendingProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final isTesting = connStatus == ConnStatus.testing;
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
        child: Form(
          key: formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // — Section: Impressora —
              _SectionHeader(
                icon: Icons.print_outlined,
                label: 'Impressora',
                isMobile: isMobile,
              ),
              SizedBox(height: isMobile ? 10 : 12),
              _buildIpPortFields(context, ref, cfg, isMobile),
              SizedBox(height: isMobile ? 16 : 20),

              // — Section: Etiqueta —
              _SectionHeader(
                icon: Icons.label_outline,
                label: 'Dados da Etiqueta',
                isMobile: isMobile,
              ),
              SizedBox(height: isMobile ? 10 : 12),
              TextFormField(
                controller: titleCtrl,
                decoration: InputDecoration(
                  labelText: selectedTemplate.titleLabel,
                  prefixIcon: const Icon(Icons.title),
                  hintText: 'Produto Exemplo',
                  isDense: isMobile,
                ),
                style: TextStyle(fontSize: isMobile ? 14 : 16),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Título obrigatório'
                    : null,
              ),
              SizedBox(height: isMobile ? 10 : 12),
              if (selectedTemplate.showsBarcode)
                TextFormField(
                  controller: barcodeCtrl,
                  validator: (value) => LabelValidation.templateBarcode(
                    value,
                    selectedTemplate,
                    LabelProfile.fromConfig(cfg),
                  ),
                  decoration: InputDecoration(
                    labelText: selectedTemplate.barcodeLabel,
                    prefixIcon: const Icon(Icons.qr_code_scanner),
                    hintText: selectedTemplate == LabelTemplate.qrCode
                        ? 'https://exemplo.local'
                        : '0000000000000',
                    isDense: isMobile,
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.camera_alt),
                      tooltip: 'Escanear código de barras',
                      onPressed: () async {
                        final code = await BarcodeScannerSheet.show(context);
                        if (code != null && context.mounted) {
                          barcodeCtrl.text = code;
                        }
                      },
                    ),
                  ),
                  style: TextStyle(fontSize: isMobile ? 14 : 16),
                  keyboardType: selectedTemplate == LabelTemplate.qrCode
                      ? TextInputType.url
                      : TextInputType.text,
                ),
              SizedBox(height: isMobile ? 10 : 12),
              if (selectedTemplate.showsSubtitle)
                TextFormField(
                  controller: subtitleCtrl,
                  validator: selectedTemplate == LabelTemplate.priceTag
                      ? (value) =>
                            LabelValidation.price(value, allowEmpty: true)
                      : null,
                  keyboardType: selectedTemplate == LabelTemplate.priceTag
                      ? const TextInputType.numberWithOptions(decimal: true)
                      : TextInputType.text,
                  decoration: InputDecoration(
                    labelText: selectedTemplate.subtitleLabel,
                    hintText: selectedTemplate == LabelTemplate.priceTag
                        ? 'R\$ 0,00'
                        : null,
                    prefixIcon: const Icon(Icons.short_text),
                    isDense: isMobile,
                  ),
                  style: TextStyle(fontSize: isMobile ? 14 : 16),
                ),
              SizedBox(height: isMobile ? 16 : 20),

              if (selectedTemplate.detailLabel != null &&
                  detailCtrl != null) ...[
                TextFormField(
                  controller: detailCtrl,
                  decoration: InputDecoration(
                    labelText: selectedTemplate.detailLabel,
                    hintText: selectedTemplate == LabelTemplate.inventory
                        ? 'dd/mm/aaaa (vazio = hoje)'
                        : 'Ex.: PROD-001',
                    isDense: isMobile,
                  ),
                ),
                SizedBox(height: isMobile ? 16 : 20),
              ],
              // — Template picker —
              _SectionHeader(
                icon: Icons.dashboard_customize_outlined,
                label: 'Template',
                isMobile: isMobile,
              ),
              SizedBox(height: isMobile ? 8 : 10),
              Wrap(
                spacing: isMobile ? 6 : 8,
                runSpacing: isMobile ? 6 : 8,
                children: LabelTemplate.standard.map((t) {
                  return ChoiceChip(
                    label: Text(
                      t.displayName,
                      style: TextStyle(fontSize: isMobile ? 12 : 14),
                    ),
                    selected: selectedTemplate == t,
                    onSelected: (_) => onTemplateChange(t),
                    visualDensity: isMobile
                        ? VisualDensity.compact
                        : VisualDensity.standard,
                  );
                }).toList(),
              ),
              SizedBox(height: isMobile ? 16 : 20),

              OutlinedButton.icon(
                onPressed: onPickTemplate,
                icon: const Icon(Icons.design_services_outlined),
                label: const Text('Meus templates e designer'),
              ),
              const SizedBox(height: 12),

              // — Buttons —
              _buildActionButtons(
                context,
                colorScheme,
                isTesting,
                connStatus,
                sending,
                isMobile,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIpPortFields(
    BuildContext context,
    WidgetRef ref,
    PrinterConfig cfg,
    bool isMobile,
  ) {
    final savedPrinters = ref.watch(savedPrintersProvider);
    final hasValidPrinter = cfg.connectionError == null;

    return Container(
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      decoration: BoxDecoration(
        color: hasValidPrinter
            ? Colors.green.withValues(alpha: 0.08)
            : Colors.orange.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: hasValidPrinter
              ? Colors.green.shade300
              : Colors.orange.shade300,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Impressora atual
          Row(
            children: [
              Icon(
                hasValidPrinter ? Icons.print : Icons.print_disabled,
                color: hasValidPrinter
                    ? Colors.green.shade700
                    : Colors.orange.shade700,
                size: isMobile ? 20 : 24,
              ),
              SizedBox(width: isMobile ? 8 : 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      cfg.name,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: isMobile ? 14 : 16,
                      ),
                    ),
                    if (hasValidPrinter)
                      Text(
                        '${cfg.ip}:${cfg.port} • ${cfg.dpi} DPI',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: isMobile ? 12 : 13,
                        ),
                      )
                    else
                      Text(
                        'Nenhum IP configurado',
                        style: TextStyle(
                          color: Colors.orange.shade700,
                          fontSize: isMobile ? 12 : 13,
                        ),
                      ),
                  ],
                ),
              ),
              // Botão para gerenciar/trocar impressora
              FilledButton.tonalIcon(
                onPressed: () =>
                    _showPrinterSelector(context, ref, cfg, savedPrinters),
                icon: Icon(Icons.swap_horiz, size: isMobile ? 16 : 18),
                label: Text(
                  savedPrinters.length > 1 ? 'Trocar' : 'Configurar',
                  style: TextStyle(fontSize: isMobile ? 12 : 13),
                ),
                style: FilledButton.styleFrom(
                  padding: EdgeInsets.symmetric(
                    horizontal: isMobile ? 12 : 16,
                    vertical: isMobile ? 6 : 8,
                  ),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),

          // Se não tem impressora válida, mostrar dica
          if (!hasValidPrinter) ...[
            SizedBox(height: isMobile ? 10 : 12),
            Row(
              children: [
                Icon(
                  Icons.info_outline,
                  size: 14,
                  color: Colors.orange.shade700,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    cfg.connectionError ??
                        'Configure a impressora para imprimir',
                    style: TextStyle(
                      fontSize: isMobile ? 11 : 12,
                      color: Colors.orange.shade700,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  void _showPrinterSelector(
    BuildContext context,
    WidgetRef ref,
    PrinterConfig currentCfg,
    List<PrinterConfig> savedPrinters,
  ) {
    // Se tiver mais de uma impressora salva, mostrar menu de seleção
    if (savedPrinters.length > 1) {
      showModalBottomSheet(
        context: context,
        builder: (ctx) => _PrinterSelectorSheet(
          printers: savedPrinters,
          currentPrinter: currentCfg,
          onSelect: (printer) {
            ref.read(printerConfigProvider.notifier).selectPrinter(printer);
            Navigator.pop(ctx);
          },
          onManage: () {
            Navigator.pop(ctx);
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const PrintersPage()),
            );
          },
        ),
      );
    } else {
      // Se só tem uma ou nenhuma, ir direto para página de impressoras
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const PrintersPage()),
      );
    }
  }

  Widget _buildActionButtons(
    BuildContext context,
    ColorScheme colorScheme,
    bool isTesting,
    ConnStatus connStatus,
    bool sending,
    bool isMobile,
  ) {
    if (isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FilledButton.icon(
            icon: isTesting
                ? const SizedBox.square(
                    dimension: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.wifi_tethering, size: 18),
            label: Text(isTesting ? 'Testando...' : 'Testar'),
            onPressed: isTesting ? null : onTest,
            style: FilledButton.styleFrom(
              backgroundColor: connStatus == ConnStatus.connected
                  ? Colors.green.shade600
                  : connStatus == ConnStatus.failed
                  ? Colors.red.shade600
                  : colorScheme.primary,
            ),
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            icon: sending
                ? const SizedBox.square(
                    dimension: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.print, size: 18),
            label: Text(sending ? 'Enviando...' : 'Imprimir'),
            onPressed: sending ? null : onPrint,
          ),
        ],
      );
    }

    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            icon: isTesting
                ? const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.wifi_tethering),
            label: Text(isTesting ? 'Testando...' : 'Testar conexão'),
            onPressed: isTesting ? null : onTest,
            style: FilledButton.styleFrom(
              backgroundColor: connStatus == ConnStatus.connected
                  ? Colors.green.shade600
                  : connStatus == ConnStatus.failed
                  ? Colors.red.shade600
                  : colorScheme.primary,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: FilledButton.icon(
            icon: sending
                ? const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.print),
            label: Text(sending ? 'Enviando...' : 'Imprimir'),
            onPressed: sending ? null : onPrint,
          ),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isMobile;
  const _SectionHeader({
    required this.icon,
    required this.label,
    this.isMobile = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icon,
          size: isMobile ? 16 : 18,
          color: Theme.of(context).colorScheme.primary,
        ),
        SizedBox(width: isMobile ? 6 : 8),
        Text(
          label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: Theme.of(context).colorScheme.primary,
            fontSize: isMobile ? 13 : null,
          ),
        ),
      ],
    );
  }
}

/// Bottom sheet para selecionar impressora
class _PrinterSelectorSheet extends StatelessWidget {
  final List<PrinterConfig> printers;
  final PrinterConfig currentPrinter;
  final ValueChanged<PrinterConfig> onSelect;
  final VoidCallback onManage;

  const _PrinterSelectorSheet({
    required this.printers,
    required this.currentPrinter,
    required this.onSelect,
    required this.onManage,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.print, color: colorScheme.primary),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Selecionar Impressora',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                TextButton.icon(
                  onPressed: onManage,
                  icon: const Icon(Icons.settings, size: 18),
                  label: const Text('Gerenciar'),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Lista de impressoras
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.4,
            ),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: printers.length,
              itemBuilder: (ctx, i) {
                final printer = printers[i];
                final isSelected = printer.id == currentPrinter.id;
                final hasIp = printer.ip.isNotEmpty;

                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: isSelected
                        ? colorScheme.primaryContainer
                        : Colors.grey.shade200,
                    child: Icon(
                      Icons.print,
                      color: isSelected
                          ? colorScheme.onPrimaryContainer
                          : Colors.grey.shade600,
                    ),
                  ),
                  title: Text(
                    printer.name,
                    style: TextStyle(
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                  subtitle: Text(
                    hasIp
                        ? '${printer.ip}:${printer.port} • ${printer.dpi} DPI'
                        : 'Sem IP configurado',
                    style: TextStyle(
                      color: hasIp ? null : Colors.orange.shade700,
                    ),
                  ),
                  trailing: isSelected
                      ? Icon(Icons.check_circle, color: colorScheme.primary)
                      : null,
                  selected: isSelected,
                  onTap: hasIp ? () => onSelect(printer) : null,
                );
              },
            ),
          ),

          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
