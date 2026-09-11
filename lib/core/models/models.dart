/// Domain models shared across the app.
///
/// All models are plain immutable Dart classes with `fromMap` / `toMap`
/// converters so they work with Cloud Firestore (online + offline cache)
/// and with bundled JSON assets.
library;

import 'package:cloud_firestore/cloud_firestore.dart';

DateTime _toDate(dynamic v) {
  if (v is Timestamp) return v.toDate();
  if (v is DateTime) return v;
  if (v is String) return DateTime.tryParse(v) ?? DateTime.now();
  if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
  return DateTime.now();
}

int _toInt(dynamic v, [int fallback = 0]) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? fallback;
  return fallback;
}

double _toDouble(dynamic v, [double fallback = 0]) {
  if (v is double) return v;
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v) ?? fallback;
  return fallback;
}

List<String> _toStringList(dynamic v) =>
    v is List ? v.map((e) => e.toString()).toList() : const [];

// ---------------------------------------------------------------------------
// Users & cats
// ---------------------------------------------------------------------------

enum PremiumTier { free, plus, pro }

extension PremiumTierX on PremiumTier {
  String get id => name;
  static PremiumTier parse(String? s) => PremiumTier.values.firstWhere(
        (t) => t.name == s,
        orElse: () => PremiumTier.free,
      );
  bool get isPaid => this != PremiumTier.free;
}

class AppUser {
  const AppUser({
    required this.uid,
    required this.email,
    this.displayName = '',
    this.photoUrl,
    this.tier = PremiumTier.free,
    this.locale = 'en',
    this.totalDonatedCents = 0,
    this.fcmTokens = const [],
    this.createdAt,
    this.subscriptionStatus,
    this.stripeCustomerId,
  });

  final String uid;
  final String email;
  final String displayName;
  final String? photoUrl;
  final PremiumTier tier;
  final String locale;
  final int totalDonatedCents;
  final List<String> fcmTokens;
  final DateTime? createdAt;
  final String? subscriptionStatus;
  final String? stripeCustomerId;

  factory AppUser.fromMap(String uid, Map<String, dynamic> m) => AppUser(
        uid: uid,
        email: (m['email'] ?? '') as String,
        displayName: (m['displayName'] ?? '') as String,
        photoUrl: m['photoUrl'] as String?,
        tier: PremiumTierX.parse(m['tier'] as String?),
        locale: (m['locale'] ?? 'en') as String,
        totalDonatedCents: _toInt(m['totalDonatedCents']),
        fcmTokens: _toStringList(m['fcmTokens']),
        createdAt: m['createdAt'] == null ? null : _toDate(m['createdAt']),
        subscriptionStatus: m['subscriptionStatus'] as String?,
        stripeCustomerId: m['stripeCustomerId'] as String?,
      );

  Map<String, dynamic> toMap() => {
        'email': email,
        'displayName': displayName,
        'photoUrl': photoUrl,
        'tier': tier.id,
        'locale': locale,
        'totalDonatedCents': totalDonatedCents,
        'fcmTokens': fcmTokens,
        'createdAt': createdAt ?? FieldValue.serverTimestamp(),
        'subscriptionStatus': subscriptionStatus,
        'stripeCustomerId': stripeCustomerId,
      };

  AppUser copyWith({String? displayName, String? locale, PremiumTier? tier}) =>
      AppUser(
        uid: uid,
        email: email,
        displayName: displayName ?? this.displayName,
        photoUrl: photoUrl,
        tier: tier ?? this.tier,
        locale: locale ?? this.locale,
        totalDonatedCents: totalDonatedCents,
        fcmTokens: fcmTokens,
        createdAt: createdAt,
        subscriptionStatus: subscriptionStatus,
        stripeCustomerId: stripeCustomerId,
      );
}

class CatProfile {
  const CatProfile({
    required this.id,
    required this.ownerId,
    required this.name,
    this.breed = '',
    this.ageMonths = 0,
    this.photoUrl,
    this.notes = '',
  });

  final String id;
  final String ownerId;
  final String name;
  final String breed;
  final int ageMonths;
  final String? photoUrl;
  final String notes;

  factory CatProfile.fromMap(String id, Map<String, dynamic> m) => CatProfile(
        id: id,
        ownerId: (m['ownerId'] ?? '') as String,
        name: (m['name'] ?? '') as String,
        breed: (m['breed'] ?? '') as String,
        ageMonths: _toInt(m['ageMonths']),
        photoUrl: m['photoUrl'] as String?,
        notes: (m['notes'] ?? '') as String,
      );

