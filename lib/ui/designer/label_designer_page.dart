import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:thermal_desk/models/custom_label.dart';
import 'package:thermal_desk/models/label_job.dart';
import 'package:thermal_desk/providers/custom_labels_provider.dart';
import 'package:thermal_desk/providers/history_provider.dart';
import 'package:thermal_desk/providers/printer_provider.dart';
import 'package:thermal_desk/services/template_files.dart';
import 'package:thermal_desk/services/thermaldesk_service.dart';
import 'package:thermal_desk/ui/designer/designer_fields.dart';
import 'package:thermal_desk/ui/designer/label_canvas.dart';
import 'package:thermal_desk/ui/pages/printers_page.dart';
import 'package:thermal_desk/ui/widgets/modern_snackbar.dart';
import 'package:uuid/uuid.dart';

class LabelDesignerPage extends ConsumerStatefulWidget {
  final CustomLabel? label;
  final bool editing;
  final bool isNew;
  const LabelDesignerPage({
    super.key,
    this.label,
    this.editing = true,
    this.isNew = false,
  });
  @override
  ConsumerState<LabelDesignerPage> createState() => _LabelDesignerPageState();
}

class _LabelDesignerPageState extends ConsumerState<LabelDesignerPage> {
  late CustomLabel _label = widget.label ?? CustomLabel.blank();
  late bool _editing = widget.editing;
  late String _saved = widget.isNew ? '' : widget.label?.encode() ?? '';
  final _formKey = GlobalKey<FormState>();
  final _undo = <CustomLabel>[], _redo = <CustomLabel>[];
  final _values = <String, String>{};
  final _copies = TextEditingController(text: '1');
  String? _selectedId;
  bool _busy = false, _allowPop = false;
  int get _dpi => ref.read(printerConfigProvider).dpi;
  bool get _dirty => _label.encode() != _saved;
  LabelElement? get _selected =>
      _label.elements.where((e) => e.id == _selectedId).firstOrNull;

  @override
  void dispose() {
    _copies.dispose();
    super.dispose();
  }

  void _checkpoint() {
    _undo.add(_label);
    if (_undo.length > 60) _undo.removeAt(0);
    _redo.clear();
  }

  void _change(CustomLabel next, {bool record = true}) {
    if (record) _checkpoint();
    setState(() => _label = next);
  }

  void _element(LabelElement next, {bool record = true}) => _change(
    _label.copyWith(
      elements: _label.elements.map((e) => e.id == next.id ? next : e).toList(),
    ),
    record: record,
  );
  void _transform(String id, Offset delta, bool resize) {
    final e = _label.elements.firstWhere((e) => e.id == id);
    if (resize) {
      _element(
        e.copyWith(
          width: (e.width + delta.dx).clamp(
            .2,
            math.max(.2, _label.widthMm - e.x),
          ),
          height: (e.height + delta.dy).clamp(
            .2,
            math.max(.2, _label.heightMm - e.y),
          ),
        ),
        record: false,
      );
    } else {
      _element(
        e.copyWith(
          x: (e.x + delta.dx).clamp(0.0, math.max(0, _label.widthMm - e.width)),
          y: (e.y + delta.dy).clamp(
            0.0,
            math.max(0, _label.heightMm - e.height),
          ),
        ),
        record: false,
      );
    }
  }

  void _restore(bool redo) {
    FocusManager.instance.primaryFocus?.unfocus();
    final from = redo ? _redo : _undo, to = redo ? _undo : _redo;
    if (from.isEmpty) return;
    setState(() {
      to.add(_label);
      _label = from.removeLast();
    });
  }

