import 'package:flutter/material.dart';

import '../diagnostics.dart';
import '../main.dart';
import '../panels.dart';
import '../theme.dart';
import '../store.dart';
import '../xtream_client.dart';
import '../widgets/focus_ring.dart';

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

  bool _anonBusy = false;
  bool _advanced = false;
  List<AnonProbe> _anonResults = const [];

  /// Looks at each known panel without sending any credentials: which ones are
  /// even reachable from here, and which of them hand out their lists to
  /// anyone. Answers "can I see servers before I log in".
  Future<void> _probeAnon() async {
    setState(() {
      _anonBusy = true;
      _anonResults = const [];
    });
    final targets = <String>{
      if (_server.text.trim().isNotEmpty) XtreamClient.normaliseServer(_server.text),
      ...kPanelPresets.map((p) => p.url),
    }.toList();
    final out = <AnonProbe>[];
    for (final t in targets) {
      out.add(await probeAnonymous(server: t));
      if (mounted) setState(() => _anonResults = List.of(out));
    }
    if (!mounted) return;
    setState(() => _anonBusy = false);
  }

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
    await appState.signIn(
      username: _user.text,
      password: _pass.text,
      // No server typed: let the app find the panel itself.
      server: _server.text.trim().isEmpty ? null : _server.text.trim(),
    );
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
                    Container(
                      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
                      decoration: BoxDecoration(
                        gradient: AppTheme.headerGradient(),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: AppTheme.border),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [AppTheme.accent, AppTheme.accent2],
                              ),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Icon(Icons.play_arrow_rounded,
                                color: AppTheme.onAccent, size: 30),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Xtream Player',
                                    style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w700,
                                        color: AppTheme.text,
                                        letterSpacing: 0.2)),
                                const SizedBox(height: 3),
                                Text(
                                  'Your subscription, on every screen you own.',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: AppTheme.muted,
                                      height: 1.35),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 22),
                    if (appState.recentLogins.isNotEmpty) ...[
                      Text('Continue as',
                          style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.muted,
                              letterSpacing: 0.4)),
                      const SizedBox(height: 8),
                      for (final l in appState.recentLogins.take(3))
                        _SavedLoginTile(
                          login: l,
                          onResume: () => appState.resumeLogin(l),
                          onForget: () => appState.forget(l),
                        ),
                      const SizedBox(height: 14),
                    ],
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
                            Text('Remember me',
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
                    if (appState.discoveryNote != null) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              appState.discoveryNote!,
                              style: TextStyle(
                                  fontSize: 12, color: AppTheme.muted),
                            ),
                          ),
                        ],
                      ),
                    ],
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
                        onPressed: () => setState(() => _advanced = !_advanced),
                        icon: Icon(_advanced ? Icons.expand_less : Icons.tune, size: 16),
                        label: Text(
                            _advanced
                                ? 'Hide options'
                                : 'Panel, server address, diagnostics',
                            style: const TextStyle(fontSize: 13)),
                      ),
                    ),
                    if (_advanced) ...[
                      const SizedBox(height: 8),
                      TextField(
                        controller: _server,
                        decoration: const InputDecoration(
                          labelText: 'Server address (optional)',
                          hintText: 'Leave empty — the app finds your panel',
                        ),
                        keyboardType: TextInputType.url,
                        autocorrect: false,
                        onSubmitted: (_) => _submit(),
                      ),
                      const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _panelPicker(),
                        TextButton.icon(
                          onPressed: () => setState(() {
                            _showList = !_showList;
                            if (_showList && _serversList.text.trim().isEmpty) {
                              _serversList.text = presetUrlsAsText();
                            }
                          }),
                          icon: Icon(
                              _showList ? Icons.expand_less : Icons.playlist_add_check,
                              size: 16),
                          label: const Text('Test a list of servers',
                              style: TextStyle(fontSize: 13)),
                        ),
                        TextButton.icon(
                          onPressed: _anonBusy ? null : _probeAnon,
                          icon: _anonBusy
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.travel_explore, size: 16),
                          label: Text(
                              _anonBusy ? 'Looking…' : 'Look at servers without login',
                              style: const TextStyle(fontSize: 13)),
                        ),
                      ],
                    ),
                      if (_showList) _serversListSection(),
                    ],
                    if (_anonResults.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _AnonBox(
                        results: _anonResults,
                        onBrowse: (server) {
                          _server.text = server;
                          appState.setCredentials(server: server);
                          appState.browseAsGuest(server);
                        },
                        onDismiss: () => setState(() => _anonResults = const []),
                      ),
                    ],
                    const SizedBox(height: 10),
                    Text(
                      'Your username and password only ever go to the panel you sign in to. '
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

  Widget _panelPicker() {
    return OutlinedButton.icon(
      onPressed: () async {
        final chosen = await showDialog<PanelPreset>(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: AppTheme.surface,
            title: const Text('Select panel',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, letterSpacing: 2)),
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
                        borderRadius: 4,
                        onSelect: () => Navigator.pop(context, p),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                          decoration: BoxDecoration(
                            color: AppTheme.card,
                            border: Border.all(
                              color: _server.text.trim() == p.url
                                  ? AppTheme.accent
                                  : AppTheme.border,
                            ),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            children: [
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
                                            fontSize: 11,
                                            fontFamily: 'monospace',
                                            color: AppTheme.muted)),
                                  ],
                                ),
                              ),
                              if (_server.text.trim() == p.url)
                                Icon(Icons.check_circle,
                                    size: 18, color: AppTheme.accent),
                            ],
                          ),
                        ),
                      ),
                    ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(4, 14, 4, 0),
                    child: Text(
                      'These are the panels that ship with the Spectre build this subscription came '
                      'from. They only answer to their own customers\' networks, so some will refuse '
                      'from here — use "Test a list of servers" to see which one accepts your login.',
                      style: TextStyle(fontSize: 11, color: AppTheme.muted, height: 1.5),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
            ],
          ),
        );
        if (chosen != null) {
          setState(() {
            _server.text = chosen.url;
            _serversList.text = presetUrlsAsText();
            _showList = true;
          });
          appState.setCredentials(server: chosen.url);
        }
      },
      icon: const Icon(Icons.grid_view, size: 16),
      label: const Text('Select panel', style: TextStyle(fontSize: 13)),
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
          Text(
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
                              style: TextStyle(
                                  fontSize: 12, fontFamily: 'monospace', color: AppTheme.text)),
                          Text(r.note,
                              style: TextStyle(
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

/// One remembered login on the login screen: tap to sign straight back in,
/// X to forget it for good.
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
                  width: 36,
                  height: 36,
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

class _AnonBox extends StatelessWidget {
  const _AnonBox({
    required this.results,
    required this.onBrowse,
    required this.onDismiss,
  });

  final List<AnonProbe> results;
  final void Function(String server) onBrowse;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        color: AppTheme.card,
        border: Border.all(color: AppTheme.border),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.travel_explore, size: 15, color: AppTheme.accent),
              const SizedBox(width: 6),
              Expanded(
                child: Text('Panels, checked without any login',
                    style: TextStyle(fontSize: 12.5, color: AppTheme.text)),
              ),
              IconButton(
                onPressed: onDismiss,
                icon: const Icon(Icons.close, size: 15),
                tooltip: 'Hide',
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          Text(
            'No username or password was sent. A panel marked OPEN hands out its '
            'categories to anyone, so its channels can be browsed right away.',
            style: TextStyle(fontSize: 11, color: AppTheme.muted, height: 1.45),
          ),
          const SizedBox(height: 8),
          for (final r in results)
            Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    r.open
                        ? Icons.lock_open
                        : (r.reachable ? Icons.lock_outline : Icons.cloud_off),
                    size: 14,
                    color: r.open
                        ? AppTheme.accent
                        : (r.reachable ? AppTheme.muted : AppTheme.danger),
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(r.server,
                            style: TextStyle(
                                fontSize: 12, color: AppTheme.text)),
                        Text(r.label,
                            style: TextStyle(
                                fontSize: 11,
                                color: r.open ? AppTheme.accent : AppTheme.muted,
                                height: 1.35)),
                      ],
                    ),
                  ),
                  if (r.open)
                    TextButton(
                      onPressed: () => onBrowse(r.server),
                      child: const Text('Browse', style: TextStyle(fontSize: 12)),
                    ),
                ],
              ),
            ),
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
            style: TextStyle(
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
              Icon(Icons.error_outline, color: AppTheme.danger, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(message,
                    style: TextStyle(color: AppTheme.danger, fontSize: 13, height: 1.4)),
              ),
            ],
          ),
          if (hint != null) ...[
            const SizedBox(height: 10),
            Text(hint!, style: TextStyle(color: AppTheme.muted, fontSize: 12, height: 1.5)),
          ],
        ],
      ),
    );
  }
}