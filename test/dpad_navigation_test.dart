import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xtream_player/main.dart';
import 'package:xtream_player/models.dart';
import 'package:xtream_player/screens/home_screen.dart';
import 'package:xtream_player/store.dart';
import 'package:xtream_player/widgets/focus_ring.dart';
import 'package:xtream_player/xtream_client.dart';

/// A remote / D-pad has to work with no pointer at all: something must already
/// hold focus when a shell appears, arrows must walk between cards, and the OK
/// button (which arrives as `select`) must activate the focused one.
void main() {
  setUp(() {
    appState.client = XtreamClient(
      server: 'http://127.0.0.1:1',
      username: 'u',
      password: 'p',
    );
    appState.items = [
      StreamItem(id: '1', name: 'Alpha', kind: 'live', categoryId: '1'),
      StreamItem(id: '2', name: 'Bravo', kind: 'live', categoryId: '1'),
      StreamItem(id: '3', name: 'Charlie', kind: 'series', categoryId: '1'),
    ];
    appState.categories = [Category(id: '1', name: 'Group')];
    appState.selectedCategoryId = null;
  });

  for (final style in LayoutStyle.values) {
    testWidgets('${style.name}: focus starts in the content and arrows move it',
        (tester) async {
      appState.layout = style;
      await tester.pumpWidget(const MaterialApp(home: AppShortcuts(child: HomeScreen())));
      await tester.pump(const Duration(milliseconds: 400));

      // Something inside a FocusRing holds focus without any pointer input.
      expect(find.byType(FocusRing, skipOffstage: false).evaluate(), isNotEmpty);
      expect(FocusManager.instance.primaryFocus, isNotNull);

      final before = FocusManager.instance.primaryFocus;
      for (var i = 0; i < 3; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pump(const Duration(milliseconds: 60));
      }
      final afterDown = FocusManager.instance.primaryFocus;
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump(const Duration(milliseconds: 60));
      final afterRight = FocusManager.instance.primaryFocus;

      expect(before != afterDown || before != afterRight, isTrue,
          reason: 'arrow keys must move the focus somewhere');
    });
  }

  testWidgets('the OK button (select) activates the focused card', (tester) async {
    appState.layout = LayoutStyle.classic;
    appState.items = [
      StreamItem(id: '3', name: 'Charlie', kind: 'series', categoryId: '1'),
    ];
    await tester.pumpWidget(const MaterialApp(home: AppShortcuts(child: HomeScreen())));
    await tester.pump(const Duration(milliseconds: 400));

    // A series opens the season sheet — no media playback in tests.
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pump(const Duration(milliseconds: 500));

    // The series sheet appears; without media_kit in tests, its content is the
    // seasons/episodes list rather than a player.
    expect(
      find.textContaining('Season').evaluate().isNotEmpty ||
          find.byType(BottomSheet).evaluate().isNotEmpty,
      isTrue,
      reason: 'select on a series card should open its seasons',
    );
  });

  testWidgets('Back closes what OK opened', (tester) async {
    appState.layout = LayoutStyle.classic;
    appState.items = [
      StreamItem(id: '3', name: 'Charlie', kind: 'series', categoryId: '1'),
    ];
    await tester.pumpWidget(const MaterialApp(home: AppShortcuts(child: HomeScreen())));
    await tester.pump(const Duration(milliseconds: 400));

    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pump(const Duration(milliseconds: 500));
    final opened = find.byType(BottomSheet).evaluate().isNotEmpty ||
        find.textContaining('Season').evaluate().isNotEmpty;
    expect(opened, isTrue, reason: 'OK should open the series sheet');

    // Esc here; goBack/browserBack/gameButtonB are the same intent and have no
    // physical key in Flutter's test simulator, so they are covered by the
    // mapping test below instead.
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump(const Duration(milliseconds: 700));
    expect(find.byType(BottomSheet).evaluate(), isEmpty,
        reason: 'Back should dismiss it again');
  });

  test('the app maps the remote keys: OK, A, Back, B, Esc', () {
    final widget = AppShortcuts(child: const SizedBox()).build(_FakeBuildContext());
    final triggers = (widget as Shortcuts)
        .shortcuts
        .keys
        .whereType<SingleActivator>()
        .map((a) => a.trigger)
        .toSet();

    expect(triggers, containsAll(<LogicalKeyboardKey>[
      LogicalKeyboardKey.select, // DPAD_CENTER / the remote's OK
      LogicalKeyboardKey.gameButtonA,
      LogicalKeyboardKey.goBack,
      LogicalKeyboardKey.browserBack,
      LogicalKeyboardKey.escape,
      LogicalKeyboardKey.gameButtonB,
    ]));
  });
}

/// Just enough context for the structural check above.
class _FakeBuildContext implements BuildContext {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
