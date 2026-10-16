import 'package:thermal_desk/ui/widgets/thermaldesk_logo.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:thermal_desk/core/constants.dart';
import 'package:thermal_desk/models/printer_config.dart';
import 'package:thermal_desk/providers/printer_provider.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  final _formKey = GlobalKey<FormState>();
  bool _saving = false;
  late TextEditingController _ipCtrl;
  late TextEditingController _portCtrl;
  late int _dpi;
  late String _labelSize;

  @override
  void initState() {
    super.initState();
    final cfg = ref.read(printerConfigProvider);
    _ipCtrl = TextEditingController(text: cfg.ip);
    _portCtrl = TextEditingController(text: cfg.port.toString());
    _dpi = cfg.dpi;
    _labelSize = AppConstants.labelSizeForDpi(cfg.labelSize, cfg.dpi);
  }

  @override
  void dispose() {
    _ipCtrl.dispose();
    _portCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    final current = ref.read(printerConfigProvider);
    final config = current.copyWith(
      ip: _ipCtrl.text.trim(),
      port: int.parse(_portCtrl.text.trim()),
      dpi: _dpi,
      labelSize: _labelSize,
    );
    final selected = ref.read(printerConfigProvider.notifier);
    final saved = ref.read(savedPrintersProvider.notifier);
    setState(() => _saving = true);
    try {
      await selected.save(config);
      await saved.update(config);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Configurações salvas')));
      Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Não foi possível guardar as configurações.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configurações'),
        actions: [
          FilledButton.icon(
            icon: const Icon(Icons.save, size: 18),
            label: const Text('Salvar'),
            onPressed: _saving ? null : _save,
            style: FilledButton.styleFrom(
              visualDensity: VisualDensity.compact,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _GroupCard(
              title: 'Conexão',
              icon: Icons.wifi,
              children: [
                TextFormField(
                  controller: _ipCtrl,
                  validator: PrinterConfig.validateIp,
                  decoration: const InputDecoration(
                    labelText: 'Endereço IP da impressora',
                    prefixIcon: Icon(Icons.router_outlined),
                    hintText: 'Introduza o IP da impressora',
                  ),
                  keyboardType: TextInputType.url,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _portCtrl,
                  validator: PrinterConfig.validatePort,
                  decoration: const InputDecoration(
                    labelText: 'Porta TCP (padrão: 9100)',
                    prefixIcon: Icon(Icons.settings_ethernet),
                  ),
                  keyboardType: TextInputType.number,
                ),
              ],
            ),
            const SizedBox(height: 16),
            _GroupCard(
              title: 'Impressão',
              icon: Icons.print_outlined,
              children: [
                const Text(
                  'Resolução (DPI)',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  children: [203, 200, 300].map((d) {
                    return ChoiceChip(
                      label: Text(d == 203 ? '203 DPI (S4M)' : '$d DPI'),
                      selected: _dpi == d,
                      onSelected: (_) => setState(() {
                        _dpi = d;
                        _labelSize = AppConstants.labelSizeForDpi(
                          _labelSize,
                          d,
                        );
                      }),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Tamanho da etiqueta',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 10),
                RadioGroup<String>(
                  groupValue: _labelSize,
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _labelSize = value;
                        _dpi = AppConstants.labelSizes[value]!.dpi;
                      });
                    }
                  },
                  child: Column(
                    children: AppConstants.labelSizes.keys
                        .map(
                          (key) => RadioListTile<String>(
                            dense: true,
                            title: Text(key),
                            value: key,
                          ),
                        )
                        .toList(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const _GroupCard(
              title: 'Sobre',
              icon: Icons.info_outline,
              children: [
                ListTile(
                  dense: true,
                  leading: ThermalDeskLogo(size: 40),
                  title: Text('ThermalDesk'),
                  subtitle: Text('Versão 2.1.0'),
                ),
                ListTile(
                  dense: true,
                  leading: Icon(Icons.code),
                  title: Text('Protocolo'),
                  subtitle: Text('ZPL II via TCP/IP raw socket'),
                ),
                ListTile(
                  dense: true,
                  leading: Icon(Icons.new_releases_outlined),
                  title: Text('Novidades'),
                  subtitle: Text('Dashboard, Lote, Multi-impressoras, QR Code'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _GroupCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;

  const _GroupCard({
    required this.title,
    required this.icon,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  size: 18,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 14),
            ...children,
          ],
        ),
      ),
    );
  }
}
