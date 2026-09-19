import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xtream_player/screens/login_screen.dart';

void main() {
  testWidgets('login asks for credentials only — the panel comes later',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));

    // Username + password, nothing else. The server/panel is behind Options
    // because the app looks the panel up itself after signing in.
    expect(find.byType(TextField), findsNWidgets(2));
    expect(find.text('Username'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Sign In'), findsOneWidget);
    expect(find.text('Remember me'), findsOneWidget);
    expect(find.text('Server'), findsNothing);

    await tester.tap(find.text('Panel, server address, diagnostics'));
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsNWidgets(3));
    expect(find.text('Server address (optional)'), findsOneWidget);
    expect(find.text('Select panel'), findsOneWidget);
    expect(find.text('Test a list of servers'), findsOneWidget);
  });

  testWidgets('password field is obscured and can be revealed', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));

    TextField passwordField() => tester.widgetList<TextField>(find.byType(TextField)).last;
    expect(passwordField().obscureText, isTrue);

    await tester.tap(find.byTooltip('Show password').first);
    await tester.pump();
    expect(passwordField().obscureText, isFalse);
  });
}