  Map<String, dynamic> toMap() => {
        'ownerId': ownerId,
        'name': name,
        'breed': breed,
        'ageMonths': ageMonths,
        'photoUrl': photoUrl,
        'notes': notes,
      };
}

// ---------------------------------------------------------------------------
// Learning content (bundled JSON, works fully offline)
// ---------------------------------------------------------------------------

enum GuideCategory {
  furniture,
  litter,
  scratching,
  handling,
  biting,
  vocalization,
  feeding,
  tricks,
  socialization,
  enrichment,
}

extension GuideCategoryX on GuideCategory {
  static GuideCategory parse(String? s) => GuideCategory.values.firstWhere(
        (c) => c.name == s,
        orElse: () => GuideCategory.enrichment,
      );
}

class TrainingGuide {
  const TrainingGuide({
    required this.id,
    required this.title,
    required this.category,
    required this.summary,
    required this.whyCatsDoIt,
    required this.steps,
    required this.reinforcementTips,
    required this.commonMistakes,
    this.difficulty = 2,
    this.estimatedDays = 14,
    this.premium = false,
  });

  final String id;
  final String title;
  final GuideCategory category;
  final String summary;
  final String whyCatsDoIt;
  final List<String> steps;
  final List<String> reinforcementTips;
  final List<String> commonMistakes;
  final int difficulty; // 1..5
  final int estimatedDays;
  final bool premium;

  factory TrainingGuide.fromMap(Map<String, dynamic> m) => TrainingGuide(
        id: m['id'] as String,
        title: m['title'] as String,
        category: GuideCategoryX.parse(m['category'] as String?),
        summary: (m['summary'] ?? '') as String,
        whyCatsDoIt: (m['whyCatsDoIt'] ?? '') as String,
        steps: _toStringList(m['steps']),
        reinforcementTips: _toStringList(m['reinforcementTips']),
        commonMistakes: _toStringList(m['commonMistakes']),
        difficulty: _toInt(m['difficulty'], 2),
        estimatedDays: _toInt(m['estimatedDays'], 14),
        premium: (m['premium'] ?? false) as bool,
      );
}

// ---------------------------------------------------------------------------
// Training & progress
// ---------------------------------------------------------------------------

enum BehaviorStatus { active, mastered, paused }

class BehaviorGoal {
  const BehaviorGoal({
    required this.id,
    required this.ownerId,
    required this.catId,
    required this.title,
    required this.category,
    this.guideId,
    this.status = BehaviorStatus.active,
    this.targetSessionsPerWeek = 5,
    this.createdAt,
    this.masteredAt,
  });

  final String id;
  final String ownerId;
  final String catId;
  final String title;
  final GuideCategory category;
  final String? guideId;
  final BehaviorStatus status;
  final int targetSessionsPerWeek;
  final DateTime? createdAt;
  final DateTime? masteredAt;

  factory BehaviorGoal.fromMap(String id, Map<String, dynamic> m) =>
      BehaviorGoal(
        id: id,
        ownerId: (m['ownerId'] ?? '') as String,
        catId: (m['catId'] ?? '') as String,
        title: (m['title'] ?? '') as String,
        category: GuideCategoryX.parse(m['category'] as String?),
        guideId: m['guideId'] as String?,
        status: BehaviorStatus.values.firstWhere(
          (s) => s.name == m['status'],
          orElse: () => BehaviorStatus.active,
        ),
        targetSessionsPerWeek: _toInt(m['targetSessionsPerWeek'], 5),
        createdAt: m['createdAt'] == null ? null : _toDate(m['createdAt']),
        masteredAt: m['masteredAt'] == null ? null : _toDate(m['masteredAt']),
      );

  Map<String, dynamic> toMap() => {
        'ownerId': ownerId,
        'catId': catId,
        'title': title,
        'category': category.name,
        'guideId': guideId,
        'status': status.name,
        'targetSessionsPerWeek': targetSessionsPerWeek,
        'createdAt': createdAt ?? FieldValue.serverTimestamp(),
        'masteredAt': masteredAt,
      };
}

class TrainingSession {
  const TrainingSession({
    required this.id,
    required this.ownerId,
    required this.behaviorId,
    required this.catId,
    required this.date,
    required this.successRating,
    this.durationMinutes = 5,
    this.notes = '',
    this.reward = '',
    this.videoId,
  });

