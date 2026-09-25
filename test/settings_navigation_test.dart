import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xtream_player/screens/settings_sheet.dart';

void main() {
  testWidgets('Account tab reload stays in the tab, not pop the route', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: SettingsPage())),
    );
    final reload = find.text('Reload content');
    await tester.ensureVisible(reload);
    await tester.pump();
    await tester.tap(reload);
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.byType(SettingsPage), findsOneWidget);
  });
}
