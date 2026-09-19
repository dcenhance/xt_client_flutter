import 'package:flutter/material.dart';

import '../diagnostics.dart';
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
  bool _diagBusy = false;
  bool _showList = false;
  bool _listBusy = false;
  List<CandidateResult> _listResults = const [];
  late final TextEditingController _serversList;
  DiagnosticsResult? _diag;

  Future<void> _runDiagnostics() async {
    setState(() {
      _diagBusy = true;
      _diag = null;
    });
    final result = await Diagnostics.run(
      server: _server.text,
      username: _user.text.trim(),
      password: _pass.text,
    );
    if (!mounted) return;
    setState(() {
      _diag = result;
      _diagBusy = false;
    });
  }

  Future<void> _testList() async {
    setState(() {
      _listBusy = true;
      _listResults = const [];
    });
    final results = await testServers(
      servers: _serversList.text.split('\n'),
      username: _user.text.trim(),
      password: _pass.text,
    );
    if (!mounted) return;
    setState(() {
      _listResults = results;
      _listBusy = false;
    });
  }

  @override
  void initState() {
    super.initState();
    _server = TextEditingController(text: appState.server);
    _serversList = TextEditingController(text: appState.server);
    _user = TextEditingController(text: appState.username);
    _pass = TextEditingController(text: appState.password);
  }

  @override
  void dispose() {
    _server.dispose();
    _user.dispose();
    _pass.dispose();
    _serversList.dispose();
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
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _diagBusy ? null : _runDiagnostics,
                              icon: _diagBusy
                                  ? const SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(strokeWidth: 2))
                                  : const Icon(Icons.health_and_safety_outlined, size: 16),
                              label: Text(_diagBusy
                                  ? 'Checking host…'
                                  : 'Diagnose this server (DNS + ports)'),
                            ),
                          ),
                          if (_diag != null) ...[
                            const SizedBox(width: 8),
                            IconButton(
                              tooltip: 'Clear diagnostics',
                              icon: const Icon(Icons.close, size: 16),
                              onPressed: () => setState(() => _diag = null),
                            ),
                          ],
                        ],
                      ),
                      if (_diag != null) ...[
                        const SizedBox(height: 12),
                        _DiagnosticsBox(
                          result: _diag!,
                          onUseServer: (server) {
                            _server.text = server;
                            appState.setCredentials(server: server);
                            setState(() => _diag = null);
                            _submit();
                          },
                        ),
                      ],
                    ],
                    const SizedBox(height: 6),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () => setState(() => _showList = !_showList),
                        icon: Icon(_showList ? Icons.expand_less : Icons.playlist_add_check,
                            size: 16),
                        label: const Text('Test a list of servers',
                            style: TextStyle(fontSize: 13)),
                      ),
                    ),
                    if (_showList) _serversListSection(),
                    const SizedBox(height: 10),
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

  Widget _serversListSection() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.card,
        border: Border.all(color: AppTheme.border),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Try several servers with the same login',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          const Text(
            'One address per line. Useful when the address you have is dead — the app can tell you '
            'which of a provider\'s hosts actually accepts your account.',
            style: TextStyle(fontSize: 11.5, color: AppTheme.muted, height: 1.5),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _serversList,
            minLines: 3,
            maxLines: 6,
            style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
            decoration: const InputDecoration(
              hintText: 'http://host1:8080\nhttp://host2:8080\nhttps://host3',
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              FilledButton.icon(
                onPressed: _listBusy ? null : _testList,
                icon: _listBusy
                    ? const SizedBox(
                        width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.play_arrow, size: 16),
                label: Text(_listBusy ? 'Testing…' : 'Test list'),
              ),
              const SizedBox(width: 10),
              TextButton(
                onPressed: () {
                  setState(() {
                    final text = _serversList.text.trim();
                    final current = _server.text.trim();
                    if (current.isNotEmpty && !text.contains(current)) {
                      _serversList.text = text.isEmpty ? current : '$text\n$current';
                    }
                  });
                },
                child: const Text('Add current server', style: TextStyle(fontSize: 12.5)),
              ),
            ],
          ),
          if (_listResults.isNotEmpty) ...[
            const Divider(height: 20),
            for (final r in _listResults)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(r.ok ? Icons.check_circle : Icons.cancel,
                        size: 16, color: r.ok ? AppTheme.ok : AppTheme.danger),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(r.server,
                              style: const TextStyle(
                                  fontSize: 12, fontFamily: 'monospace', color: AppTheme.text)),
                          Text(r.note,
                              style: const TextStyle(
                                  fontSize: 11, color: AppTheme.muted, height: 1.4)),
                        ],
                      ),
                    ),
                    if (r.ok)
                      TextButton(
                        onPressed: () {
                          _server.text = r.server;
                          appState.setCredentials(server: r.server);
                          setState(() {
                            _showList = false;
                            _listResults = const [];
                          });
                          _submit();
                        },
                        child: const Text('Use', style: TextStyle(fontSize: 12.5)),
                      ),
                  ],
                ),
              ),
          ],
        ],
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

class _DiagnosticsBox extends StatelessWidget {
  const _DiagnosticsBox({required this.result, required this.onUseServer});

  final DiagnosticsResult result;
  final ValueChanged<String> onUseServer;

  @override
  Widget build(BuildContext context) {
    final working = result.workingHost;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.card,
        border: Border.all(color: working != null ? AppTheme.ok : AppTheme.border),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Server diagnostics',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          SelectableText(
            result.report.join('\n'),
            style: const TextStyle(
                fontSize: 11.5, color: AppTheme.muted, fontFamily: 'monospace', height: 1.5),
          ),
          if (working != null) ...[
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () => onUseServer(working),
              icon: const Icon(Icons.check, size: 16),
              label: Text('Use this server: $working'),
            ),
          ],
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