  final String id;
  final String ownerId;
  final String behaviorId;
  final String catId;
  final DateTime date;
  final int successRating; // 1..5
  final int durationMinutes;
  final String notes;
  final String reward;
  final String? videoId;

  factory TrainingSession.fromMap(String id, Map<String, dynamic> m) =>
      TrainingSession(
        id: id,
        ownerId: (m['ownerId'] ?? '') as String,
        behaviorId: (m['behaviorId'] ?? '') as String,
        catId: (m['catId'] ?? '') as String,
        date: _toDate(m['date']),
        successRating: _toInt(m['successRating'], 3),
        durationMinutes: _toInt(m['durationMinutes'], 5),
        notes: (m['notes'] ?? '') as String,
        reward: (m['reward'] ?? '') as String,
        videoId: m['videoId'] as String?,
      );

  Map<String, dynamic> toMap() => {
        'ownerId': ownerId,
        'behaviorId': behaviorId,
        'catId': catId,
        'date': Timestamp.fromDate(date),
        'successRating': successRating,
        'durationMinutes': durationMinutes,
        'notes': notes,
        'reward': reward,
        'videoId': videoId,
      };
}

class TrainingVideo {
  const TrainingVideo({
    required this.id,
    required this.ownerId,
    required this.storagePath,
    required this.downloadUrl,
    required this.createdAt,
    this.catId,
    this.behaviorId,
    this.caption = '',
    this.thumbnailUrl,
    this.sizeBytes = 0,
  });

  final String id;
  final String ownerId;
  final String storagePath;
  final String downloadUrl;
  final DateTime createdAt;
  final String? catId;
  final String? behaviorId;
  final String caption;
  final String? thumbnailUrl;
  final int sizeBytes;

  factory TrainingVideo.fromMap(String id, Map<String, dynamic> m) =>
      TrainingVideo(
        id: id,
        ownerId: (m['ownerId'] ?? '') as String,
        storagePath: (m['storagePath'] ?? '') as String,
        downloadUrl: (m['downloadUrl'] ?? '') as String,
        createdAt: _toDate(m['createdAt']),
        catId: m['catId'] as String?,
        behaviorId: m['behaviorId'] as String?,
        caption: (m['caption'] ?? '') as String,
        thumbnailUrl: m['thumbnailUrl'] as String?,
        sizeBytes: _toInt(m['sizeBytes']),
      );

  Map<String, dynamic> toMap() => {
        'ownerId': ownerId,
        'storagePath': storagePath,
        'downloadUrl': downloadUrl,
        'createdAt': Timestamp.fromDate(createdAt),
        'catId': catId,
        'behaviorId': behaviorId,
        'caption': caption,
        'thumbnailUrl': thumbnailUrl,
        'sizeBytes': sizeBytes,
      };
}

// ---------------------------------------------------------------------------
// Experts
// ---------------------------------------------------------------------------

class Expert {
  const Expert({
    required this.id,
    required this.name,
    required this.credentials,
    required this.bio,
    required this.specialties,
    required this.ratePerSessionCents,
    this.photoUrl,
    this.languages = const ['en'],
    this.rating = 5.0,
    this.reviewCount = 0,
  });

  final String id;
  final String name;
  final String credentials;
  final String bio;
  final List<String> specialties;
  final int ratePerSessionCents;
  final String? photoUrl;
  final List<String> languages;
  final double rating;
  final int reviewCount;

  factory Expert.fromMap(String id, Map<String, dynamic> m) => Expert(
        id: id,
        name: (m['name'] ?? '') as String,
        credentials: (m['credentials'] ?? '') as String,
        bio: (m['bio'] ?? '') as String,
        specialties: _toStringList(m['specialties']),
        ratePerSessionCents: _toInt(m['ratePerSessionCents']),
        photoUrl: m['photoUrl'] as String?,
        languages: _toStringList(m['languages']),
        rating: _toDouble(m['rating'], 5),
        reviewCount: _toInt(m['reviewCount']),
      );
}

enum ConsultationStatus { requested, scheduled, completed, cancelled }

class Consultation {
  const Consultation({
    required this.id,
    required this.userId,
    required this.expertId,
    required this.expertName,
    required this.question,
    required this.createdAt,
    this.catId,
    this.status = ConsultationStatus.requested,
    this.scheduledAt,
    this.lastMessage = '',
  });

