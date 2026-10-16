import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:thermal_desk/models/custom_label.dart';
import 'package:thermal_desk/ui/widgets/zpl_local_preview.dart';

class LabelCanvas extends StatelessWidget {
  final CustomLabel label;
  final int dpi;
  final Map<String, String> values;
  final String? selectedId;
  final bool editing;
  final ValueChanged<String>? onSelect;
  final VoidCallback? onGestureStart;
  final void Function(String, Offset)? onMove;
  final void Function(String, Offset)? onResize;
  const LabelCanvas({
    super.key,
    required this.label,
    required this.dpi,
    this.values = const {},
    this.selectedId,
    this.editing = false,
    this.onSelect,
    this.onGestureStart,
    this.onMove,
    this.onResize,
  });

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final scale = math
          .min(
            (constraints.maxWidth - 24) / label.widthMm,
            (constraints.maxHeight - 24) / label.heightMm,
          )
          .clamp(.01, 30.0);
      return Center(
        child: Container(
          width: label.widthMm * scale,
          height: label.heightMm * scale,
          decoration: const BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 8,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: ZplLocalPreview(
                  zpl: label.buildZpl(dpi, values: values, validate: false),
                  profile: label.profile(dpi),
                ),
              ),
              if (editing)
                ...label.elements.map(
                  (e) => Positioned(
                    left: e.x * scale,
                    top: e.y * scale,
                    width: e.width * scale,
                    height: e.height * scale,
                    child: _ElementHitRegion(
                      borderOnly: e.type == LabelElementType.box,
                      child: GestureDetector(
                        key: ValueKey('canvas-${e.id}'),
                        behavior: HitTestBehavior.opaque,
                        onTap: () => onSelect?.call(e.id),
                        onPanStart: (_) {
                          onSelect?.call(e.id);
                          onGestureStart?.call();
                        },
                        onPanUpdate: (details) =>
                            onMove?.call(e.id, details.delta / scale),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: e.id == selectedId
                                  ? Theme.of(context).colorScheme.primary
                                  : Colors.blueGrey.withValues(alpha: .3),
                              width: e.id == selectedId ? 2 : 1,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              if (editing && label.elements.any((e) => e.id == selectedId))
                ...label.elements
                    .where((e) => e.id == selectedId)
                    .map(
                      (e) => Positioned(
                        left: (e.x + e.width) * scale - 12,
                        top: (e.y + e.height) * scale - 12,
                        width: 24,
                        height: 24,
                        child: GestureDetector(
                          key: const ValueKey('resize-element'),
                          behavior: HitTestBehavior.opaque,
                          onPanStart: (_) => onGestureStart?.call(),
                          onPanUpdate: (details) =>
                              onResize?.call(e.id, details.delta / scale),
                          child: Icon(
                            Icons.open_in_full,
                            size: 18,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ),
                    ),
            ],
          ),
        ),
      );
    },
  );
}

/// A borda seleciona a caixa sem impedir o toque nos elementos dentro dela.
class _ElementHitRegion extends SingleChildRenderObjectWidget {
  final bool borderOnly;
  const _ElementHitRegion({required this.borderOnly, required super.child});
  @override
  RenderObject createRenderObject(BuildContext context) =>
      _ElementHitBox(borderOnly);
  @override
  void updateRenderObject(
    BuildContext context,
    covariant _ElementHitBox renderObject,
  ) {
    renderObject.borderOnly = borderOnly;
  }
}

class _ElementHitBox extends RenderProxyBox {
  bool borderOnly;
  _ElementHitBox(this.borderOnly);
  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    if (borderOnly && (Offset.zero & size).deflate(6).contains(position)) {
      return false;
    }
    return super.hitTest(result, position: position);
  }
}
