import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xtream_player/main.dart';
import 'package:xtream_player/screens/login_screen.dart';
import 'package:xtream_player/widgets/focus_ring.dart';
/// The login screen has to be usable with nothing but a remote: a text field
/// normally eats the arrow keys for its caret, which left TV users stuck inside
/// the first field with no way to reach Sign In.
void main() {
  Future<void> pumpLogin(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
      home: MediaQuery(
        data: const MediaQueryData(disableAnimations: true, size: Size(360, 780)),
        child: const AppShortcuts(child: LoginScreen()),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 600));
  }

  Future<void> arrow(WidgetTester tester, LogicalKeyboardKey key,
      {int times = 1}) async {
    for (var i = 0; i < times; i++) {
      await tester.sendKeyEvent(key);
      await tester.pump(const Duration(milliseconds: 90));
    }
  }

  bool usernameHasFocus(WidgetTester tester) =>
      tester.widget<TextField>(find.byType(TextField).at(0)).focusNode!.hasFocus;
  bool passwordHasFocus(WidgetTester tester) =>
      tester.widget<TextField>(find.byType(TextField).at(1)).focusNode!.hasFocus;

  /// Whatever holds the focus right now, in the terms this screen cares about.
  String focusedKind() {
    final ctx = FocusManager.instance.primaryFocus?.context;
    if (ctx == null) return '<none>';
    if (ctx.findAncestorWidgetOfExactType<TextField>() != null) return 'field';
    if (ctx.findAncestorWidgetOfExactType<FocusRing>() != null) return 'ring';
    return ctx.widget.runtimeType.toString();
  }

  testWidgets('the screen opens with the first field focused, no pointer needed',
      (tester) async {
    await pumpLogin(tester);
    expect(usernameHasFocus(tester), isTrue,
        reason: 'a remote has to be able to type straight away');
  });

  testWidgets('down walks the form: field, field, remember, sign in, panel',
      (tester) async {
    await pumpLogin(tester);
    expect(usernameHasFocus(tester), isTrue);

    await arrow(tester, LogicalKeyboardKey.arrowDown);
    expect(passwordHasFocus(tester), isTrue,
        reason: 'down out of the username field must reach the password');

    await arrow(tester, LogicalKeyboardKey.arrowDown);
    expect(focusedKind(), 'ring', reason: 'remember me comes next');

    await arrow(tester, LogicalKeyboardKey.arrowDown);
    expect(focusedKind(), isNot('field'),
        reason: 'the sign in button must be reachable');

    await arrow(tester, LogicalKeyboardKey.arrowDown);
    expect(focusedKind(), 'ring', reason: 'the panel row is the last stop');

    await arrow(tester, LogicalKeyboardKey.arrowDown);
    expect(focusedKind(), 'ring', reason: 'and the walk never runs off screen');
  });

  testWidgets('up walks back out of a field the same way', (tester) async {
    await pumpLogin(tester);
    await arrow(tester, LogicalKeyboardKey.arrowDown);
    expect(passwordHasFocus(tester), isTrue);
    await arrow(tester, LogicalKeyboardKey.arrowUp);
    expect(usernameHasFocus(tester), isTrue);
  });

  testWidgets('left and right keep editing inside a field', (tester) async {
    await pumpLogin(tester);
    final field = tester.widget<TextField>(find.byType(TextField).at(0));
    field.controller!.text = 'hello';
    field.controller!.selection = const TextSelection.collapsed(offset: 5);
    await tester.pump();

    // Left/right belong to the caret, at the edges too — that is what a TV
    // keyboard needs; up/down are the way out.
    for (final key in [LogicalKeyboardKey.arrowLeft, LogicalKeyboardKey.arrowRight]) {
      await arrow(tester, key);
      expect(usernameHasFocus(tester), isTrue,
          reason: 'horizontal arrows must not steal the focus from the text');
    }
    field.controller!.selection = const TextSelection.collapsed(offset: 0);
    await tester.pump();
    await arrow(tester, LogicalKeyboardKey.arrowLeft);
    expect(usernameHasFocus(tester), isTrue);

    // And the vertical way out still works with the caret in the middle.
    await arrow(tester, LogicalKeyboardKey.arrowDown);
    expect(passwordHasFocus(tester), isTrue,
        reason: 'down must leave the field even mid-text');
  });

  testWidgets('OK on the panel row opens the list and OK picks a panel',
      (tester) async {
    await pumpLogin(tester);
    await arrow(tester, LogicalKeyboardKey.arrowDown, times: 4);
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pump(const Duration(milliseconds: 700));
    expect(find.text('Select panel'), findsOneWidget,
        reason: 'the remote OK button must open the panel list');

    await arrow(tester, LogicalKeyboardKey.arrowDown, times: 2);
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('Select panel'), findsNothing,
        reason: 'OK must close the dialog with a choice');
    expect(
      tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data)
          .where((d) =>
              d != null && d.startsWith('Panel · ') && d != 'Panel · Automatic')
          .isNotEmpty,
      isTrue,
      reason: 'the chosen panel shows up on the button',
    );
  });

  testWidgets('OK on Sign In starts a sign in attempt', (tester) async {
    await pumpLogin(tester);
    // username -> password -> remember -> sign in
    await arrow(tester, LogicalKeyboardKey.arrowDown, times: 3);
    expect(focusedKind(), isNot('field'));
    expect(FocusManager.instance.primaryFocus?.context, isNotNull);

    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pump(const Duration(milliseconds: 400));
    expect(appState.busy || appState.error != null, isTrue,
        reason: 'OK on Sign In must actually try to sign in');
    await tester.pump(const Duration(seconds: 1));
    appState.error = null;
  });
}
