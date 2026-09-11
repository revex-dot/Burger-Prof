import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/models.dart';
import '../../core/router/app_router.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/repositories.dart';
import '../../core/utils/formatting.dart';
import '../../core/widgets/common.dart';

/// Forum (tips & questions) and social feed (success stories & updates).
class CommunityScreen extends ConsumerWidget {
  const CommunityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l.communityTitle),
          bottom: TabBar(tabs: [Tab(text: l.feed), Tab(text: l.forum)]),
        ),
        body: TabBarView(
          children: [
            _PostList(provider: feedPostsProvider),
            _PostList(provider: forumPostsProvider),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => context.go(Routes.newPost),
          icon: const Icon(Icons.edit_outlined),
          label: Text(l.newPost),
        ),
      ),
    );
  }
}

class _PostList extends ConsumerWidget {
  const _PostList({required this.provider});
  final ProviderListenable<AsyncValue<List<CommunityPost>>> provider;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    return AsyncBody(
      value: ref.watch(provider),
      builder: (posts) => posts.isEmpty
          ? EmptyState(icon: Icons.forum_outlined, message: l.noPostsYet)
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
              itemCount: posts.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) => PostCard(post: posts[i]),
            ),
    );
  }
}

String postTypeLabel(BuildContext context, PostType t) => switch (t) {
      PostType.tip => context.l10n.postTypeTip,
      PostType.successStory => context.l10n.postTypeSuccessStory,
      PostType.question => context.l10n.postTypeQuestion,
      PostType.update => context.l10n.postTypeUpdate,
    };

class PostCard extends ConsumerWidget {
  const PostCard({super.key, required this.post, this.expanded = false});
  final CommunityPost post;
  final bool expanded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final uid = ref.watch(currentUidProvider);
    final liked = uid == null
        ? false
        : ref.watch(_likedProvider((post.id, uid))).valueOrNull ?? false;
    final locale = Localizations.localeOf(context).toString();
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: expanded ? null : () => context.go(Routes.post(post.id)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    child: Text(post.authorName.isEmpty
                        ? '?'
                        : post.authorName[0].toUpperCase()),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(post.authorName,
                            style:
                                const TextStyle(fontWeight: FontWeight.w600)),
                        Text(
                          formatDate(post.createdAt, locale: locale),
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      ],
                    ),
                  ),
                  Chip(
                    label: Text(postTypeLabel(context, post.type)),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(post.title,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(
                post.body,
                maxLines: expanded ? null : 4,
                overflow: expanded ? null : TextOverflow.ellipsis,
              ),
              if (post.mediaUrl != null) ...[
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(post.mediaUrl!, fit: BoxFit.cover),
                ),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  TextButton.icon(
                    onPressed: uid == null
                        ? null
                        : () => ref
                            .read(communityRepositoryProvider)
                            .toggleLike(post.id, uid),
                    icon: Icon(liked ? Icons.favorite : Icons.favorite_border,
                        color: liked ? Colors.red : null),
                    label: Text('${post.likeCount}'),
                  ),
                  TextButton.icon(
                    onPressed: expanded
                        ? null
                        : () => context.go(Routes.post(post.id)),
                    icon: const Icon(Icons.mode_comment_outlined),
                    label: Text('${post.commentCount} ${l.comments}'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

final _likedProvider =
    StreamProvider.family<bool, (String, String)>((ref, key) {
  return ref.watch(communityRepositoryProvider).watchLiked(key.$1, key.$2);
});

final _commentsProvider =
    StreamProvider.family<List<PostComment>, String>((ref, postId) {
  return ref.watch(communityRepositoryProvider).watchComments(postId);
});

class PostDetailScreen extends ConsumerStatefulWidget {
  const PostDetailScreen({super.key, required this.postId});
  final String postId;
  @override
  ConsumerState<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends ConsumerState<PostDetailScreen> {
  final _comment = TextEditingController();

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final user = ref.read(appUserProvider).valueOrNull;
    final text = _comment.text.trim();
    if (user == null || text.isEmpty) return;
    _comment.clear();
    await ref.read(communityRepositoryProvider).addComment(
          widget.postId,
          PostComment(
            id: '',
            authorId: user.uid,
            authorName: user.displayName,
            body: text,
            createdAt: DateTime.now(),
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final all = [
      ...?ref.watch(feedPostsProvider).valueOrNull,
      ...?ref.watch(forumPostsProvider).valueOrNull,
    ];
    final post = all.where((p) => p.id == widget.postId).firstOrNull;
    final comments = ref.watch(_commentsProvider(widget.postId));
    return Scaffold(
      appBar: AppBar(title: Text(l.communityTitle)),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (post != null) PostCard(post: post, expanded: true),
                SectionHeader(l.comments),
                ...?comments.valueOrNull?.map(
                  (c) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      radius: 14,
                      child: Text(
                        c.authorName.isEmpty
                            ? '?'
                            : c.authorName[0].toUpperCase(),
                      ),
                    ),
                    title: Text(c.authorName,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(c.body),
                  ),
                ),
              ],
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _comment,
                      decoration: InputDecoration(hintText: l.addComment),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                      onPressed: _send, icon: const Icon(Icons.send)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class NewPostScreen extends ConsumerStatefulWidget {
  const NewPostScreen({super.key});
  @override
  ConsumerState<NewPostScreen> createState() => _NewPostScreenState();
}

class _NewPostScreenState extends ConsumerState<NewPostScreen> {
  final _title = TextEditingController();
  final _body = TextEditingController();
  PostType _type = PostType.successStory;
  bool _busy = false;

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final user = ref.read(appUserProvider).valueOrNull;
    if (user == null || _title.text.trim().isEmpty) return;
    setState(() => _busy = true);
    await ref.read(communityRepositoryProvider).createPost(
          CommunityPost(
            id: '',
            authorId: user.uid,
            authorName: user.displayName,
            type: _type,
            title: _title.text.trim(),
            body: _body.text.trim(),
            createdAt: DateTime.now(),
          ),
        );
    if (mounted) context.go(Routes.community);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l.newPost)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SegmentedButton<PostType>(
            segments: [
              for (final t in PostType.values)
                ButtonSegment(value: t, label: Text(postTypeLabel(context, t))),
            ],
            selected: {_type},
            onSelectionChanged: (s) => setState(() => _type = s.first),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _title,
            decoration: InputDecoration(labelText: l.postTitle),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _body,
            maxLines: 8,
            decoration: InputDecoration(labelText: l.postBody),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _busy ? null : _submit,
            child: Text(l.post),
          ),
        ],
      ),
    );
  }
}
