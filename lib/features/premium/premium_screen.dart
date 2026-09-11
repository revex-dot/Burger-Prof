import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_stripe/flutter_stripe.dart' show StripeException;
import 'package:url_launcher/url_launcher.dart';

import '../../core/models/models.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/payment_service.dart';
import '../../core/services/repositories.dart';
import '../../core/utils/formatting.dart';
import '../../core/widgets/common.dart';

/// Fallback plans, used when the `plans` collection hasn't been seeded yet.
const defaultPlans = [
  SubscriptionPlan(
    tier: PremiumTier.free,
    name: 'Free',
    monthlyPriceCents: 0,
    charityShareBps: 0,
    features: [
      'Core behavior guides',
      'Progress tracker for 1 cat',
      'Community forum & feed',
      'Daily reminders',
    ],
  ),
  SubscriptionPlan(
    tier: PremiumTier.plus,
    name: 'Plus',
    monthlyPriceCents: 499,
    charityShareBps: 3000,
    features: [
      'All premium guides',
      'Unlimited cats & goals',
      'Video gallery (10 GB)',
      '30% goes to partner shelters',
    ],
  ),
  SubscriptionPlan(
    tier: PremiumTier.pro,
    name: 'Pro',
    monthlyPriceCents: 1299,
    charityShareBps: 5000,
    features: [
      'Everything in Plus',
      'Expert consultations (1 / month included)',
      'Priority support',
      '50% goes to partner shelters',
    ],
  ),
];

class PremiumScreen extends ConsumerStatefulWidget {
  const PremiumScreen({super.key});
  @override
  ConsumerState<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends ConsumerState<PremiumScreen> {
  bool _busy = false;

  Future<void> _subscribe(SubscriptionPlan plan) async {
    final l = context.l10n;
    setState(() => _busy = true);
    try {
      await ref.read(paymentServiceProvider).subscribe(tier: plan.tier.id);
      if (mounted) showSnack(context, l.subscriptionSuccess);
    } on StripeException {
      if (mounted) showSnack(context, l.donationFailed);
    } catch (_) {
      if (mounted) showSnack(context, l.errorGeneric);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _manage() async {
    try {
      final url = await ref.read(paymentServiceProvider).customerPortalUrl();
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {
      if (mounted) showSnack(context, context.l10n.errorGeneric);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final locale = Localizations.localeOf(context).toString();
    final user = ref.watch(appUserProvider).valueOrNull;
    final remote = ref.watch(plansProvider).valueOrNull;
    final plans = (remote == null || remote.isEmpty) ? defaultPlans : remote;
    final current = user?.tier ?? PremiumTier.free;

    return Scaffold(
      appBar: AppBar(title: Text(l.premiumTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (final p in plans)
            Card(
              margin: const EdgeInsets.only(bottom: 12),
              color: p.tier == current
                  ? Theme.of(context).colorScheme.primaryContainer
                  : null,
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(p.name,
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(fontWeight: FontWeight.w800)),
                        const Spacer(),
                        Text(
                          p.monthlyPriceCents == 0
                              ? l.planFree
                              : '${formatMoney(p.monthlyPriceCents, locale: locale)} ${l.perMonth}',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ],
                    ),
                    if (p.tier == current)
                      Text(l.currentPlan,
                          style: Theme.of(context).textTheme.labelMedium),
                    const SizedBox(height: 10),
                    for (final f in p.features)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          children: [
                            const Icon(Icons.check, size: 18),
                            const SizedBox(width: 8),
                            Expanded(child: Text(f)),
                          ],
                        ),
                      ),
                    if (p.charityShareBps > 0) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.volunteer_activism,
                              size: 18, color: Colors.pink),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              l.charityShare(p.charityShareBps ~/ 100),
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 14),
                    if (p.tier == current && p.tier.isPaid)
                      OutlinedButton(
                        onPressed: _manage,
                        child: Text(l.manageSubscription),
                      )
                    else if (p.tier.isPaid && p.tier.index > current.index)
                      FilledButton(
                        onPressed: _busy ? null : () => _subscribe(p),
                        child: Text(l.subscribe),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