  void _add(LabelElementType type) {
    if (_label.elements.length >= CustomLabel.maxElements) {
      ModernSnackbar.warning(context, 'Limite de 50 elementos por etiqueta.');
      return;
    }
    final index = _label.elements.length + 1;
    final height = switch (type) {
      LabelElementType.qr => 20.0,
      LabelElementType.barcode => 12.0,
      LabelElementType.box => 15.0,
      LabelElementType.line => .4,
      _ => 6.0,
    };
    final width = type == LabelElementType.qr ? 20.0 : 45.0;
    final element = LabelElement(
      id: const Uuid().v4(),
      type: type,
      x: 2,
      y: 2,
      width: math.min(width, _label.widthMm - 4),
      height: math.min(height, _label.heightMm - 4),
      content: switch (type) {
        LabelElementType.text => 'Produto Exemplo',
        LabelElementType.barcode => '0000000000000',
        LabelElementType.qr => 'https://exemplo.local',
        _ => '',
      },
      fieldName: '${type.label} $index',
      editable: type.hasContent,
    );
    _selectedId = element.id;
    _change(_label.copyWith(elements: [..._label.elements, element]));
  }

  Future<void> _save() async {
    if (_busy || !(_formKey.currentState?.validate() ?? true)) return;
    final errors = _label.issues(_dpi);
    if (errors.isNotEmpty) {
      ModernSnackbar.warning(context, errors.first);
      return;
    }
    setState(() => _busy = true);
    final snapshot = _label;
    try {
      await ref.read(customLabelsProvider.notifier).save(snapshot);
      if (!mounted) return;
      setState(() {
        _saved = snapshot.encode();
        _editing = false;
        _values.clear();
      });
      ModernSnackbar.success(
        context,
        'Template salvo em Meus templates. Pronto para usar!',
      );
    } catch (e) {
      if (mounted) ModernSnackbar.error(context, _message(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _message(Object error) => error is FormatException
      ? error.message
      : 'Não foi possível concluir a operação. Tente novamente.';

  Future<void> _leave() async {
    if (_busy) return;
    if (_dirty) {
      final discard = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Sair sem salvar?'),
          content: const Text(
            'As alterações deste template serão descartadas.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Continuar editando'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Descartar'),
            ),
          ],
        ),
      );
      if (discard != true || !mounted) return;
    }
    setState(() => _allowPop = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.pop(context);
    });
  }

