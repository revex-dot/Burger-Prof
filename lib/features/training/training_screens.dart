import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/models.dart';
import '../../core/router/app_router.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/content_service.dart';
import '../../core/services/repositories.dart';
import '../../core/utils/analytics.dart';
import '../../core/utils/formatting.dart';
import '../../core/widgets/common.dart';

/// Progress tracker: cats, behavior goals and their sessions.
class TrainingScreen extends ConsumerWidget {
  const TrainingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final cats = ref.watch(catsProvider).valueOrNull ?? const [];
    final goals = ref.watch(goalsProvider);
    final sessions = ref.watch(sessionsProvider).valueOrNull ?? const [];

    return Scaffold(
      appBar: AppBar(
        title: Text(l.trainTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.video_library_outlined),
            tooltip: l.galleryTitle,
            onPressed: () => context.push(Routes.gallery),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
        children: [
          SectionHeader(
            l.myCats,
            action: l.addCat,
            onAction: () => _showAddCat(context, ref),
          ),
          if (cats.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(l.noCatsYet),
              ),
            )
          else
            SizedBox(
              height: 96,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: cats.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (_, i) => _CatChip(cats[i]),
              ),
            ),
          SectionHeader(
            l.goals,
            action: l.addGoal,
            onAction: () => context.go(Routes.addGoal),
          ),
          AsyncBody(
            value: goals,
            builder: (items) {
              if (items.isEmpty) {
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(l.noGoalsYet),
                  ),
                );
              }
              return Column(
                children: [
                  for (final g in items)
                    _GoalCard(goal: g, sessions: sessions, cats: cats),
                ],
              );
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go(Routes.logSession),
        icon: const Icon(Icons.add_task),
        label: Text(l.logSession),
      ),
    );
  }

  Future<void> _showAddCat(BuildContext context, WidgetRef ref) async {
    final l = context.l10n;
    final name = TextEditingController();
    final breed = TextEditingController();
    final age = TextEditingController();
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          MediaQuery.of(ctx).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l.addCat, style: Theme.of(ctx).textTheme.titleLarge),
            const SizedBox(height: 16),
            TextField(
              controller: name,
              autofocus: true,
              decoration: InputDecoration(labelText: l.catName),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: breed,
              decoration: InputDecoration(labelText: l.breed),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: age,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: l.ageMonths),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l.save),
            ),
          ],
        ),
      ),
    );
    if (ok != true || name.text.trim().isEmpty) return;
    final uid = ref.read(currentUidProvider);
    if (uid == null) return;
    await ref.read(trainingRepositoryProvider).addCat(
          uid,
          CatProfile(
            id: '',
            ownerId: uid,
            name: name.text.trim(),
            breed: breed.text.trim(),
            ageMonths: int.tryParse(age.text) ?? 0,
          ),
        );
  }
}

class _CatChip extends StatelessWidget {
  const _CatChip(this.cat);
  final CatProfile cat;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircleAvatar(child: Text('🐱')),
              const SizedBox(height: 6),
              Text(cat.name,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              if (cat.breed.isNotEmpty)
                Text(cat.breed, style: Theme.of(context).textTheme.labelSmall),
            ],
          ),
        ),
      );
}

