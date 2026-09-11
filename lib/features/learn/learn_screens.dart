import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/models.dart';
import '../../core/router/app_router.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/content_service.dart';
import '../../core/widgets/common.dart';

final _searchProvider = StateProvider<String>((_) => '');
final _categoryFilterProvider = StateProvider<GuideCategory?>((_) => null);

/// Behavior library. Content is bundled, so it works offline.
class LearnScreen extends ConsumerWidget {
  const LearnScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final guides = ref.watch(guidesProvider);
    final query = ref.watch(_searchProvider).toLowerCase();
    final filter = ref.watch(_categoryFilterProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l.learnTitle)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              decoration: InputDecoration(
                hintText: l.searchGuides,
                prefixIcon: const Icon(Icons.search),
              ),
              onChanged: (v) => ref.read(_searchProvider.notifier).state = v,
            ),
          ),
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(l.allCategories),
                    selected: filter == null,
                    onSelected: (_) =>
                        ref.read(_categoryFilterProvider.notifier).state = null,
                  ),
                ),
                for (final c in GuideCategory.values)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      avatar: Icon(categoryIcon(c), size: 16),
                      label: Text(categoryLabel(context, c)),
                      selected: filter == c,
                      onSelected: (_) => ref
                          .read(_categoryFilterProvider.notifier)
                          .state = filter == c ? null : c,
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: AsyncBody(
              value: guides,
              builder: (all) {
                final items = all.where((g) {
                  if (filter != null && g.category != filter) return false;
                  if (query.isEmpty) return true;
                  return g.title.toLowerCase().contains(query) ||
                      g.summary.toLowerCase().contains(query);
                }).toList();
                if (items.isEmpty) {
                  return EmptyState(
                    icon: Icons.search_off,
                    message: l.errorGeneric,
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) => _GuideCard(items[i]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _GuideCard extends StatelessWidget {
  const _GuideCard(this.guide);
  final TrainingGuide guide;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => context.go(Routes.guide(guide.id)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                child: Icon(categoryIcon(guide.category)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            guide.title,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                        if (guide.premium) const PremiumBadge(),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      guide.summary,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        RatingStars(
                            rating: guide.difficulty.toDouble(), size: 14),
                        const SizedBox(width: 8),
                        Text(
                          l.estimatedDays(guide.estimatedDays),
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class GuideDetailScreen extends ConsumerWidget {
  const GuideDetailScreen({super.key, required this.guideId});
  final String guideId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final guide = ref.watch(guideByIdProvider(guideId));
    final premium = ref.watch(isPremiumProvider);
    if (guide == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final locked = guide.premium && !premium;
    return Scaffold(
      appBar: AppBar(title: Text(categoryLabel(context, guide.category))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
        children: [
          Text(
            guide.title,
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text('${l.difficulty}: '),
              RatingStars(rating: guide.difficulty.toDouble()),
              const Spacer(),
              Text(l.estimatedDays(guide.estimatedDays)),
            ],
          ),
          const SizedBox(height: 12),
          Text(guide.summary, style: Theme.of(context).textTheme.bodyLarge),
          SectionHeader(l.whyCatsDoIt),
          Text(guide.whyCatsDoIt),
          if (locked) ...[
            const SizedBox(height: 24),
            Card(
              color: Theme.of(context).colorScheme.tertiaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const Icon(Icons.lock_outline, size: 32),
                    const SizedBox(height: 8),
                    Text(l.premiumRequired, textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: () => context.push(Routes.premium),
                      child: Text(l.upgrade),
                    ),
                  ],
                ),
              ),
            ),
          ] else ...[
            SectionHeader(l.steps),
            for (var i = 0; i < guide.steps.length; i++)
              _NumberedStep(index: i + 1, text: guide.steps[i]),
            SectionHeader(l.reinforcementTips),
            for (final t in guide.reinforcementTips)
              _Bullet(icon: Icons.favorite_outline, text: t),
            SectionHeader(l.commonMistakes),
            for (final m in guide.commonMistakes)
              _Bullet(icon: Icons.do_not_disturb_alt_outlined, text: m),
          ],
        ],
      ),
      floatingActionButton: locked
          ? null
          : FloatingActionButton.extended(
              onPressed: () =>
                  context.go('${Routes.addGoal}?guideId=${guide.id}'),
              icon: const Icon(Icons.flag),
              label: Text(l.startTrainingThis),
            ),
    );
  }
}

class _NumberedStep extends StatelessWidget {
  const _NumberedStep({required this.index, required this.text});
  final int index;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(radius: 14, child: Text('$index')),
            const SizedBox(width: 12),
            Expanded(
                child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(text),
            )),
          ],
        ),
      );
}

class _Bullet extends StatelessWidget {
  const _Bullet({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 10),
            Expanded(child: Text(text)),
          ],
        ),
      );
}
