import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xtream_player/screens/login_screen.dart';

void main() {
  testWidgets('login screen offers exactly the three Xtream fields', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));

    expect(find.byType(TextField), findsNWidgets(3));
    expect(find.text('Server'), findsOneWidget);
    expect(find.text('Username'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Sign In'), findsOneWidget);
    expect(find.text('Xtream-Codes compatible API'), findsOneWidget);
    expect(find.text('Remember me'), findsOneWidget);
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