import 'package:flutter/material.dart';

import 'dpad_field.dart';

import '../diagnostics.dart';
import '../l10n.dart';
import '../main.dart';
import '../panels.dart';
import '../theme.dart';
import '../xtream_client.dart';

/// Server tools, kept off the login screen on purpose: the login form is just
/// credentials. These live under Account → Server tools for when a login has
/// already failed and the address itself is the suspect.
class ServerToolsSection extends StatefulWidget {
  const ServerToolsSection({super.key});

  @override
  State<ServerToolsSection> createState() => _ServerToolsSectionState();
}

class _ServerToolsSectionState extends State<ServerToolsSection> {
  late final TextEditingController _server;
  late final TextEditingController _list;
  // D-pad: both fields must be leaveable with a remote; the list field is
  // multi-line, so up/down stay inside it until the caret reaches the edge.
  late final FocusNode _serverFocus;
  late final FocusNode _listFocus;
  bool _listOpen = false;
  bool _diagBusy = false;
  bool _listBusy = false;
  bool _anonBusy = false;
  DiagnosticsResult? _diag;
  List<CandidateResult> _listResults = const [];
  List<AnonProbe> _anonResults = const [];

  @override
  void initState() {
    super.initState();
    _server = TextEditingController(text: appState.server);
    _list = TextEditingController();
    _serverFocus = dpadTextFocusNode(controller: _server);
    _listFocus = dpadTextFocusNode(controller: _list);
  }

  @override
  void dispose() {
    _server.dispose();
    _list.dispose();
    _serverFocus.dispose();
    _listFocus.dispose();
    super.dispose();
  }

  Future<void> _diagnose() async {
    setState(() {
      _diagBusy = true;
      _diag = null;
    });
    final result = await Diagnostics.run(
      server: _server.text.trim(),
      username: appState.username,
      password: appState.password,
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
      servers: _list.text.split('\n'),
      username: appState.username,
      password: appState.password,
    );
    if (!mounted) return;
    setState(() {
      _listResults = results;
      _listBusy = false;
    });
  }

