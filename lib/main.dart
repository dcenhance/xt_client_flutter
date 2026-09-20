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
    return ListenableBuilder(
      listenable: appState,
      builder: (context, _) => MaterialApp(
        title: 'Spectre',
        debugShowCheckedModeBanner: false,
        // Rebuilt from the active palette, so picking a theme repaints at once.
        theme: AppTheme.data(),
        home: AppShortcuts(
          child: ListenableBuilder(
            listenable: appState,
            builder: (context, _) {
              // Signing in swaps the whole screen: the login card fades and
              // lifts away while the app fades in under it.
              return AnimatedSwitcher(
                duration: const Duration(milliseconds: 420),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: ScaleTransition(
                    scale: Tween<double>(begin: 0.97, end: 1).animate(animation),
                    child: child,
                  ),
                ),
                child: appState.loggedIn
                    ? const HomeScreen(key: ValueKey('home'))
                    : const LoginScreen(key: ValueKey('login')),
              );
            },
          ),
        ),
      ),
    );
  }
}