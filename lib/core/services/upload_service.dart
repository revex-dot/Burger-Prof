import 'dart:convert';
import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import 'auth_service.dart';
import 'connectivity_service.dart';
import 'prefs_service.dart';
import 'repositories.dart';

class PendingUpload {
  const PendingUpload({
    required this.id,
    required this.localPath,
    required this.caption,
    this.catId,
    this.behaviorId,
  });

  final String id;
  final String localPath;
  final String caption;
  final String? catId;
  final String? behaviorId;

  Map<String, dynamic> toJson() => {
        'id': id,
        'localPath': localPath,
        'caption': caption,
        'catId': catId,
        'behaviorId': behaviorId,
      };

  factory PendingUpload.fromJson(Map<String, dynamic> m) => PendingUpload(
        id: m['id'] as String,
        localPath: m['localPath'] as String,
        caption: (m['caption'] ?? '') as String,
        catId: m['catId'] as String?,
        behaviorId: m['behaviorId'] as String?,
      );
}

/// Offline-first video uploads.
///
/// Videos are queued locally and uploaded to Firebase Storage as soon as the
/// device is online; the Firestore metadata document is written after the
/// upload completes. The queue survives app restarts.
class UploadQueue extends Notifier<List<PendingUpload>> {
  bool _flushing = false;

  @override
  List<PendingUpload> build() {
    final raw = ref
            .watch(sharedPreferencesProvider)
            .getStringList(PrefKeys.pendingUploads) ??
        const [];
    final items = raw
        .map((s) =>
            PendingUpload.fromJson(jsonDecode(s) as Map<String, dynamic>))
        .toList();

    // Flush whenever we come back online.
    ref.listen<AsyncValue<bool>>(isOnlineProvider, (_, next) {
      if (next.valueOrNull == true) flush();
    });
    return items;
  }

  Future<void> enqueue(PendingUpload upload) async {
    state = [...state, upload];
    await _persist();
    await flush();
  }

  Future<void> _persist() => ref.read(sharedPreferencesProvider).setStringList(
        PrefKeys.pendingUploads,
        state.map((u) => jsonEncode(u.toJson())).toList(),
      );

  Future<void> flush() async {
    if (_flushing) return;
    final uid = ref.read(currentUidProvider);
    if (uid == null) return;
    if (ref.read(isOnlineProvider).valueOrNull != true) return;
    _flushing = true;
    try {
      for (final upload in List<PendingUpload>.from(state)) {
        try {
          await _upload(uid, upload);
          state = state.where((u) => u.id != upload.id).toList();
          await _persist();
        } catch (e) {
          debugPrint('Upload ${upload.id} failed, will retry: $e');
        }
      }
    } finally {
      _flushing = false;
    }
  }

  Future<void> _upload(String uid, PendingUpload upload) async {
    final file = File(upload.localPath);
    if (!await file.exists()) {
      // Source file is gone (e.g. cleared temp dir) – drop silently.
      return;
    }
    final path = 'users/$uid/videos/${upload.id}.mp4';
    final storageRef = FirebaseStorage.instance.ref(path);
    final task = await storageRef.putFile(
      file,
      SettableMetadata(contentType: 'video/mp4'),
    );
    final url = await task.ref.getDownloadURL();
    await ref.read(galleryRepositoryProvider).saveVideo(
          uid,
          TrainingVideo(
            id: upload.id,
            ownerId: uid,
            storagePath: path,
            downloadUrl: url,
            createdAt: DateTime.now(),
            caption: upload.caption,
            catId: upload.catId,
            behaviorId: upload.behaviorId,
            sizeBytes: task.totalBytes,
          ),
        );
  }
}

final uploadQueueProvider =
    NotifierProvider<UploadQueue, List<PendingUpload>>(UploadQueue.new);