  Future<void> _probeAnon() async {
    setState(() {
      _anonBusy = true;
      _anonResults = const [];
    });
    final targets = <String>{
      if (_server.text.trim().isNotEmpty)
        XtreamClient.normaliseServer(_server.text),
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

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: appState,
      builder: (context, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _server,
            focusNode: _serverFocus,
            decoration: InputDecoration(
              labelText: tr(context, 'Server address'),
              hintText: 'http://host:8080',
            ),
            keyboardType: TextInputType.url,
            autocorrect: false,
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: _diagBusy ? null : _diagnose,
                icon: _diagBusy
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.health_and_safety_outlined, size: 16),
                label: Text(
                  _diagBusy
                      ? tr(context, 'Checking…')
                      : tr(context, 'Diagnose (DNS + ports)'),
                ),
              ),
              OutlinedButton.icon(
                onPressed: () => setState(() {
                  _listOpen = !_listOpen;
                  if (_listOpen && _list.text.trim().isEmpty) {
                    _list.text = presetUrlsAsText();
                  }
                }),
                icon: Icon(
                  _listOpen ? Icons.expand_less : Icons.playlist_add_check,
                  size: 16,
                ),
                label: Text(tr(context, 'Test a list of servers')),
              ),
              OutlinedButton.icon(
                onPressed: _anonBusy ? null : _probeAnon,
                icon: _anonBusy
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.travel_explore, size: 16),
                label: Text(
                  _anonBusy
                      ? tr(context, 'Looking…')
                      : tr(context, 'Check without a login'),
                ),
              ),
            ],
          ),
          if (_diag != null) ...[
            const SizedBox(height: 12),
            _Box(
              title: tr(context, 'Diagnosis'),
              onClose: () => setState(() => _diag = null),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final line in _diagnosticReport(context, _diag!))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 3),
                      child: Text(
                        line,
                        style: TextStyle(
                          fontSize: 11.5,
                          color: AppTheme.muted,
                          fontFamily: 'monospace',
                          height: 1.4,
                        ),
                      ),
                    ),
                  const SizedBox(height: 6),
                  Text(
                    _diagnosticVerdict(context, _diag!),
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.text,
                      height: 1.45,
                    ),
                  ),
                  if (_diag!.workingHost != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: FilledButton(
                        onPressed: () =>
                            appState.switchPanel(_diag!.workingHost!),
                        child: Text(tr(context, 'Use this server')),
                      ),
                    ),
                ],
              ),
            ),
          ],
          if (_listOpen) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _list,
              focusNode: _listFocus,
              minLines: 4,
              maxLines: 8,
              decoration: InputDecoration(
                hintText: tr(context, 'one server per line'),
                labelText: tr(context, 'Servers to test'),
              ),
              style: const TextStyle(fontSize: 12.5, fontFamily: 'monospace'),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.icon(
                onPressed: _listBusy ? null : _testList,
                icon: _listBusy
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.playlist_play, size: 16),
                label: Text(
                  _listBusy
                      ? tr(context, 'Testing…')
                      : tr(context, 'Test these servers'),
                ),
              ),
            ),
          ],
          if (_listResults.isNotEmpty) ...[
            const SizedBox(height: 10),
            _Box(
              title: tr(context, 'Which server accepts this account'),
              onClose: () => setState(() => _listResults = const []),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final r in _listResults)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 7),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            r.ok ? Icons.check_circle : Icons.cancel,
                            size: 14,
                            color: r.ok ? AppTheme.ok : AppTheme.danger,
                          ),
                          const SizedBox(width: 7),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  r.server,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.text,
                                  ),
                                ),
                                Text(
                                  _candidateNote(context, r),
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppTheme.muted,
                                    height: 1.35,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (r.ok)
                            TextButton(
                              onPressed: () => appState.switchPanel(r.server),
                              child: Text(
                                tr(context, 'Use'),
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
          if (_anonResults.isNotEmpty) ...[
            const SizedBox(height: 10),
            _Box(
              title: tr(context, 'Panels checked without any login'),
              onClose: () => setState(() => _anonResults = const []),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final r in _anonResults)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 7),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            r.open
                                ? Icons.lock_open
                                : (r.reachable
                                      ? Icons.lock_outline
                                      : Icons.cloud_off),
                            size: 14,
                            color: r.open
                                ? AppTheme.accent
                                : (r.reachable
                                      ? AppTheme.muted
                                      : AppTheme.danger),
                          ),
                          const SizedBox(width: 7),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  r.server,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.text,
                                  ),
                                ),
                                Text(
                                  _anonymousLabel(context, r),
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: r.open
                                        ? AppTheme.accent
                                        : AppTheme.muted,
                                    height: 1.35,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (r.open)
                            TextButton(
                              onPressed: () => appState.browseAsGuest(r.server),
                              child: Text(
                                tr(context, 'Browse'),
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Box extends StatelessWidget {
  const _Box({required this.title, required this.child, required this.onClose});

  final String title;
  final Widget child;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 12),
      decoration: BoxDecoration(
        color: AppTheme.card,
        border: Border.all(color: AppTheme.border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(fontSize: 12.5, color: AppTheme.text),
                ),
              ),
              IconButton(
                onPressed: onClose,
                icon: Icon(Icons.close, size: 15, color: AppTheme.muted),
                tooltip: tr(context, 'Hide'),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          child,
        ],
      ),
    );
  }
}

// Translate the structured diagnostics before formatting interpolated values.
List<String> _diagnosticReport(BuildContext context, DiagnosticsResult result) {
  final lines = <String>[
    tr(context, 'DNS: {host} → {addresses}', {
      'host': result.host,
      'addresses': result.addresses.isEmpty
          ? tr(context, 'no address')
          : result.addresses.join(', '),
    }),
  ];
  if (result.placeholderDns) {
    lines.add(tr(context, 'That address is a placeholder, not a server.'));
  }
  for (final p in result.probes) {
    if (!p.reachable) {
      lines.add(tr(context, 'port {port} — no answer', {'port': p.port}));
    } else if (p.authenticated) {
      lines.add(
        tr(context, 'port {port} — Xtream panel, login accepted', {
          'port': p.port,
        }),
      );
    } else if (p.xtreamLike) {
      lines.add(
        tr(context, 'port {port} — Xtream panel, login refused', {
          'port': p.port,
        }),
      );
    } else {
      lines.add(
        tr(context, 'port {port} — HTTP {status}, not Xtream', {
          'port': p.port,
          'status': p.statusCode,
        }),
      );
    }
    if (p.detail.isNotEmpty) {
      lines.add('    ${_probeDetail(context, p.detail)}');
    }
  }
  lines.add('');
  lines.add(_diagnosticVerdict(context, result));
  return lines;
}

