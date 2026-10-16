import 'package:thermal_desk/core/label_validation.dart';

import 'dart:async';
import 'dart:io';

import 'package:thermal_desk/services/zpl_exporter.dart';

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:thermal_desk/models/label_job.dart';
import 'package:thermal_desk/models/label_profile.dart';
import 'package:thermal_desk/providers/history_provider.dart';
import 'package:thermal_desk/providers/printer_provider.dart';
import 'package:thermal_desk/providers/preview_provider.dart';
import 'package:thermal_desk/services/labelary_service.dart';
import 'package:thermal_desk/ui/widgets/history_tile.dart';
import 'package:thermal_desk/ui/widgets/zpl_local_preview.dart';

class PreviewCard extends ConsumerStatefulWidget {
  final TextEditingController titleCtrl, barcodeCtrl, subtitleCtrl;
  final TextEditingController previousPriceCtrl,
      newPriceCtrl,
      labelCountCtrl,
      expiryDateCtrl;
  final LabelTemplate template;
  final VoidCallback onCopyZpl;

  const PreviewCard({
    super.key,
    required this.titleCtrl,
    required this.barcodeCtrl,
    required this.subtitleCtrl,
    required this.previousPriceCtrl,
    required this.newPriceCtrl,
    required this.labelCountCtrl,
    required this.expiryDateCtrl,
    required this.template,
    required this.onCopyZpl,
  });

  @override
  ConsumerState<PreviewCard> createState() => _PreviewCardState();
}

class _PreviewCardState extends ConsumerState<PreviewCard> {
  final _transform = TransformationController();
  int _rotation = 0;
  Uint8List? _image;
  String? _error;
  bool _online = false, _loading = false;
  int _revision = 0;
  Timer? _debounce;

  List<TextEditingController> _controllers(PreviewCard card) => [
    card.titleCtrl,
    card.barcodeCtrl,
    card.subtitleCtrl,
    card.previousPriceCtrl,
    card.newPriceCtrl,
    card.labelCountCtrl,
    card.expiryDateCtrl,
  ];

  @override
  void initState() {
    super.initState();
    for (final controller in _controllers(widget)) {
      controller.addListener(_invalidate);
    }
  }

  @override
  void didUpdateWidget(covariant PreviewCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    for (final controller in _controllers(oldWidget)) {
      controller.removeListener(_invalidate);
    }
    for (final controller in _controllers(widget)) {
      controller.addListener(_invalidate);
    }
    if (oldWidget.template != widget.template ||
        !_controllers(oldWidget)
            .every((c) => _controllers(widget).contains(c))) {
      _transform.value = Matrix4.identity();
      _invalidate();
    }
  }

  void _zoom(double factor) {
    final scale = (_transform.value.getMaxScaleOnAxis() * factor).clamp(
      1.0,
      5.0,
    );
    _transform.value = Matrix4.diagonal3Values(scale, scale, 1);
  }

  void _invalidate() {
    _revision++;
    _debounce?.cancel();
    if (!mounted) return;
    setState(() {
      _image = null;
      _error = null;
      _loading = _online;
    });
    if (_online) {
      _debounce = Timer(const Duration(milliseconds: 600), _render);
    }
  }

  String _zpl() => ref
      .read(thermalDeskServiceProvider)
      .buildZpl(
        title: widget.titleCtrl.text,
        barcode: widget.barcodeCtrl.text,
        subtitle: widget.subtitleCtrl.text,
        template: widget.template,
        cfg: ref.read(printerConfigProvider),
        previousPrice: widget.previousPriceCtrl.text,
        newPrice: widget.newPriceCtrl.text,
        expiryDate: widget.expiryDateCtrl.text,
        copies: int.tryParse(widget.labelCountCtrl.text.trim()) ?? 1,
      );

