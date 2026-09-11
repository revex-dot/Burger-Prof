import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import 'auth_service.dart';

/// Firestore repositories. All reads are realtime streams so the dashboard
/// analytics and community screens update live; with offline persistence
/// enabled the same streams serve cached data when the device is offline.
class TrainingRepository {
  TrainingRepository(this._db);
  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> _cats(String uid) =>
      _db.collection('users').doc(uid).collection('cats');
  CollectionReference<Map<String, dynamic>> _goals(String uid) =>
      _db.collection('users').doc(uid).collection('goals');
  CollectionReference<Map<String, dynamic>> _sessions(String uid) =>
      _db.collection('users').doc(uid).collection('sessions');

  Stream<List<CatProfile>> watchCats(String uid) =>
      _cats(uid).orderBy('name').snapshots().map(
            (s) =>
                s.docs.map((d) => CatProfile.fromMap(d.id, d.data())).toList(),
          );

  Future<String> addCat(String uid, CatProfile cat) async {
    final ref = await _cats(uid).add(cat.toMap());
    return ref.id;
  }

  Future<void> deleteCat(String uid, String catId) =>
      _cats(uid).doc(catId).delete();

  Stream<List<BehaviorGoal>> watchGoals(String uid) => _goals(uid)
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map(
        (s) => s.docs.map((d) => BehaviorGoal.fromMap(d.id, d.data())).toList(),
      );

  Future<String> addGoal(String uid, BehaviorGoal goal) async {
    final ref = await _goals(uid).add(goal.toMap());
    return ref.id;
  }

  Future<void> updateGoalStatus(
    String uid,
    String goalId,
    BehaviorStatus status,
  ) =>
      _goals(uid).doc(goalId).update({
        'status': status.name,
        'masteredAt': status == BehaviorStatus.mastered
            ? FieldValue.serverTimestamp()
            : null,
      });

  Future<void> deleteGoal(String uid, String goalId) =>
      _goals(uid).doc(goalId).delete();

  Stream<List<TrainingSession>> watchSessions(String uid, {int limit = 500}) =>
      _sessions(uid)
          .orderBy('date', descending: true)
          .limit(limit)
          .snapshots()
          .map(
            (s) => s.docs
                .map((d) => TrainingSession.fromMap(d.id, d.data()))
                .toList(),
          );

  Future<String> addSession(String uid, TrainingSession session) async {
    final ref = await _sessions(uid).add(session.toMap());
    return ref.id;
  }

  Future<void> deleteSession(String uid, String id) =>
      _sessions(uid).doc(id).delete();
}

class GalleryRepository {
  GalleryRepository(this._db);
  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> _videos(String uid) =>
      _db.collection('users').doc(uid).collection('videos');

  Stream<List<TrainingVideo>> watchVideos(String uid) =>
      _videos(uid).orderBy('createdAt', descending: true).snapshots().map(
            (s) => s.docs
                .map((d) => TrainingVideo.fromMap(d.id, d.data()))
                .toList(),
          );

  Future<void> saveVideo(String uid, TrainingVideo video) =>
      _videos(uid).doc(video.id).set(video.toMap());

  Future<void> deleteVideo(String uid, String id) =>
      _videos(uid).doc(id).delete();
}

class ExpertRepository {
  ExpertRepository(this._db);
  final FirebaseFirestore _db;

  Stream<List<Expert>> watchExperts() => _db
      .collection('experts')
      .orderBy('rating', descending: true)
      .snapshots()
      .map(
        (s) => s.docs.map((d) => Expert.fromMap(d.id, d.data())).toList(),
      );

  Stream<List<Consultation>> watchConsultations(String uid) => _db
      .collection('consultations')
      .where('userId', isEqualTo: uid)
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map(
        (s) => s.docs.map((d) => Consultation.fromMap(d.id, d.data())).toList(),
      );

  Future<String> requestConsultation(Consultation c) async {
    final ref = await _db.collection('consultations').add(c.toMap());
    await ref.collection('messages').add(
          ChatMessage(
            id: '',
            senderId: c.userId,
            text: c.question,
            sentAt: c.createdAt,
          ).toMap(),
        );
    return ref.id;
  }

