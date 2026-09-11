import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_stripe/flutter_stripe.dart' show StripeException;
import 'package:go_router/go_router.dart';

import '../../core/models/models.dart';
import '../../core/router/app_router.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/payment_service.dart';
import '../../core/services/repositories.dart';
import '../../core/utils/formatting.dart';
import '../../core/widgets/common.dart';

String charityTypeLabel(BuildContext context, CharityType t) => switch (t) {
      CharityType.shelter => context.l10n.charityShelter,
      CharityType.rescue => context.l10n.charityRescue,
      CharityType.vetClinic => context.l10n.charityVetClinic,
    };

IconData charityIcon(CharityType t) => switch (t) {
      CharityType.shelter => Icons.home_work_outlined,
      CharityType.rescue => Icons.pets_outlined,
      CharityType.vetClinic => Icons.medical_services_outlined,
    };

/// Impact dashboard: your giving, partner organisations and their
/// transparency reports.
class GivingScreen extends ConsumerWidget {
  const GivingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final user = ref.watch(appUserProvider).valueOrNull;
    final donations = ref.watch(donationsProvider).valueOrNull ?? const [];
    final charities = ref.watch(charitiesProvider);
    final updates = ref.watch(impactUpdatesProvider).valueOrNull ?? const [];
    final locale = Localizations.localeOf(context).toString();

    final succeeded =
        donations.where((d) => d.status == DonationStatus.succeeded).toList();
    final totalNet = succeeded.fold(0, (s, d) => s + d.netCents);
    final supportedIds = succeeded.map((d) => d.charityId).toSet();
    // Rough, transparent estimate: partners report ~$45 per cat helped.
    final catsHelped = (totalNet / 4500).floor();

