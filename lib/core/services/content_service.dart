import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';

/// Training guides ship inside the app bundle so the whole "Learn" library is
/// available offline. Remote updates could be layered on top via Firestore.
final guidesProvider = FutureProvider<List<TrainingGuide>>((ref) async {
  final raw = await rootBundle.loadString('assets/content/guides.json');
  final list = jsonDecode(raw) as List;
  return list
      .map((e) => TrainingGuide.fromMap(Map<String, dynamic>.from(e as Map)))
      .toList();
});

final guideByIdProvider = Provider.family<TrainingGuide?, String>((ref, id) {
  final guides = ref.watch(guidesProvider).valueOrNull ?? const [];
  for (final g in guides) {
    if (g.id == id) return g;
  }
  return null;
});

final dailyTipsProvider = FutureProvider<List<String>>((ref) async {
  final raw = await rootBundle.loadString('assets/content/tips.json');
  return (jsonDecode(raw) as List).map((e) => e.toString()).toList();
});

/// Deterministic "tip of the day".
final tipOfTheDayProvider = Provider<String?>((ref) {
  final tips = ref.watch(dailyTipsProvider).valueOrNull;
  if (tips == null || tips.isEmpty) return null;
  final dayIndex = DateTime.now().difference(DateTime(2024)).inDays;
  return tips[dayIndex % tips.length];
});