class _GoalCard extends StatelessWidget {
  const _GoalCard({
    required this.goal,
    required this.sessions,
    required this.cats,
  });
  final BehaviorGoal goal;
  final List<TrainingSession> sessions;
  final List<CatProfile> cats;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final stats = ProgressStats.forGoal(sessions, goal.id);
    final cat = cats.where((c) => c.id == goal.catId).firstOrNull;
    final weekProgress =
        (stats.lastWeek / goal.targetSessionsPerWeek).clamp(0.0, 1.0);
    final statusLabel = switch (goal.status) {
      BehaviorStatus.active => l.statusActive,
      BehaviorStatus.mastered => l.statusMastered,
      BehaviorStatus.paused => l.statusPaused,
    };
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => context.go(Routes.goal(goal.id)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(categoryIcon(goal.category)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      goal.title,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  Chip(
                    label: Text(statusLabel),
                    visualDensity: VisualDensity.compact,
                    backgroundColor: goal.status == BehaviorStatus.mastered
                        ? Colors.green.withValues(alpha: 0.2)
                        : null,
                  ),
                ],
              ),
              if (cat != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text('🐱 ${cat.name}',
                      style: Theme.of(context).textTheme.bodySmall),
                ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: weekProgress,
                        minHeight: 8,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text('${stats.lastWeek}/${goal.targetSessionsPerWeek}'),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Text(l.sessionsLogged(stats.count)),
                  const Spacer(),
                  if (stats.count > 0) RatingStars(rating: stats.avg, size: 14),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AddGoalScreen extends ConsumerStatefulWidget {
  const AddGoalScreen({super.key, this.guideId});
  final String? guideId;
  @override
  ConsumerState<AddGoalScreen> createState() => _AddGoalScreenState();
}

class _AddGoalScreenState extends ConsumerState<AddGoalScreen> {
  final _title = TextEditingController();
  GuideCategory _category = GuideCategory.furniture;
  String? _catId;
  int _target = 5;
  bool _initialised = false;

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final uid = ref.read(currentUidProvider);
    if (uid == null || _title.text.trim().isEmpty) return;
    final cats = ref.read(catsProvider).valueOrNull ?? const [];
    final goalId = await ref.read(trainingRepositoryProvider).addGoal(
          uid,
          BehaviorGoal(
            id: '',
            ownerId: uid,
            catId: _catId ?? cats.firstOrNull?.id ?? '',
            title: _title.text.trim(),
            category: _category,
            guideId: widget.guideId,
            targetSessionsPerWeek: _target,
          ),
        );
    if (mounted) context.go(Routes.goal(goalId));
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cats = ref.watch(catsProvider).valueOrNull ?? const [];
    final guide = widget.guideId == null
        ? null
        : ref.watch(guideByIdProvider(widget.guideId!));
    if (!_initialised && guide != null) {
      _title.text = guide.title;
      _category = guide.category;
      _initialised = true;
    }
    _catId ??= cats.firstOrNull?.id;

    return Scaffold(
      appBar: AppBar(title: Text(l.addGoal)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _title,
            decoration: InputDecoration(labelText: l.goalTitle),
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<GuideCategory>(
            initialValue: _category,
            items: [
              for (final c in GuideCategory.values)
                DropdownMenuItem(
                  value: c,
                  child: Text(categoryLabel(context, c)),
                ),
            ],
            onChanged: (v) => setState(() => _category = v ?? _category),
          ),
          const SizedBox(height: 14),
          if (cats.isNotEmpty)
            DropdownButtonFormField<String>(
              initialValue: _catId,
              decoration: InputDecoration(labelText: l.selectCat),
              items: [
                for (final c in cats)
                  DropdownMenuItem(value: c.id, child: Text(c.name)),
              ],
              onChanged: (v) => setState(() => _catId = v),
            )
          else
            Text(l.noCatsYet),
          const SizedBox(height: 14),
          Text('${l.targetSessionsPerWeek}: $_target'),
          Slider(
            value: _target.toDouble(),
            min: 1,
            max: 14,
            divisions: 13,
            label: '$_target',
            onChanged: (v) => setState(() => _target = v.round()),
          ),
          const SizedBox(height: 20),
          FilledButton(onPressed: _save, child: Text(l.save)),
        ],
      ),
    );
  }
}

class GoalDetailScreen extends ConsumerWidget {
  const GoalDetailScreen({super.key, required this.goalId});
  final String goalId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final goals = ref.watch(goalsProvider).valueOrNull ?? const [];
    final goal = goals.where((g) => g.id == goalId).firstOrNull;
    final sessions = (ref.watch(sessionsProvider).valueOrNull ?? const [])
        .where((s) => s.behaviorId == goalId)
        .toList();
    final locale = Localizations.localeOf(context).toString();
    if (goal == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final repo = ref.read(trainingRepositoryProvider);
    final uid = ref.read(currentUidProvider)!;
    final guide = goal.guideId == null
        ? null
        : ref.watch(guideByIdProvider(goal.guideId!));

    return Scaffold(
      appBar: AppBar(
        title: Text(goal.title),
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) async {
              switch (v) {
                case 'mastered':
                  await repo.updateGoalStatus(
                      uid, goal.id, BehaviorStatus.mastered);
                case 'paused':
                  await repo.updateGoalStatus(
                      uid, goal.id, BehaviorStatus.paused);
                case 'active':
                  await repo.updateGoalStatus(
                      uid, goal.id, BehaviorStatus.active);
                case 'delete':
                  await repo.deleteGoal(uid, goal.id);
                  if (context.mounted) context.go(Routes.train);
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(value: 'mastered', child: Text(l.markMastered)),
              PopupMenuItem(value: 'paused', child: Text(l.statusPaused)),
              PopupMenuItem(value: 'active', child: Text(l.statusActive)),
              PopupMenuItem(value: 'delete', child: Text(l.delete)),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
        children: [
          SectionHeader(l.weeklyProgress),
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
              child: SizedBox(height: 160, child: _SessionBars(sessions)),
            ),
          ),
          if (guide != null)
            ListTile(
              leading: const Icon(Icons.menu_book_outlined),
              title: Text(guide.title),
              subtitle: Text(l.steps),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push(Routes.guide(guide.id)),
            ),
          SectionHeader(l.recentSessions),
          if (sessions.isEmpty) Text(l.noSessionsYet),
          for (final s in sessions)
            Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                title: Text(formatDate(s.date, locale: locale)),
                subtitle: Text(
                  [
                    l.minutes(s.durationMinutes),
                    if (s.reward.isNotEmpty) '${l.reward}: ${s.reward}',
                    if (s.notes.isNotEmpty) s.notes,
                  ].join(' · '),
                ),
                trailing: RatingStars(rating: s.successRating.toDouble()),
                onLongPress: () => repo.deleteSession(uid, s.id),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('${Routes.logSession}?goalId=${goal.id}'),
        icon: const Icon(Icons.add_task),
        label: Text(l.logSession),
      ),
    );
  }
}

