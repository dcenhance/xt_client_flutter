import 'package:flutter/material.dart';

import '../diagnostics.dart';
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
  }

  @override
  void dispose() {
    _server.dispose();
    _list.dispose();
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

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: appState,
      builder: (context, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _server,
            decoration: const InputDecoration(
              labelText: 'Server address',
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
                        width: 14, height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.health_and_safety_outlined, size: 16),
                label: Text(_diagBusy ? 'Checking…' : 'Diagnose (DNS + ports)'),
              ),
              OutlinedButton.icon(
                onPressed: () => setState(() {
                  _listOpen = !_listOpen;
                  if (_listOpen && _list.text.trim().isEmpty) {
                    _list.text = presetUrlsAsText();
                  }
                }),
                icon: Icon(_listOpen ? Icons.expand_less : Icons.playlist_add_check, size: 16),
                label: const Text('Test a list of servers'),
              ),
              OutlinedButton.icon(
                onPressed: _anonBusy ? null : _probeAnon,
                icon: _anonBusy
                    ? const SizedBox(
                        width: 14, height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.travel_explore, size: 16),
                label: Text(_anonBusy ? 'Looking…' : 'Check without a login'),
              ),
            ],
          ),
          if (_diag != null) ...[
            const SizedBox(height: 12),
            _Box(
              title: 'Diagnosis',
              onClose: () => setState(() => _diag = null),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final line in _diag!.report)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 3),
                      child: Text(line,
                          style: TextStyle(
                              fontSize: 11.5,
                              color: AppTheme.muted,
                              fontFamily: 'monospace',
                              height: 1.4)),
                    ),
                  const SizedBox(height: 6),
                  Text(_diag!.verdict,
                      style: TextStyle(fontSize: 12, color: AppTheme.text, height: 1.45)),
                  if (_diag!.workingHost != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: FilledButton(
                        onPressed: () => appState.switchPanel(_diag!.workingHost!),
                        child: const Text('Use this server'),
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
              minLines: 4,
              maxLines: 8,
              decoration: const InputDecoration(
                hintText: 'one server per line',
                labelText: 'Servers to test',
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
                        width: 14, height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.playlist_play, size: 16),
                label: Text(_listBusy ? 'Testing…' : 'Test these servers'),
              ),
            ),
          ],
          if (_listResults.isNotEmpty) ...[
            const SizedBox(height: 10),
            _Box(
              title: 'Which server accepts this account',
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
                          Icon(r.ok ? Icons.check_circle : Icons.cancel,
                              size: 14, color: r.ok ? AppTheme.ok : AppTheme.danger),
                          const SizedBox(width: 7),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(r.server,
                                    style: TextStyle(fontSize: 12, color: AppTheme.text)),
                                Text(r.note,
                                    style: TextStyle(
                                        fontSize: 11, color: AppTheme.muted, height: 1.35)),
                              ],
                            ),
                          ),
                          if (r.ok)
                            TextButton(
                              onPressed: () => appState.switchPanel(r.server),
                              child: const Text('Use', style: TextStyle(fontSize: 12)),
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
              title: 'Panels checked without any login',
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
                                    style: TextStyle(fontSize: 12, color: AppTheme.text)),
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
                              onPressed: () => appState.browseAsGuest(r.server),
                              child: const Text('Browse', style: TextStyle(fontSize: 12)),
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
                child: Text(title,
                    style: TextStyle(fontSize: 12.5, color: AppTheme.text)),
              ),
              IconButton(
                onPressed: onClose,
                icon: Icon(Icons.close, size: 15, color: AppTheme.muted),
                tooltip: 'Hide',
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