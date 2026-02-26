import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:zebra_label_pro/core/responsive.dart';
import 'package:zebra_label_pro/models/label_job.dart';
import 'package:zebra_label_pro/providers/history_provider.dart';
import 'package:zebra_label_pro/providers/printer_provider.dart';
import 'package:zebra_label_pro/services/zebra_service.dart';
import 'package:zebra_label_pro/ui/widgets/barcode_scanner_sheet.dart';
import 'package:zebra_label_pro/ui/widgets/modern_snackbar.dart';

class BatchPrintPage extends ConsumerStatefulWidget {
  const BatchPrintPage({super.key});

  @override
  ConsumerState<BatchPrintPage> createState() => _BatchPrintPageState();
}

class _BatchPrintPageState extends ConsumerState<BatchPrintPage> {
  final _items = <_BatchItem>[];
  LabelTemplate _template = LabelTemplate.product;
  bool _isPrinting = false;
  int _printedCount = 0;
  int _failedCount = 0;

  void _addItem() {
    setState(() {
      _items.add(_BatchItem(
        id: const Uuid().v4(),
        title: '',
        subtitle: '',
        barcode: '',
      ));
    });
  }

  void _removeItem(String id) {
    setState(() {
      _items.removeWhere((i) => i.id == id);
    });
  }

  void _duplicateItem(_BatchItem item) {
    final index = _items.indexOf(item);
    setState(() {
      _items.insert(index + 1, _BatchItem(
        id: const Uuid().v4(),
        title: item.title,
        subtitle: item.subtitle,
        barcode: item.barcode,
      ));
    });
  }

