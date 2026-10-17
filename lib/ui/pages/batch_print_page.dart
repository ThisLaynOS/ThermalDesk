import 'package:thermal_desk/models/label_profile.dart';
import 'package:thermal_desk/core/label_validation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:thermal_desk/core/responsive.dart';
import 'package:thermal_desk/models/label_job.dart';
import 'package:thermal_desk/providers/history_provider.dart';
import 'package:thermal_desk/providers/printer_provider.dart';
import 'package:thermal_desk/services/thermaldesk_service.dart';
import 'package:thermal_desk/ui/widgets/barcode_scanner_sheet.dart';
import 'package:thermal_desk/ui/widgets/modern_snackbar.dart';

class BatchPrintPage extends ConsumerStatefulWidget {
  const BatchPrintPage({super.key});

  @override
  ConsumerState<BatchPrintPage> createState() => _BatchPrintPageState();
}

class _BatchPrintPageState extends ConsumerState<BatchPrintPage> {
  final _items = <_BatchItem>[];
  LabelTemplate _template = LabelTemplate.basic;
  bool _isPrinting = false;
  bool _stopRequested = false;
  int _printedCount = 0;
  int _failedCount = 0;

  void _addItem() {
    if (_items.length >= 1000) {
      ModernSnackbar.warning(context, 'Limite de 1000 itens por lote.');
      return;
    }
    setState(() {
      _items.add(
        _BatchItem(id: const Uuid().v4(), title: '', subtitle: '', barcode: ''),
      );
    });
  }

  void _removeItem(String id) {
    setState(() {
      _items.removeWhere((i) => i.id == id);
    });
  }

