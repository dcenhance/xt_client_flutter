import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme.dart';

/// Wraps any widget so it can be reached with arrow keys / a D-pad / a remote
/// and shows a clear focus ring. Enter (and the remote's OK button) activates it.
class FocusRing extends StatefulWidget {
  const FocusRing({
    super.key,
    required this.child,
    this.onSelect,
    this.autofocus = false,
    this.borderRadius = 6,
    this.padding = EdgeInsets.zero,
    this.focusColor,
    this.onFocusChange,
    this.focusNode,
  });

  final Widget child;
  final VoidCallback? onSelect;
  final bool autofocus;
  final double borderRadius;
  final EdgeInsets padding;
  final Color? focusColor;
  final ValueChanged<bool>? onFocusChange;
  final FocusNode? focusNode;

  @override
  State<FocusRing> createState() => _FocusRingState();
}

class _FocusRingState extends State<FocusRing> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final accent = widget.focusColor ?? AppTheme.accent;
    return FocusableActionDetector(
      focusNode: widget.focusNode,
      autofocus: widget.autofocus,
      enabled: widget.onSelect != null,
      mouseCursor: SystemMouseCursors.click,
      // Drive the ring from *focus*, not from Flutter's "highlight mode":
      // a D-pad or remote that reports no highlight mode would otherwise move
      // an invisible cursor, and on-focus work (the Guide's now/next) would
      // never run.
      onFocusChange: (v) {
        setState(() => _focused = v);
        widget.onFocusChange?.call(v);
      },
      actions: <Type, Action<Intent>>{
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            widget.onSelect?.call();
            return null;
          },
        ),
        ButtonActivateIntent: CallbackAction<ButtonActivateIntent>(
          onInvoke: (_) {
            widget.onSelect?.call();
            return null;
          },
        ),
      },
      child: GestureDetector(
        onTap: widget.onSelect,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 110),
          curve: Curves.easeOut,
          padding: widget.padding,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            border: Border.all(
              color: _focused ? accent : Colors.transparent,
              width: _focused ? 2 : 1,
            ),
            boxShadow: _focused
                ? [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.35),
                      blurRadius: 12,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
          child: widget.child,
        ),
      ),
    );
  }
}

/// A single line of text acting as a keyboard/D-pad hint bar.
class KeyHintBar extends StatelessWidget {
  const KeyHintBar({super.key, required this.hints});

  final List<(String, String)> hints;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 14,
      runSpacing: 6,
      children: [
        for (final (key, meaning) in hints)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.card,
                  border: Border.all(color: AppTheme.border),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Text(
                  key,
                  style: TextStyle(
                    fontSize: 10,
                    color: AppTheme.text,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
              const SizedBox(width: 5),
              Text(
                meaning,
                style: TextStyle(fontSize: 11, color: AppTheme.muted),
              ),
            ],
          ),
      ],
    );
  }
}

/// App-level key handling that every screen inherits: Back/Escape pops, F11-style
/// fullscreen toggle is delegated to the player screen.
class AppShortcuts extends StatelessWidget {
  const AppShortcuts({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: const <ShortcutActivator, Intent>{
        SingleActivator(LogicalKeyboardKey.escape): _PopIntent(),
        SingleActivator(LogicalKeyboardKey.goBack): _PopIntent(),
        SingleActivator(LogicalKeyboardKey.browserBack): _PopIntent(),
        // TV / Fire TV remotes: the OK button arrives as "select" (DPAD_CENTER)
        // or as a gamepad A button. Flutter's defaults do not map those to
        // ActivateIntent, so focusable widgets would ignore the OK button.
        SingleActivator(LogicalKeyboardKey.select): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.gameButtonA): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.gameButtonB): _PopIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          _PopIntent: CallbackAction<_PopIntent>(
            onInvoke: (_) {
              final nav = Navigator.maybeOf(context);
              if (nav != null && nav.canPop()) nav.pop();
              return null;
            },
          ),
        },
        child: child,
      ),
    );
  }
}

class _PopIntent extends Intent {
  const _PopIntent();
}
