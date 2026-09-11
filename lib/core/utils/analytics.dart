import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../services/repositories.dart';
import 'formatting.dart';

/// Pure, testable progress analytics derived from training sessions.
class ProgressStats {
  const ProgressStats({
    required this.streakDays,
    required this.sessionsThisWeek,
    required this.successRate,
    required this.activeGoals,
    required this.masteredGoals,
    required this.trend,
    required this.byCategory,
    required this.trainedToday,
    required this.totalMinutes,
  });

  final int streakDays;
  final int sessionsThisWeek;

  /// 0..1 – share of sessions rated 4 or 5 over the last 30 days.
  final double successRate;
  final int activeGoals;
  final int masteredGoals;

  /// Average rating per day for the last 14 days (oldest first). `null` for
  /// days without sessions.
  final List<double?> trend;

  /// Average rating per category, only categories with data.
  final Map<GuideCategory, double> byCategory;
  final bool trainedToday;
  final int totalMinutes;

  static const empty = ProgressStats(
    streakDays: 0,
    sessionsThisWeek: 0,
    successRate: 0,
    activeGoals: 0,
    masteredGoals: 0,
    trend: [],
    byCategory: {},
    trainedToday: false,
    totalMinutes: 0,
  );

  static ProgressStats compute({
    required List<TrainingSession> sessions,
    required List<BehaviorGoal> goals,
    DateTime? now,
  }) {
    final today = dateOnly(now ?? DateTime.now());

    // Streak: consecutive days (ending today or yesterday) with >=1 session.
    final days = sessions.map((s) => dateOnly(s.date)).toSet();
    var streak = 0;
    var cursor =
        days.contains(today) ? today : today.subtract(const Duration(days: 1));
    while (days.contains(cursor)) {
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }

    final weekStart = today.subtract(Duration(days: today.weekday - 1));
    final thisWeek =
        sessions.where((s) => !dateOnly(s.date).isBefore(weekStart));

    final last30 = sessions.where(
      (s) => s.date.isAfter(today.subtract(const Duration(days: 30))),
    );
    final last30Count = last30.length;
    final successes = last30.where((s) => s.successRating >= 4).length;

    final trend = List<double?>.generate(14, (i) {
      final day = today.subtract(Duration(days: 13 - i));
      final ratings = sessions
          .where((s) => isSameDay(s.date, day))
          .map((s) => s.successRating)
          .toList();
      if (ratings.isEmpty) return null;
      return ratings.reduce((a, b) => a + b) / ratings.length;
    });

    final goalById = {for (final g in goals) g.id: g};
    final sums = <GuideCategory, List<int>>{};
    for (final s in sessions) {
      final goal = goalById[s.behaviorId];
      if (goal == null) continue;
      sums.putIfAbsent(goal.category, () => []).add(s.successRating);
    }
    final byCategory = {
      for (final e in sums.entries)
        e.key: e.value.reduce((a, b) => a + b) / e.value.length,
    };

    return ProgressStats(
      streakDays: streak,
      sessionsThisWeek: thisWeek.length,
      successRate: last30Count == 0 ? 0 : successes / last30Count,
      activeGoals: goals.where((g) => g.status == BehaviorStatus.active).length,
      masteredGoals:
          goals.where((g) => g.status == BehaviorStatus.mastered).length,
      trend: trend,
      byCategory: byCategory,
      trainedToday: days.contains(today),
      totalMinutes: sessions.fold(0, (sum, s) => sum + s.durationMinutes),
    );
  }

  /// Sessions + average rating for a single goal.
  static ({int count, double avg, int lastWeek}) forGoal(
    List<TrainingSession> sessions,
    String goalId,
  ) {
    final mine = sessions.where((s) => s.behaviorId == goalId).toList();
    if (mine.isEmpty) return (count: 0, avg: 0, lastWeek: 0);
    final weekAgo = DateTime.now().subtract(const Duration(days: 7));
    return (
      count: mine.length,
      avg: mine.map((s) => s.successRating).reduce((a, b) => a + b) /
          mine.length,
      lastWeek: mine.where((s) => s.date.isAfter(weekAgo)).length,
    );
  }
}

/// Realtime: recomputed whenever a session or goal changes in Firestore.
final progressStatsProvider = Provider<ProgressStats>((ref) {
  final sessions = ref.watch(sessionsProvider).valueOrNull ?? const [];
  final goals = ref.watch(goalsProvider).valueOrNull ?? const [];
  if (sessions.isEmpty && goals.isEmpty) return ProgressStats.empty;
  return ProgressStats.compute(sessions: sessions, goals: goals);
});
