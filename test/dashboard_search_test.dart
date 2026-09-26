import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xtream_player/main.dart';
import 'package:xtream_player/models.dart';
import 'package:xtream_player/screens/home_screen.dart';
import 'package:xtream_player/store.dart';

/// The Dashboard overview ("Übersicht") shows section tiles, not a tab list.
/// Its search field is always visible, so a typed query has to produce real
/// results instead of silently changing state nothing reads.
void main() {
  tearDown(() {
    appState.categories = const [];
    appState.items = const [];
    appState.tab = ContentTab.live;
    appState.setSearch('');
    appState.layout = LayoutStyle.classic;
  });

  for (final width in [320.0, 1280.0]) {
    testWidgets('Dashboard search lists matches across sections at $width dp', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      appState.layout = LayoutStyle.dashboard;
      appState.tab = ContentTab.movies;
      appState.items = [
        StreamItem(id: '1', name: 'Nature One', kind: 'movie'),
        StreamItem(id: '2', name: 'Other Film', kind: 'movie'),
      ];
      await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
      await tester.pump();

      // The overview leads with its section tiles.
      expect(find.text('The on-demand library'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'nature');
      await tester.pumpAndSettle();

      expect(find.text('Nature One'), findsWidgets);
      expect(find.text('Other Film'), findsNothing);
      expect(find.text('The on-demand library'), findsNothing);
      expect(find.text('1 of 2 items'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('the query keeps focus while results build', (tester) async {
    appState.layout = LayoutStyle.dashboard;
    appState.items = [StreamItem(id: '1', name: 'Nature One', kind: 'movie')];
    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
    await tester.tap(find.byType(TextField));
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'nat');
    await tester.pumpAndSettle();
    // A result card must not steal the caret mid-query on a TV.
    expect(
      tester.widget<TextField>(find.byType(TextField)).focusNode?.hasFocus,
      isTrue,
    );
  });

  testWidgets('clearing the query brings the section tiles back', (
    tester,
  ) async {
    appState.layout = LayoutStyle.dashboard;
    appState.items = [StreamItem(id: '1', name: 'Nature One', kind: 'movie')];
    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
    await tester.enterText(find.byType(TextField), 'nothing matches this');
    await tester.pumpAndSettle();
    expect(find.text('No titles match this view'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '');
    await tester.pumpAndSettle();
    expect(find.text('The on-demand library'), findsOneWidget);
    expect(find.text('Channels, now and next'), findsOneWidget);
  });

  test('the search spans every loaded section, not just the visible one', () {
    appState.tab = ContentTab.live;
    appState.items = [
      StreamItem(id: '1', name: 'News Live', kind: 'live'),
      StreamItem(id: '2', name: 'Quiet Channel', kind: 'live'),
    ];
    appState.setSearch('news');
    expect(appState.searchMatches.map((i) => i.name), ['News Live']);
    expect(appState.searchableCount, 2);
    appState.setSearch('   ');
    expect(appState.searchMatches, isEmpty);
  });
}
