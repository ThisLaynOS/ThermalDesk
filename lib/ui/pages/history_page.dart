import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:zebra_label_pro/models/label_job.dart';
import 'package:zebra_label_pro/providers/history_provider.dart';

class HistoryPage extends ConsumerWidget {
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(historyProvider);
    final fmt = DateFormat('dd/MM/yyyy HH:mm');

    return Scaffold(
      appBar: AppBar(
        title: Text('Histórico (${history.length})'),
        actions: [
          if (history.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep_outlined),
              tooltip: 'Limpar histórico',
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('Limpar histórico'),
                    content: const Text(
                        'Deseja remover todas as impressões do histórico?'),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancelar')),
                      FilledButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Limpar')),
                    ],
                  ),
                );
                if (confirm == true) {
                  ref.read(historyProvider.notifier).clear();
                }
              },
            ),
        ],
      ),
      body: history.isEmpty
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.history, size: 64, color: Colors.grey),
                  SizedBox(height: 12),
                  Text('Nenhuma impressão registrada',
                      style: TextStyle(color: Colors.grey)),
                ],
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: history.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final job = history[i];
                return Card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    leading: CircleAvatar(
                      backgroundColor: job.success
                          ? Colors.green.shade100
                          : Colors.red.shade100,
                      child: Icon(
                        job.success ? Icons.check : Icons.close,
                        color: job.success ? Colors.green : Colors.red,
                        size: 18,
                      ),
                    ),
                    title: Text(job.title,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (job.subtitle.isNotEmpty) Text(job.subtitle),
                        Text(
                          '${job.template.displayName} · ${fmt.format(job.sentAt)}',
                          style: const TextStyle(fontSize: 11),
                        ),
                        if (job.barcode.isNotEmpty)
                          Text('Código: ${job.barcode}',
                              style: const TextStyle(fontSize: 11)),
                      ],
                    ),
                    trailing: PopupMenuButton<String>(
                      onSelected: (v) async {
                        if (v == 'copy_zpl') {
                          await Clipboard.setData(
                              ClipboardData(text: job.zpl));
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('ZPL copiado')));
                        } else if (v == 'delete') {
                          ref
                              .read(historyProvider.notifier)
                              .remove(job.id);
                        }
                      },
                      itemBuilder: (_) => [
                        const PopupMenuItem(
                            value: 'copy_zpl',
                            child: ListTile(
                                dense: true,
                                leading: Icon(Icons.code),
                                title: Text('Copiar ZPL'))),
                        const PopupMenuItem(
                            value: 'delete',
                            child: ListTile(
                                dense: true,
                                leading: Icon(Icons.delete_outline,
                                    color: Colors.red),
                                title: Text('Remover',
                                    style:
                                        TextStyle(color: Colors.red)))),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
