import 'package:flutter_test/flutter_test.dart';
import 'package:pawsitive_cat/core/models/models.dart';
import 'package:pawsitive_cat/core/utils/analytics.dart';

TrainingSession _session(String goalId, DateTime date, int rating,
        {int minutes = 5}) =>
    TrainingSession(
      id: '${goalId}_${date.millisecondsSinceEpoch}',
      ownerId: 'u1',
      behaviorId: goalId,
      catId: 'c1',
      date: date,
      successRating: rating,
      durationMinutes: minutes,
    );

BehaviorGoal _goal(String id, GuideCategory category,
        [BehaviorStatus status = BehaviorStatus.active]) =>
    BehaviorGoal(
      id: id,
      ownerId: 'u1',
      catId: 'c1',
      title: id,
      category: category,
      status: status,
    );

void main() {
  final now = DateTime(2026, 9, 11, 15); // Friday

  group('ProgressStats.compute', () {
    test('empty input yields empty stats', () {
      final s = ProgressStats.compute(sessions: [], goals: [], now: now);
      expect(s.streakDays, 0);
      expect(s.sessionsThisWeek, 0);
      expect(s.successRate, 0);
      expect(s.trend.length, 14);
      expect(s.trend.every((v) => v == null), isTrue);
      expect(s.trainedToday, isFalse);
    });

    test('streak counts consecutive days ending today', () {
      final sessions = [
        _session('g1', now, 5),
        _session('g1', now.subtract(const Duration(days: 1)), 4),
        _session('g1', now.subtract(const Duration(days: 2)), 3),
        // gap on day 3
        _session('g1', now.subtract(const Duration(days: 4)), 3),
      ];
      final s = ProgressStats.compute(
        sessions: sessions,
        goals: [_goal('g1', GuideCategory.furniture)],
        now: now,
      );
      expect(s.streakDays, 3);
      expect(s.trainedToday, isTrue);
    });

    test('streak survives a missed today if yesterday was trained', () {
      final sessions = [
        _session('g1', now.subtract(const Duration(days: 1)), 4),
        _session('g1', now.subtract(const Duration(days: 2)), 4),
      ];
      final s = ProgressStats.compute(sessions: sessions, goals: [], now: now);
      expect(s.streakDays, 2);
      expect(s.trainedToday, isFalse);
    });

    test('sessions this week start on Monday', () {
      final monday = DateTime(2026, 9, 7, 9);
      final sunday = DateTime(2026, 9, 6, 9);
      final s = ProgressStats.compute(
        sessions: [
          _session('g1', monday, 4),
          _session('g1', sunday, 4),
          _session('g1', now, 4),
        ],
        goals: [],
        now: now,
      );
      expect(s.sessionsThisWeek, 2);
    });

    test('success rate is share of 4+ ratings in the last 30 days', () {
      final s = ProgressStats.compute(
        sessions: [
          _session('g1', now, 5),
          _session('g1', now.subtract(const Duration(days: 1)), 4),
          _session('g1', now.subtract(const Duration(days: 2)), 2),
          _session('g1', now.subtract(const Duration(days: 3)), 1),
          // outside the 30-day window – ignored
          _session('g1', now.subtract(const Duration(days: 40)), 1),
        ],
        goals: [],
        now: now,
      );
      expect(s.successRate, closeTo(0.5, 0.0001));
    });

    test('goal counters and per-category averages', () {
      final goals = [
        _goal('g1', GuideCategory.furniture),
        _goal('g2', GuideCategory.litter, BehaviorStatus.mastered),
        _goal('g3', GuideCategory.tricks, BehaviorStatus.paused),
      ];
      final s = ProgressStats.compute(
        sessions: [
          _session('g1', now, 5),
          _session('g1', now.subtract(const Duration(days: 1)), 3),
          _session('g2', now, 4),
        ],
        goals: goals,
        now: now,
      );
      expect(s.activeGoals, 1);
      expect(s.masteredGoals, 1);
      expect(s.byCategory[GuideCategory.furniture], closeTo(4.0, 0.0001));
      expect(s.byCategory[GuideCategory.litter], closeTo(4.0, 0.0001));
      expect(s.byCategory.containsKey(GuideCategory.tricks), isFalse);
      expect(s.totalMinutes, 15);
    });

    test('trend has 14 entries, oldest first, today last', () {
      final s = ProgressStats.compute(
        sessions: [
          _session('g1', now, 5),
          _session('g1', now, 3),
          _session('g1', now.subtract(const Duration(days: 13)), 2),
        ],
        goals: [],
        now: now,
      );
      expect(s.trend.length, 14);
      expect(s.trend.last, closeTo(4.0, 0.0001));
      expect(s.trend.first, closeTo(2.0, 0.0001));
      expect(s.trend[7], isNull);
    });
  });

  group('ProgressStats.forGoal', () {
    test('aggregates only the requested goal', () {
      final sessions = [
        _session('g1', now, 5),
        _session('g1', now.subtract(const Duration(days: 10)), 3),
        _session('g2', now, 1),
      ];
      final r = ProgressStats.forGoal(sessions, 'g1');
      expect(r.count, 2);
      expect(r.avg, closeTo(4.0, 0.0001));
      expect(r.lastWeek, 1);
      expect(ProgressStats.forGoal(sessions, 'missing').count, 0);
    });
  });
}