  final String id;
  final String userId;
  final String expertId;
  final String expertName;
  final String question;
  final DateTime createdAt;
  final String? catId;
  final ConsultationStatus status;
  final DateTime? scheduledAt;
  final String lastMessage;

  factory Consultation.fromMap(String id, Map<String, dynamic> m) =>
      Consultation(
        id: id,
        userId: (m['userId'] ?? '') as String,
        expertId: (m['expertId'] ?? '') as String,
        expertName: (m['expertName'] ?? '') as String,
        question: (m['question'] ?? '') as String,
        createdAt: _toDate(m['createdAt']),
        catId: m['catId'] as String?,
        status: ConsultationStatus.values.firstWhere(
          (s) => s.name == m['status'],
          orElse: () => ConsultationStatus.requested,
        ),
        scheduledAt:
            m['scheduledAt'] == null ? null : _toDate(m['scheduledAt']),
        lastMessage: (m['lastMessage'] ?? '') as String,
      );

  Map<String, dynamic> toMap() => {
        'userId': userId,
        'expertId': expertId,
        'expertName': expertName,
        'question': question,
        'createdAt': Timestamp.fromDate(createdAt),
        'catId': catId,
        'status': status.name,
        'scheduledAt':
            scheduledAt == null ? null : Timestamp.fromDate(scheduledAt!),
        'lastMessage': lastMessage,
      };
}

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.senderId,
    required this.text,
    required this.sentAt,
  });

  final String id;
  final String senderId;
  final String text;
  final DateTime sentAt;

  factory ChatMessage.fromMap(String id, Map<String, dynamic> m) => ChatMessage(
        id: id,
        senderId: (m['senderId'] ?? '') as String,
        text: (m['text'] ?? '') as String,
        sentAt: _toDate(m['sentAt']),
      );

  Map<String, dynamic> toMap() => {
        'senderId': senderId,
        'text': text,
        'sentAt': Timestamp.fromDate(sentAt),
      };
}

// ---------------------------------------------------------------------------
// Community: forum + social feed
// ---------------------------------------------------------------------------

enum PostType { tip, successStory, question, update }

class CommunityPost {
  const CommunityPost({
    required this.id,
    required this.authorId,
    required this.authorName,
    required this.type,
    required this.title,
    required this.body,
    required this.createdAt,
    this.mediaUrl,
    this.likeCount = 0,
    this.commentCount = 0,
    this.tags = const [],
  });

  final String id;
  final String authorId;
  final String authorName;
  final PostType type;
  final String title;
  final String body;
  final DateTime createdAt;
  final String? mediaUrl;
  final int likeCount;
  final int commentCount;
  final List<String> tags;

  factory CommunityPost.fromMap(String id, Map<String, dynamic> m) =>
      CommunityPost(
        id: id,
        authorId: (m['authorId'] ?? '') as String,
        authorName: (m['authorName'] ?? 'Cat friend') as String,
        type: PostType.values.firstWhere(
          (t) => t.name == m['type'],
          orElse: () => PostType.update,
        ),
        title: (m['title'] ?? '') as String,
        body: (m['body'] ?? '') as String,
        createdAt: _toDate(m['createdAt']),
        mediaUrl: m['mediaUrl'] as String?,
        likeCount: _toInt(m['likeCount']),
        commentCount: _toInt(m['commentCount']),
        tags: _toStringList(m['tags']),
      );

  Map<String, dynamic> toMap() => {
        'authorId': authorId,
        'authorName': authorName,
        'type': type.name,
        'title': title,
        'body': body,
        'createdAt': Timestamp.fromDate(createdAt),
        'mediaUrl': mediaUrl,
        'likeCount': likeCount,
        'commentCount': commentCount,
        'tags': tags,
      };
}

class PostComment {
  const PostComment({
    required this.id,
    required this.authorId,
    required this.authorName,
    required this.body,
    required this.createdAt,
  });

  final String id;
  final String authorId;
  final String authorName;
  final String body;
  final DateTime createdAt;

  factory PostComment.fromMap(String id, Map<String, dynamic> m) => PostComment(
        id: id,
        authorId: (m['authorId'] ?? '') as String,
        authorName: (m['authorName'] ?? 'Cat friend') as String,
        body: (m['body'] ?? '') as String,
        createdAt: _toDate(m['createdAt']),
      );

