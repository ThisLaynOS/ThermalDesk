import 'package:flutter/material.dart';

/// Controladores sobrevivem ao repaint do canvas e sincronizam desfazer/refazer.
class DesignerTextField extends StatefulWidget {
  final String value, label;
  final ValueChanged<String> onChanged;
  final int maxLength;
  const DesignerTextField({
    super.key,
    required this.value,
    required this.label,
    required this.onChanged,
    this.maxLength = 1024,
  });
  @override
  State<DesignerTextField> createState() => _DesignerTextFieldState();
}

class _DesignerTextFieldState extends State<DesignerTextField> {
  late final controller = TextEditingController(text: widget.value);
  @override
  void didUpdateWidget(covariant DesignerTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (controller.text != widget.value) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && controller.text != widget.value) {
          controller.text = widget.value;
        }
      });
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextFormField(
    controller: controller,
    decoration: InputDecoration(labelText: widget.label, counterText: ''),
    maxLength: widget.maxLength,
    onChanged: widget.onChanged,
  );
}

class DesignerNumberField extends StatefulWidget {
  final double value, min, max;
  final String label;
  final ValueChanged<double> onChanged;
  const DesignerNumberField({
    super.key,
    required this.value,
    required this.label,
    required this.onChanged,
    this.min = .2,
    this.max = 300,
  });
  @override
  State<DesignerNumberField> createState() => _DesignerNumberFieldState();
}

class _DesignerNumberFieldState extends State<DesignerNumberField> {
  late final controller = TextEditingController(text: _format(widget.value));
  String _format(double value) =>
      value.toStringAsFixed(1).replaceFirst(RegExp(r'\.0$'), '');
  double? get number => double.tryParse(controller.text.replaceAll(',', '.'));
  bool get valid =>
      number != null &&
      number!.isFinite &&
      number! >= widget.min &&
      number! <= widget.max;
  @override
  void didUpdateWidget(covariant DesignerNumberField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value && number != widget.value) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && number != widget.value) {
          controller.text = _format(widget.value);
        }
      });
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextFormField(
    controller: controller,
    decoration: InputDecoration(labelText: widget.label, suffixText: 'mm'),
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    autovalidateMode: AutovalidateMode.onUserInteraction,
    validator: (_) => valid ? null : '${widget.min} a ${widget.max}',
    onChanged: (_) {
      if (valid) widget.onChanged(number!);
    },
  );
}
