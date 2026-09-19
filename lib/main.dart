import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';

import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'store.dart';
import 'theme.dart';
import 'widgets/focus_ring.dart';

/// Single global state object; the app is small enough that an InheritedNotifier
/// would only add ceremony.
final appState = AppState();

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  appState.init();
  runApp(const XtreamPlayerApp());
}

class XtreamPlayerApp extends StatelessWidget {
  const XtreamPlayerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Xtream Player',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      home: AppShortcuts(
        child: ListenableBuilder(
          listenable: appState,
          builder: (context, _) {
            if (appState.loggedIn) return const HomeScreen();
            return const LoginScreen();
          },
        ),
      ),
    );
  }
}