  Map<String, dynamic> toMap() => {
        'authorId': authorId,
        'authorName': authorName,
        'body': body,
        'createdAt': Timestamp.fromDate(createdAt),
      };
}

// ---------------------------------------------------------------------------
// Giving: beneficiaries, donations & transparent impact tracking
// ---------------------------------------------------------------------------

enum CharityType { shelter, rescue, vetClinic }

class Charity {
  const Charity({
    required this.id,
    required this.name,
    required this.type,
    required this.location,
    required this.description,
    this.imageUrl,
    this.verified = true,
    this.totalReceivedCents = 0,
    this.donorCount = 0,
    this.catsHelped = 0,
  });

  final String id;
  final String name;
  final CharityType type;
  final String location;
  final String description;
  final String? imageUrl;
  final bool verified;
  final int totalReceivedCents;
  final int donorCount;
  final int catsHelped;

  factory Charity.fromMap(String id, Map<String, dynamic> m) => Charity(
        id: id,
        name: (m['name'] ?? '') as String,
        type: CharityType.values.firstWhere(
          (t) => t.name == m['type'],
          orElse: () => CharityType.shelter,
        ),
        location: (m['location'] ?? '') as String,
        description: (m['description'] ?? '') as String,
        imageUrl: m['imageUrl'] as String?,
        verified: (m['verified'] ?? false) as bool,
        totalReceivedCents: _toInt(m['totalReceivedCents']),
        donorCount: _toInt(m['donorCount']),
        catsHelped: _toInt(m['catsHelped']),
      );
}

enum DonationStatus { pending, succeeded, failed, refunded }

class Donation {
  const Donation({
    required this.id,
    required this.userId,
    required this.charityId,
    required this.charityName,
    required this.amountCents,
    required this.feeCents,
    required this.netCents,
    required this.currency,
    required this.status,
    required this.createdAt,
    this.stripePaymentIntentId,
    this.source = 'one_time',
  });

  final String id;
  final String userId;
  final String charityId;
  final String charityName;
  final int amountCents;
  final int feeCents;
  final int netCents;
  final String currency;
  final DonationStatus status;
  final DateTime createdAt;
  final String? stripePaymentIntentId;
  final String source; // one_time | subscription | marketplace

  factory Donation.fromMap(String id, Map<String, dynamic> m) => Donation(
        id: id,
        userId: (m['userId'] ?? '') as String,
        charityId: (m['charityId'] ?? '') as String,
        charityName: (m['charityName'] ?? '') as String,
        amountCents: _toInt(m['amountCents']),
        feeCents: _toInt(m['feeCents']),
        netCents: _toInt(m['netCents']),
        currency: (m['currency'] ?? 'usd') as String,
        status: DonationStatus.values.firstWhere(
          (s) => s.name == m['status'],
          orElse: () => DonationStatus.pending,
        ),
        createdAt: _toDate(m['createdAt']),
        stripePaymentIntentId: m['stripePaymentIntentId'] as String?,
        source: (m['source'] ?? 'one_time') as String,
      );
}

class ImpactUpdate {
  const ImpactUpdate({
    required this.id,
    required this.charityId,
    required this.charityName,
    required this.title,
    required this.body,
    required this.createdAt,
    this.mediaUrl,
    this.amountSpentCents = 0,
    this.catsHelped = 0,
  });

  final String id;
  final String charityId;
  final String charityName;
  final String title;
  final String body;
  final DateTime createdAt;
  final String? mediaUrl;
  final int amountSpentCents;
  final int catsHelped;

  factory ImpactUpdate.fromMap(String id, Map<String, dynamic> m) =>
      ImpactUpdate(
        id: id,
        charityId: (m['charityId'] ?? '') as String,
        charityName: (m['charityName'] ?? '') as String,
        title: (m['title'] ?? '') as String,
        body: (m['body'] ?? '') as String,
        createdAt: _toDate(m['createdAt']),
        mediaUrl: m['mediaUrl'] as String?,
        amountSpentCents: _toInt(m['amountSpentCents']),
        catsHelped: _toInt(m['catsHelped']),
      );
}

// ---------------------------------------------------------------------------
// Monetisation: subscriptions & marketplace
// ---------------------------------------------------------------------------

class SubscriptionPlan {
  const SubscriptionPlan({
    required this.tier,
    required this.name,
    required this.monthlyPriceCents,
    required this.features,
    required this.charityShareBps,
    this.stripePriceId,
  });