    return Scaffold(
      appBar: AppBar(title: Text(l.giveTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        children: [
          Card(
            color: Theme.of(context).colorScheme.secondaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l.impactTitle,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _Impact(
                          label: l.totalDonated,
                          value: formatMoney(
                            totalNet +
                                (user?.totalDonatedCents ?? 0) -
                                totalNet,
                            locale: locale,
                          ),
                        ),
                      ),
                      Expanded(
                        child: _Impact(
                          label: l.catsHelped,
                          value: '~$catsHelped 🐈',
                        ),
                      ),
                      Expanded(
                        child: _Impact(
                          label: l.beneficiaries,
                          value: '${supportedIds.length}',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(l.transparencyNote,
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
          ),
          SectionHeader(l.beneficiaries),
          AsyncBody(
            value: charities,
            builder: (items) => Column(
              children: [
                for (final c in items)
                  Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(12),
                      leading: CircleAvatar(child: Icon(charityIcon(c.type))),
                      title: Row(
                        children: [
                          Expanded(
                            child: Text(c.name,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700)),
                          ),
                          if (c.verified)
                            Tooltip(
                              message: l.verifiedPartner,
                              child: const Icon(Icons.verified,
                                  size: 18, color: Colors.blue),
                            ),
                        ],
                      ),
                      subtitle: Text(
                        '${charityTypeLabel(context, c.type)} · ${c.location}\n'
                        '${formatMoney(c.totalReceivedCents, locale: locale)} · '
                        '${c.catsHelped} ${l.catsHelped.toLowerCase()}',
                      ),
                      isThreeLine: true,
                      trailing: FilledButton(
                        onPressed: () => context.go(Routes.donate(c.id)),
                        child: Text(l.donate),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (updates.isNotEmpty) ...[
            SectionHeader(l.impactUpdates),
            for (final u in updates.take(10))
              Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(u.charityName,
                          style: Theme.of(context).textTheme.labelMedium),
                      Text(u.title,
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text(u.body),
                      const SizedBox(height: 6),
                      Text(
                        '${formatDate(u.createdAt, locale: locale)} · '
                        '${formatMoney(u.amountSpentCents, locale: locale)} · '
                        '${u.catsHelped} ${l.catsHelped.toLowerCase()}',
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ],
                  ),
                ),
              ),
          ],
          if (donations.isNotEmpty) ...[
            SectionHeader(l.donationHistory),
            for (final d in donations)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  d.status == DonationStatus.succeeded
                      ? Icons.check_circle
                      : Icons.hourglass_bottom,
                  color: d.status == DonationStatus.succeeded
                      ? Colors.green
                      : null,
                ),
                title: Text(d.charityName),
                subtitle: Text(
                  '${formatDate(d.createdAt, locale: locale)} · '
                  '${l.netToPartner}: ${formatMoney(d.netCents, currency: d.currency, locale: locale)}',
                ),
                trailing: Text(
                  formatMoney(d.amountCents,
                      currency: d.currency, locale: locale),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _Impact extends StatelessWidget {
  const _Impact({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value,
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800)),
          Text(label, style: Theme.of(context).textTheme.labelSmall),
        ],
      );
}

class DonateScreen extends ConsumerStatefulWidget {
  const DonateScreen({super.key, required this.charityId});
  final String charityId;
  @override
  ConsumerState<DonateScreen> createState() => _DonateScreenState();
}

class _DonateScreenState extends ConsumerState<DonateScreen> {
  static const _presets = [500, 1000, 2500, 5000];
  int _amount = 1000;
  final _custom = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _custom.dispose();
    super.dispose();
  }

  Future<void> _donate(Charity charity) async {
    setState(() => _busy = true);
    final l = context.l10n;
    try {
      await ref.read(paymentServiceProvider).donate(
            charityId: charity.id,
            amountCents: _amount,
            currency: 'usd',
          );
      if (!mounted) return;
      showSnack(context, l.donationSuccess(charity.name));
      context.go(Routes.give);
    } on StripeException {
      if (mounted) showSnack(context, l.donationFailed);
    } catch (_) {
      if (mounted) showSnack(context, l.errorGeneric);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final locale = Localizations.localeOf(context).toString();
    final charity = (ref.watch(charitiesProvider).valueOrNull ?? const [])
        .where((c) => c.id == widget.charityId)
        .firstOrNull;
    if (charity == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final fee = PaymentService.feeForAmount(_amount);
    return Scaffold(
      appBar: AppBar(title: Text(l.donate)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(charity.name,
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w800)),
          Text(
              '${charityTypeLabel(context, charity.type)} · ${charity.location}'),
          const SizedBox(height: 8),
          Text(charity.description),
          SectionHeader(l.chooseAmount),
          Wrap(
            spacing: 8,
            children: [
              for (final p in _presets)
                ChoiceChip(
                  label: Text(formatMoney(p, locale: locale)),
                  selected: _amount == p,
                  onSelected: (_) => setState(() {
                    _amount = p;
                    _custom.clear();
                  }),
                ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _custom,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: l.customAmount,
              prefixText: r'$ ',
            ),
            onChanged: (v) {
              final d = double.tryParse(v);
              if (d != null && d >= 1)
                setState(() => _amount = (d * 100).round());
            },
          ),
          const SizedBox(height: 20),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _Line(l.donate, formatMoney(_amount, locale: locale)),
                  _Line('- ${PaymentService.donationFeeBps / 100}%',
                      formatMoney(fee, locale: locale)),
                  const Divider(),
                  _Line(
                    l.netToPartner,
                    formatMoney(_amount - fee, locale: locale),
                    bold: true,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l.processingFeeNote(
                        '${PaymentService.donationFeeBps / 100}%'),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _busy ? null : () => _donate(charity),
            icon: const Icon(Icons.favorite),
            label: Text(l.donateNow),
          ),
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line(this.label, this.value, {this.bold = false});
  final String label;
  final String value;
  final bool bold;
  @override
  Widget build(BuildContext context) {
    final style = bold ? const TextStyle(fontWeight: FontWeight.w800) : null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style)),
          Text(value, style: style),
        ],
      ),
    );
  }
}
