import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawsitive_cat/core/locale/locale_controller.dart';
import 'package:pawsitive_cat/l10n/generated/app_localizations.dart';

void main() {
  test('every supported locale has a localization delegate', () {
    for (final locale in supportedLocales) {
      expect(
        AppLocalizations.delegate.isSupported(locale),
        isTrue,
        reason: '${locale.languageCode} should be supported',
      );
      expect(localeDisplayNames.containsKey(locale.languageCode), isTrue);
    }
  });

  test('plural messages resolve in each locale', () async {
    for (final locale in supportedLocales) {
      final l = await AppLocalizations.delegate.load(locale);
      expect(l.streakDays(0), isNotEmpty);
      expect(l.streakDays(1), isNotEmpty);
      expect(l.streakDays(5), isNotEmpty);
      expect(l.dashboardGreeting('Sam'), contains('Sam'));
      expect(l.charityShare(50), contains('50'));
    }
  });

  testWidgets('localized strings render in a widget tree', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('es'),
        supportedLocales: supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Builder(
          builder: (context) => Text(AppLocalizations.of(context).navLearn),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Aprender'), findsOneWidget);
  });
}
