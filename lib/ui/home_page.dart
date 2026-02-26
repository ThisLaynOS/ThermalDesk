import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:zebra_label_pro/core/responsive.dart';
import 'package:zebra_label_pro/models/label_job.dart';
import 'package:zebra_label_pro/providers/history_provider.dart';
import 'package:zebra_label_pro/providers/printer_provider.dart';
import 'package:zebra_label_pro/providers/theme_provider.dart';
import 'package:zebra_label_pro/ui/pages/batch_print_page.dart';
import 'package:zebra_label_pro/ui/pages/dashboard_page.dart';
import 'package:zebra_label_pro/ui/pages/history_page.dart';
import 'package:zebra_label_pro/ui/pages/printers_page.dart';
import 'package:zebra_label_pro/ui/pages/settings_page.dart';
import 'package:zebra_label_pro/ui/pages/template_picker_page.dart';
import 'package:zebra_label_pro/ui/widgets/modern_snackbar.dart';
import 'package:zebra_label_pro/ui/widgets/preview_card.dart';
import 'package:zebra_label_pro/ui/widgets/printer_form_card.dart';
import 'package:zebra_label_pro/services/zebra_service.dart';


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
  LabelTemplate _template = LabelTemplate.product;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _barcodeCtrl.dispose();
    _subtitleCtrl.dispose();
    super.dispose();
  }

  Future<void> _testConnection() async {
    final cfg = ref.read(printerConfigProvider);
    
    // Verificar se a impressora está configurada
    if (cfg.ip.isEmpty) {
      ModernSnackbar.warning(context, 'Configure o IP da impressora primeiro');
      return;
    }
    
    ref.read(connStatusProvider.notifier).state = ConnStatus.testing;
    final result = await ref.read(zebraServiceProvider).testConnection(cfg);
    final ok = result is ZebraSuccess;
    ref.read(connStatusProvider.notifier).state =
        ok ? ConnStatus.connected : ConnStatus.failed;
    if (!mounted) return;
    if (ok) {
      ModernSnackbar.success(context, 'Conectado com sucesso!');
    } else {
      ModernSnackbar.error(context, 'Falha na conexão');
    }
  }

  Future<void> _print() async {
    if (!_formKey.currentState!.validate()) return;
    final cfg = ref.read(printerConfigProvider);
    
    // Verificar se a impressora está configurada
    if (cfg.ip.isEmpty) {
      ModernSnackbar.warning(context, 'Configure o IP da impressora primeiro');
      return;
    }
    
    final service = ref.read(zebraServiceProvider);
    ref.read(sendingProvider.notifier).state = true;

    final zpl = service.buildZpl(
      title: _titleCtrl.text,
      barcode: _barcodeCtrl.text,
      subtitle: _subtitleCtrl.text,
      template: _template,
      cfg: cfg,
    );

    final result = await service.sendZpl(cfg, zpl);
    final ok = result is ZebraSuccess;

    final job = LabelJob(
      id: const Uuid().v4(),
      sentAt: DateTime.now(),
      title: _titleCtrl.text,
      barcode: _barcodeCtrl.text,
      subtitle: _subtitleCtrl.text,
      template: _template,
      success: ok,
      zpl: zpl,
    );

    await ref.read(historyProvider.notifier).add(job);
    ref.read(sendingProvider.notifier).state = false;

    if (!mounted) return;
    if (ok) {
      ModernSnackbar.success(context, 'Etiqueta enviada com sucesso!');
    } else {
      ModernSnackbar.error(context, 'Falha ao enviar etiqueta');
    }
  }

  Future<void> _copyZpl() async {
    final cfg = ref.read(printerConfigProvider);
    final zpl = ref.read(zebraServiceProvider).buildZpl(
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
        title: Image.asset(
          Theme.of(context).brightness == Brightness.dark
              ? 'assets/logow.png'
              : 'assets/logo.png',
          height: isMobile ? 28 : 36,
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
              label: Text('$historyCount', style: TextStyle(fontSize: isMobile ? 10 : 12)),
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
              builder: (_) => TemplatePicker(current: _template)),
        );
        if (picked != null) setState(() => _template = picked);
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
          constraints: BoxConstraints(
            maxWidth: maxWidth ?? double.infinity,
          ),
          child: content,
        ),
      ),
    );
  }

  Widget _buildDrawer(BuildContext context, ColorScheme colorScheme, bool isDark, int historyCount) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(color: colorScheme.primaryContainer),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colorScheme.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: 
                  Image.asset(
                    Theme.of(context).brightness == Brightness.dark
                        ? 'assets/logow.png'
                        : 'assets/logo.png',
                    width: 32,
                    height: 32,
                    color: colorScheme.onPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Zebra Label Pro',
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
                    color: colorScheme.onPrimaryContainer.withValues(alpha: 0.7),
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
            leading: const Icon(Icons.dashboard_outlined),
            title: const Text('Dashboard'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const DashboardPage()));
            },
          ),
          ListTile(
            leading: const Icon(Icons.dynamic_feed),
            title: const Text('Impressão em Lote'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const BatchPrintPage()));
            },
          ),
          ListTile(
            leading: const Icon(Icons.print),
            title: const Text('Impressoras'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const PrintersPage()));
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
              Navigator.push(context, MaterialPageRoute(builder: (_) => const HistoryPage()));
            },
          ),
          ListTile(
            leading: const Icon(Icons.settings_outlined),
            title: const Text('Configurações'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsPage()));
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
              'v2.1.0 • ZPL II \nFeito com ❤️ por LaynOS',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
            ),
          ),
        ],
      ),
    );
  }
}
