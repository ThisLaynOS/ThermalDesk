import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zebra_label_pro/core/constants.dart';
import 'package:zebra_label_pro/models/printer_config.dart';
import 'package:zebra_label_pro/providers/printer_provider.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
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
    _labelSize = cfg.labelSize;
  }

  @override
  void dispose() {
    _ipCtrl.dispose();
    _portCtrl.dispose();
    super.dispose();
  }

  void _save() {
    final p = int.tryParse(_portCtrl.text) ?? 9100;
    final current = ref.read(printerConfigProvider);
    ref.read(printerConfigProvider.notifier).save(PrinterConfig(
          id: current.id,
          name: current.name,
          ip: _ipCtrl.text.trim(),
          port: p,
          dpi: _dpi,
          labelSize: _labelSize,
          isDefault: current.isDefault,
        ));
    // Atualizar também na lista de impressoras salvas
    ref.read(savedPrintersProvider.notifier).update(PrinterConfig(
          id: current.id,
          name: current.name,
          ip: _ipCtrl.text.trim(),
          port: p,
          dpi: _dpi,
          labelSize: _labelSize,
          isDefault: current.isDefault,
        ));
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('✅ Configurações salvas'),
      backgroundColor: Colors.green,
      behavior: SnackBarBehavior.floating,
    ));
    Navigator.of(context).pop();
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
            onPressed: _save,
            style: FilledButton.styleFrom(
                visualDensity: VisualDensity.compact,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _GroupCard(
            title: 'Conexão',
            icon: Icons.wifi,
            children: [
              TextFormField(
                controller: _ipCtrl,
                decoration: const InputDecoration(
                  labelText: 'Endereço IP da impressora',
                  prefixIcon: Icon(Icons.router_outlined),
                  hintText: '192.168.1.100',
                ),
                keyboardType: TextInputType.url,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _portCtrl,
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
              const Text('Resolução (DPI)', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                children: [203, 200, 300].map((d) {
                  return ChoiceChip(
                    label: Text(d == 203 ? '203 DPI (S4M)' : '$d DPI'),
                    selected: _dpi == d,
                    onSelected: (_) => setState(() => _dpi = d),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              const Text('Tamanho da etiqueta', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 10),
              ...AppConstants.labelSizes.keys.map((key) => RadioListTile<String>(
                    dense: true,
                    title: Text(key),
                    value: key,
                    groupValue: _labelSize,
                    onChanged: (v) => setState(() => _labelSize = v!),
                  )),
            ],
          ),
          const SizedBox(height: 16),
          const _GroupCard(
            title: 'Sobre',
            icon: Icons.info_outline,
            children: [
              ListTile(
                dense: true,
                leading: Icon(Icons.verified_outlined),
                title: Text('Zebra Label Pro'),
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
    );
  }
}

class _GroupCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;

  const _GroupCard(
      {required this.title, required this.icon, required this.children});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 8),
              Text(title,
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.bold)),
            ]),
            const SizedBox(height: 14),
            ...children,
          ],
        ),
      ),
    );
  }
}
