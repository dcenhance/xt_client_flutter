import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xtream_player/main.dart';
import 'package:xtream_player/screens/home_screen.dart';
import 'package:xtream_player/store.dart';
import 'package:xtream_player/widgets/layout_picker.dart';

/// Every shell has to render on every platform pick — the setting is not tied
/// to the OS, so all four must build from the same state.
void main() {
  for (final style in LayoutStyle.values) {
    testWidgets('the ${style.name} shell builds', (tester) async {
      appState.layout = style;
      await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
      await tester.pump(const Duration(milliseconds: 100));

      expect(tester.takeException(), isNull);
      // Each shell offers a way to the account/settings.
      expect(
        find.byTooltip('Account & settings').evaluate().isNotEmpty ||
            find.byIcon(Icons.settings_outlined).evaluate().isNotEmpty,
        isTrue,
      );
    });
  }

  for (final style in LayoutStyle.values) {
    testWidgets('the ${style.name} shell fits a 320 dp phone', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      appState.layout = style;
      await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull);
    });
  }

  for (final style in [LayoutStyle.showcase, LayoutStyle.cinema]) {
    testWidgets('${style.name} compact search opens a real field', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      appState.layout = style;
      await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
      await tester.tap(find.byTooltip('Search'));
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.byType(TextField), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'nature');
      expect(appState.search, 'nature');
      await tester.tap(find.text('Done'));
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.byType(AlertDialog), findsNothing);
      appState.setSearch('');
    });
  }

  test('layout and theme choices are separate and persisted by name', () async {
    final state = AppState();
    await state.setTheme('oled');
    await state.setLayout(LayoutStyle.showcase);
    expect(state.themeId, 'oled');
    expect(state.layout, LayoutStyle.showcase);
    // Defaults are the golden palette and the classic shell.
    expect(AppState().themeId, 'oled');
    expect(AppState().layout, LayoutStyle.classic);
  });

  testWidgets('Guide is removed; a saved Guide selection opens Classic', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'layout': 'guide'});
    addTearDown(() => SharedPreferences.setMockInitialValues({}));
    final state = AppState();
    await state.init();
    expect(
      LayoutStyle.values.map((style) => style.name),
      isNot(contains('guide')),
    );
    expect(state.layout, LayoutStyle.classic);
    expect(
      (await SharedPreferences.getInstance()).getString('layout'),
      'classic',
    );
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: LayoutPicker())),
    );
    expect(find.text('Guide'), findsNothing);
    expect(find.text('Cinema'), findsOneWidget);
  });
}