  Stream<List<ChatMessage>> watchMessages(String consultationId) => _db
      .collection('consultations')
      .doc(consultationId)
      .collection('messages')
      .orderBy('sentAt')
      .snapshots()
      .map(
        (s) => s.docs.map((d) => ChatMessage.fromMap(d.id, d.data())).toList(),
      );

  Future<void> sendMessage(String consultationId, ChatMessage m) async {
    final doc = _db.collection('consultations').doc(consultationId);
    await doc.collection('messages').add(m.toMap());
    await doc.update({'lastMessage': m.text});
  }
}

class CommunityRepository {
  CommunityRepository(this._db);
  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _posts =>
      _db.collection('posts');

  /// Forum = questions & tips; Feed = success stories & updates.
  Stream<List<CommunityPost>> watchPosts({required bool feed}) {
    final types = feed
        ? [PostType.successStory.name, PostType.update.name]
        : [PostType.tip.name, PostType.question.name];
    return _posts
        .where('type', whereIn: types)
        .orderBy('createdAt', descending: true)
        .limit(100)
        .snapshots()
        .map(
          (s) =>
              s.docs.map((d) => CommunityPost.fromMap(d.id, d.data())).toList(),
        );
  }

  Future<void> createPost(CommunityPost post) => _posts.add(post.toMap());

  Stream<List<PostComment>> watchComments(String postId) => _posts
      .doc(postId)
      .collection('comments')
      .orderBy('createdAt')
      .snapshots()
      .map(
        (s) => s.docs.map((d) => PostComment.fromMap(d.id, d.data())).toList(),
      );

  Future<void> addComment(String postId, PostComment c) async {
    final post = _posts.doc(postId);
    await post.collection('comments').add(c.toMap());
    await post.update({'commentCount': FieldValue.increment(1)});
  }

  Stream<bool> watchLiked(String postId, String uid) =>
      _posts.doc(postId).collection('likes').doc(uid).snapshots().map(
            (s) => s.exists,
          );

  Future<void> toggleLike(String postId, String uid) async {
    final post = _posts.doc(postId);
    final like = post.collection('likes').doc(uid);
    final snap = await like.get();
    final batch = _db.batch();
    if (snap.exists) {
      batch.delete(like);
      batch.update(post, {'likeCount': FieldValue.increment(-1)});
    } else {
      batch.set(like, {'createdAt': FieldValue.serverTimestamp()});
      batch.update(post, {'likeCount': FieldValue.increment(1)});
    }
    await batch.commit();
  }
}

class GivingRepository {
  GivingRepository(this._db);
  final FirebaseFirestore _db;

  Stream<List<Charity>> watchCharities() => _db
      .collection('charities')
      .where('verified', isEqualTo: true)
      .snapshots()
      .map(
        (s) => s.docs.map((d) => Charity.fromMap(d.id, d.data())).toList(),
      );

  Stream<List<Donation>> watchDonations(String uid) => _db
      .collection('donations')
      .where('userId', isEqualTo: uid)
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map(
        (s) => s.docs.map((d) => Donation.fromMap(d.id, d.data())).toList(),
      );

  Stream<List<ImpactUpdate>> watchImpactUpdates() => _db
      .collection('impactUpdates')
      .orderBy('createdAt', descending: true)
      .limit(50)
      .snapshots()
      .map(
        (s) => s.docs.map((d) => ImpactUpdate.fromMap(d.id, d.data())).toList(),
      );
}

class MarketplaceRepository {
  MarketplaceRepository(this._db);
  final FirebaseFirestore _db;

  Stream<List<Product>> watchProducts() => _db
      .collection('products')
      .where('stock', isGreaterThan: 0)
      .snapshots()
      .map(
        (s) => s.docs.map((d) => Product.fromMap(d.id, d.data())).toList(),
      );