  Future<void> _render() async {
    final revision = _revision;
    final profile = LabelProfile.fromConfig(ref.read(printerConfigProvider));
    final result = await ref
        .read(labelaryServiceProvider)
        .renderZpl(_zpl(), profile: profile);
    if (!mounted || !_online || revision != _revision) return;
    setState(() {
      _loading = false;
      if (result is LabelarySuccess<List<int>>) {
        _image = Uint8List.fromList(result.value);
      }
      if (result is LabelaryFailure<List<int>>) {
        _error = result.message;
      }
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _transform.dispose();
    for (final controller in _controllers(widget)) {
      controller.removeListener(_invalidate);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(printerConfigProvider);
    ref.listen(printerConfigProvider, (previous, next) {
      if (previous?.labelSize != next.labelSize || previous?.dpi != next.dpi) {
        _transform.value = Matrix4.identity();
      }
      _invalidate();
    });
    final profile = LabelProfile.fromConfig(config);
    final barcodeError =
        widget.template == LabelTemplate.address ||
            widget.template == LabelTemplate.cable
        ? null
        : LabelValidation.barcode(
            widget.barcodeCtrl.text,
            qr: widget.template == LabelTemplate.qrCode,
            availableDots: widget.template == LabelTemplate.qrCode
                ? profile.availableQrDots
                : profile.availableBarcodeDots(
                    promotional:
                        widget.template == LabelTemplate.promoShelf ||
                        widget.template == LabelTemplate.promoExpiry,
                  ),
          );
    final history = ref.watch(historyProvider);
    final zpl = _zpl();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  'Pré-visualização da etiqueta',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                Chip(
                  avatar: Icon(widget.template.icon, size: 16),
                  label: Text(widget.template.displayName),
                ),
              ],
            ),
            Text(
              '${config.labelSize} • ${config.dpi} DPI • ${profile.width} × ${profile.height} dots',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (barcodeError != null)
              Text(
                barcodeError,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final aspectRatio = _rotation.isEven
                    ? profile.aspectRatio
                    : 1 / profile.aspectRatio;
                final width = math.min(
                  constraints.maxWidth,
                  math.min(560.0, 360 * aspectRatio),
                );
                return Center(
                  child: SizedBox(
                    width: width,
                    height: width / aspectRatio,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: Colors.grey),
                      ),
                      child: ClipRect(
                        child: InteractiveViewer(
                          transformationController: _transform,
                          minScale: 1,
                          maxScale: 5,
                          child: RotatedBox(
                            quarterTurns: _rotation,
                            child: _image != null
                                ? Image.memory(
                                    _image!,
                                    key: const ValueKey('online-preview'),
                                    fit: BoxFit.fill,
                                    errorBuilder: (_, __, ___) =>
                                        ZplLocalPreview(
                                          zpl: zpl,
                                          profile: profile,
                                        ),
                                  )
                                : ZplLocalPreview(zpl: zpl, profile: profile),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
            Wrap(
              children: [
                IconButton(
                  tooltip: 'Ampliar prévia',
                  onPressed: () => _zoom(1.25),
                  icon: const Icon(Icons.zoom_in),
                ),
                IconButton(
                  tooltip: 'Reduzir prévia',
                  onPressed: () => _zoom(.8),
                  icon: const Icon(Icons.zoom_out),
                ),
                IconButton(
                  tooltip: 'Repor zoom',
                  onPressed: () {
                    _transform.value = Matrix4.identity();
                  },
                  icon: const Icon(Icons.center_focus_strong),
                ),
                IconButton(
                  tooltip: 'Girar apenas a prévia',
                  onPressed: () {
                    _transform.value = Matrix4.identity();
                    setState(() => _rotation = (_rotation + 1) % 4);
                  },
                  icon: const Icon(Icons.rotate_90_degrees_cw),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _image == null
                  ? 'Prévia local aproximada'
                  : 'Renderização do ZPL via Labelary',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('Prévia online (Labelary)'),
              subtitle: const Text(
                'Ao ativar, o conteúdo da etiqueta é enviado ao serviço externo.',
              ),
              value: _online,
              onChanged: (enabled) {
                _online = enabled;
                _invalidate();
              },
            ),
            if (_loading) const LinearProgressIndicator(),
            if (_error != null) ...[
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              TextButton.icon(
                onPressed: _invalidate,
                icon: const Icon(Icons.refresh),
                label: const Text('Tentar novamente'),
              ),
            ],
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: const Text('Ver código ZPL'),
              leading: const Icon(Icons.code),
              children: [
                SizedBox(
                  width: double.infinity,
                  child: SelectableText(
                    zpl,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11,
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: widget.onCopyZpl,
                    icon: const Icon(Icons.copy),
                    label: const Text('Copiar ZPL'),
                  ),
                ),
              ],
            ),
            if (Platform.isLinux || Platform.isMacOS || Platform.isWindows)
              TextButton.icon(
                onPressed: () => ZplExporter.saveToFile(context, zpl),
                icon: const Icon(Icons.save_alt),
                label: const Text('Exportar ZPL'),
              ),
            const Divider(),
            Text(
              'Últimas impressões',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            if (history.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text('Nenhuma impressão recente'),
              ),
            ...history
                .take(3)
                .map((job) => HistoryTile(job: job, compact: true)),
          ],
        ),
      ),
    );
  }
}
