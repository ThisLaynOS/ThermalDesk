import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:thermal_desk/core/responsive.dart';
import 'package:thermal_desk/models/label_job.dart';
import 'package:thermal_desk/providers/history_provider.dart';

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(historyProvider);
    final stats = _calculateStats(history);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(historyProvider),
            tooltip: 'Atualizar',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: Responsive.padding(context),
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: Responsive.maxContentWidth(context) ?? double.infinity,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header stats
                _buildHeaderStats(context, stats, colorScheme),
                SizedBox(height: Responsive.cardSpacing(context) + 4),

                // Charts section - responsive
                _buildChartsSection(context, stats),
                SizedBox(height: Responsive.cardSpacing(context) + 4),

                // Recent activity
                _buildCard(
                  context,
                  title: 'Atividade Recente',
                  icon: Icons.history,
                  child: _buildRecentActivity(
                    context,
                    history.take(5).toList(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderStats(
    BuildContext context,
    _Stats stats,
    ColorScheme colorScheme,
  ) {
    final columns = Responsive.value(
      context: context,
      mobile: 2,
      tablet: 2,
      desktop: 4,
    );
    final spacing = Responsive.cardSpacing(context);

    return GridView.count(
      shrinkWrap: true,
      crossAxisCount: columns,
      mainAxisSpacing: spacing,
      crossAxisSpacing: spacing,
      mainAxisExtent: 150,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        _StatCard(
          icon: Icons.print,
          label: 'Tentativas de envio',
          value: '${stats.total}',
          color: colorScheme.primary,
          trend: stats.totalToday > 0 ? '+${stats.totalToday} hoje' : null,
        ),
        _StatCard(
          icon: Icons.check_circle,
          label: 'Sucesso',
          value: '${stats.successRate.toStringAsFixed(1)}%',
          color: Colors.green,
          trend: '${stats.success} etiquetas',
        ),
        _StatCard(
          icon: Icons.error_outline,
          label: 'Falhas',
          value: '${stats.failed}',
          color: stats.failed > 0 ? Colors.red : Colors.grey,
        ),
        _StatCard(
          icon: Icons.trending_up,
          label: 'Esta Semana',
          value: '${stats.thisWeek}',
          color: colorScheme.tertiary,
        ),
      ],
    );
  }

  Widget _buildChartsSection(BuildContext context, _Stats stats) {
    final isMobile = !Responsive.isDesktop(context);
    final spacing = Responsive.cardSpacing(context);

    final templateChart = _buildCard(
      context,
      title: 'Por Template',
      icon: Icons.pie_chart_outline,
      child: _buildTemplateChart(context, stats.templateCounts),
    );

    final weekChart = _buildCard(
      context,
      title: 'Últimos 7 Dias',
      icon: Icons.show_chart,
      child: _buildWeekChart(context, stats.weekCounts),
    );

    if (isMobile) {
      return Column(
        children: [
          templateChart,
          SizedBox(height: spacing),
          weekChart,
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: templateChart),
        SizedBox(width: spacing),
        Expanded(child: weekChart),
      ],
    );
  }

  Widget _buildCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildTemplateChart(
    BuildContext context,
    Map<LabelTemplate, int> counts,
  ) {
    if (counts.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text('Nenhum dado ainda'),
        ),
      );
    }

    final total = counts.values.fold(0, (a, b) => a + b);
    final colors = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.teal,
      Colors.pink,
      Colors.indigo,
      Colors.amber,
    ];

    return Column(
      children: counts.entries.toList().asMap().entries.map((entry) {
        final index = entry.key;
        final template = entry.value.key;
        final count = entry.value.value;
        final percentage = (count / total * 100);
        final color = colors[index % colors.length];

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              Icon(template.icon, size: 18, color: color),
              const SizedBox(width: 8),
              SizedBox(
                width: 80,
                child: Text(
                  template.displayName,
                  style: const TextStyle(fontSize: 12),
                ),
              ),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: percentage / 100,
                    backgroundColor: color.withValues(alpha: 0.1),
                    color: color,
                    minHeight: 12,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 50,
                child: Text(
                  '${percentage.toStringAsFixed(0)}%',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildWeekChart(BuildContext context, Map<String, int> weekCounts) {
    final maxCount = weekCounts.values.fold(0, (a, b) => a > b ? a : b);
    final days = ['Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb', 'Dom'];

    return SizedBox(
      height: 150,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: days.map((day) {
          final count = weekCounts[day] ?? 0;
          final height = maxCount > 0 ? (count / maxCount * 100) : 0.0;

          return Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                '$count',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(height: 4),
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 28,
                height: height.clamp(4, 100),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary
                      .withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 8),
              Text(day, style: const TextStyle(fontSize: 11)),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildRecentActivity(BuildContext context, List<LabelJob> recent) {
    if (recent.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text('Nenhuma atividade recente'),
        ),
      );
    }

    return Column(
      children: recent.map((job) {
        return ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          leading: CircleAvatar(
            radius: 16,
            backgroundColor: job.success
                ? Colors.green.withValues(alpha: 0.1)
                : Colors.red.withValues(alpha: 0.1),
            child: Icon(
              job.success ? Icons.check : Icons.close,
              size: 16,
              color: job.success ? Colors.green : Colors.red,
            ),
          ),
          title: Text(
            job.title.isEmpty ? 'Sem título' : job.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            '${job.template.displayName} • ${_formatTime(job.sentAt)}',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          trailing: Icon(job.template.icon, size: 18),
        );
      }).toList(),
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inMinutes < 1) return 'Agora';
    if (diff.inMinutes < 60) return '${diff.inMinutes}min atrás';
    if (diff.inHours < 24) return '${diff.inHours}h atrás';
    if (diff.inDays < 7) return '${diff.inDays}d atrás';
    return '${dt.day}/${dt.month}';
  }

  _Stats _calculateStats(List<LabelJob> history) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final weekAgo = today.subtract(const Duration(days: 7));

    final total = history.length;
    final success = history.where((j) => j.success).length;
    final failed = total - success;
    final successRate = total > 0 ? (success / total * 100) : 0.0;
    final totalToday = history.where((j) => j.sentAt.isAfter(today)).length;
    final thisWeek = history.where((j) => j.sentAt.isAfter(weekAgo)).length;

    // Template counts
    final templateCounts = <LabelTemplate, int>{};
    for (final job in history) {
      templateCounts[job.template] = (templateCounts[job.template] ?? 0) + 1;
    }

    // Week counts
    final weekCounts = <String, int>{};
    final dayNames = ['Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb', 'Dom'];
    for (final job in history.where((j) => j.sentAt.isAfter(weekAgo))) {
      final dayIndex = (job.sentAt.weekday - 1) % 7;
      final dayName = dayNames[dayIndex];
      weekCounts[dayName] = (weekCounts[dayName] ?? 0) + 1;
    }

    return _Stats(
      total: total,
      success: success,
      failed: failed,
      successRate: successRate,
      totalToday: totalToday,
      thisWeek: thisWeek,
      templateCounts: templateCounts,
      weekCounts: weekCounts,
    );
  }
}

class _Stats {
  final int total;
  final int success;
  final int failed;
  final double successRate;
  final int totalToday;
  final int thisWeek;
  final Map<LabelTemplate, int> templateCounts;
  final Map<String, int> weekCounts;

  const _Stats({
    required this.total,
    required this.success,
    required this.failed,
    required this.successRate,
    required this.totalToday,
    required this.thisWeek,
    required this.templateCounts,
    required this.weekCounts,
  });
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final String? trend;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.trend,
  });

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          if (trend != null)
            Text(
              trend!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
        ],
      ),
    ),
  );
}
