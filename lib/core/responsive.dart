import 'package:flutter/material.dart';

/// Sistema de breakpoints responsivos
/// Mobile: < 600px
/// Tablet: 600px - 900px
/// Desktop: > 900px
/// Wide Desktop: > 1200px

enum ScreenSize { mobile, tablet, desktop, wideDesktop }

class Responsive {
  static const double mobileBreakpoint = 600;
  static const double tabletBreakpoint = 900;
  static const double desktopBreakpoint = 1200;

  static ScreenSize getScreenSize(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width < mobileBreakpoint) return ScreenSize.mobile;
    if (width < tabletBreakpoint) return ScreenSize.tablet;
    if (width < desktopBreakpoint) return ScreenSize.desktop;
    return ScreenSize.wideDesktop;
  }

  static bool isMobile(BuildContext context) =>
      MediaQuery.sizeOf(context).width < mobileBreakpoint;

  static bool isTablet(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return width >= mobileBreakpoint && width < tabletBreakpoint;
  }

  static bool isDesktop(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= tabletBreakpoint;

  static bool isWideDesktop(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= desktopBreakpoint;

  /// Retorna valor baseado no tamanho da tela
  static T value<T>({
    required BuildContext context,
    required T mobile,
    T? tablet,
    T? desktop,
    T? wideDesktop,
  }) {
    final size = getScreenSize(context);
    return switch (size) {
      ScreenSize.mobile => mobile,
      ScreenSize.tablet => tablet ?? mobile,
      ScreenSize.desktop => desktop ?? tablet ?? mobile,
      ScreenSize.wideDesktop => wideDesktop ?? desktop ?? tablet ?? mobile,
    };
  }

  /// Padding responsivo
  static EdgeInsets padding(BuildContext context) {
    return value(
      context: context,
      mobile: const EdgeInsets.all(12),
      tablet: const EdgeInsets.all(16),
      desktop: const EdgeInsets.all(20),
      wideDesktop: const EdgeInsets.all(24),
    );
  }

  /// Espaçamento entre cards
  static double cardSpacing(BuildContext context) {
    return value(context: context, mobile: 12.0, tablet: 16.0, desktop: 20.0);
  }

  /// Número de colunas para grid
  static int gridColumns(BuildContext context) {
    return value(
      context: context,
      mobile: 1,
      tablet: 2,
      desktop: 3,
      wideDesktop: 4,
    );
  }

  /// Largura máxima do conteúdo (para centralizar em telas grandes)
  static double? maxContentWidth(BuildContext context) {
    return value<double?>(
      context: context,
      mobile: null,
      tablet: null,
      desktop: 1200,
      wideDesktop: 1400,
    );
  }

  /// Tamanho de fonte responsivo
  static double fontSize(BuildContext context, {required double base}) {
    return value(
      context: context,
      mobile: base * 0.9,
      tablet: base,
      desktop: base,
      wideDesktop: base * 1.05,
    );
  }

  /// Tamanho de ícone responsivo
  static double iconSize(BuildContext context, {double base = 24}) {
    return value(
      context: context,
      mobile: base * 0.9,
      tablet: base,
      desktop: base,
    );
  }
}

/// Widget que constrói layouts diferentes baseado na tela
class ResponsiveBuilder extends StatelessWidget {
  final Widget mobile;
  final Widget? tablet;
  final Widget? desktop;
  final Widget? wideDesktop;

  const ResponsiveBuilder({
    super.key,
    required this.mobile,
    this.tablet,
    this.desktop,
    this.wideDesktop,
  });

  @override
  Widget build(BuildContext context) {
    return Responsive.value(
      context: context,
      mobile: mobile,
      tablet: tablet,
      desktop: desktop,
      wideDesktop: wideDesktop,
    );
  }
}

/// Widget que centraliza conteúdo com largura máxima
class ResponsiveContainer extends StatelessWidget {
  final Widget child;
  final double? maxWidth;
  final EdgeInsetsGeometry? padding;

  const ResponsiveContainer({
    super.key,
    required this.child,
    this.maxWidth,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveMaxWidth = maxWidth ?? Responsive.maxContentWidth(context);
    final effectivePadding = padding ?? Responsive.padding(context);

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: effectiveMaxWidth ?? double.infinity,
        ),
        child: Padding(padding: effectivePadding, child: child),
      ),
    );
  }
}

/// Widget para layouts em Row ou Column baseado na tela
class ResponsiveRowColumn extends StatelessWidget {
  final List<Widget> children;
  final MainAxisAlignment mainAxisAlignment;
  final CrossAxisAlignment crossAxisAlignment;
  final double spacing;
  final bool forceColumn;

  const ResponsiveRowColumn({
    super.key,
    required this.children,
    this.mainAxisAlignment = MainAxisAlignment.start,
    this.crossAxisAlignment = CrossAxisAlignment.start,
    this.spacing = 16,
    this.forceColumn = false,
  });

  @override
  Widget build(BuildContext context) {
    final isWide = Responsive.isDesktop(context) && !forceColumn;

    if (isWide) {
      return Row(
        mainAxisAlignment: mainAxisAlignment,
        crossAxisAlignment: crossAxisAlignment,
        children: _addSpacing(children, spacing, horizontal: true),
      );
    }

    return Column(
      mainAxisAlignment: mainAxisAlignment,
      crossAxisAlignment: crossAxisAlignment,
      children: _addSpacing(children, spacing, horizontal: false),
    );
  }

  List<Widget> _addSpacing(
    List<Widget> widgets,
    double spacing, {
    required bool horizontal,
  }) {
    if (widgets.isEmpty) return widgets;

    final result = <Widget>[];
    for (var i = 0; i < widgets.length; i++) {
      if (horizontal) {
        result.add(Expanded(child: widgets[i]));
      } else {
        result.add(widgets[i]);
      }
      if (i < widgets.length - 1) {
        result.add(
          SizedBox(
            width: horizontal ? spacing : null,
            height: horizontal ? null : spacing,
          ),
        );
      }
    }
    return result;
  }
}

/// Grid responsivo
class ResponsiveGrid extends StatelessWidget {
  final List<Widget> children;
  final double spacing;
  final double runSpacing;
  final int? columns;

  const ResponsiveGrid({
    super.key,
    required this.children,
    this.spacing = 16,
    this.runSpacing = 16,
    this.columns,
  });

  @override
  Widget build(BuildContext context) {
    final cols = columns ?? Responsive.gridColumns(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final itemWidth =
            (constraints.maxWidth - (spacing * (cols - 1))) / cols;

        return Wrap(
          spacing: spacing,
          runSpacing: runSpacing,
          children: children.map((child) {
            return SizedBox(
              width: itemWidth.clamp(200, constraints.maxWidth),
              child: child,
            );
          }).toList(),
        );
      },
    );
  }
}
