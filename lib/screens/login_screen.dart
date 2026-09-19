import 'package:flutter/material.dart';

import '../main.dart';
import '../panels.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets/app_mark.dart';
import '../widgets/focus_ring.dart';
import '../widgets/motion.dart';
import '../xtream_client.dart';

/// The login screen, deliberately bare: the app mark and name, username,
/// password, remember-me, sign in — plus one button to pick a panel by hand for
/// the rare case the app cannot find it on its own. Everything technical
/// (addresses, diagnostics, server testing) lives in Account → Server tools.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  late final TextEditingController _user;
  late final TextEditingController _pass;
  String? _server;
  bool _obscure = true;

  @override
  void initState() {
    super.initState();
    _user = TextEditingController(text: appState.username);
    _pass = TextEditingController(text: appState.password);
  }

  @override
  void dispose() {
    _user.dispose();
    _pass.dispose();
    super.dispose();
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
    return Scaffold(
      body: MotionBackdrop(
        child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: ListenableBuilder(
              listenable: appState,
              builder: (context, _) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Mark and name, nothing else. The glow breathes while idle.
                  FadeSlideIn(
                    offset: const Offset(0, -10),
                    duration: const Duration(milliseconds: 620),
                    child: Center(
                      child: Column(
                        children: [
                          BreathingMark(
                            size: 96,
                            child: AppMark(size: 96),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Orion Player',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.text,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 26),

                  if (appState.recentLogins.isNotEmpty) ...[
                    for (var i = 0; i < appState.recentLogins.take(3).length; i++)
                      FadeSlideIn(
                        delay: Duration(milliseconds: 80 + 70 * i),
                        child: _SavedLoginTile(
                          login: appState.recentLogins[i],
                          onResume: () => appState.resumeLogin(appState.recentLogins[i]),
                          onForget: () => appState.forget(appState.recentLogins[i]),
                        ),
                      ),
                    const SizedBox(height: 12),
                  ],

                  FadeSlideIn(
                    delay: const Duration(milliseconds: 160),
                    child: TextField(
                    controller: _user,
                    decoration: const InputDecoration(labelText: 'Username'),
                    autocorrect: false,
                    onSubmitted: (_) => _submit(),
                  ),
                  ),
                  const SizedBox(height: 12),
                  FadeSlideIn(
                    delay: const Duration(milliseconds: 240),
                    child: TextField(
                    controller: _pass,
                    obscureText: _obscure,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      suffixIcon: IconButton(
                        tooltip: _obscure ? 'Show password' : 'Hide password',
                        icon: Icon(
                          _obscure ? Icons.visibility_off : Icons.visibility,
                          size: 18,
                          color: AppTheme.muted,
                        ),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                    ),
                    onSubmitted: (_) => _submit(),
                  ),
                  ),
                  const SizedBox(height: 8),
                  FadeSlideIn(
                    delay: const Duration(milliseconds: 300),
                    child: Row(
                    children: [
                      Switch(
                        value: appState.remember,
                        activeThumbColor: AppTheme.accent,
                        onChanged: (v) => appState.setCredentials(remember: v),
                      ),
                      Text('Remember me',
                          style: TextStyle(fontSize: 13, color: AppTheme.muted)),
                    ],
                  ),
                  ),
                  const SizedBox(height: 10),
                  FadeSlideIn(
                    delay: const Duration(milliseconds: 360),
                    child: PressableScale(
                      onTap: appState.busy ? null : _submit,
                      child: FilledButton(
                        onPressed: appState.busy ? null : _submit,
                        child: appState.busy
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Sign In'),
                      ),
                    ),
                  ),

                  // The one extra control: choose a panel yourself.
                  const SizedBox(height: 4),
                  FadeSlideIn(
                    delay: const Duration(milliseconds: 420),
                    child: Center(
                      child: TextButton.icon(
                        onPressed: appState.busy ? null : _pickPanel,
                        icon: const Icon(Icons.dns_outlined, size: 16),
                        label: Text(
                          _server == null
                              ? 'Select panel · Automatic'
                              : 'Select panel · ${panelNameFor(_server!)}',
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    ),
                  ),

                  if (appState.discoveryNote != null) ...[
                    const SizedBox(height: 10),
                    Row(
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
                                  fontSize: 12, color: AppTheme.muted, height: 1.4)),
                        ),
                      ],
                    ),
                  ],
                  if (appState.error != null) ...[
                    const SizedBox(height: 16),
                    ShakeOnChange(
                      tick: appState.error,
                      child: _ErrorBox(
                        message: appState.error!,
                        hint: appState.errorHint,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
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