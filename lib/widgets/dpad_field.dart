import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A focus node for a text field that a D-pad / remote can leave again.
///
/// A Flutter text field claims the arrow keys for its caret, so on Android TV,
/// Fire TV and any remote-driven box the focus enters the field and never comes
/// back out — the user cannot reach the button that submits what they typed.
/// This node handles the keys itself, before the field's editing shortcuts:
/// up/down walk the focus, left/right stay with the caret, and the remote's OK
/// button opens the on-screen keyboard (Android does that for a tap, but the
/// D-pad centre arrives as a key event, which a text field would ignore).
///
/// Pass [controller] and up/down only leave the field from its first/last line,
/// so a multi-line box keeps its own vertical caret movement until the caret
/// reaches the top or bottom line. Without a controller the field is treated as
/// a single line and up/down always walk.
///
/// [onKey] runs first and may claim a key itself (returning non-null); anything
/// it ignores falls through to the D-pad handling.
FocusNode dpadTextFocusNode({
  TextEditingController? controller,
  KeyEventResult Function(KeyEvent event)? onKey,
}) {
  return FocusNode(
    onKeyEvent: (node, event) {
      final claimed = onKey?.call(event);
      if (claimed != null) return claimed;
      if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
        return KeyEventResult.ignored;
      }
      final key = event.logicalKey;
      final context = node.context;
      if (context == null) return KeyEventResult.ignored;
      final scope = FocusScope.of(context);
      switch (key) {
        case LogicalKeyboardKey.arrowUp:
          if (_onLineEdge(controller, first: true)) {
            scope.focusInDirection(TraversalDirection.up);
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        case LogicalKeyboardKey.arrowDown:
          if (_onLineEdge(controller, first: false)) {
            scope.focusInDirection(TraversalDirection.down);
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        case LogicalKeyboardKey.select:
        case LogicalKeyboardKey.gameButtonA:
          SystemChannels.textInput.invokeMethod<void>('TextInput.show');
          return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    },
  );
}

/// Is the caret on the first (or last) line of the field's text?
bool _onLineEdge(TextEditingController? controller, {required bool first}) {
  if (controller == null) return true;
  final text = controller.text;
  final selection = controller.selection;
  final offset = selection.isValid && selection.isCollapsed
      ? selection.baseOffset
      : (first ? 0 : text.length);
  final lines = text.split('\n');
  if (first) {
    return !text.substring(0, offset.clamp(0, text.length)).contains('\n');
  }
  final tail = text.substring(offset.clamp(0, text.length));
  return !tail.contains('\n') || lines.length <= 1;
}
