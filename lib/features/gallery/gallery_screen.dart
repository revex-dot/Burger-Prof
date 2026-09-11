import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';

import '../../core/models/models.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/connectivity_service.dart';
import '../../core/services/repositories.dart';
import '../../core/services/upload_service.dart';
import '../../core/utils/formatting.dart';
import '../../core/widgets/common.dart';

/// Training video gallery with offline-first uploads.
class GalleryScreen extends ConsumerWidget {
  const GalleryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final videos = ref.watch(videosProvider);
    final pending = ref.watch(uploadQueueProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l.galleryTitle)),
      body: Column(
        children: [
          if (pending.isNotEmpty)
            MaterialBanner(
              leading: const Icon(Icons.cloud_upload_outlined),
              content: Text(l.pendingUploads(pending.length)),
              actions: [
                TextButton(
                  onPressed: () =>
                      ref.read(uploadQueueProvider.notifier).flush(),
                  child: Text(l.retry),
                ),
              ],
            ),
          Expanded(
            child: AsyncBody(
              value: videos,
              builder: (items) {
                if (items.isEmpty && pending.isEmpty) {
                  return EmptyState(
                    icon: Icons.videocam_outlined,
                    message: l.noVideosYet,
                  );
                }
                return GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.9,
                  ),
                  itemCount: items.length,
                  itemBuilder: (_, i) => _VideoCard(items[i]),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _pick(context, ref),
        icon: const Icon(Icons.add),
        label: Text(l.uploadVideo),
      ),
    );
  }

  Future<void> _pick(BuildContext context, WidgetRef ref) async {
    final l = context.l10n;
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.videocam),
              title: Text(l.recordVideo),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.video_library),
              title: Text(l.pickFromLibrary),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;
    final file = await ImagePicker().pickVideo(
      source: source,
      maxDuration: const Duration(minutes: 3),
    );
    if (file == null || !context.mounted) return;

    final captionCtrl = TextEditingController();
    final goals = ref.read(goalsProvider).valueOrNull ?? const [];
    String? goalId = goals.firstOrNull?.id;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text(l.uploadVideo),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: captionCtrl,
                decoration: InputDecoration(labelText: l.caption),
              ),
              if (goals.isNotEmpty) ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: goalId,
                  decoration: InputDecoration(labelText: l.goals),
                  items: [
                    for (final g in goals)
                      DropdownMenuItem(value: g.id, child: Text(g.title)),
                  ],
                  onChanged: (v) => setState(() => goalId = v),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l.uploadVideo),
            ),
          ],
        ),
      ),
    );
    if (ok != true || !context.mounted) return;

    final goal = goals.where((g) => g.id == goalId).firstOrNull;
    await ref.read(uploadQueueProvider.notifier).enqueue(
          PendingUpload(
            id: DateTime.now().microsecondsSinceEpoch.toString(),
            localPath: file.path,
            caption: captionCtrl.text.trim(),
            catId: goal?.catId,
            behaviorId: goal?.id,
          ),
        );
    if (!context.mounted) return;
    final online = ref.read(isOnlineProvider).valueOrNull ?? true;
    showSnack(context, online ? l.uploading : l.uploadQueued);
  }
}

class _VideoCard extends ConsumerWidget {
  const _VideoCard(this.video);
  final TrainingVideo video;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = Localizations.localeOf(context).toString();
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => showDialog(
          context: context,
          builder: (_) => _VideoPlayerDialog(video),
        ),
        onLongPress: () async {
          final uid = ref.read(currentUidProvider);
          if (uid == null) return;
          await ref.read(galleryRepositoryProvider).deleteVideo(uid, video.id);
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Container(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: const Center(
                  child: Icon(Icons.play_circle_outline, size: 48),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    video.caption.isEmpty ? '🎬' : video.caption,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    formatDate(video.createdAt, locale: locale),
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VideoPlayerDialog extends StatefulWidget {
  const _VideoPlayerDialog(this.video);
  final TrainingVideo video;
  @override
  State<_VideoPlayerDialog> createState() => _VideoPlayerDialogState();
}

class _VideoPlayerDialogState extends State<_VideoPlayerDialog> {
  late final VideoPlayerController _controller;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _controller =
        VideoPlayerController.networkUrl(Uri.parse(widget.video.downloadUrl))
          ..initialize().then((_) {
            if (!mounted) return;
            setState(() => _ready = true);
            _controller.play();
          });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: AspectRatio(
          aspectRatio: _ready ? _controller.value.aspectRatio : 16 / 9,
          child: _ready
              ? GestureDetector(
                  onTap: () => setState(() {
                    _controller.value.isPlaying
                        ? _controller.pause()
                        : _controller.play();
                  }),
                  child: VideoPlayer(_controller),
                )
              : const Center(child: CircularProgressIndicator()),
        ),
      );
}
