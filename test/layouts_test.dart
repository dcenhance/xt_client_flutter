import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xtream_player/main.dart';
import 'package:xtream_player/screens/home_screen.dart';
import 'package:xtream_player/store.dart';

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
      expect(find.byTooltip('Account & settings').evaluate().isNotEmpty ||
          find.byIcon(Icons.settings_outlined).evaluate().isNotEmpty, isTrue);
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
}
