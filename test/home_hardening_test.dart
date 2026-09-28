import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xtream_player/main.dart';
import 'package:xtream_player/models.dart';
import 'package:xtream_player/screens/home_screen.dart';
import 'package:xtream_player/store.dart';
import 'package:xtream_player/widgets/focus_ring.dart';

void main() {
  setUp(() async {
    await appState.logout();
    appState.setSearch('');
    appState.tab = ContentTab.movies;
    appState.items = [
      StreamItem(id: 'other', name: 'Other Film', kind: 'movie'),
      StreamItem(id: 'nature', name: 'Nature Movie', kind: 'movie'),
    ];
  });
  tearDown(() async {
    await appState.logout();
    appState.setSearch('');
    appState.layout = LayoutStyle.classic;
  });

  testWidgets(
    'Dashboard section entry focuses an actionable result, not the shell',
    (tester) async {
      appState.layout = LayoutStyle.dashboard;
      await tester.pumpWidget(
        const MaterialApp(home: AppShortcuts(child: HomeScreen())),
      );
      await tester.tap(find.text('Movies').first);
      await tester.pump();
      // A panel can deliver its catalogue after the section is entered.
      appState.items = [
        StreamItem(id: 'other', name: 'Other Film', kind: 'movie'),
        StreamItem(id: 'nature', name: 'Nature Movie', kind: 'movie'),
      ];
      appState.notifyListeners();
      await tester.pump();
      expect(find.text('Other Film'), findsWidgets);
      expect(
        FocusManager.instance.primaryFocus?.debugLabel,
        isNot('dashboard-section'),
      );
      final card = find
          .ancestor(
            of: find.text('Other Film').last,
            matching: find.byType(FocusRing),
          )
          .first;
      expect(Focus.of(tester.element(card)).hasFocus, isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(
        FocusManager.instance.primaryFocus?.debugLabel,
        'dashboard-movies',
      );
    },
  );

  testWidgets(
    'Dashboard search arrow traversal skips the non-actionable shell',
    (tester) async {
      appState.layout = LayoutStyle.dashboard;
      await tester.pumpWidget(
        const MaterialApp(home: AppShortcuts(child: HomeScreen())),
      );
      await tester.enterText(find.byType(TextField), 'nature');
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(
        FocusManager.instance.primaryFocus?.debugLabel,
        isNot('dashboard-section'),
      );
      final card = find
          .ancestor(
            of: find.text('Nature Movie').last,
            matching: find.byType(FocusRing),
          )
          .first;
      expect(Focus.of(tester.element(card)).hasFocus, isTrue);
    },
  );

  testWidgets('Showcase hero respects the current search', (tester) async {
    appState.layout = LayoutStyle.showcase;
    appState.setSearch('nature');
    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
    expect(find.text('Nature Movie'), findsWidgets);
    expect(find.text('Other Film'), findsNothing);
  });

  testWidgets('compact Sidebar guest mode fits a 320 dp phone', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    appState.layout = LayoutStyle.sidebar;
    appState.guest = true;
    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  for (final layout in [LayoutStyle.showcase, LayoutStyle.cinema]) {
    testWidgets('${layout.name} icon-only navigation names its buttons', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final semantics = tester.ensureSemantics();
      try {
        appState.layout = layout;
        await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
        expect(find.bySemanticsLabel('Movies'), findsWidgets);
        expect(find.bySemanticsLabel('Series'), findsWidgets);
      } finally {
        semantics.dispose();
      }
    });
  }

  for (final layout in [LayoutStyle.dashboard, LayoutStyle.masterDetail]) {
    testWidgets('${layout.name} fits a 320 dp phone with 2x text', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      appState.layout = layout;
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: const HomeScreen(),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  }
}
