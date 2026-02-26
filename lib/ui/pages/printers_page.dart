import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:zebra_label_pro/core/constants.dart';
import 'package:zebra_label_pro/core/responsive.dart';
import 'package:zebra_label_pro/models/printer_config.dart';
import 'package:zebra_label_pro/providers/printer_provider.dart';
import 'package:zebra_label_pro/services/zebra_service.dart';
import 'package:zebra_label_pro/ui/widgets/modern_snackbar.dart';

class PrintersPage extends ConsumerWidget {
  const PrintersPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final printers = ref.watch(savedPrintersProvider);
    final currentPrinter = ref.watch(printerConfigProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final isMobile = Responsive.isMobile(context);
    final isDesktop = Responsive.isDesktop(context);
    final padding = Responsive.padding(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(isMobile ? 'Impressoras' : 'Impressoras Salvas'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showPrinterDialog(context, ref, null),
            tooltip: 'Adicionar impressora',
          ),
        ],
      ),
      body: printers.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.print_disabled, size: isMobile ? 48 : 64, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  const Text('Nenhuma impressora salva'),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text('Adicionar Impressora'),
                    onPressed: () => _showPrinterDialog(context, ref, null),
                  ),
                ],
              ),
            )
          : isDesktop
              ? _buildGridView(context, ref, printers, currentPrinter, colorScheme, padding)
              : _buildListView(context, ref, printers, currentPrinter, colorScheme, padding),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showPrinterDialog(context, ref, null),
        icon: const Icon(Icons.add),
        label: Text(isMobile ? 'Nova' : 'Nova Impressora'),
      ),
    );
  }

  Widget _buildGridView(
    BuildContext context,
    WidgetRef ref,
    List<PrinterConfig> printers,
    PrinterConfig currentPrinter,
    ColorScheme colorScheme,
    EdgeInsets padding,
  ) {
    final columns = Responsive.gridColumns(context).clamp(2, 3);
    return GridView.builder(
      padding: padding,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 2.2,
      ),
      itemCount: printers.length,
      itemBuilder: (context, index) => _buildPrinterCard(
        context, ref, printers[index], currentPrinter, colorScheme, printers,
      ),
    );
  }

  Widget _buildListView(
    BuildContext context,
    WidgetRef ref,
    List<PrinterConfig> printers,
    PrinterConfig currentPrinter,
    ColorScheme colorScheme,
    EdgeInsets padding,
  ) {
    return ListView.builder(
      padding: padding,
      itemCount: printers.length,
      itemBuilder: (context, index) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: _buildPrinterCard(
          context, ref, printers[index], currentPrinter, colorScheme, printers,
        ),
      ),
    );
  }

  Widget _buildPrinterCard(
    BuildContext context,
    WidgetRef ref,
    PrinterConfig printer,
    PrinterConfig currentPrinter,
    ColorScheme colorScheme,
    List<PrinterConfig> printers,
  ) {
    final isSelected = printer.id == currentPrinter.id;
    final isMobile = Responsive.isMobile(context);

    return Card(
      color: isSelected ? colorScheme.primaryContainer : null,
      child: InkWell(
        onTap: () {
          ref.read(printerConfigProvider.notifier).selectPrinter(printer);
          Navigator.pop(context);
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: EdgeInsets.all(isMobile ? 12 : 16),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(isMobile ? 10 : 12),
                decoration: BoxDecoration(
                  color: isSelected
                      ? colorScheme.primary
                      : colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.print,
                  size: isMobile ? 20 : 24,
                  color: isSelected
                      ? colorScheme.onPrimary
                      : colorScheme.onSurfaceVariant,
                ),
              ),
              SizedBox(width: isMobile ? 12 : 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            printer.name,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: isMobile ? 14 : 16,
                              color: isSelected
                                  ? colorScheme.onPrimaryContainer
                                  : null,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (printer.isDefault) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: colorScheme.tertiary,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'PADRÃO',
                              style: TextStyle(
                                fontSize: isMobile ? 8 : 10,
                                fontWeight: FontWeight.bold,
                                color: colorScheme.onTertiary,
                              ),
                            ),
                          ),
                        ],
                        if (isSelected) ...[
                          const SizedBox(width: 6),
                          Icon(
                            Icons.check_circle,
                            size: isMobile ? 14 : 16,
                            color: colorScheme.primary,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${printer.ip}:${printer.port}',
                      style: TextStyle(
                        fontSize: isMobile ? 11 : 13,
                        color: isSelected
                            ? colorScheme.onPrimaryContainer.withValues(alpha: 0.7)
                            : Colors.grey.shade600,
                      ),
                    ),
                    Text(
                      '${printer.dpi} DPI • ${printer.labelSize}',
                      style: TextStyle(
                        fontSize: isMobile ? 10 : 12,
                        color: isSelected
                            ? colorScheme.onPrimaryContainer.withValues(alpha: 0.6)
                            : Colors.grey.shade500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                iconSize: isMobile ? 20 : 24,
                onSelected: (action) {
                  switch (action) {
                    case 'edit':
                      _showPrinterDialog(context, ref, printer);
                      break;
                    case 'test':
                      _testConnection(context, ref, printer);
                      break;
                    case 'default':
                      ref.read(savedPrintersProvider.notifier).setDefault(printer.id);
                      break;
                    case 'delete':
                      _confirmDelete(context, ref, printer);
                      break;
                  }
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: 'test',
                    child: ListTile(
                      dense: true,
                      leading: Icon(Icons.wifi_tethering),
                      title: Text('Testar conexão'),
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'edit',
                    child: ListTile(
                      dense: true,
                      leading: Icon(Icons.edit),
                      title: Text('Editar'),
                    ),
                  ),
                  if (!printer.isDefault)
                    const PopupMenuItem(
                      value: 'default',
                      child: ListTile(
                        dense: true,
                        leading: Icon(Icons.star_outline),
                        title: Text('Definir como padrão'),
                      ),
                    ),
                  if (printers.length > 1)
                    const PopupMenuItem(
                      value: 'delete',
                      child: ListTile(
                        dense: true,
                        leading: Icon(Icons.delete_outline, color: Colors.red),
                        title: Text('Remover', style: TextStyle(color: Colors.red)),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPrinterDialog(BuildContext context, WidgetRef ref, PrinterConfig? printer) {
    final isEdit = printer != null;
    final nameCtrl = TextEditingController(text: printer?.name ?? '');
    final ipCtrl = TextEditingController(text: printer?.ip ?? '');
    final portCtrl = TextEditingController(text: (printer?.port ?? 9100).toString());
    var dpi = printer?.dpi ?? 203;
    var labelSize = printer?.labelSize ?? '30x100mm (203dpi S4M)';

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(isEdit ? 'Editar Impressora' : 'Nova Impressora'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Nome da impressora',
                        hintText: 'Ex: Zebra Escritório',
                        prefixIcon: Icon(Icons.label_outline),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: ipCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Endereço IP',
                        hintText: '192.168.1.100',
                        prefixIcon: Icon(Icons.router_outlined),
                      ),
                      keyboardType: TextInputType.url,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: portCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Porta TCP',
                        hintText: '9100',
                        prefixIcon: Icon(Icons.settings_ethernet),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 16),
                    const Text('DPI', style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [203, 200, 300].map((d) {
                        return ChoiceChip(
                          label: Text(d == 203 ? '203 (S4M)' : '$d'),
                          selected: dpi == d,
                          onSelected: (_) => setState(() => dpi = d),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: labelSize,
                      decoration: const InputDecoration(
                        labelText: 'Tamanho da etiqueta',
                        prefixIcon: Icon(Icons.straighten),
                      ),
                      items: AppConstants.labelSizes.keys.map((key) {
                        return DropdownMenuItem(value: key, child: Text(key, style: const TextStyle(fontSize: 13)));
                      }).toList(),
                      onChanged: (v) => setState(() => labelSize = v!),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: () {
                    final config = PrinterConfig(
                      id: printer?.id ?? const Uuid().v4(),
                      name: nameCtrl.text.isEmpty ? 'Impressora' : nameCtrl.text,
                      ip: ipCtrl.text,
                      port: int.tryParse(portCtrl.text) ?? 9100,
                      dpi: dpi,
                      labelSize: labelSize,
                      isDefault: printer?.isDefault ?? false,
                    );

                    if (isEdit) {
                      ref.read(savedPrintersProvider.notifier).update(config);
                      // Se estiver editando a impressora atual, atualizar
                      if (ref.read(printerConfigProvider).id == config.id) {
                        ref.read(printerConfigProvider.notifier).save(config);
                      }
                    } else {
                      ref.read(savedPrintersProvider.notifier).add(config);
                    }
                    Navigator.pop(ctx);
                  },
                  child: Text(isEdit ? 'Salvar' : 'Adicionar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _testConnection(BuildContext context, WidgetRef ref, PrinterConfig printer) async {
    final service = ref.read(zebraServiceProvider);
    
    ModernSnackbar.show(
      context,
      message: 'Testando conexão com ${printer.name}...',
      type: SnackType.info,
      duration: const Duration(seconds: 10),
    );

    final result = await service.testConnection(printer);
    final ok = result is ZebraSuccess;

    if (!context.mounted) return;
    if (ok) {
      ModernSnackbar.success(context, 'Conexão OK!');
    } else {
      ModernSnackbar.error(context, 'Falha na conexão');
    }
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, PrinterConfig printer) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remover impressora?'),
        content: Text('Tem certeza que deseja remover "${printer.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              ref.read(savedPrintersProvider.notifier).remove(printer.id);
              Navigator.pop(ctx);
            },
            child: const Text('Remover'),
          ),
        ],
      ),
    );
  }
}
