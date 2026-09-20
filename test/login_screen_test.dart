import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xtream_player/screens/login_screen.dart';

/// Phone-sized surface: the login screen is built for a hand, and the default
/// 800x600 test window pushes the lowest control out of view.
Future<void> pumpLogin(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(MaterialApp(
    home: MediaQuery(
      data: const MediaQueryData(disableAnimations: true, size: Size(360, 780)),
      child: const LoginScreen(),
    ),
  ));
  await tester.pump(const Duration(milliseconds: 600));
}

void main() {
  testWidgets('login is just the mark, name and credentials', (tester) async {
    // Animations off: the login screen has continuous idle motion, so a widget
    // test must not wait for it to settle — and reduced-motion is a real path
    // worth exercising anyway.
    await pumpLogin(tester);

    expect(find.text('Spectre'), findsOneWidget);
    expect(find.byType(TextField), findsNWidgets(2));
    expect(find.text('Username'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Remember me'), findsOneWidget);
    expect(find.text('Sign In'), findsOneWidget);
    // The technical extras stay off this screen.
    expect(find.text('Server address'), findsNothing);
    expect(find.text('Diagnose (DNS + ports)'), findsNothing);
    expect(find.text('Test a list of servers'), findsNothing);
  });

  testWidgets('one Select panel button, defaulting to automatic', (tester) async {
    // Animations off: the login screen has continuous idle motion, so a widget
    // test must not wait for it to settle — and reduced-motion is a real path
    // worth exercising anyway.
    await pumpLogin(tester);

    expect(find.text('Panel · Automatic'), findsOneWidget);

    await tester.tap(find.text('Panel · Automatic'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));

    // The dialog lists the panels the app can try by itself.
    expect(find.text('EUROPE 1'), findsOneWidget);
    expect(find.text('EUROPE 2'), findsOneWidget);
    expect(find.text('TÜRKİYE PANEL 1'), findsOneWidget);
  });

  testWidgets('password field is obscured and can be revealed', (tester) async {
    // Animations off: the login screen has continuous idle motion, so a widget
    // test must not wait for it to settle — and reduced-motion is a real path
    // worth exercising anyway.
    await pumpLogin(tester);

    TextField passwordField() => tester.widgetList<TextField>(find.byType(TextField)).last;
    expect(passwordField().obscureText, isTrue);

    await tester.tap(find.byTooltip('Show password').first);
    await tester.pump();
    expect(passwordField().obscureText, isFalse);
  });
}
