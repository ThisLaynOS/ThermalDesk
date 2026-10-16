import 'package:flutter/material.dart';

enum SnackType { success, error, warning, info }

/// Helper para exibir snackbars modernas e bonitas
class ModernSnackbar {
  static void show(
    BuildContext context, {
    required String message,
    SnackType type = SnackType.info,
    Duration duration = const Duration(seconds: 3),
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    final config = _getConfig(type);

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: _SnackbarContent(
          message: message,
          icon: config.icon,
          iconColor: config.iconColor,
          gradientColors: config.gradientColors,
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        padding: EdgeInsets.zero,
        duration: duration,
        dismissDirection: DismissDirection.horizontal,
        action: actionLabel != null
            ? SnackBarAction(
                label: actionLabel,
                textColor: Colors.white,
                onPressed: onAction ?? () {},
              )
            : null,
      ),
    );
  }

  static void success(BuildContext context, String message) =>
      show(context, message: message, type: SnackType.success);

  static void error(BuildContext context, String message) =>
      show(context, message: message, type: SnackType.error);

  static void warning(BuildContext context, String message) =>
      show(context, message: message, type: SnackType.warning);

  static void info(BuildContext context, String message) =>
      show(context, message: message, type: SnackType.info);

  static _SnackConfig _getConfig(SnackType type) {
    return switch (type) {
      SnackType.success => const _SnackConfig(
        icon: Icons.check_circle_rounded,
        iconColor: Colors.white,
        gradientColors: [Color(0xFF00C853), Color(0xFF69F0AE)],
      ),
      SnackType.error => const _SnackConfig(
        icon: Icons.error_rounded,
        iconColor: Colors.white,
        gradientColors: [Color(0xFFD32F2F), Color(0xFFFF5252)],
      ),
      SnackType.warning => const _SnackConfig(
        icon: Icons.warning_rounded,
        iconColor: Colors.white,
        gradientColors: [Color(0xFFFF6D00), Color(0xFFFFAB40)],
      ),
      SnackType.info => const _SnackConfig(
        icon: Icons.info_rounded,
        iconColor: Colors.white,
        gradientColors: [Color(0xFF2196F3), Color(0xFF64B5F6)],
      ),
    };
  }
}

class _SnackConfig {
  final IconData icon;
  final Color iconColor;
  final List<Color> gradientColors;

  const _SnackConfig({
    required this.icon,
    required this.iconColor,
    required this.gradientColors,
  });
}

class _SnackbarContent extends StatelessWidget {
  final String message;
  final IconData icon;
  final Color iconColor;
  final List<Color> gradientColors;

  const _SnackbarContent({
    required this.message,
    required this.icon,
    required this.iconColor,
    required this.gradientColors,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: gradientColors.first.withValues(alpha: 0.4),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Ícone com fundo
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 14),
          // Mensagem
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.2,
              ),
            ),
          ),
          // Botão de fechar
          GestureDetector(
            onTap: () => ScaffoldMessenger.of(context).hideCurrentSnackBar(),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.close_rounded,
                color: Colors.white.withValues(alpha: 0.8),
                size: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
