import 'package:flutter/material.dart';

import '../main.dart';
import '../panels.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets/dpad_field.dart';
import '../widgets/focus_ring.dart';
import '../widgets/motion.dart';
import '../xtream_client.dart';

/// The login screen. Bare on purpose — mark, name, username, password,
/// remember-me, sign in — but it moves: the mark floats inside a turning halo,
/// a light band sweeps across it, every control arrives in turn, the fields
/// warm up when focused and the whole card settles when it works.
///
/// Everything technical (addresses, diagnostics, server testing) still lives in
/// Account → Server tools.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  late final TextEditingController _user;
  late final TextEditingController _pass;
  late final FocusNode _userFocus;
  late final FocusNode _passFocus;
  final ScrollController _scroll = ScrollController();
  // Pointer-only control: it stays tappable but out of the arrow/D-pad order.
  final FocusNode _revealFocus = FocusNode(skipTraversal: true);
  final GlobalKey _errorKey = GlobalKey();
  String? _server;
  bool _obscure = true;
  Object? _seenError;

  @override
  void initState() {
    super.initState();
    _user = TextEditingController(text: appState.username);
    _pass = TextEditingController(text: appState.password);
    // A remote has no pointer: the arrow keys must walk the form, but a focused
    // text field swallows them for the caret. Both nodes therefore get their own
    // key handler — it runs before the field's editing shortcuts, so up/down
    // still move the focus, while left/right keep editing until the caret hits
    // the edge of the text.
    _userFocus = dpadTextFocusNode(controller: _user)..addListener(_onFocusChanged);
    _passFocus = dpadTextFocusNode(controller: _pass)..addListener(_onFocusChanged);
    appState.addListener(_onAppStateChanged);
  }

  void _onFocusChanged() => setState(() {});

  @override
  void dispose() {
    appState.removeListener(_onAppStateChanged);
    _userFocus.removeListener(_onFocusChanged);
    _passFocus.removeListener(_onFocusChanged);
    _userFocus.dispose();
    _passFocus.dispose();
    _user.dispose();
    _pass.dispose();
    _scroll.dispose();
    _revealFocus.dispose();
    super.dispose();
  }

  /// Focus lands back in the password field after a failed attempt: on a TV the
  /// user is looking at the screen, not at a keyboard, and retyping is the next
  /// thing they do.
  void _onAppStateChanged() {
    final error = appState.error;
    if (error != null && error != _seenError) {
      _seenError = error;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _passFocus.requestFocus();
        _revealError();
      });
    }
  }

  void _revealError() {
    final target = _errorKey.currentContext;
    if (target == null) return;
    Scrollable.ensureVisible(
      target,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      alignment: 1,
    );
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    // No server chosen: the app finds the panel itself.
    await appState.signIn(
      username: _user.text,
      password: _pass.text,
      server: _server,
    );
  }

  Future<void> _pickPanel() async {
    final chosen = await showDialog<PanelPreset>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select panel'),
        contentPadding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
        content: SizedBox(
          width: 380,
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final p in kPanelPresets)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: FocusRing(
                    borderRadius: 12,
                    onSelect: () => Navigator.pop(context, p),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => Navigator.pop(context, p),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                        decoration: BoxDecoration(
                          color: AppTheme.card,
                          border: Border.all(
                            color: (_server ?? appState.server) == p.url
                                ? AppTheme.accent
                                : AppTheme.border,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.dns_outlined, size: 16, color: AppTheme.accent),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(p.name,
                                      style: TextStyle(
                                          fontSize: 13, color: AppTheme.text)),
                                  const SizedBox(height: 2),
                                  Text(p.url,
                                      style: TextStyle(
                                          fontSize: 11, color: AppTheme.muted)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 6),
              Text(
                'Leave it automatic and the app picks the panel that accepts '
                'your account.',
                style: TextStyle(fontSize: 11.5, color: AppTheme.muted, height: 1.45),
              ),
            ],
          ),
        ),
      ),
    );
    if (chosen == null || !mounted) return;
    setState(() => _server = chosen.url);
    // Credentials already typed? Then just sign in on that panel.
    if (_user.text.trim().isNotEmpty && _pass.text.isNotEmpty) {
      await _submit();
    }
  }

  @override
  Widget build(BuildContext context) {
    final busy = appState.busy;
    return Scaffold(
      body: MotionBackdrop(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                // A vertical form read top to bottom: the spatial policy walks
                // it with a D-pad in exactly that order.
                child: FocusTraversalGroup(
                  policy: ReadingOrderTraversalPolicy(),
                  child: ListenableBuilder(
                  listenable: appState,
                  builder: (context, _) => Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const _BrandHeader(),
                      const SizedBox(height: 30),

                      if (appState.recentLogins.isNotEmpty) ...[
                        for (var i = 0; i < appState.recentLogins.take(3).length; i++)
                          FadeSlideIn(
                            delay: Duration(milliseconds: 90 + 70 * i),
                            child: _SavedLoginTile(
                              login: appState.recentLogins[i],
                              onResume: () => appState.resumeLogin(appState.recentLogins[i]),
                              onForget: () => appState.forget(appState.recentLogins[i]),
                            ),
                          ),
                        const SizedBox(height: 14),
                      ],

                      FadeSlideIn(
                        delay: const Duration(milliseconds: 220),
                        child: _FieldShell(
                          label: 'Username',
                          icon: Icons.person_outline,
                          focused: _userFocus.hasFocus,
                          child: TextField(
                            controller: _user,
                            focusNode: _userFocus,
                            // The screen opens with focus on the first field, so
                            // a remote works from the very first key press.
                            autofocus: true,
                            autocorrect: false,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                            onSubmitted: (_) => _passFocus.requestFocus(),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      FadeSlideIn(
                        delay: const Duration(milliseconds: 300),
                        child: _FieldShell(
                          label: 'Password',
                          icon: Icons.lock_outline,
                          focused: _passFocus.hasFocus,
                          trailing: IconButton(
                            tooltip: _obscure ? 'Show password' : 'Hide password',
                            // Pointer affordance only: on a remote/arrow path it
                            // would be a pointless stop between the two fields.
                            focusNode: _revealFocus,
                            splashRadius: 18,
                            icon: Icon(
                              _obscure ? Icons.visibility_off : Icons.visibility,
                              size: 18,
                              color: _passFocus.hasFocus ? AppTheme.accent : AppTheme.muted,
                            ),
                            onPressed: () => setState(() => _obscure = !_obscure),
                          ),
                          child: TextField(
                            controller: _pass,
                            focusNode: _passFocus,
                            obscureText: _obscure,
                            textInputAction: TextInputAction.done,
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                            onSubmitted: (_) => _submit(),
                          ),
                        ),
                      ),

                      const SizedBox(height: 6),
                      FadeSlideIn(
                        delay: const Duration(milliseconds: 360),
                        child: _RememberRow(
                          value: appState.remember,
                          onChanged: (v) => appState.setCredentials(remember: v),
                        ),
                      ),

                      const SizedBox(height: 14),
                      FadeSlideIn(
                        delay: const Duration(milliseconds: 420),
                        child: _SignInButton(busy: busy, onTap: _submit),
                      ),

                      const SizedBox(height: 10),
                      FadeSlideIn(
                        delay: const Duration(milliseconds: 480),
                        child: _PanelButton(
                          label: _server == null
                              ? 'Panel · Automatic'
                              : 'Panel · ${panelNameFor(_server!)}',
                          automatic: _server == null,
                          enabled: !busy,
                          onTap: _pickPanel,
                        ),
                      ),

                      AnimatedSize(
                        duration: const Duration(milliseconds: 260),
                        curve: Curves.easeOutCubic,
                        alignment: Alignment.topCenter,
                        child: appState.discoveryNote == null
                            ? const SizedBox(width: double.infinity)
                            : Padding(
                                padding: const EdgeInsets.only(top: 16),
                                child: FadeSlideIn(
                                  offset: const Offset(0, 8),
                                  child: Row(
                                    children: [
                                      const SizedBox(
                                        width: 14,
                                        height: 14,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(appState.discoveryNote!,
                                            style: TextStyle(
                                                fontSize: 12,
                                                color: AppTheme.muted,
                                                height: 1.4)),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                      ),
                      AnimatedSize(
                        duration: const Duration(milliseconds: 260),
                        curve: Curves.easeOutCubic,
                        alignment: Alignment.topCenter,
                        child: appState.error == null
                            ? const SizedBox(width: double.infinity)
                            : Padding(
                                padding: const EdgeInsets.only(top: 16),
                                child: ShakeOnChange(
                                  key: _errorKey,
                                  tick: appState.error,
                                  child: _ErrorBox(
                                    message: appState.error!,
                                    hint: appState.errorHint,
                                  ),
                                ),
                              ),
                      ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Mark, name and one line of what this is — the part that moves the most.
class _BrandHeader extends StatelessWidget {
  const _BrandHeader();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        EntrancePop(
          child: RotatingHalo(
            size: 96,
            child: SpectralSweep(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(96 * 0.28),
                child: Image.asset(
                  'assets/branding/spectre_icon.png',
                  width: 96,
                  height: 96,
                  filterQuality: FilterQuality.high,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 18),
        FadeSlideIn(
          delay: const Duration(milliseconds: 140),
          offset: const Offset(0, 10),
          child: const _AnimatedTitle(),
        ),
        const SizedBox(height: 6),
        FadeSlideIn(
          delay: const Duration(milliseconds: 200),
          offset: const Offset(0, 8),
          child: Text(
            'Live TV, movies and series from your own panel',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12.5, color: AppTheme.muted, height: 1.4),
          ),
        ),
      ],
    );
  }
}

/// The product name, easing its letter spacing open as it fades in.
class _AnimatedTitle extends StatefulWidget {
  const _AnimatedTitle();

  @override
  State<_AnimatedTitle> createState() => _AnimatedTitleState();
}

class _AnimatedTitleState extends State<_AnimatedTitle>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..forward();
  late final Animation<double> _t =
      CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _t,
      builder: (context, child) => Opacity(
        opacity: _t.value.clamp(0, 1),
        child: Transform.translate(
          offset: Offset(0, 8 * (1 - _t.value)),
          child: Text(
            'Spectre',
            style: TextStyle(
              fontSize: 27,
              fontWeight: FontWeight.w700,
              color: AppTheme.text,
              letterSpacing: 0.4 + 2.6 * (1 - _t.value),
            ),
          ),
        ),
      ),
    );
  }
}

/// An input that lights up while it has the keyboard: border, glow and the
/// leading icon all move to the accent colour together.
class _FieldShell extends StatelessWidget {
  const _FieldShell({
    required this.label,
    required this.icon,
    required this.focused,
    required this.child,
    this.trailing,
  });

  final String label;
  final IconData icon;
  final bool focused;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: focused ? AppTheme.accent : AppTheme.border,
          width: focused ? 1.4 : 1,
        ),
        boxShadow: focused
            ? [
                BoxShadow(
                  color: AppTheme.accent.withValues(alpha: 0.18),
                  blurRadius: 18,
                  spreadRadius: 1,
                ),
              ]
            : const [],
      ),
      child: Row(
        children: [
          // Colour-only animation: no keys, so nothing can collide while two
          // fields change state in the same frame.
          TweenAnimationBuilder<Color?>(
            tween: ColorTween(
              begin: AppTheme.muted,
              end: focused ? AppTheme.accent : AppTheme.muted,
            ),
            duration: const Duration(milliseconds: 200),
            builder: (context, color, _) => Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 200),
                  style: TextStyle(
                    fontSize: focused ? 10.5 : 11,
                    letterSpacing: focused ? 0.6 : 0.2,
                    color: focused ? AppTheme.accent : AppTheme.muted,
                    fontWeight: focused ? FontWeight.w700 : FontWeight.w500,
                  ),
                  child: Text(label),
                ),
                DefaultTextStyle.merge(
                  style: TextStyle(fontSize: 14.5, color: AppTheme.text),
                  child: child,
                ),
              ],
            ),
          ),
          if (trailing != null) trailing! else const SizedBox(width: 8),
        ],
      ),
    );
  }
}

class _RememberRow extends StatelessWidget {
  const _RememberRow({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    // One focus node for the whole row: OK/Enter toggles it, a tap toggles it,
    // and the ring shows where the remote is.
    return FocusRing(
      borderRadius: 12,
      onSelect: () => onChanged(!value),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      child: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              color: value ? AppTheme.accent.withValues(alpha: 0.16) : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: value ? AppTheme.accent : AppTheme.border,
                width: value ? 1.4 : 1,
              ),
            ),
            child: AnimatedScale(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutBack,
              scale: value ? 1 : 0.4,
              child: Icon(Icons.check, size: 13, color: AppTheme.accent),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text('Remember me',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13, color: AppTheme.text)),
          ),
          Text('fills in next time',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, color: AppTheme.muted)),
          const SizedBox(width: 4),
        ],
      ),
    );
  }
}

