import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xtream_player/main.dart';
import 'package:xtream_player/models.dart';
import 'package:xtream_player/screens/home_screen.dart';
import 'package:xtream_player/store.dart';
import 'package:xtream_player/theme.dart';
import 'package:xtream_player/widgets/focus_ring.dart';

void main() {
  tearDown(() {
    appState.categories = const [];
    appState.items = const [];
    appState.username = '';
    appState.server = '';
    appState.setSearch('');
  });

  testWidgets('dashboard Back restores the invoking section focus', (
    tester,
  ) async {
    appState.layout = LayoutStyle.dashboard;
    await tester.pumpWidget(
      const MaterialApp(home: AppShortcuts(child: HomeScreen())),
    );
    await tester.tap(find.text('Movies').first);
    await tester.pump();
    expect(find.byTooltip('Back to sections'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(find.byTooltip('Back to sections'), findsNothing);
    expect(FocusManager.instance.primaryFocus?.debugLabel, 'dashboard-movies');
  });

  testWidgets('Showcase exposes sparse and uncategorized titles', (
    tester,
  ) async {
    appState.layout = LayoutStyle.showcase;
    appState.categories = [Category(id: 'one', name: 'Short shelf')];
    appState.items = [
      StreamItem(id: '1', name: 'Only movie', kind: 'movie', categoryId: 'one'),
      StreamItem(id: '2', name: 'Outside category', kind: 'movie'),
    ];
    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
    expect(find.text('Short shelf'), findsOneWidget);
    expect(find.text('Only movie'), findsWidgets);
    expect(find.text('Other'), findsOneWidget);
    expect(find.text('Outside category'), findsOneWidget);
  });

  for (final width in [320.0, 360.0, 1280.0]) {
    testWidgets('Showcase banner scrolls away at ${width.toInt()} dp', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, width >= 900 ? 720 : 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      appState.layout = LayoutStyle.showcase;
      appState.tab = ContentTab.movies;
      appState.categories = [
        for (var i = 0; i < 5; i++) Category(id: '$i', name: 'Shelf $i'),
      ];
      appState.items = [
        for (var i = 0; i < 5; i++)
          StreamItem(
            id: '$i',
            name: 'Film $i',
            kind: 'movie',
            categoryId: '$i',
          ),
      ];
      await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
      expect(find.text('FEATURED'), findsOneWidget);
      final navTop = tester.getTopLeft(find.byTooltip('Account & settings')).dy;
      await tester.drag(find.byType(ListView).first, const Offset(0, -550));
      await tester.pumpAndSettle();
      final banner = find.text('FEATURED');
      expect(
        banner.evaluate().isEmpty || tester.getTopLeft(banner).dy < 0,
        isTrue,
        reason: 'The banner must leave the viewport rather than stay above the scrolling shelves',
      );
      expect(
        tester.getTopLeft(find.byTooltip('Account & settings')).dy,
        navTop,
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Dashboard leads with content, not account details', (
    tester,
  ) async {
    appState.layout = LayoutStyle.dashboard;
    appState.username = 'private-dashboard-user';
    appState.server = 'https://private-dashboard-server.example';
    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
    expect(find.text('Live TV'), findsWidgets);
    expect(find.text('Movies'), findsWidgets);
    expect(find.text('Series'), findsWidgets);
    expect(find.text('private-dashboard-user'), findsNothing);
    expect(find.text('https://private-dashboard-server.example'), findsNothing);
    expect(find.text('Manage'), findsNothing);
    expect(find.byTooltip('Account & settings'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Dashboard tiles stay compact on a TV-sized screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    appState.layout = LayoutStyle.dashboard;
    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
    final movieTile = find.ancestor(
      of: find.text('Movies').first,
      matching: find.byType(FocusRing),
    );
    expect(movieTile, findsOneWidget);
    expect(tester.getSize(movieTile).height, lessThan(280));
    expect(tester.takeException(), isNull);
  });

  for (final width in [320.0, 1280.0]) {
    testWidgets(
      'Cinema scrolls from hero into every shelf at ${width.toInt()} dp',
      (tester) async {
        tester.view.physicalSize = Size(width, width >= 900 ? 720 : 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        appState.layout = LayoutStyle.cinema;
        appState.tab = ContentTab.movies;
        appState.categories = [
          for (var i = 0; i < 5; i++) Category(id: '$i', name: 'Shelf $i'),
        ];
        appState.items = [
          for (var i = 0; i < 5; i++)
            StreamItem(
              id: '$i',
              name: 'Film $i',
              kind: 'movie',
              categoryId: '$i',
            ),
        ];
        await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
        final navTop = tester
            .getTopLeft(find.byTooltip('Account & settings'))
            .dy;
        final vertical = find.byWidgetPredicate(
          (widget) =>
              widget is Scrollable &&
              widget.axisDirection == AxisDirection.down,
        );
        expect(vertical, findsOneWidget);
        await tester.scrollUntilVisible(
          find.text('Shelf 4'),
          400,
          scrollable: vertical,
          maxScrolls: 12,
        );
        expect(find.text('Shelf 4'), findsOneWidget);
        expect(
          tester.getTopLeft(find.byTooltip('Account & settings')).dy,
          navTop,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  test('palette IDs are unique', () {
    expect(kPalettes.map((p) => p.id).toSet().length, kPalettes.length);
  });
}
