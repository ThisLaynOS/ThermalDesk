import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:thermal_desk/models/label_job.dart';
import 'package:thermal_desk/providers/history_provider.dart';
import 'package:thermal_desk/ui/widgets/modern_snackbar.dart';

class HistoryTile extends ConsumerWidget {
  final LabelJob job;

  /// [compact] = true → versão enxuta para usar no PreviewCard
  /// [compact] = false → versão completa para usar na HistoryPage
  final bool compact;

  const HistoryTile({super.key, required this.job, this.compact = false});

  static final _fmt = DateFormat('dd/MM/yyyy HH:mm');
  static final _fmtCompact = DateFormat('dd/MM HH:mm');

  Future<void> _copyZpl(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: job.zpl));
    if (!context.mounted) return;
    ModernSnackbar.info(context, 'ZPL copiado para a área de transferência');
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    if (compact) {
      // No modo compacto, deleta direto sem confirmação
      ref.read(historyProvider.notifier).remove(job.id);
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Remover impressão'),
        content: Text('Remover "${job.title}" do histórico?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remover'),
          ),
        ],
      ),
    );

    if (confirm == true && context.mounted) {
      ref.read(historyProvider.notifier).remove(job.id);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final successColor = job.success ? Colors.green : Colors.red;

    if (compact) {
      return ListTile(
        dense: true,
        contentPadding: EdgeInsets.zero,
        leading: Icon(
          job.success ? Icons.check_circle_outline : Icons.error_outline,
          color: successColor,
          size: 20,
        ),
        title: Text(
          job.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Text(
          '${job.template.displayName} · ${_fmtCompact.format(job.sentAt)}',
          style: const TextStyle(fontSize: 11),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.code, size: 16),
              tooltip: 'Copiar ZPL',
              onPressed: () => _copyZpl(context),
            ),
            IconButton(
              icon: const Icon(Icons.close, size: 16),
              tooltip: 'Remover',
              onPressed: () => _confirmDelete(context, ref),
            ),
          ],
        ),
      );
    }

    // Versão completa (HistoryPage)
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: job.success
              ? Colors.green.shade100
              : Colors.red.shade100,
          child: Icon(
            job.success ? Icons.check : Icons.close,
            color: successColor,
            size: 18,
          ),
        ),
        title: Text(
          job.title,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (job.detail.isNotEmpty)
              Text('${job.template.detailLabel ?? 'Detalhe'}: ${job.detail}'),
            if (job.subtitle.isNotEmpty)
              Text(job.subtitle, style: const TextStyle(fontSize: 12)),
            const SizedBox(height: 2),
            Row(
              children: [
                _Tag(
                  label: job.template.displayName,
                  color: colorScheme.primaryContainer,
                ),
                const SizedBox(width: 6),
                _Tag(
                  label: job.success ? 'Sucesso' : 'Falha',
                  color: job.success
                      ? Colors.green.shade100
                      : Colors.red.shade100,
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              _fmt.format(job.sentAt),
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
            if (job.barcode.isNotEmpty)
              Text(
                'Cód: ${job.barcode}',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (v) async {
            if (v == 'copy_zpl') {
              await _copyZpl(context);
            } else if (v == 'delete') {
              await _confirmDelete(context, ref);
            }
          },
          itemBuilder: (_) => [
            const PopupMenuItem(
              value: 'copy_zpl',
              child: ListTile(
                dense: true,
                leading: Icon(Icons.code),
                title: Text('Copiar ZPL'),
              ),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: ListTile(
                dense: true,
                leading: Icon(Icons.delete_outline, color: Colors.red),
                title: Text('Remover', style: TextStyle(color: Colors.red)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final String label;
  final Color color;
  const _Tag({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
      ),
    );
  }
}
