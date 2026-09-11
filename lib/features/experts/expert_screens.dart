import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/models.dart';
import '../../core/router/app_router.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/repositories.dart';
import '../../core/utils/formatting.dart';
import '../../core/widgets/common.dart';

/// Certified behaviorists & vets offering personalised advice.
class ExpertsScreen extends ConsumerWidget {
  const ExpertsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final experts = ref.watch(expertsProvider);
    final locale = Localizations.localeOf(context).toString();
    return Scaffold(
      appBar: AppBar(
        title: Text(l.expertsTitle),
        actions: [
          TextButton.icon(
            onPressed: () => context.push(Routes.consultations),
            icon: const Icon(Icons.chat_bubble_outline),
            label: Text(l.myConsultations),
          ),
        ],
      ),
      body: AsyncBody(
        value: experts,
        builder: (items) => ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (_, i) {
            final e = items[i];
            return Card(
              child: ListTile(
                contentPadding: const EdgeInsets.all(12),
                leading: CircleAvatar(
                  radius: 26,
                  backgroundImage:
                      e.photoUrl == null ? null : NetworkImage(e.photoUrl!),
                  child: e.photoUrl == null ? const Icon(Icons.person) : null,
                ),
                title: Text(e.name,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(e.credentials),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        RatingStars(rating: e.rating, size: 14),
                        const SizedBox(width: 4),
                        Text('(${e.reviewCount})'),
                        const Spacer(),
                        Text(
                          '${formatMoney(e.ratePerSessionCents, locale: locale)} '
                          '${l.perSession}',
                        ),
                      ],
                    ),
                  ],
                ),
                onTap: () => context.push(Routes.expert(e.id)),
              ),
            );
          },
        ),
      ),
    );
  }
}

class ExpertDetailScreen extends ConsumerStatefulWidget {
  const ExpertDetailScreen({super.key, required this.expertId});
  final String expertId;
  @override
  ConsumerState<ExpertDetailScreen> createState() => _ExpertDetailScreenState();
}

class _ExpertDetailScreenState extends ConsumerState<ExpertDetailScreen> {
  final _question = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _question.dispose();
    super.dispose();
  }

  Future<void> _request(Expert expert) async {
    final uid = ref.read(currentUidProvider);
    if (uid == null || _question.text.trim().isEmpty) return;
    setState(() => _busy = true);
    final cats = ref.read(catsProvider).valueOrNull ?? const [];
    final id = await ref.read(expertRepositoryProvider).requestConsultation(
          Consultation(
            id: '',
            userId: uid,
            expertId: expert.id,
            expertName: expert.name,
            question: _question.text.trim(),
            createdAt: DateTime.now(),
            catId: cats.firstOrNull?.id,
          ),
        );
    if (!mounted) return;
    showSnack(context, context.l10n.consultationRequested);
    context.pushReplacement(Routes.consultation(id));
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final expert = (ref.watch(expertsProvider).valueOrNull ?? const [])
        .where((e) => e.id == widget.expertId)
        .firstOrNull;
    final premium = ref.watch(isPremiumProvider);
    if (expert == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      appBar: AppBar(title: Text(expert.name)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(expert.credentials,
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(expert.bio),
          SectionHeader(l.specialties),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final s in expert.specialties) Chip(label: Text(s))
            ],
          ),
          SectionHeader(l.bookConsultation),
          if (!premium)
            Card(
              color: Theme.of(context).colorScheme.tertiaryContainer,
              child: ListTile(
                leading: const Icon(Icons.workspace_premium),
                title: Text(l.premiumRequired),
                trailing: FilledButton(
                  onPressed: () => context.push(Routes.premium),
                  child: Text(l.upgrade),
                ),
              ),
            )
          else ...[
            TextField(
              controller: _question,
              maxLines: 5,
              decoration: InputDecoration(labelText: l.yourQuestion),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _busy ? null : () => _request(expert),
              icon: const Icon(Icons.send),
              label: Text(l.requestConsultation),
            ),
          ],
        ],
      ),
    );
  }
}

class ConsultationsScreen extends ConsumerWidget {
  const ConsultationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final items = ref.watch(consultationsProvider);
    String status(ConsultationStatus s) => switch (s) {
          ConsultationStatus.requested => l.consultationStatusRequested,
          ConsultationStatus.scheduled => l.consultationStatusScheduled,
          ConsultationStatus.completed => l.consultationStatusCompleted,
          ConsultationStatus.cancelled => l.consultationStatusCancelled,
        };
    return Scaffold(
      appBar: AppBar(title: Text(l.myConsultations)),
      body: AsyncBody(
        value: items,
        builder: (list) => list.isEmpty
            ? EmptyState(icon: Icons.support_agent, message: l.bookConsultation)
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: list.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) {
                  final c = list[i];
                  return Card(
                    child: ListTile(
                      leading: const Icon(Icons.chat_bubble_outline),
                      title: Text(c.expertName),
                      subtitle: Text(
                        c.lastMessage.isEmpty ? c.question : c.lastMessage,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: Chip(
                        label: Text(status(c.status)),
                        visualDensity: VisualDensity.compact,
                      ),
                      onTap: () => context.push(Routes.consultation(c.id)),
                    ),
                  );
                },
              ),
      ),
    );
  }
}

class ConsultationChatScreen extends ConsumerStatefulWidget {
  const ConsultationChatScreen({super.key, required this.consultationId});
  final String consultationId;
  @override
  ConsumerState<ConsultationChatScreen> createState() =>
      _ConsultationChatScreenState();
}

class _ConsultationChatScreenState
    extends ConsumerState<ConsultationChatScreen> {
  final _text = TextEditingController();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final uid = ref.read(currentUidProvider);
    final text = _text.text.trim();
    if (uid == null || text.isEmpty) return;
    _text.clear();
    await ref.read(expertRepositoryProvider).sendMessage(
          widget.consultationId,
          ChatMessage(
              id: '', senderId: uid, text: text, sentAt: DateTime.now()),
        );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final uid = ref.watch(currentUidProvider);
    final messages = ref.watch(_messagesProvider(widget.consultationId));
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(l.expertsTitle)),
      body: Column(
        children: [
          Expanded(
            child: AsyncBody(
              value: messages,
              builder: (list) => ListView.builder(
                reverse: true,
                padding: const EdgeInsets.all(16),
                itemCount: list.length,
                itemBuilder: (_, i) {
                  final m = list[list.length - 1 - i];
                  final mine = m.senderId == uid;
                  return Align(
                    alignment:
                        mine ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      constraints: const BoxConstraints(maxWidth: 300),
                      decoration: BoxDecoration(
                        color: mine
                            ? scheme.primaryContainer
                            : scheme.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(m.text),
                    ),
                  );
                },
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _text,
                      decoration: InputDecoration(hintText: l.typeMessage),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _send,
                    icon: const Icon(Icons.send),
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

final _messagesProvider =
    StreamProvider.family<List<ChatMessage>, String>((ref, id) {
  return ref.watch(expertRepositoryProvider).watchMessages(id);
});
