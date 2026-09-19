import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xtream_player/screens/login_screen.dart';

void main() {
  testWidgets('login is just the mark, name and credentials', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));

    expect(find.text('Orion Player'), findsOneWidget);
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
    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));

    expect(find.text('Select panel · Automatic'), findsOneWidget);

    await tester.tap(find.text('Select panel · Automatic'));
    await tester.pumpAndSettle();

    // The dialog lists the panels the app can try by itself.
    expect(find.text('EUROPE 1'), findsOneWidget);
    expect(find.text('EUROPE 2'), findsOneWidget);
    expect(find.text('TÜRKİYE PANEL 1'), findsOneWidget);
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