  void _clearAll() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Limpar tudo?'),
        content: const Text('Isso removerá todos os itens da lista.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              setState(() => _items.clear());
              Navigator.pop(ctx);
            },
            child: const Text('Limpar'),
          ),
        ],
      ),
    );
  }

  void _generateBarcodeSequence() {
    showDialog(
      context: context,
      builder: (ctx) {
        final prefixCtrl = TextEditingController();
        final startCtrl = TextEditingController(text: '1');
        final countCtrl = TextEditingController(text: '10');
        final titleCtrl = TextEditingController();

        return AlertDialog(
          title: const Text('Gerar Sequência'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(
                  labelText: 'Título (opcional)',
                  hintText: 'Produto',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: prefixCtrl,
                decoration: const InputDecoration(
                  labelText: 'Prefixo do código',
                  hintText: 'PROD-',
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: startCtrl,
                      decoration: const InputDecoration(labelText: 'Início'),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: countCtrl,
                      decoration: const InputDecoration(labelText: 'Quantidade'),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                final prefix = prefixCtrl.text;
                final start = int.tryParse(startCtrl.text) ?? 1;
                final count = int.tryParse(countCtrl.text) ?? 10;
                final title = titleCtrl.text;

                setState(() {
                  for (var i = 0; i < count; i++) {
                    _items.add(_BatchItem(
                      id: const Uuid().v4(),
                      title: title.isEmpty ? 'Item ${start + i}' : '$title ${start + i}',
                      subtitle: '',
                      barcode: '$prefix${(start + i).toString().padLeft(6, '0')}',
                    ));
                  }
                });
                Navigator.pop(ctx);
              },
              child: const Text('Gerar'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _printAll() async {
    if (_items.isEmpty) return;

    final cfg = ref.read(printerConfigProvider);
    final service = ref.read(zebraServiceProvider);

    setState(() {
      _isPrinting = true;
      _printedCount = 0;
      _failedCount = 0;
    });

    for (final item in _items) {
      if (!mounted || !_isPrinting) break;

      final zpl = service.buildZpl(
        title: item.title,
        barcode: item.barcode,
        subtitle: item.subtitle,
        template: _template,
        cfg: cfg,
      );

      final result = await service.sendZpl(cfg, zpl);
      final ok = result is ZebraSuccess;

      if (ok) {
        _printedCount++;
      } else {
        _failedCount++;
      }
      setState(() {});

      // Salvar no histórico
      final job = LabelJob(
        id: const Uuid().v4(),
        sentAt: DateTime.now(),
        title: item.title,
        barcode: item.barcode,
        subtitle: item.subtitle,
        template: _template,
        success: ok,
        zpl: zpl,
      );
      await ref.read(historyProvider.notifier).add(job);

      // Pequeno delay entre impressões
      await Future.delayed(const Duration(milliseconds: 200));
    }

    setState(() => _isPrinting = false);

    if (!mounted) return;

    if (_failedCount == 0) {
      ModernSnackbar.success(
        context,
        'Impresso: $_printedCount etiquetas',
      );
    } else {
      ModernSnackbar.show(
        context,
        message: 'Impresso: $_printedCount | Falhas: $_failedCount',
        type: SnackType.warning,
      );
    }
  }

  void _stopPrinting() {
    setState(() => _isPrinting = false);
  }

  Widget _buildToolbar(BuildContext context, ColorScheme colorScheme, bool isMobile) {
    if (isMobile) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerLow,
          border: Border(
            bottom: BorderSide(color: colorScheme.outlineVariant),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Adicionar'),
                    onPressed: _addItem,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.auto_awesome, size: 18),
                    label: const Text('Sequência'),
                    onPressed: _generateBarcodeSequence,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<LabelTemplate>(
              initialValue: _template,
              decoration: const InputDecoration(
                labelText: 'Template',
                isDense: true,
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              onChanged: (v) => setState(() => _template = v!),
              items: LabelTemplate.values.map((t) {
                return DropdownMenuItem(
                  value: t,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(t.icon, size: 16),
                      const SizedBox(width: 6),
                      Text(t.displayName, style: const TextStyle(fontSize: 13)),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        border: Border(
          bottom: BorderSide(color: colorScheme.outlineVariant),
        ),
      ),
      child: Row(
        children: [
          FilledButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('Adicionar'),
            onPressed: _addItem,
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            icon: const Icon(Icons.auto_awesome),
            label: const Text('Gerar Sequência'),
            onPressed: _generateBarcodeSequence,
          ),
          const Spacer(),
          const Text('Template: '),
          const SizedBox(width: 8),
          DropdownButton<LabelTemplate>(
            value: _template,
            onChanged: (v) => setState(() => _template = v!),
            items: LabelTemplate.values.map((t) {
              return DropdownMenuItem(
                value: t,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(t.icon, size: 18),
                    const SizedBox(width: 8),
                    Text(t.displayName),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isMobile = Responsive.isMobile(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(isMobile ? 'Lote' : 'Impressão em Lote'),
        actions: [
          if (_items.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep),
              onPressed: _clearAll,
              tooltip: 'Limpar tudo',
            ),
        ],
      ),
      body: Column(
        children: [
          // Toolbar - responsive
          _buildToolbar(context, colorScheme, isMobile),

          // Progress bar quando imprimindo
          if (_isPrinting)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: colorScheme.primaryContainer,
              child: Row(
                children: [
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Imprimindo ${_printedCount + _failedCount + 1} de ${_items.length}...',
                    style: TextStyle(color: colorScheme.onPrimaryContainer),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: _stopPrinting,
                    child: const Text('Parar'),
                  ),
                ],
              ),
            ),

          // Lista de itens
          Expanded(
            child: _items.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.playlist_add,
                          size: 64,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Nenhum item adicionado',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Use "Adicionar" ou "Gerar Sequência" para começar',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  )
                : ReorderableListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _items.length,
                    onReorder: (oldIndex, newIndex) {
                      setState(() {
                        if (newIndex > oldIndex) newIndex--;
                        final item = _items.removeAt(oldIndex);
                        _items.insert(newIndex, item);
                      });
                    },
                    itemBuilder: (context, index) {
                      final item = _items[index];
                      return _BatchItemCard(
                        key: ValueKey(item.id),
                        item: item,
                        index: index,
                        onRemove: () => _removeItem(item.id),
                        onDuplicate: () => _duplicateItem(item),
                        onChanged: (updated) {
                          setState(() => _items[index] = updated);
                        },
                      );
                    },
                  ),
          ),

          // Footer com botão de imprimir
          if (_items.isNotEmpty)
            Container(
              padding: EdgeInsets.all(isMobile ? 12 : 16),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                border: Border(
                  top: BorderSide(color: colorScheme.outlineVariant),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: isMobile ? 16 : 18, color: Colors.grey.shade600),
                  const SizedBox(width: 8),
                  Text(
                    '${_items.length} ${_items.length == 1 ? 'etiqueta' : 'etiquetas'}',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: isMobile ? 12 : 14),
                  ),
                  const Spacer(),
                  FilledButton.icon(
                    icon: _isPrinting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.print),
                    label: Text(
                      _isPrinting ? 'Imprimindo...' : (isMobile ? 'Imprimir' : 'Imprimir Tudo'),
                    ),
                    onPressed: _isPrinting ? null : _printAll,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _BatchItem {
  final String id;
  String title;
  String subtitle;
  String barcode;

  _BatchItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.barcode,
  });
}

class _BatchItemCard extends StatelessWidget {
  final _BatchItem item;
  final int index;
  final VoidCallback onRemove;
  final VoidCallback onDuplicate;
  final ValueChanged<_BatchItem> onChanged;

  const _BatchItemCard({
    super.key,
    required this.item,
    required this.index,
    required this.onRemove,
    required this.onDuplicate,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(
                      labelText: 'Título',
                      isDense: true,
                    ),
                    controller: TextEditingController(text: item.title),
                    onChanged: (v) {
                      item.title = v;
                      onChanged(item);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.copy, size: 20),
                  onPressed: onDuplicate,
                  tooltip: 'Duplicar',
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 20),
                  onPressed: onRemove,
                  tooltip: 'Remover',
                  color: Colors.red,
                ),
                ReorderableDragStartListener(
                  index: index,
                  child: const Icon(Icons.drag_handle),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const SizedBox(width: 40),
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(
                      labelText: 'Subtítulo',
                      isDense: true,
                    ),
                    controller: TextEditingController(text: item.subtitle),
                    onChanged: (v) {
                      item.subtitle = v;
                      onChanged(item);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      labelText: 'Código de barras',
                      isDense: true,
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.camera_alt, size: 20),
                        tooltip: 'Escanear',
                        onPressed: () async {
                          final code = await BarcodeScannerSheet.show(context);
                          if (code != null) {
                            item.barcode = code;
                            onChanged(item);
                          }
                        },
                      ),
                    ),
                    controller: TextEditingController(text: item.barcode),
                    onChanged: (v) {
                      item.barcode = v;
                      onChanged(item);
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
