import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xtream_player/l10n.dart';
import 'package:xtream_player/l10n_catalog.dart';
import 'package:xtream_player/main.dart';
import 'package:xtream_player/store.dart';
import 'package:xtream_player/widgets/language_picker.dart';

List<String> placeholders(String input) =>
    (RegExp(r'\{[a-zA-Z]\w*\}')
        .allMatches(input)
        .map((match) => match.group(0)!)
        .toList()
      ..sort());

void main() {
  test('all archive app languages have complete in-app messages', () {
    final source = (jsonDecode(
      File('lib/l10n/en.json').readAsStringSync(),
    ) as Map<String, dynamic>).keys.toSet();
    expect(supportedLanguageTags.length, 21);
    expect(languageNames.keys.toSet(), supportedLanguageTags.toSet());
    expect(supportedAppLocales.length, 21);
    final androidLocales = RegExp(r'<locale android:name="([^"]+)"')
        .allMatches(
          File('android/app/src/main/res/xml/locales_config.xml')
              .readAsStringSync(),
        )
        .map((match) => match.group(1)!)
        .toList();
    expect(androidLocales, supportedLanguageTags);
    expect(
      localizedCatalog.keys.toSet(),
      supportedLanguageTags.skip(1).toSet(),
    );
    for (final tag in supportedLanguageTags.skip(1)) {
      final translated = (jsonDecode(
        File('lib/l10n/$tag.json').readAsStringSync(),
      ) as Map<String, dynamic>);
      expect(translated.keys.toSet(), source, reason: tag);
      expect(localizedCatalog[tag]!.keys.toSet(), source, reason: tag);
      for (final key in source) {
        final value = translated[key] as String;
        expect(value.trim(), isNotEmpty, reason: '$tag: $key');
        expect(placeholders(value), placeholders(key), reason: '$tag: $key');
        expect(localizedCatalog[tag]![key], value, reason: '$tag: $key');
      }
    }
  });

  test('Traditional Chinese matches regional device locales', () {
    expect(languageTagFor(const Locale('zh', 'TW')), 'zh-Hant');
    expect(languageTagFor(const Locale('zh', 'HK')), 'zh-Hant');
    expect(languageTagFor(const Locale('zh', 'MO')), 'zh-Hant');
    expect(languageTagFor(const Locale('zh', 'CN')), 'zh');
    expect(languageTagFor(const Locale('xx')), 'en');
  });

  testWidgets('context translations follow selected language and parameters', (
    tester,
  ) async {
    preferredLanguageTag = 'de';
    addTearDown(() => preferredLanguageTag = '');
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('de'),
        supportedLocales: supportedAppLocales,
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Builder(builder: (context) => Text(tr(context, 'Language'))),
      ),
    );
    final expected = localizedCatalog['de']!['Language'];
    expect(find.text(expected!), findsOneWidget);
  });

  test(
    'language selection persists, unsupported values fall back to the system',
    () async {
      SharedPreferences.setMockInitialValues({});
      addTearDown(() {
        SharedPreferences.setMockInitialValues({});
        preferredLanguageTag = '';
      });
      final state = AppState();
      await state.init();
      await state.setLanguageTag('ar');
      expect(
        (await SharedPreferences.getInstance()).getString('language_tag'),
        'ar',
      );
      final restored = AppState();
      await restored.init();
      expect(restored.languageTag, 'ar');
      await restored.setLanguageTag('invalid');
      expect(restored.languageTag, 'ar');
      await restored.setLanguageTag('');
      expect(restored.languageTag, '');
    },
  );

  for (final width in [320.0, 1280.0]) {
    testWidgets('scrollable language picker works at $width dp', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      await appState.init();
      await appState.setLanguageTag('');
      addTearDown(() {
        appState.setLanguageTag('');
        tester.view.reset();
      });
      tester.view.physicalSize = Size(width, 720);
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListenableBuilder(
              listenable: appState,
              builder: (_, _) => const LanguagePicker(),
            ),
          ),
        ),
      );
      await tester.tap(find.text('System default'));
      await tester.pumpAndSettle();
      expect(find.byType(ListView), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Deutsch'));
      await tester.pumpAndSettle();
      expect(appState.languageTag, 'de');
      expect(find.text('Deutsch'), findsOneWidget);
    });
  }

  for (final tag in supportedLanguageTags) {
    testWidgets('login fits at 320 dp in $tag', (tester) async {
      tester.view.physicalSize = const Size(320, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        preferredLanguageTag = '';
        tester.view.reset();
      });
      await appState.setLanguageTag(tag);
      await tester.pumpWidget(const XtreamPlayerApp());
      await tester.pump(const Duration(milliseconds: 500));
      expect(tester.takeException(), isNull, reason: tag);
      expect(find.byType(Directionality), findsWidgets);
    });
  }
}