class _SessionBars extends StatelessWidget {
  const _SessionBars(this.sessions);
  final List<TrainingSession> sessions;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final today = dateOnly(DateTime.now());
    final groups = List.generate(7, (i) {
      final day = today.subtract(Duration(days: 6 - i));
      final ratings = sessions
          .where((s) => isSameDay(s.date, day))
          .map((s) => s.successRating)
          .toList();
      final avg = ratings.isEmpty
          ? 0.0
          : ratings.reduce((a, b) => a + b) / ratings.length;
      return BarChartGroupData(x: i, barRods: [
        BarChartRodData(
          toY: avg,
          width: 18,
          color: avg >= 4 ? Colors.green : scheme.primary,
          borderRadius: BorderRadius.circular(6),
        ),
      ]);
    });
    final labels = [
      context.l10n.weekdayMon,
      context.l10n.weekdayTue,
      context.l10n.weekdayWed,
      context.l10n.weekdayThu,
      context.l10n.weekdayFri,
      context.l10n.weekdaySat,
      context.l10n.weekdaySun,
    ];
    return BarChart(
      BarChartData(
        maxY: 5,
        barGroups: groups,
        gridData: const FlGridData(drawVerticalLine: false),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(),
          rightTitles: const AxisTitles(),
          leftTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: true, reservedSize: 24),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (v, _) {
                final day = today.subtract(Duration(days: 6 - v.toInt()));
                return Text(
                  labels[day.weekday - 1],
                  style: Theme.of(context).textTheme.labelSmall,
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class LogSessionScreen extends ConsumerStatefulWidget {
  const LogSessionScreen({super.key, this.goalId});
  final String? goalId;
  @override
  ConsumerState<LogSessionScreen> createState() => _LogSessionScreenState();
}

class _LogSessionScreenState extends ConsumerState<LogSessionScreen> {
  String? _goalId;
  int _rating = 4;
  int _minutes = 5;
  DateTime _date = DateTime.now();
  final _notes = TextEditingController();
  final _reward = TextEditingController(text: 'Treat');
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _goalId = widget.goalId;
  }

  @override
  void dispose() {
    _notes.dispose();
    _reward.dispose();
    super.dispose();
  }

  Future<void> _save(List<BehaviorGoal> goals) async {
    final uid = ref.read(currentUidProvider);
    final goal = goals.where((g) => g.id == _goalId).firstOrNull;
    if (uid == null || goal == null) return;
    setState(() => _busy = true);
    await ref.read(trainingRepositoryProvider).addSession(
          uid,
          TrainingSession(
            id: '',
            ownerId: uid,
            behaviorId: goal.id,
            catId: goal.catId,
            date: _date,
            successRating: _rating,
            durationMinutes: _minutes,
            notes: _notes.text.trim(),
            reward: _reward.text.trim(),
          ),
        );
    if (mounted) context.go(Routes.goal(goal.id));
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final goals = (ref.watch(goalsProvider).valueOrNull ?? const [])
        .where((g) => g.status != BehaviorStatus.mastered)
        .toList();
    _goalId ??= goals.firstOrNull?.id;
    final locale = Localizations.localeOf(context).toString();

    return Scaffold(
      appBar: AppBar(title: Text(l.logSession)),
      body: goals.isEmpty
          ? EmptyState(
              icon: Icons.flag_outlined,
              message: l.noGoalsYet,
              action: FilledButton(
                onPressed: () => context.go(Routes.learn),
                child: Text(l.navLearn),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                DropdownButtonFormField<String>(
                  initialValue: _goalId,
                  decoration: InputDecoration(labelText: l.goals),
                  items: [
                    for (final g in goals)
                      DropdownMenuItem(value: g.id, child: Text(g.title)),
                  ],
                  onChanged: (v) => setState(() => _goalId = v),
                ),
                const SizedBox(height: 14),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.event),
                  title: Text(l.sessionDate),
                  subtitle: Text(formatDate(_date, locale: locale)),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _date,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) setState(() => _date = picked);
                  },
                ),
                Text(l.successRating,
                    style: Theme.of(context).textTheme.titleSmall),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    5,
                    (i) => IconButton(
                      iconSize: 36,
                      icon: Icon(
                        i < _rating
                            ? Icons.star_rounded
                            : Icons.star_outline_rounded,
                        color: Colors.amber,
                      ),
                      onPressed: () => setState(() => _rating = i + 1),
                    ),
                  ),
                ),
                Text('${l.duration}: ${l.minutes(_minutes)}'),
                Slider(
                  value: _minutes.toDouble(),
                  min: 1,
                  max: 30,
                  divisions: 29,
                  label: '$_minutes',
                  onChanged: (v) => setState(() => _minutes = v.round()),
                ),
                TextField(
                  controller: _reward,
                  decoration: InputDecoration(labelText: l.reward),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _notes,
                  maxLines: 3,
                  decoration: InputDecoration(labelText: l.notes),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => context.push(Routes.gallery),
                  icon: const Icon(Icons.videocam_outlined),
                  label: Text(l.attachVideo),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: _busy ? null : () => _save(goals),
                  child: Text(l.save),
                ),
              ],
            ),
    );
  }
}