String _probeDetail(BuildContext context, String detail) {
  if (detail == 'no hostname given') {
    return tr(context, 'no hostname given');
  }
  if (detail == 'timed out') {
    return tr(context, 'timed out');
  }
  if (detail ==
      'Cloudflare error 1034 — the DNS record points at a placeholder, nothing is listening behind it') {
    return tr(
      context,
      'Cloudflare error 1034 — the DNS record points at a placeholder, nothing is listening behind it',
    );
  }
  if (detail.startsWith('said: "') && detail.endsWith('"')) {
    return tr(context, 'said: "{response}"', {
      'response': detail.substring(7, detail.length - 1),
    });
  }
  if (detail.startsWith('TLS failed: ')) {
    return tr(context, 'TLS failed: {error}', {'error': detail.substring(12)});
  }
  // Platform/network errors may not have a known translation.
  return tr(context, detail);
}

String _diagnosticVerdict(BuildContext context, DiagnosticsResult result) {
  final working = result.probes.where((p) => p.authenticated);
  if (working.isNotEmpty) {
    return tr(
      context,
      'Login works on {host}:{port} — tap "Use this server" below.',
      {'host': result.host, 'port': working.first.port},
    );
  }
  final refused = result.probes.where((p) => p.xtreamLike && !p.authenticated);
  if (refused.isNotEmpty) {
    return tr(
      context,
      'Verdict: the panel is reachable on port {port} but refused these credentials — wrong username/password, an expired subscription, or too many connections.',
      {'port': refused.first.port},
    );
  }
  if (result.placeholderDns) {
    return tr(
      context,
      'Verdict: {host} resolves to a placeholder address (Cloudflare uses 1.1.1.1 / 1.0.0.1 when a DNS record points nowhere). No request can reach a server there, so the username and password are never even sent. This has to be fixed by whoever gave you the address — ask them for the current panel host; if an app you used before still logs in, it is talking to a different host.',
      {'host': result.host},
    );
  }
  final answered = result.probes.where((p) => p.reachable && !p.xtreamLike);
  if (answered.isNotEmpty) {
    return tr(
      context,
      'Verdict: the host answers (HTTP {status}) but not as an Xtream panel. Most often that is an IP/network gate (401/403/511/512) or a wrong port — the detail lines above say which.',
      {'status': answered.first.statusCode},
    );
  }
  return tr(
    context,
    'Verdict: nothing answered on {host} (typed port {port} and the usual panel ports). Either the host is offline or firewalled, or the address is wrong.',
    {'host': result.host, 'port': result.typedPort},
  );
}

String _candidateNote(BuildContext context, CandidateResult result) {
  final note = result.note;
  if (note.startsWith('login ok but EXPIRED ')) {
    return tr(context, 'login ok but EXPIRED {expiry}', {
      'expiry': note.substring('login ok but EXPIRED '.length),
    });
  }
  final match = RegExp(r'^login ok · expires (.*) · (\d+)/(\d+) conn$')
      .firstMatch(note);
  if (match != null) {
    return tr(context, 'login ok · expires {expiry} · {active}/{max} conn', {
      'expiry': match.group(1)!,
      'active': match.group(2)!,
      'max': match.group(3)!,
    });
  }
  if (note.startsWith('refused — ')) {
    return tr(context, 'refused — {reason}', {
      'reason': tr(context, note.substring('refused — '.length)),
    });
  }
  return tr(context, note);
}

String _anonymousLabel(BuildContext context, AnonProbe probe) {
  final reason = probe.note == 'no response'
      ? tr(context, 'no response')
      : tr(context, probe.note);
  if (!probe.reachable) {
    return tr(context, 'no answer — {reason}', {'reason': reason});
  }
  if (!probe.xtreamLike) {
    return tr(context, 'answers, but not like an Xtream panel — {reason}', {
      'reason': reason,
    });
  }
  if (probe.open) {
    return tr(
      context,
      'OPEN — {live} live / {vod} VOD / {series} series categories without login',
      {
        'live': probe.liveCategories,
        'vod': probe.vodCategories,
        'series': probe.seriesCategories,
      },
    );
  }
  return tr(context, 'panel answers but keeps its lists private');
}
