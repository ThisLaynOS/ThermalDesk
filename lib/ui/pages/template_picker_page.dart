import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:thermal_desk/models/custom_label.dart';
import 'package:thermal_desk/models/label_job.dart';
import 'package:thermal_desk/providers/custom_labels_provider.dart';
import 'package:thermal_desk/providers/printer_provider.dart';
import 'package:thermal_desk/services/template_files.dart';
import 'package:thermal_desk/ui/designer/label_canvas.dart';
import 'package:thermal_desk/ui/designer/label_designer_page.dart';
import 'package:thermal_desk/ui/widgets/modern_snackbar.dart';
import 'package:uuid/uuid.dart';

class TemplatePicker extends ConsumerStatefulWidget {
  final LabelTemplate current;
  final bool showCustom;
  const TemplatePicker({
    super.key,
    this.current = LabelTemplate.basic,
    this.showCustom = false,
  });
  @override
  ConsumerState<TemplatePicker> createState() => _TemplatePickerState();
}

class _TemplatePickerState extends ConsumerState<TemplatePicker>
    with SingleTickerProviderStateMixin {
  late final _tabs = TabController(
    length: 2,
    vsync: this,
    initialIndex: widget.showCustom ? 1 : 0,
  );
  bool _busy = false;
  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _open({
    CustomLabel? label,
    bool editing = true,
    bool isNew = false,
  }) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            LabelDesignerPage(label: label, editing: editing, isNew: isNew),
      ),
    );
    if (mounted) _tabs.animateTo(1);
  }

  Future<void> _import() async {
    setState(() => _busy = true);
    try {
      final label = await ref.read(templateFilesProvider).importLabel();
      if (!mounted || label == null) return;
      await _open(label: label, isNew: true);
    } catch (e) {
      if (mounted) {
        ModernSnackbar.error(
          context,
          e is FormatException
              ? e.message
              : 'Não foi possível importar o arquivo.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _action(String action, CustomLabel label) async {
    if (_busy) return;
    if (action == 'edit') {
      await _open(label: label);
      return;
    }
    if (action == 'duplicate') {
      await _open(
        label: label.copyWith(
          id: const Uuid().v4(),
          name:
              '${label.name.length > 70 ? label.name.substring(0, 70) : label.name} (cópia)',
        ),
        isNew: true,
      );
      return;
    }
    if (action == 'delete') {
      final yes = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Excluir template?'),
          content: Text('Excluir "${label.name}" dos seus templates?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Excluir'),
            ),
          ],
        ),
      );
      if (yes != true || !mounted) return;
    }
    setState(() => _busy = true);
    try {
      if (action == 'delete') {
        await ref.read(customLabelsProvider.notifier).remove(label.id);
      }
      if (action == 'export') {
        final saved = await ref.read(templateFilesProvider).exportLabel(label);
        if (mounted && saved) {
          ModernSnackbar.success(
            context,
            'Modelo exportado para compartilhar.',
          );
        }
      }
    } catch (_) {
      if (mounted) {
        ModernSnackbar.error(context, 'Não foi possível concluir a operação.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final custom = ref.watch(customLabelsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Templates'),
        bottom: TabBar(
          controller: _tabs,
          tabs: [
            const Tab(text: 'Padrão'),
            Tab(text: 'Meus templates (${custom.valueOrNull?.length ?? 0})'),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: _busy ? null : () => _open(),
                  icon: const Icon(Icons.add),
                  label: const Text('Criar etiqueta'),
                ),
                OutlinedButton.icon(
                  onPressed: _busy ? null : _import,
                  icon: const Icon(Icons.file_open_outlined),
                  label: const Text('Importar modelo'),
                ),
              ],
            ),
          ),
          if (_busy) const LinearProgressIndicator(),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                _standard(),
                custom.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (_, _) => Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Não foi possível carregar os templates.'),
                        TextButton(
                          onPressed: () => ref.invalidate(customLabelsProvider),
                          child: const Text('Tentar novamente'),
                        ),
                      ],
                    ),
                  ),
                  data: (labels) => Column(
                    children: [
                      if (ref
                              .read(customLabelsProvider.notifier)
                              .skippedRecords >
                          0)
                        const Padding(
                          padding: EdgeInsets.all(12),
                          child: Text(
                            'Alguns registros inválidos não puderam ser carregados.',
                          ),
                        ),
                      Expanded(
                        child: labels.isEmpty
                            ? const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(24),
                                  child: Text(
                                    'Crie sua primeira etiqueta ou importe um modelo ThermalDesk.\nSeus templates salvos aparecerão aqui.',
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              )
                            : GridView.builder(
                                padding: const EdgeInsets.all(16),
                                gridDelegate:
                                    const SliverGridDelegateWithMaxCrossAxisExtent(
                                      maxCrossAxisExtent: 320,
                                      mainAxisExtent: 250,
                                      mainAxisSpacing: 12,
                                      crossAxisSpacing: 12,
                                    ),
                                itemCount: labels.length,
                                itemBuilder: (context, index) =>
                                    _customCard(labels[index]),
                              ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _standard() => GridView.builder(
    padding: const EdgeInsets.all(16),
    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
      maxCrossAxisExtent: 280,
      mainAxisExtent: 180,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
    ),
    itemCount: LabelTemplate.standard.length,
    itemBuilder: (context, index) {
      final template = LabelTemplate.standard[index];
      final selected = template == widget.current;
      return Card(
        clipBehavior: Clip.antiAlias,
        color: selected ? Theme.of(context).colorScheme.primaryContainer : null,
        child: InkWell(
          onTap: () => Navigator.pop(context, template),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(template.icon),
                const Spacer(),
                Text(
                  template.displayName,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  template.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );

  Widget _customCard(CustomLabel label) => Card(
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: _busy ? null : () => _open(label: label, editing: false),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ExcludeSemantics(
              child: LabelCanvas(
                label: label,
                dpi: ref.watch(printerConfigProvider).dpi,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
            child: Text(
              label.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              '${label.widthMm} × ${label.heightMm} mm',
              style: const TextStyle(fontSize: 12),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: _busy
                      ? null
                      : () => _open(label: label, editing: false),
                  child: const Text('Usar etiqueta'),
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'Opções de ${label.name}',
                enabled: !_busy,
                onSelected: (v) => _action(v, label),
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: Text('Editar')),
                  PopupMenuItem(value: 'duplicate', child: Text('Duplicar')),
                  PopupMenuItem(
                    value: 'export',
                    child: Text('Exportar modelo'),
                  ),
                  PopupMenuItem(value: 'delete', child: Text('Excluir')),
                ],
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
