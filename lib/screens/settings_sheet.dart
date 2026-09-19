import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../main.dart';
import '../theme.dart';
import '../widgets/focus_ring.dart';

Future<void> showSettingsSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppTheme.surface,
    isScrollControlled: true,
    builder: (context) => const _SettingsSheet(),
  );
}

class _SettingsSheet extends StatelessWidget {
  const _SettingsSheet();

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: appState,
      builder: (context, _) {
        final a = appState.account;
        return FocusTraversalGroup(
          policy: OrderedTraversalPolicy(),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(22),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 620),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text('Account & settings',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _row('Server', appState.server),
                  _row('Username', a?.username ?? appState.username),
                  if (a != null) ...[
                    _row('Status', a.expired ? 'EXPIRED' : (a.status ?? 'active'),
                        valueColor: a.expired ? AppTheme.danger : AppTheme.ok),
                    _row('Expires', a.expiryLabel),
                    _row('Connections', '${a.activeConnections} active / ${a.maxConnections} max'),
                    _row('Output formats', a.allowedOutputFormats.join(', ')),
                    if (a.serverProtocol != null)
                      _row('Panel', [
                        a.serverProtocol,
                        'port ${a.serverPort ?? '?'}',
                        if ((a.httpsPort ?? '').isNotEmpty) 'https ${a.httpsPort}',
                      ].join(' · ')),
                  ],
                  const SizedBox(height: 18),
                  const Text('Use the same subscription in another app',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  const Text(
                    'Any client that speaks Xtream Codes can use these. They embed your '
                    'username and password, so treat them like a secret and do not paste them '
                    'into chats or public sites.',
                    style: TextStyle(fontSize: 12, color: AppTheme.muted, height: 1.5),
                  ),
                  const SizedBox(height: 12),
                  if (appState.client != null) ...[
                    _urlTile(context, 'M3U playlist (ts)', appState.client!.playlistUrl()),
                    _urlTile(context, 'M3U playlist (hls)', appState.client!.playlistUrl(hls: true)),
                    _urlTile(context, 'EPG (XMLTV)', appState.client!.epgUrl()),
                  ],
                  const SizedBox(height: 18),
                  const Text('Keyboard / remote',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  const Text(
                    'Arrows move the focus, Enter (or the remote’s OK) activates, Esc/Back goes '
                    'back. In the player: ↑↓ switch channel, ←→ seek, Enter/Space pause, M mute, '
                    'C cinema mode. Works with Fire TV / Android TV remotes, HID remotes and '
                    'keyboard-style controllers. Raw gamepads that expose no keyboard events '
                    'are not mapped yet.',
                    style: TextStyle(fontSize: 12, color: AppTheme.muted, height: 1.5),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      OutlinedButton(
                        onPressed: () async {
                          Navigator.pop(context);
                          await appState.logout();
                        },
                        child: const Text('Log out'),
                      ),
                      const SizedBox(width: 10),
                      OutlinedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          appState.loadContent(appState.tab, refresh: true);
                        },
                        child: const Text('Reload content'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  static Widget _row(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.muted)),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: TextStyle(fontSize: 12.5, color: valueColor ?? AppTheme.text),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _urlTile(BuildContext context, String label, String url) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          SizedBox(
            width: 140,
            child: Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.muted)),
          ),
          Expanded(
            child: Text(
              url.replaceAll(RegExp(r'password=[^&]+'), 'password=••••'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: AppTheme.text, fontFamily: 'monospace'),
            ),
          ),
          FocusRing(
            borderRadius: 4,
            onSelect: () async {
              await Clipboard.setData(ClipboardData(text: url));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('$label copied to clipboard')),
                );
              }
            },
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Icon(Icons.copy, size: 16, color: AppTheme.accent),
            ),
          ),
        ],
      ),
    );
  }
}