import 'package:flutter/material.dart';

import '../main.dart';
import '../theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  late final TextEditingController _server;
  late final TextEditingController _user;
  late final TextEditingController _pass;
  bool _obscure = true;

  @override
  void initState() {
    super.initState();
    _server = TextEditingController(text: appState.server);
    _user = TextEditingController(text: appState.username);
    _pass = TextEditingController(text: appState.password);
  }

  @override
  void dispose() {
    _server.dispose();
    _user.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    appState.setCredentials(
      server: _server.text,
      username: _user.text,
      password: _pass.text,
      remember: appState.remember,
    );
    await appState.login();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: ListenableBuilder(
              listenable: appState,
              builder: (context, _) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: AppTheme.accent.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppTheme.border),
                          ),
                          child: const Icon(Icons.live_tv_outlined,
                              color: AppTheme.accent, size: 24),
                        ),
                        const SizedBox(width: 14),
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Xtream Player',
                                style: TextStyle(
                                    fontSize: 19,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.text)),
                            SizedBox(height: 2),
                            Text('Xtream-Codes compatible API',
                                style: TextStyle(fontSize: 12, color: AppTheme.muted)),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),
                    TextField(
                      controller: _server,
                      decoration: const InputDecoration(
                        labelText: 'Server',
                        hintText: 'https or http://server:port',
                      ),
                      keyboardType: TextInputType.url,
                      autocorrect: false,
                      onSubmitted: (_) => _submit(),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _user,
                      decoration: const InputDecoration(labelText: 'Username'),
                      autocorrect: false,
                      onSubmitted: (_) => _submit(),
                    ),
                    const SizedBox(height: 12),
                    TextField(
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
                    const SizedBox(height: 10),
                    // Wrap, not Row: on phone widths the switch row plus the help
                    // button overflow a fixed Row by ~75 px.
                    Wrap(
                      spacing: 10,
                      runSpacing: 2,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Switch(
                              value: appState.remember,
                              activeThumbColor: AppTheme.accent,
                              onChanged: (v) => appState.setCredentials(remember: v),
                            ),
                            const Text('Remember me',
                                style: TextStyle(fontSize: 13, color: AppTheme.muted)),
                          ],
                        ),
                        TextButton(
                          onPressed: () => _importFromClipboardHint(context),
                          child: const Text('Where do I get these?',
                              style: TextStyle(fontSize: 13)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    FilledButton(
                      onPressed: appState.busy ? null : _submit,
                      child: appState.busy
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.black))
                          : const Text('Sign In'),
                    ),
                    if (appState.error != null) ...[
                      const SizedBox(height: 18),
                      _ErrorBox(message: appState.error!, hint: appState.errorHint),
                    ],
                    const SizedBox(height: 22),
                    const Text(
                      'The credentials you enter are sent only to the server above. '
                      'Nothing is forwarded anywhere else.',
                      style: TextStyle(fontSize: 11, color: AppTheme.muted, height: 1.5),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  void _importFromClipboardHint(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Where the three values come from', style: TextStyle(fontSize: 16)),
        content: const SizedBox(
          width: 420,
          child: Text(
            'Your IPTV seller gives you three things:\n\n'
            '• Server — the panel address, usually with a port, e.g. http://example.com:8080\n'
            '• Username — the account name\n'
            '• Password — the account password\n\n'
            'The server has to answer /player_api.php. If a plain browser shows '
            '"error code 1034" or a Cloudflare page for that address, the DNS record points '
            'somewhere dead and no client (this one or the phone app) can log in.',
            style: TextStyle(fontSize: 13, height: 1.6),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        ],
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
        border: Border.all(color: AppTheme.danger.withValues(alpha: 0.45)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.error_outline, color: AppTheme.danger, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(message,
                    style: const TextStyle(color: AppTheme.danger, fontSize: 13, height: 1.4)),
              ),
            ],
          ),
          if (hint != null) ...[
            const SizedBox(height: 10),
            Text(hint!, style: const TextStyle(color: AppTheme.muted, fontSize: 12, height: 1.5)),
          ],
        ],
      ),
    );
  }
}