  void _duplicateItem(_BatchItem item) {
    if (_items.length >= 1000) return;
    final index = _items.indexOf(item);
    setState(() {
      _items.insert(
        index + 1,
        _BatchItem(
          id: const Uuid().v4(),
          title: item.title,
          subtitle: item.subtitle,
          detail: item.detail,
          barcode: item.barcode,
        ),
      );
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

  Future<void> _generateBarcodeSequence() async {
    final prefixCtrl = TextEditingController();
    final startCtrl = TextEditingController(text: '1');
    final countCtrl = TextEditingController(text: '10');
    final titleCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    await showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Gerar Sequência'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: titleCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Título (opcional)',
                      hintText: 'Produto',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
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
                        child: TextFormField(
                          controller: startCtrl,
                          validator: (v) => (int.tryParse(v ?? '') ?? -1) < 0
                              ? 'Informe um início válido'
                              : null,
                          decoration: const InputDecoration(
                            labelText: 'Início',
                          ),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: countCtrl,
                          validator: (v) {
                            final count = int.tryParse(v ?? '');
                            return count == null ||
                                    count < 1 ||
                                    count + _items.length > 1000
                                ? 'Use de 1 a ${1000 - _items.length} itens'
                                : null;
                          },
                          decoration: const InputDecoration(
                            labelText: 'Quantidade',
                          ),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                if (!formKey.currentState!.validate()) return;
                final prefix = prefixCtrl.text;
                final start = int.tryParse(startCtrl.text) ?? 1;
                final count = int.tryParse(countCtrl.text) ?? 10;
                final title = titleCtrl.text;

                setState(() {
                  for (var i = 0; i < count; i++) {
                    _items.add(
                      _BatchItem(
                        id: const Uuid().v4(),
                        title: title.isEmpty
                            ? 'Item ${start + i}'
                            : '$title ${start + i}',
                        subtitle: '',
                        barcode:
                            '$prefix${(start + i).toString().padLeft(6, '0')}',
                      ),
                    );
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
    prefixCtrl.dispose();
    startCtrl.dispose();
    countCtrl.dispose();
    titleCtrl.dispose();
  }

  Future<void> _printAll() async {
    if (_isPrinting || _items.isEmpty) return;
    if (ref.read(sendingProvider)) {
      ModernSnackbar.warning(context, 'Aguarde o envio em curso.');
      return;
    }
    final cfg = ref.read(printerConfigProvider);
    if (cfg.connectionError case final String message) {
      ModernSnackbar.warning(context, message);
      return;
    }
    if (_items.any((item) => item.title.trim().isEmpty)) {
      ModernSnackbar.warning(context, 'Preencha o título de todos os itens.');
      return;
    }
    if (_template == LabelTemplate.priceTag &&
        _items.any(
          (item) =>
              LabelValidation.price(item.subtitle, allowEmpty: true) != null,
        )) {
      ModernSnackbar.warning(
        context,
        'No template Preço, preencha o subtítulo com um preço válido.',
      );
      return;
    }
    final profile = LabelProfile.fromConfig(cfg);
    for (final item in _items) {
      if (_template.usesBarcode) {
        final error = LabelValidation.templateBarcode(
          item.barcode,
          _template,
          profile,
        );
        if (error != null) {
          ModernSnackbar.warning(context, error);
          return;
        }
      }
    }
    final service = ref.read(thermalDeskServiceProvider);
    final history = ref.read(historyProvider.notifier);
    final template = _template;
    final items = _items
        .map(
          (item) => _BatchItem(
            id: item.id,
            title: item.title,
            subtitle: item.subtitle,
            detail: item.detail,
            barcode: item.barcode,
          ),
        )
        .toList();
    final sending = ref.read(sendingProvider.notifier);
    sending.state = true;
    setState(() {
      _isPrinting = true;
      _stopRequested = false;
      _printedCount = 0;
      _failedCount = 0;
    });
    try {
      for (final item in items) {
        if (!mounted || _stopRequested) break;
        final zpl = service.buildZpl(
          title: item.title,
          barcode: item.barcode,
          subtitle: item.subtitle,
          detail: item.detail,
          template: template,
          cfg: cfg,
        );
        final result = await service.sendZpl(cfg, zpl);
        final ok = result is ThermalDeskSuccess;
        if (ok) {
          _printedCount++;
        } else {
          _failedCount++;
        }
        try {
          await history.add(
            LabelJob(
              id: const Uuid().v4(),
              sentAt: DateTime.now(),
              title: item.title,
              barcode: item.barcode,
              subtitle: item.subtitle,
              detail: item.detail,
              template: template,
              success: ok,
              zpl: zpl,
            ),
          );
        } catch (_) {
          if (mounted) {
            ModernSnackbar.warning(
              context,
              'Não foi possível guardar o histórico do lote.',
            );
          }
        }
        if (!mounted) return;
        setState(() {});
        if (!_stopRequested) {
          await Future<void>.delayed(const Duration(milliseconds: 200));
        }
      }
      if (mounted) {
        ModernSnackbar.show(
          context,
          message:
              '${_stopRequested ? 'Lote interrompido' : 'Lote concluído'}: '
              '$_printedCount enviadas | $_failedCount falhas',
          type: _failedCount > 0 || _stopRequested
              ? SnackType.warning
              : SnackType.success,
        );
      }
    } finally {
      sending.state = false;
      if (mounted) setState(() => _isPrinting = false);
    }
  }

  void _stopPrinting() {
    setState(() => _stopRequested = true);
  }

  Widget _buildToolbar(
    BuildContext context,
    ColorScheme colorScheme,
    bool isMobile,
  ) {
    if (isMobile) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerLow,
          border: Border(bottom: BorderSide(color: colorScheme.outlineVariant)),
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
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
              ),
              onChanged: (v) => setState(() => _template = v!),
              items: LabelTemplate.standard.map((t) {
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
        border: Border(bottom: BorderSide(color: colorScheme.outlineVariant)),
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
            items: LabelTemplate.standard.map((t) {
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
    final busy = ref.watch(sendingProvider);
    final isMobile = !Responsive.isDesktop(context);

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
                    onPressed: _stopRequested ? null : _stopPrinting,
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
                    onReorderItem: (oldIndex, newIndex) {
                      setState(() {
                        final item = _items.removeAt(oldIndex);
                        _items.insert(newIndex, item);
                      });
                    },
                    itemBuilder: (context, index) {
                      final item = _items[index];
                      return _BatchItemCard(
                        key: ValueKey(item.id),
                        item: item,
                        template: _template,
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
                  Icon(
                    Icons.info_outline,
                    size: isMobile ? 16 : 18,
                    color: Colors.grey.shade600,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${_items.length} ${_items.length == 1 ? 'etiqueta' : 'etiquetas'}',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: isMobile ? 12 : 14,
                    ),
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
                      _isPrinting
                          ? 'Imprimindo...'
                          : (isMobile ? 'Imprimir' : 'Imprimir Tudo'),
                    ),
                    onPressed: _isPrinting || busy ? null : _printAll,
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
  String detail;

  _BatchItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.barcode,
    this.detail = '',
  });
}

class _BatchItemCard extends StatefulWidget {
  final _BatchItem item;
  final LabelTemplate template;
  final int index;
  final VoidCallback onRemove;
  final VoidCallback onDuplicate;
  final ValueChanged<_BatchItem> onChanged;

  const _BatchItemCard({
    super.key,
    required this.item,
    required this.template,
    required this.index,
    required this.onRemove,
    required this.onDuplicate,
    required this.onChanged,
  });

  @override
  State<_BatchItemCard> createState() => _BatchItemCardState();
}

class _BatchItemCardState extends State<_BatchItemCard> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _subtitleCtrl;
  late final TextEditingController _barcodeCtrl;
  late final TextEditingController _detailCtrl;
  _BatchItem get item => widget.item;
  int get index => widget.index;
  VoidCallback get onDuplicate => widget.onDuplicate;
  VoidCallback get onRemove => widget.onRemove;
  ValueChanged<_BatchItem> get onChanged => widget.onChanged;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: item.title);
    _subtitleCtrl = TextEditingController(text: item.subtitle);
    _barcodeCtrl = TextEditingController(text: item.barcode);
    _detailCtrl = TextEditingController(text: item.detail);
  }

  @override
  void didUpdateWidget(covariant _BatchItemCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_titleCtrl.text != item.title) _titleCtrl.text = item.title;
    if (_subtitleCtrl.text != item.subtitle) _subtitleCtrl.text = item.subtitle;
    if (_detailCtrl.text != item.detail) _detailCtrl.text = item.detail;
    if (_barcodeCtrl.text != item.barcode) _barcodeCtrl.text = item.barcode;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _subtitleCtrl.dispose();
    _barcodeCtrl.dispose();
    _detailCtrl.dispose();
    super.dispose();
  }

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
                    decoration: InputDecoration(
                      labelText: widget.template == LabelTemplate.address
                          ? widget.template.titleLabel
                          : 'Título',
                      isDense: true,
                    ),
                    controller: _titleCtrl,
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
                if (widget.template.showsSubtitle)
                  Expanded(
                    child: TextField(
                      decoration: InputDecoration(
                        labelText: widget.template.subtitleLabel,
                        isDense: true,
                      ),
                      controller: _subtitleCtrl,
                      onChanged: (v) {
                        item.subtitle = v;
                        onChanged(item);
                      },
                    ),
                  ),
                const SizedBox(width: 12),
                if (widget.template.showsBarcode)
                  Expanded(
                    child: TextField(
                      decoration: InputDecoration(
                        labelText: widget.template.barcodeLabel,
                        isDense: true,
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.camera_alt, size: 20),
                          tooltip: 'Escanear',
                          onPressed: () async {
                            final code = await BarcodeScannerSheet.show(
                              context,
                            );
                            if (code != null && mounted) {
                              item.barcode = code;
                              onChanged(item);
                            }
                          },
                        ),
                      ),
                      controller: _barcodeCtrl,
                      onChanged: (v) {
                        item.barcode = v;
                        onChanged(item);
                      },
                    ),
                  ),
              ],
            ),
            if (widget.template.detailLabel != null) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _detailCtrl,
                decoration: InputDecoration(
                  labelText: widget.template.detailLabel,
                  hintText: widget.template == LabelTemplate.inventory
                      ? 'dd/mm/aaaa (vazio = hoje)'
                      : 'Ex.: PROD-001',
                  isDense: true,
                ),
                onChanged: (value) {
                  item.detail = value;
                  onChanged(item);
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}