  Stream<List<Order>> watchOrders(String uid) => _db
      .collection('orders')
      .where('userId', isEqualTo: uid)
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((s) => s.docs.map((d) => Order.fromMap(d.id, d.data())).toList());

  Stream<List<SubscriptionPlan>> watchPlans() =>
      _db.collection('plans').orderBy('monthlyPriceCents').snapshots().map(
            (s) =>
                s.docs.map((d) => SubscriptionPlan.fromMap(d.data())).toList(),
          );
}

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

final trainingRepositoryProvider =
    Provider((ref) => TrainingRepository(ref.watch(firestoreProvider)));
final galleryRepositoryProvider =
    Provider((ref) => GalleryRepository(ref.watch(firestoreProvider)));
final expertRepositoryProvider =
    Provider((ref) => ExpertRepository(ref.watch(firestoreProvider)));
final communityRepositoryProvider =
    Provider((ref) => CommunityRepository(ref.watch(firestoreProvider)));
final givingRepositoryProvider =
    Provider((ref) => GivingRepository(ref.watch(firestoreProvider)));
final marketplaceRepositoryProvider =
    Provider((ref) => MarketplaceRepository(ref.watch(firestoreProvider)));

Stream<List<T>> _emptyIfSignedOut<T>(
  String? uid,
  Stream<List<T>> Function(String uid) source,
) =>
    uid == null ? Stream.value(const []) : source(uid);

final catsProvider =
    StreamProvider<List<CatProfile>>((ref) => _emptyIfSignedOut(
          ref.watch(currentUidProvider),
          ref.watch(trainingRepositoryProvider).watchCats,
        ));

final goalsProvider =
    StreamProvider<List<BehaviorGoal>>((ref) => _emptyIfSignedOut(
          ref.watch(currentUidProvider),
          ref.watch(trainingRepositoryProvider).watchGoals,
        ));

final sessionsProvider =
    StreamProvider<List<TrainingSession>>((ref) => _emptyIfSignedOut(
          ref.watch(currentUidProvider),
          ref.watch(trainingRepositoryProvider).watchSessions,
        ));

final videosProvider =
    StreamProvider<List<TrainingVideo>>((ref) => _emptyIfSignedOut(
          ref.watch(currentUidProvider),
          ref.watch(galleryRepositoryProvider).watchVideos,
        ));

final expertsProvider = StreamProvider<List<Expert>>(
  (ref) => ref.watch(expertRepositoryProvider).watchExperts(),
);

final consultationsProvider =
    StreamProvider<List<Consultation>>((ref) => _emptyIfSignedOut(
          ref.watch(currentUidProvider),
          ref.watch(expertRepositoryProvider).watchConsultations,
        ));

final forumPostsProvider = StreamProvider<List<CommunityPost>>(
  (ref) => ref.watch(communityRepositoryProvider).watchPosts(feed: false),
);
final feedPostsProvider = StreamProvider<List<CommunityPost>>(
  (ref) => ref.watch(communityRepositoryProvider).watchPosts(feed: true),
);

final charitiesProvider = StreamProvider<List<Charity>>(
  (ref) => ref.watch(givingRepositoryProvider).watchCharities(),
);
final donationsProvider =
    StreamProvider<List<Donation>>((ref) => _emptyIfSignedOut(
          ref.watch(currentUidProvider),
          ref.watch(givingRepositoryProvider).watchDonations,
        ));
final impactUpdatesProvider = StreamProvider<List<ImpactUpdate>>(
  (ref) => ref.watch(givingRepositoryProvider).watchImpactUpdates(),
);

final productsProvider = StreamProvider<List<Product>>(
  (ref) => ref.watch(marketplaceRepositoryProvider).watchProducts(),
);
final ordersProvider = StreamProvider<List<Order>>((ref) => _emptyIfSignedOut(
      ref.watch(currentUidProvider),
      ref.watch(marketplaceRepositoryProvider).watchOrders,
    ));
final plansProvider = StreamProvider<List<SubscriptionPlan>>(
  (ref) => ref.watch(marketplaceRepositoryProvider).watchPlans(),
);
