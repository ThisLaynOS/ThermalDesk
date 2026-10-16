import 'package:flutter/material.dart';

/// Identidade visual partilhada entre as superfícies da aplicação.
class ThermalDeskLogo extends StatelessWidget {
  static const assetPath = 'assets/branding/thermaldesk-abstract.png';

  final double size;

  const ThermalDeskLogo({super.key, this.size = 48});

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(size * 0.22),
    child: ColoredBox(
      color: const Color(0xFFF3FAF8),
      child: Image.asset(
        assetPath,
        width: size,
        height: size,
        fit: BoxFit.contain,
        semanticLabel: 'Logo ThermalDesk',
      ),
    ),
  );
}