  Future<void> _export(String mode) async {
    if (_busy || !(_formKey.currentState?.validate() ?? true)) return;
    setState(() => _busy = true);
    try {
      final files = ref.read(templateFilesProvider);
      bool exported;
      if (mode == 'template') {
        final errors = _label.issues(_dpi);
        if (errors.isNotEmpty) throw FormatException(errors.first);
        exported = await files.exportLabel(_label);
      } else {
        final zpl = _label.buildZpl(
          _dpi,
          values: _editing ? const {} : _values,
          copies: _editing ? 1 : int.tryParse(_copies.text) ?? 0,
        );
        if (mode == 'copy') {
          await Clipboard.setData(ClipboardData(text: zpl));
          exported = true;
        } else {
          exported = await files.exportZpl(_label.name, zpl);
        }
      }
      if (mounted && exported) {
        ModernSnackbar.success(
          context,
          mode == 'copy' ? 'ZPL copiado.' : 'Arquivo exportado.',
        );
      }
    } catch (e) {
      if (mounted) ModernSnackbar.error(context, _message(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _print() async {
    if (_busy ||
        ref.read(sendingProvider) ||
        !(_formKey.currentState?.validate() ?? true)) {
      return;
    }
    final cfg = ref.read(printerConfigProvider);
    if (cfg.connectionError case final String error) {
      ModernSnackbar.warning(context, error);
      return;
    }
    final label = _label;
    String zpl;
    try {
      zpl = label.buildZpl(
        cfg.dpi,
        values: _values,
        copies: int.tryParse(_copies.text) ?? 0,
      );
    } catch (e) {
      ModernSnackbar.warning(context, _message(e));
      return;
    }
    final service = ref.read(thermalDeskServiceProvider);
    final sending = ref.read(sendingProvider.notifier);
    final history = ref.read(historyProvider.notifier);
    sending.state = true;
    setState(() => _busy = true);
    try {
      final result = await service.sendZpl(cfg, zpl);
      final ok = result is ThermalDeskSuccess;
      var recorded = true;
      try {
        await history.add(
          LabelJob(
            id: const Uuid().v4(),
            sentAt: DateTime.now(),
            title: label.name,
            barcode: '',
            subtitle: '${label.widthMm} × ${label.heightMm} mm',
            template: LabelTemplate.custom,
            success: ok,
            zpl: zpl,
          ),
        );
      } catch (_) {
        recorded = false;
      }
      if (!mounted) return;
      if (!ok) {
        ModernSnackbar.error(context, (result as ThermalDeskFailure).message);
      } else if (!recorded) {
        ModernSnackbar.warning(
          context,
          'Etiqueta enviada; não foi possível salvar o histórico.',
        );
      } else {
        ModernSnackbar.success(context, 'Etiqueta enviada à impressora.');
      }
    } catch (_) {
      if (mounted) {
        ModernSnackbar.error(context, 'Não foi possível enviar a etiqueta.');
      }
    } finally {
      sending.state = false;
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cfg = ref.watch(printerConfigProvider);
    final sending = ref.watch(sendingProvider);
    final errors = _label.issues(
      cfg.dpi,
      values: _editing ? const {} : _values,
    );
    return PopScope(
      canPop: _allowPop || (!_dirty && !_busy),
      onPopInvokedWithResult: (popped, _) {
        if (!popped) _leave();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            _editing ? 'Designer de etiquetas' : _label.name,
            overflow: TextOverflow.ellipsis,
          ),
          actions: [
            if (_editing)
              IconButton(
                tooltip: 'Salvar template',
                icon: const Icon(Icons.save_outlined),
                onPressed: _busy ? null : _save,
              ),
            if (!_editing)
              IconButton(
                tooltip: 'Editar template',
                icon: const Icon(Icons.edit_outlined),
                onPressed: _busy
                    ? null
                    : () => setState(() {
                        _editing = true;
                        _values.clear();
                      }),
              ),
            PopupMenuButton<String>(
              tooltip: 'Exportar etiqueta',
              enabled: !_busy,
              onSelected: _export,
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 'template',
                  child: Text('Exportar modelo ThermalDesk'),
                ),
                PopupMenuItem(value: 'zpl', child: Text('Exportar ZPL')),
                PopupMenuItem(value: 'copy', child: Text('Copiar ZPL')),
              ],
            ),
          ],
        ),
        body: AbsorbPointer(
          absorbing: _busy,
          child: Column(
            children: [
              if (_busy) const LinearProgressIndicator(),
              if (_editing) _toolbar(),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final wide = constraints.maxWidth >= 900;
                    final controls = Form(
                      key: _formKey,
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: _editing
                            ? _editorControls()
                            : _useControls(sending, errors),
                      ),
                    );
                    final preview = Container(
                      color: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest,
                      child: Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                            child: Text(
                              '${_label.widthMm.toStringAsFixed(1)} × ${_label.heightMm.toStringAsFixed(1)} mm · ${cfg.dpi} DPI · Prévia local aproximada',
                              style: Theme.of(context).textTheme.labelSmall,
                              textAlign: TextAlign.center,
                            ),
                          ),
                          Expanded(
                            child: LabelCanvas(
                              label: _label,
                              dpi: cfg.dpi,
                              values: _editing ? const {} : _values,
                              selectedId: _selectedId,
                              editing: _editing,
                              onSelect: (id) =>
                                  setState(() => _selectedId = id),
                              onGestureStart: _checkpoint,
                              onMove: (id, delta) =>
                                  _transform(id, delta, false),
                              onResize: (id, delta) =>
                                  _transform(id, delta, true),
                            ),
                          ),
                          if (errors.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.all(8),
                              child: Text(
                                errors.first,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.error,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                    if (wide) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SizedBox(width: 360, child: controls),
                          Expanded(child: preview),
                        ],
                      );
                    }
                    return Column(
                      children: [
                        SizedBox(
                          height: math.min(260, constraints.maxHeight * .42),
                          child: preview,
                        ),
                        Expanded(child: controls),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _toolbar() => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    child: Row(
      children: [
        for (final type in LabelElementType.values)
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: OutlinedButton.icon(
              key: ValueKey('add-${type.name}'),
              onPressed: () => _add(type),
              icon: const Icon(Icons.add, size: 16),
              label: Text(type.label),
            ),
          ),
        IconButton(
          tooltip: 'Desfazer',
          onPressed: _undo.isEmpty ? null : () => _restore(false),
          icon: const Icon(Icons.undo),
        ),
        IconButton(
          tooltip: 'Refazer',
          onPressed: _redo.isEmpty ? null : () => _restore(true),
          icon: const Icon(Icons.redo),
        ),
      ],
    ),
  );

  List<Widget> _editorControls() {
    final selected = _selected;
    return [
      DesignerTextField(
        key: const ValueKey('label-name'),
        value: _label.name,
        label: 'Nome do template',
        maxLength: 80,
        onChanged: (value) => _change(_label.copyWith(name: value)),
      ),
      const SizedBox(height: 12),
      Row(
        children: [
          Expanded(
            child: DesignerNumberField(
              value: _label.widthMm,
              min: 10,
              max: 200,
              label: 'Largura',
              onChanged: (v) => _change(_label.copyWith(widthMm: v)),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: DesignerNumberField(
              value: _label.heightMm,
              min: 10,
              label: 'Altura',
              onChanged: (v) => _change(_label.copyWith(heightMm: v)),
            ),
          ),
        ],
      ),
      const SizedBox(height: 16),
      Text(
        'Elementos (${_label.elements.length}/50)',
        style: Theme.of(context).textTheme.titleSmall,
      ),
      const SizedBox(height: 4),
      const Text(
        'Adicione acima. Toque para selecionar, arraste para mover e use o canto para redimensionar.',
        style: TextStyle(fontSize: 12),
      ),
      if (_label.elements.isEmpty)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 20),
          child: Text('Sua etiqueta começa em branco.'),
        ),
      Wrap(
        spacing: 6,
        children: [
          for (var i = 0; i < _label.elements.length; i++)
            ChoiceChip(
              label: Text('${i + 1}. ${_label.elements[i].type.label}'),
              selected: _selectedId == _label.elements[i].id,
              onSelected: (_) =>
                  setState(() => _selectedId = _label.elements[i].id),
            ),
        ],
      ),
      if (selected != null) ...[
        const Divider(height: 24),
        Text(
          'Editar ${selected.type.label.toLowerCase()}',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        if (selected.type.hasContent) ...[
          DesignerTextField(
            key: ValueKey('content-${selected.id}'),
            value: selected.content,
            label: 'Conteúdo de exemplo',
            onChanged: (v) => _element(selected.copyWith(content: v)),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Campo editável ao usar'),
            value: selected.editable,
            onChanged: (v) => _element(selected.copyWith(editable: v)),
          ),
          if (selected.editable)
            DesignerTextField(
              key: ValueKey('field-${selected.id}'),
              value: selected.fieldName,
              maxLength: 60,
              label: 'Nome do campo',
              onChanged: (v) => _element(selected.copyWith(fieldName: v)),
            ),
          const SizedBox(height: 12),
        ],
        Row(
          children: [
            Expanded(
              child: DesignerNumberField(
                key: ValueKey('x-${selected.id}'),
                value: selected.x,
                min: 0,
                label: 'Posição X',
                onChanged: (v) => _element(selected.copyWith(x: v)),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: DesignerNumberField(
                key: ValueKey('y-${selected.id}'),
                value: selected.y,
                min: 0,
                label: 'Posição Y',
                onChanged: (v) => _element(selected.copyWith(y: v)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: DesignerNumberField(
                key: ValueKey('w-${selected.id}'),
                value: selected.width,
                label: 'Largura do item',
                onChanged: (v) => _element(selected.copyWith(width: v)),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: DesignerNumberField(
                key: ValueKey('h-${selected.id}'),
                value: selected.height,
                label: 'Altura do item',
                onChanged: (v) => _element(selected.copyWith(height: v)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (selected.type == LabelElementType.text) ...[
          DesignerNumberField(
            key: ValueKey('font-${selected.id}'),
            value: selected.fontSize,
            min: 1,
            max: 40,
            label: 'Tamanho da fonte',
            onChanged: (v) => _element(selected.copyWith(fontSize: v)),
          ),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'L', icon: Icon(Icons.format_align_left)),
              ButtonSegment(value: 'C', icon: Icon(Icons.format_align_center)),
              ButtonSegment(value: 'R', icon: Icon(Icons.format_align_right)),
            ],
            selected: {selected.alignment},
            onSelectionChanged: (v) =>
                _element(selected.copyWith(alignment: v.first)),
          ),
        ],
        if (selected.type == LabelElementType.box)
          DesignerNumberField(
            key: ValueKey('border-${selected.id}'),
            value: selected.thickness,
            min: .1,
            max: 10,
            label: 'Espessura da borda',
            onChanged: (v) => _element(selected.copyWith(thickness: v)),
          ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            OutlinedButton.icon(
              icon: const Icon(Icons.copy, size: 18),
              label: const Text('Duplicar'),
              onPressed: () {
                if (_label.elements.length >= CustomLabel.maxElements) return;
                final duplicate = selected.copyWith(id: const Uuid().v4());
                _selectedId = duplicate.id;
                _change(
                  _label.copyWith(elements: [..._label.elements, duplicate]),
                );
              },
            ),
            OutlinedButton.icon(
              icon: const Icon(Icons.flip_to_front, size: 18),
              label: const Text('Trazer à frente'),
              onPressed: () => _change(
                _label.copyWith(
                  elements: [
                    ..._label.elements.where((e) => e.id != selected.id),
                    selected,
                  ],
                ),
              ),
            ),
            OutlinedButton.icon(
              icon: const Icon(Icons.delete_outline, size: 18),
              label: const Text('Excluir elemento'),
              onPressed: () => _change(
                _label.copyWith(
                  elements: _label.elements
                      .where((e) => e.id != selected.id)
                      .toList(),
                ),
              ),
            ),
          ],
        ),
      ],
      const SizedBox(height: 20),
      FilledButton.icon(
        onPressed: _save,
        icon: const Icon(Icons.save_outlined),
        label: const Text('Salvar e usar template'),
      ),
      const SizedBox(height: 24),
    ];
  }

  List<Widget> _useControls(bool sending, List<String> errors) {
    final printer = ref.watch(printerConfigProvider);
    return [
      Text('Preencher etiqueta', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 8),
      const Text(
        'Altere os campos e imprima. O modelo salvo mantém os valores de exemplo.',
      ),
      const SizedBox(height: 16),
      for (final element in _label.elements.where(
        (e) => e.editable && e.type.hasContent,
      )) ...[
        DesignerTextField(
          key: ValueKey('use-${element.id}'),
          value: _label.valueOf(element, _values),
          label: element.fieldName,
          onChanged: (v) => setState(() => _values[element.id] = v),
        ),
        const SizedBox(height: 12),
      ],
      TextFormField(
        controller: _copies,
        decoration: const InputDecoration(labelText: 'Cópias (1–1000)'),
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        validator: (v) {
          final n = int.tryParse(v ?? '');
          return n == null || n < 1 || n > 1000
              ? 'Use de 1 a 1000 cópias'
              : null;
        },
      ),
      const SizedBox(height: 12),
      ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.print_outlined),
        title: Text(printer.name),
        subtitle: Text(
          '${printer.dpi} DPI · Papel ${_label.widthMm} × ${_label.heightMm} mm',
        ),
        trailing: const Icon(Icons.settings_outlined),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const PrintersPage()),
        ),
      ),
      const Text(
        'Use na impressora papel com as medidas deste template.',
        style: TextStyle(fontSize: 12),
      ),
      const SizedBox(height: 16),
      FilledButton.icon(
        onPressed: sending || errors.isNotEmpty ? null : _print,
        icon: const Icon(Icons.print),
        label: Text(sending ? 'Enviando…' : 'Imprimir etiqueta'),
      ),
      const SizedBox(height: 24),
    ];
  }
}
