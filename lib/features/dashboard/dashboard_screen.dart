import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/models.dart';
import '../../core/router/app_router.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/content_service.dart';
import '../../core/services/repositories.dart';
import '../../core/services/upload_service.dart';
import '../../core/utils/analytics.dart';
import '../../core/utils/formatting.dart';
import '../../core/widgets/common.dart';

/// Home dashboard: realtime analytics, quick actions and recent activity.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final user = ref.watch(appUserProvider).valueOrNull;
    final stats = ref.watch(progressStatsProvider);
    final sessions = ref.watch(sessionsProvider).valueOrNull ?? const [];
    final goals = ref.watch(goalsProvider).valueOrNull ?? const [];
    final tip = ref.watch(tipOfTheDayProvider);
    final pendingUploads = ref.watch(uploadQueueProvider).length;
    final name = user?.displayName.isNotEmpty == true
        ? user!.displayName.split(' ').first
        : '🐈';

    return Scaffold(
      appBar: AppBar(
        title: Text(l.dashboardGreeting(name)),
        actions: [
          if (pendingUploads > 0)
            IconButton(
              tooltip: l.pendingUploads(pendingUploads),
              icon: Badge(
                label: Text('$pendingUploads'),
                child: const Icon(Icons.cloud_upload_outlined),
              ),
              onPressed: () => context.push(Routes.gallery),
            ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push(Routes.settings),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        children: [
          _TodayCard(stats: stats),
          SectionHeader(l.liveAnalytics),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.5,
            children: [
              StatTile(
                label: l.streakDays(stats.streakDays),
                value: '${stats.streakDays}🔥',
                icon: Icons.local_fire_department_outlined,
                color: Colors.deepOrange,
              ),
              StatTile(
                label: l.sessionsThisWeek,
                value: '${stats.sessionsThisWeek}',
                icon: Icons.calendar_today_outlined,
              ),
              StatTile(
                label: l.successRate,
                value: '${(stats.successRate * 100).round()}%',
                icon: Icons.trending_up,
                color: Colors.green,
              ),
              StatTile(
                label: '${l.activeGoals} / ${l.masteredGoals}',
                value: '${stats.activeGoals} / ${stats.masteredGoals}',
                icon: Icons.flag_outlined,
              ),
            ],
          ),
          SectionHeader(l.trendLast14Days),
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 20, 20, 8),
              child: SizedBox(height: 180, child: _TrendChart(stats.trend)),
            ),
          ),
          if (stats.byCategory.isNotEmpty) ...[
            SectionHeader(l.byCategory),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    for (final e in stats.byCategory.entries)
                      _CategoryBar(category: e.key, avg: e.value),
                  ],
                ),
              ),
            ),
          ],
          SectionHeader(l.quickActions),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ActionChip(
                avatar: const Icon(Icons.add_task, size: 18),
                label: Text(l.logSession),
                onPressed: () => context.go(Routes.logSession),
              ),
              ActionChip(
                avatar: const Icon(Icons.video_library_outlined, size: 18),
                label: Text(l.galleryTitle),
                onPressed: () => context.push(Routes.gallery),
              ),
              ActionChip(
                avatar: const Icon(Icons.alarm, size: 18),
                label: Text(l.remindersTitle),
                onPressed: () => context.push(Routes.reminders),
              ),
              ActionChip(
                avatar: const Icon(Icons.support_agent, size: 18),
                label: Text(l.expertsTitle),
                onPressed: () => context.push(Routes.experts),
              ),
              ActionChip(
                avatar: const Icon(Icons.workspace_premium_outlined, size: 18),
                label: Text(l.premiumTitle),
                onPressed: () => context.push(Routes.premium),
              ),
              ActionChip(
                avatar: const Icon(Icons.storefront_outlined, size: 18),
                label: Text(l.marketplaceTitle),
                onPressed: () => context.push(Routes.shop),
              ),
            ],
          ),
          if (tip != null) ...[
            SectionHeader(l.tipOfTheDay),
            Card(
              color: Theme.of(context).colorScheme.secondaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('💡', style: TextStyle(fontSize: 22)),
                    const SizedBox(width: 12),
                    Expanded(child: Text(tip)),
                  ],
                ),
              ),
            ),
          ],
          SectionHeader(
            l.recentSessions,
            action: l.viewAll,
            onAction: () => context.go(Routes.train),
          ),
          if (sessions.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(l.noSessionsYet),
              ),
            )
          else
            for (final s in sessions.take(5))
              _SessionTile(session: s, goals: goals),
        ],
      ),
    );
  }
}

class _TodayCard extends StatelessWidget {
  const _TodayCard({required this.stats});
  final ProgressStats stats;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l.todaysTraining,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    stats.trainedToday ? l.done : l.reminderBody,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            FilledButton(
              onPressed: () => context.go(Routes.logSession),
              child: Text(l.logSession),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrendChart extends StatelessWidget {
  const _TrendChart(this.trend);
  final List<double?> trend;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final spots = <FlSpot>[
      for (var i = 0; i < trend.length; i++)
        if (trend[i] != null) FlSpot(i.toDouble(), trend[i]!),
    ];
    if (spots.isEmpty) {
      return Center(child: Text(context.l10n.noSessionsYet));
    }
    return LineChart(
      LineChartData(
        minY: 1,
        maxY: 5,
        minX: 0,
        maxX: 13,
        gridData: FlGridData(
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) => FlLine(
            color: scheme.outlineVariant.withValues(alpha: 0.4),
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(),
          rightTitles: const AxisTitles(),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 1,
              reservedSize: 28,
              getTitlesWidget: (v, _) => Text(
                v.toInt().toString(),
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 13,
              getTitlesWidget: (v, _) => Text(
                v == 0 ? '-13d' : context.l10n.today,
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: scheme.primary,
            barWidth: 3,
            dotData: const FlDotData(show: true),
            belowBarData: BarAreaData(
              show: true,
              color: scheme.primary.withValues(alpha: 0.12),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryBar extends StatelessWidget {
  const _CategoryBar({required this.category, required this.avg});
  final GuideCategory category;
  final double avg;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Icon(categoryIcon(category), size: 18),
            const SizedBox(width: 8),
            SizedBox(
              width: 120,
              child: Text(
                categoryLabel(context, category),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: avg / 5,
                  minHeight: 10,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(avg.toStringAsFixed(1)),
          ],
        ),
      );
}

class _SessionTile extends StatelessWidget {
  const _SessionTile({required this.session, required this.goals});
  final TrainingSession session;
  final List<BehaviorGoal> goals;

  @override
  Widget build(BuildContext context) {
    final goal = goals.where((g) => g.id == session.behaviorId).firstOrNull;
    final locale = Localizations.localeOf(context).toString();
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(categoryIcon(goal?.category ?? GuideCategory.enrichment)),
        title: Text(goal?.title ?? session.behaviorId),
        subtitle: Text(
          '${formatDate(session.date, locale: locale)} · '
          '${context.l10n.minutes(session.durationMinutes)}',
        ),
        trailing: RatingStars(rating: session.successRating.toDouble()),
        onTap: goal == null ? null : () => context.go(Routes.goal(goal.id)),
      ),
    );
  }
}