  final PremiumTier tier;
  final String name;
  final int monthlyPriceCents;
  final List<String> features;

  /// Share of each subscription payment forwarded to animal charities, in
  /// basis points (e.g. 5000 = 50%).
  final int charityShareBps;
  final String? stripePriceId;

  factory SubscriptionPlan.fromMap(Map<String, dynamic> m) => SubscriptionPlan(
        tier: PremiumTierX.parse(m['tier'] as String?),
        name: (m['name'] ?? '') as String,
        monthlyPriceCents: _toInt(m['monthlyPriceCents']),
        features: _toStringList(m['features']),
        charityShareBps: _toInt(m['charityShareBps']),
        stripePriceId: m['stripePriceId'] as String?,
      );
}

class Product {
  const Product({
    required this.id,
    required this.name,
    required this.description,
    required this.priceCents,
    required this.category,
    this.imageUrl,
    this.stock = 0,
    this.charityShareBps = 2000,
  });

  final String id;
  final String name;
  final String description;
  final int priceCents;
  final String category;
  final String? imageUrl;
  final int stock;
  final int charityShareBps;

  factory Product.fromMap(String id, Map<String, dynamic> m) => Product(
        id: id,
        name: (m['name'] ?? '') as String,
        description: (m['description'] ?? '') as String,
        priceCents: _toInt(m['priceCents']),
        category: (m['category'] ?? 'merch') as String,
        imageUrl: m['imageUrl'] as String?,
        stock: _toInt(m['stock']),
        charityShareBps: _toInt(m['charityShareBps'], 2000),
      );
}

class CartItem {
  const CartItem({required this.product, required this.quantity});
  final Product product;
  final int quantity;
  int get totalCents => product.priceCents * quantity;
  CartItem copyWith({int? quantity}) =>
      CartItem(product: product, quantity: quantity ?? this.quantity);
}

class Order {
  const Order({
    required this.id,
    required this.userId,
    required this.items,
    required this.totalCents,
    required this.status,
    required this.createdAt,
    this.charityId,
  });

  final String id;
  final String userId;
  final List<Map<String, dynamic>> items;
  final int totalCents;
  final String status;
  final DateTime createdAt;
  final String? charityId;

  factory Order.fromMap(String id, Map<String, dynamic> m) => Order(
        id: id,
        userId: (m['userId'] ?? '') as String,
        items: (m['items'] as List? ?? const [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList(),
        totalCents: _toInt(m['totalCents']),
        status: (m['status'] ?? 'pending') as String,
        createdAt: _toDate(m['createdAt']),
        charityId: m['charityId'] as String?,
      );
}

// ---------------------------------------------------------------------------
// Reminders
// ---------------------------------------------------------------------------

class ReminderSettings {
  const ReminderSettings({
    this.enabled = true,
    this.hour = 18,
    this.minute = 0,
    this.weekdays = const {1, 2, 3, 4, 5, 6, 7},
    this.engagementEnabled = true,
  });

  final bool enabled;
  final int hour;
  final int minute;

  /// ISO weekdays: 1 = Monday … 7 = Sunday.
  final Set<int> weekdays;

  /// Opt-in for engagement / community push notifications (FCM topic).
  final bool engagementEnabled;

  ReminderSettings copyWith({
    bool? enabled,
    int? hour,
    int? minute,
    Set<int>? weekdays,
    bool? engagementEnabled,
  }) =>
      ReminderSettings(
        enabled: enabled ?? this.enabled,
        hour: hour ?? this.hour,
        minute: minute ?? this.minute,
        weekdays: weekdays ?? this.weekdays,
        engagementEnabled: engagementEnabled ?? this.engagementEnabled,
      );

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'hour': hour,
        'minute': minute,
        'weekdays': weekdays.toList(),
        'engagementEnabled': engagementEnabled,
      };

  factory ReminderSettings.fromJson(Map<String, dynamic> m) => ReminderSettings(
        enabled: (m['enabled'] ?? true) as bool,
        hour: _toInt(m['hour'], 18),
        minute: _toInt(m['minute'], 0),
        weekdays: (m['weekdays'] as List? ?? const [1, 2, 3, 4, 5, 6, 7])
            .map((e) => _toInt(e))
            .toSet(),
        engagementEnabled: (m['engagementEnabled'] ?? true) as bool,
      );
}
