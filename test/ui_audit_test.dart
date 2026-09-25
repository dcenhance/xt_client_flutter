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

  testWidgets('Guide reaches channel 121 and uncategorized channels', (
    tester,
  ) async {
    appState.layout = LayoutStyle.guide;
    appState.categories = [Category(id: 'long', name: 'Long list')];
    appState.items = [
      for (var i = 1; i <= 121; i++)
        StreamItem(
          id: '$i',
          name: 'Channel $i',
          kind: 'live',
          categoryId: 'long',
        ),
      StreamItem(id: 'orphan', name: 'Orphan channel', kind: 'live'),
    ];
    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
    expect(find.textContaining('122 channels'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Channel 121'),
      450,
      scrollable: find.byType(Scrollable).last,
      maxScrolls: 70,
    );
    expect(find.text('Channel 121'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Orphan channel'),
      300,
      scrollable: find.byType(Scrollable).last,
      maxScrolls: 12,
    );
    expect(find.text('Orphan channel'), findsOneWidget);
  });

  test('palette IDs are unique', () {
    expect(kPalettes.map((p) => p.id).toSet().length, kPalettes.length);
  });
}