/// The primary action: a light band crosses it while idle, it leans in when
/// pressed and turns into a live progress bar while the app signs in.
class _SignInButton extends StatelessWidget {
  const _SignInButton({required this.busy, required this.onTap});

  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: busy ? null : onTap,
      child: SizedBox(
        height: 50,
        child: FilledButton(
          onPressed: busy ? null : onTap,
          style: FilledButton.styleFrom(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: busy
                ? Row(
                    key: const ValueKey('busy'),
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      SizedBox(width: 10),
                      Text('Signing in…'),
                    ],
                  )
                : SpectralSweep(
                    key: const ValueKey('idle'),
                    child: const Text('Sign In',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                  ),
          ),
        ),
      ),
    );
  }
}

/// Which panel to use. Automatic is the normal case; tapping opens the list.
class _PanelButton extends StatelessWidget {
  const _PanelButton({
    required this.label,
    required this.automatic,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final bool automatic;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = automatic ? AppTheme.muted : AppTheme.accent;
    return Center(
      child: FocusRing(
        borderRadius: 12,
        onSelect: enabled ? onTap : null,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              automatic ? Icons.auto_awesome_outlined : Icons.dns_outlined,
              size: 16,
              color: color,
            ),
            const SizedBox(width: 8),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: SizeTransition(
                    sizeFactor: animation, axis: Axis.horizontal, child: child),
              ),
              child: Text(
                label,
                key: ValueKey(label),
                style: TextStyle(fontSize: 12.5, color: color),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One remembered login: tap to sign straight back in, X to forget it.
class _SavedLoginTile extends StatelessWidget {
  const _SavedLoginTile({
    required this.login,
    required this.onResume,
    required this.onForget,
  });

  final SavedLogin login;
  final VoidCallback onResume;
  final VoidCallback onForget;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: FocusRing(
        borderRadius: 14,
        onSelect: onResume,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onResume,
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
            decoration: BoxDecoration(
              color: AppTheme.card,
              border: Border.all(color: AppTheme.border),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [AppTheme.accent, AppTheme.accent2],
                    ),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Text(
                    login.username.isEmpty
                        ? '?'
                        : login.username.characters.first.toUpperCase(),
                    style: TextStyle(
                        color: AppTheme.onAccent,
                        fontWeight: FontWeight.w700,
                        fontSize: 15),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(login.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 13.5,
                              color: AppTheme.text,
                              fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Text(login.server,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 11, color: AppTheme.muted)),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Forget this login',
                  onPressed: onForget,
                  icon: Icon(Icons.close, size: 16, color: AppTheme.muted),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  const _ErrorBox({required this.message, this.hint});

  final String message;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.danger.withValues(alpha: 0.08),
        border: Border.all(color: AppTheme.danger.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.error_outline, color: AppTheme.danger, size: 17),
              const SizedBox(width: 8),
              Expanded(
                child: Text(message,
                    style: TextStyle(color: AppTheme.danger, fontSize: 12.5, height: 1.4)),
              ),
            ],
          ),
          if (hint != null) ...[
            const SizedBox(height: 8),
            Text(hint!,
                style: TextStyle(color: AppTheme.muted, fontSize: 12, height: 1.5)),
          ],
        ],
      ),
    );
  }
}

/// Friendly name for a panel address, used in the Select panel button.
String panelNameFor(String server) {
  final norm = XtreamClient.normaliseServer(server);
  for (final p in kPanelPresets) {
    if (XtreamClient.normaliseServer(p.url) == norm) return p.name;
  }
  return Uri.tryParse(norm)?.host ?? norm;
}
