import 'package:thermal_desk/ui/widgets/thermaldesk_logo.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:thermal_desk/core/responsive.dart';
import 'package:thermal_desk/models/label_job.dart';
import 'package:thermal_desk/providers/history_provider.dart';
import 'package:thermal_desk/providers/printer_provider.dart';
import 'package:thermal_desk/providers/theme_provider.dart';
import 'package:thermal_desk/ui/pages/batch_print_page.dart';
import 'package:thermal_desk/ui/pages/dashboard_page.dart';
import 'package:thermal_desk/ui/pages/history_page.dart';
import 'package:thermal_desk/ui/pages/printers_page.dart';
import 'package:thermal_desk/ui/pages/settings_page.dart';
import 'package:thermal_desk/ui/pages/template_picker_page.dart';
import 'package:thermal_desk/ui/widgets/modern_snackbar.dart';
import 'package:thermal_desk/ui/widgets/preview_card.dart';
import 'package:thermal_desk/ui/widgets/printer_form_card.dart';
import 'package:thermal_desk/services/thermaldesk_service.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _barcodeCtrl = TextEditingController();
  final _subtitleCtrl = TextEditingController();
  LabelTemplate _template = LabelTemplate.basic;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _barcodeCtrl.dispose();
    _subtitleCtrl.dispose();
    super.dispose();
  }

  Future<void> _testConnection() async {
    final cfg = ref.read(printerConfigProvider);
    if (cfg.connectionError case final String message) {
      ModernSnackbar.warning(context, message);
      return;
    }
    final status = ref.read(connStatusProvider.notifier);
    if (status.state == ConnStatus.testing) return;
    status.state = ConnStatus.testing;
    final result = await ref
        .read(thermalDeskServiceProvider)
        .testConnection(cfg);
    if (!mounted) {
      status.state = ConnStatus.idle;
      return;
    }
    if (ref.read(printerConfigProvider) != cfg) return;
    final ok = result is ThermalDeskSuccess;
    status.state = ok ? ConnStatus.connected : ConnStatus.failed;
    if (ok) {
      ModernSnackbar.success(context, 'Conectado com sucesso!');
    } else {
      ModernSnackbar.error(context, (result as ThermalDeskFailure).message);
    }
  }

  Future<void> _print() async {
    if (ref.read(sendingProvider) || !_formKey.currentState!.validate()) return;
    final cfg = ref.read(printerConfigProvider);
    if (cfg.connectionError case final String message) {
      ModernSnackbar.warning(context, message);
      return;
    }
    final service = ref.read(thermalDeskServiceProvider);
    final sending = ref.read(sendingProvider.notifier);
    final history = ref.read(historyProvider.notifier);
    final title = _titleCtrl.text,
        barcode = _barcodeCtrl.text,
        subtitle = _subtitleCtrl.text;
    final template = _template;
    sending.state = true;
    try {
      final zpl = service.buildZpl(
        title: title,
        barcode: barcode,
        subtitle: subtitle,
        template: template,
        cfg: cfg,
      );
      final result = await service.sendZpl(cfg, zpl);
      final ok = result is ThermalDeskSuccess;
      var saved = true;
      try {
        await history.add(
          LabelJob(
            id: const Uuid().v4(),
            sentAt: DateTime.now(),
            title: title,
            barcode: barcode,
            subtitle: subtitle,
            template: template,
            success: ok,
            zpl: zpl,
          ),
        );
      } catch (_) {
        saved = false;
      }
      if (!mounted) return;
      if (ok) {
        if (saved) {
          ModernSnackbar.success(context, 'Etiqueta enviada com sucesso!');
        } else {
          ModernSnackbar.warning(
            context,
            'Etiqueta enviada; não foi possível guardar o histórico.',
          );
        }
      } else {
        ModernSnackbar.error(context, (result as ThermalDeskFailure).message);
      }
    } finally {
      sending.state = false;
    }
  }

  Future<void> _copyZpl() async {
    final cfg = ref.read(printerConfigProvider);
    final zpl = ref
        .read(thermalDeskServiceProvider)
        .buildZpl(
          title: _titleCtrl.text,
          barcode: _barcodeCtrl.text,
          subtitle: _subtitleCtrl.text,
          template: _template,
          cfg: cfg,
        );
    await Clipboard.setData(ClipboardData(text: zpl));
    if (!mounted) return;
    ModernSnackbar.info(context, 'ZPL copiado para a área de transferência');
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ref.watch(themeModeProvider);
    final historyCount = ref.watch(historyProvider).length;
    final currentPrinter = ref.watch(printerConfigProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final isMobile = Responsive.isMobile(context);
    final isDesktop = Responsive.isDesktop(context);

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            ThermalDeskLogo(size: 36),
            SizedBox(width: 8),
            Flexible(
              child: Text('ThermalDesk', overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
        actions: [
          // Impressora atual - compacto em mobile
          if (!isMobile)
            ActionChip(
              avatar: Icon(
                Icons.print,
                size: 18,
                color: currentPrinter.ip.isEmpty ? Colors.orange : Colors.green,
              ),
              label: Text(
                currentPrinter.name,
                style: const TextStyle(fontSize: 12),
              ),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PrintersPage()),
              ),
            ),
          if (!isMobile) const SizedBox(width: 8),
          // Mostrar todos os ícones em desktop, apenas essenciais em mobile
          if (!isMobile)
            IconButton(
              tooltip: 'Dashboard',
              icon: const Icon(Icons.dashboard_outlined),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const DashboardPage()),
              ),
            ),
          if (!isMobile)
            IconButton(
              tooltip: 'Impressão em Lote',
              icon: const Icon(Icons.dynamic_feed),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const BatchPrintPage()),
              ),
            ),
          IconButton(
            tooltip: 'Histórico ($historyCount)',
            icon: Badge(
              isLabelVisible: historyCount > 0,
              label: Text(
                '$historyCount',
                style: TextStyle(fontSize: isMobile ? 10 : 12),
              ),
              child: const Icon(Icons.history),
            ),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const HistoryPage()),
            ),
          ),
          if (!isMobile)
            IconButton(
              tooltip: 'Configurações',
              icon: const Icon(Icons.settings_outlined),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsPage()),
              ),
            ),
          IconButton(
            tooltip: isDark ? 'Modo claro' : 'Modo escuro',
            icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode),
            onPressed: () => ref.read(themeModeProvider.notifier).toggle(),
          ),
        ],
      ),
      drawer: _buildDrawer(context, colorScheme, isDark, historyCount),
      body: _buildBody(context, isDesktop),
    );
  }

  Widget _buildBody(BuildContext context, bool isDesktop) {
    final padding = Responsive.padding(context);
    final spacing = Responsive.cardSpacing(context);
    final maxWidth = Responsive.maxContentWidth(context);

    final formCard = PrinterFormCard(
      formKey: _formKey,
      titleCtrl: _titleCtrl,
      barcodeCtrl: _barcodeCtrl,
      subtitleCtrl: _subtitleCtrl,
      selectedTemplate: _template,
      onTemplateChange: (t) => setState(() => _template = t),
      onTest: _testConnection,
      onPrint: _print,
      onPickTemplate: () async {
        final picked = await Navigator.push<LabelTemplate>(
          context,
          MaterialPageRoute(
            builder: (_) =>
                TemplatePicker(current: _template, showCustom: true),
          ),
        );
        if (mounted && picked != null) setState(() => _template = picked);
      },
    );

    final previewCard = PreviewCard(
      titleCtrl: _titleCtrl,
      barcodeCtrl: _barcodeCtrl,
      subtitleCtrl: _subtitleCtrl,
      template: _template,
      onCopyZpl: _copyZpl,
    );

    Widget content;
    if (isDesktop) {
      content = Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 5, child: formCard),
          SizedBox(width: spacing),
          Expanded(flex: 4, child: previewCard),
        ],
      );
    } else {
      content = Column(
        children: [
          formCard,
          SizedBox(height: spacing),
          previewCard,
        ],
      );
    }

    return SingleChildScrollView(
      padding: padding,
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth ?? double.infinity),
          child: content,
        ),
      ),
    );
  }

  Widget _buildDrawer(
    BuildContext context,
    ColorScheme colorScheme,
    bool isDark,
    int historyCount,
  ) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(color: colorScheme.primaryContainer),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const ThermalDeskLogo(size: 56),
                const SizedBox(height: 12),
                Text(
                  'ThermalDesk',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onPrimaryContainer,
                  ),
                ),
                Text(
                  'Impressão de etiquetas ZPL',
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onPrimaryContainer.withValues(
                      alpha: 0.7,
                    ),
                  ),
                ),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.home),
            title: const Text('Início'),
            selected: true,
            onTap: () => Navigator.pop(context),
          ),
          ListTile(
            leading: const Icon(Icons.design_services_outlined),
            title: const Text('Templates e designer'),
            onTap: () async {
              Navigator.pop(context);
              final picked = await Navigator.push<LabelTemplate>(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      TemplatePicker(current: _template, showCustom: true),
                ),
              );
              if (mounted && picked != null) setState(() => _template = picked);
            },
          ),
          ListTile(
            leading: const Icon(Icons.dashboard_outlined),
            title: const Text('Dashboard'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const DashboardPage()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.dynamic_feed),
            title: const Text('Impressão em Lote'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const BatchPrintPage()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.print),
            title: const Text('Impressoras'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PrintersPage()),
              );
            },
          ),
          const Divider(),
          ListTile(
            leading: Badge(
              isLabelVisible: historyCount > 0,
              label: Text('$historyCount'),
              child: const Icon(Icons.history),
            ),
            title: const Text('Histórico'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const HistoryPage()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.settings_outlined),
            title: const Text('Configurações'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsPage()),
              );
            },
          ),
          const Divider(),
          ListTile(
            leading: Icon(isDark ? Icons.light_mode : Icons.dark_mode),
            title: Text(isDark ? 'Modo Claro' : 'Modo Escuro'),
            onTap: () {
              ref.read(themeModeProvider.notifier).toggle();
              Navigator.pop(context);
            },
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'ThermalDesk v2.1.0 • ZPL II | Feito com ❤️ por LaynOS',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
            ),
          ),
        ],
      ),
    );
  }
}
