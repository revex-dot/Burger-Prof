import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawsitive_cat/core/models/models.dart';
import 'package:pawsitive_cat/core/services/payment_service.dart';

void main() {
  group('PremiumTier', () {
    test('parses known and unknown values', () {
      expect(PremiumTierX.parse('pro'), PremiumTier.pro);
      expect(PremiumTierX.parse('nonsense'), PremiumTier.free);
      expect(PremiumTierX.parse(null), PremiumTier.free);
      expect(PremiumTier.plus.isPaid, isTrue);
      expect(PremiumTier.free.isPaid, isFalse);
    });
  });

  group('TrainingSession round-trip', () {
    test('toMap/fromMap preserves fields', () {
      final s = TrainingSession(
        id: 's1',
        ownerId: 'u1',
        behaviorId: 'g1',
        catId: 'c1',
        date: DateTime(2026, 1, 2, 3, 4),
        successRating: 4,
        durationMinutes: 7,
        notes: 'good',
        reward: 'tuna',
      );
      final map = s.toMap();
      expect(map['date'], isA<Timestamp>());
      final back = TrainingSession.fromMap('s1', map);
      expect(back.date, s.date);
      expect(back.successRating, 4);
      expect(back.durationMinutes, 7);
      expect(back.notes, 'good');
      expect(back.reward, 'tuna');
    });

    test('fromMap tolerates missing / oddly typed values', () {
      final s = TrainingSession.fromMap('x', {
        'date': '2026-05-01T10:00:00Z',
        'successRating': '5',
      });
      expect(s.date.year, 2026);
      expect(s.successRating, 5);
      expect(s.durationMinutes, 5);
    });
  });

  group('TrainingGuide', () {
    test('parses bundled JSON shape', () {
      final g = TrainingGuide.fromMap({
        'id': 'x',
        'title': 'T',
        'category': 'litter',
        'steps': ['a', 'b'],
        'premium': true,
      });
      expect(g.category, GuideCategory.litter);
      expect(g.steps, ['a', 'b']);
      expect(g.premium, isTrue);
      expect(g.difficulty, 2);
    });
  });

  group('ReminderSettings', () {
    test('json round-trip', () {
      const r = ReminderSettings(hour: 7, minute: 30, weekdays: {1, 3, 5});
      final back = ReminderSettings.fromJson(r.toJson());
      expect(back.hour, 7);
      expect(back.minute, 30);
      expect(back.weekdays, {1, 3, 5});
      expect(back.enabled, isTrue);
    });
  });

  group('Donation fee', () {
    test('5% fee, rounded to the cent', () {
      expect(PaymentService.feeForAmount(1000), 50);
      expect(PaymentService.feeForAmount(999), 50);
      expect(PaymentService.feeForAmount(100), 5);
    });
  });

  group('CartItem', () {
    test('total is price × quantity', () {
      const p = Product(
        id: 'p',
        name: 'n',
        description: '',
        priceCents: 1500,
        category: 'merch',
      );
      expect(const CartItem(product: p, quantity: 3).totalCents, 4500);
    });
  });
}
