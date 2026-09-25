import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n.dart';
import '../main.dart';
import '../panels.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets/focus_ring.dart';
import '../widgets/language_picker.dart';
import '../widgets/layout_picker.dart';
import '../widgets/server_tools.dart';
import '../widgets/theme_picker.dart';
import '../xtream_client.dart';

Future<void> showSettingsSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppTheme.surface,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => const SettingsContent(),
  );
}

/// Account/settings content, shared by the desktop bottom sheet and the mobile
/// "Account" tab so both stay identical.
class SettingsContent extends StatelessWidget {
  const SettingsContent({super.key, this.showClose = true});

  final bool showClose;

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
                      Text(
                        tr(context, 'Account & settings'),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      if (showClose)
                        IconButton(
                          icon: const Icon(Icons.close),
                          tooltip: tr(context, 'Close'),
                          onPressed: () => Navigator.pop(context),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _row(tr(context, 'Server'), appState.server),
                  _row(
                    tr(context, 'Username'),
                    a?.username ?? appState.username,
                  ),
                  if (a != null) ...[
                    _row(
                      tr(context, 'Status'),
                      a.expired
                          ? tr(context, 'EXPIRED')
                          : (a.status ?? tr(context, 'active')),
                      valueColor: a.expired ? AppTheme.danger : AppTheme.ok,
                    ),
                    _row(tr(context, 'Expires'), a.expiryLabel),
                    _row(
                      tr(context, 'Connections'),
                      tr(context, '{active} active / {max} max', {
                        'active': a.activeConnections,
                        'max': a.maxConnections,
                      }),
                    ),
                    _row(
                      tr(context, 'Output formats'),
                      a.allowedOutputFormats.join(', '),
                    ),
                    if (a.serverProtocol != null)
                      _row(
                        tr(context, 'Panel'),
                        [
                          a.serverProtocol,
                          tr(context, 'port {port}', {
                            'port': a.serverPort ?? '?',
                          }),
                          if ((a.httpsPort ?? '').isNotEmpty)
                            'https ${a.httpsPort}',
                        ].join(' · '),
                      ),
                  ],

                  // ---- layout ------------------------------------------------
                  const SizedBox(height: 22),
                  Text(
                    tr(context, 'Layout'),
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    tr(
                      context,
                      'Pick any shell on any platform — it changes the whole navigation.',
                    ),
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.muted,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const LayoutPicker(),

                  const SizedBox(height: 12),
                  const LanguagePicker(),

                  // ---- theme -------------------------------------------------
                  const SizedBox(height: 22),
                  Text(
                    tr(context, 'Theme'),
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const ThemePicker(wrap: true),

                  // ---- panel (only meaningful after a login) ------------------
                  if (appState.account != null) ...[
                    const SizedBox(height: 22),
                    Text(
                      tr(context, 'Panel'),
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      tr(
                        context,
                        'You are on {panel}. Switching keeps the same account — nothing to retype.',
                        {'panel': AppState.panelLabel(appState.server)},
                      ),
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.muted,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final p in kPanelPresets)
                          _PanelChip(
                            panel: p,
                            active:
                                XtreamClient.normaliseServer(p.url) ==
                                XtreamClient.normaliseServer(appState.server),
                            onTap: () => appState.switchPanel(p.url),
                          ),
                      ],
                    ),
                  ],

                  // ---- remembered logins --------------------------------------
                  if (appState.logins.isNotEmpty) ...[
                    const SizedBox(height: 22),
                    Text(
                      tr(context, 'Saved logins'),
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      tr(
                        context,
                        'Kept on this device and used to sign back in automatically. Forget removes one for good.',
                      ),
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.muted,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 8),
                    for (final l in appState.recentLogins)
                      _LoginRow(
                        login: l,
                        active:
                            l.server == appState.server &&
                            l.username == appState.username,
                        onUse: () => appState.resumeLogin(l),
                        onForget: () => appState.forget(l),
                      ),
                  ],
                  const SizedBox(height: 18),
                  Text(
                    tr(context, 'Use the same subscription in another app'),
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    tr(
                      context,
                      'Any client that speaks Xtream Codes can use these. They embed your username and password, so treat them like a secret and do not paste them into chats or public sites.',
                    ),
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.muted,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (appState.client != null) ...[
                    _urlTile(
                      context,
                      tr(context, 'M3U playlist (ts)'),
                      appState.client!.playlistUrl(),
                    ),
                    _urlTile(
                      context,
                      tr(context, 'M3U playlist (hls)'),
                      appState.client!.playlistUrl(hls: true),
                    ),
                    _urlTile(
                      context,
                      tr(context, 'EPG (XMLTV)'),
                      appState.client!.epgUrl(),
                    ),
                  ],
                  const SizedBox(height: 22),
                  Text(
                    tr(context, 'Server tools'),
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    tr(
                      context,
                      'Only needed when a login fails and the address itself is in doubt. Nothing here is sent anywhere except the servers you name.',
                    ),
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.muted,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const ServerToolsSection(),

                  const SizedBox(height: 22),
                  Text(
                    tr(context, 'Keyboard / remote'),
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    tr(
                      context,
                      'Arrows move the focus, Enter (or the remote’s OK) activates, Esc/Back goes back. In the player, press OK to reveal the controls, then use arrows to choose a button and OK to activate it. With the video focused, ↑↓ switch channel, ←→ seek or change live volume; Enter/Space pauses, M mutes and C toggles cinema. Fire TV / Android TV remotes and keyboard-style controllers work; raw gamepads with no keyboard events are not mapped yet.',
                    ),
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.muted,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    children: [
                      OutlinedButton(
                        onPressed: () async {
                          if (showClose) Navigator.pop(context);
                          await appState.logout();
                        },
                        child: Text(tr(context, 'Log out')),
                      ),
                      OutlinedButton(
                        onPressed: () {
                          if (showClose) Navigator.pop(context);
                          appState.loadContent(appState.tab, refresh: true);
                        },
                        child: Text(tr(context, 'Reload content')),
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
            child: Text(
              label,
              style: TextStyle(fontSize: 12, color: AppTheme.muted),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: TextStyle(
                fontSize: 12.5,
                color: valueColor ?? AppTheme.text,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _urlTile(BuildContext context, String label, String url) {
    final masked = url.replaceAll(RegExp(r'password=[^&]+'), 'password=••••');
    final copyButton = FocusRing(
      borderRadius: 4,
      onSelect: () async {
        await Clipboard.setData(ClipboardData(text: url));
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                tr(context, '{label} copied to clipboard', {'label': label}),
              ),
            ),
          );
        }
      },
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Icon(Icons.copy, size: 16, color: AppTheme.accent),
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final urlText = Text(
            masked,
            maxLines: constraints.maxWidth < 480 ? 3 : 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.text,
              fontFamily: 'monospace',
              height: 1.4,
            ),
          );
          // Narrow (phone) layout: label above, URL below, copy button beside.
          if (constraints.maxWidth < 480) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 12, color: AppTheme.muted),
                ),
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: urlText),
                    copyButton,
                  ],
                ),
              ],
            );
          }
          return Row(
            children: [
              SizedBox(
                width: 140,
                child: Text(
                  label,
                  style: TextStyle(fontSize: 12, color: AppTheme.muted),
                ),
              ),
              Expanded(child: urlText),
              copyButton,
            ],
          );
        },
      ),
    );
  }
}

/// Standalone version used as the mobile "Account" tab (no sheet chrome, no
/// close button — the tab bar is the navigation).
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) =>
      const SafeArea(child: SettingsContent(showClose: false));
}

/// Panel chip in the Account page: tap to move this account to another panel.
class _PanelChip extends StatelessWidget {
  const _PanelChip({
    required this.panel,
    required this.active,
    required this.onTap,
  });

  final PanelPreset panel;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FocusRing(
      borderRadius: 20,
      onSelect: onTap,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
          decoration: BoxDecoration(
            color: active
                ? AppTheme.accent.withValues(alpha: 0.18)
                : AppTheme.card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: active ? AppTheme.accent : AppTheme.border,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (active) ...[
                Icon(Icons.check, size: 13, color: AppTheme.accent),
                const SizedBox(width: 6),
              ],
              Text(
                panel.name,
                style: TextStyle(
                  fontSize: 12.5,
                  color: active ? AppTheme.accent : AppTheme.text,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One remembered login in the Account page.
class _LoginRow extends StatelessWidget {
  const _LoginRow({
    required this.login,
    required this.active,
    required this.onUse,
    required this.onForget,
  });

  final SavedLogin login;
  final bool active;
  final VoidCallback onUse;
  final VoidCallback onForget;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: FocusRing(
        borderRadius: 14,
        onSelect: onUse,
        child: Container(
          padding: EdgeInsets.fromLTRB(12, 10, 6, 10),
          decoration: BoxDecoration(
            color: AppTheme.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: active ? AppTheme.accent : AppTheme.border,
            ),
          ),
          child: Row(
            children: [
              Icon(
                active ? Icons.person : Icons.person_outline,
                size: 18,
                color: active ? AppTheme.accent : AppTheme.muted,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      login.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppTheme.text,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      tr(context, '{server}  ·  last used {time}', {
                        'server': login.server,
                        'time': _ago(context, login.lastUsed),
                      }),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11, color: AppTheme.muted),
                    ),
                  ],
                ),
              ),
              if (!active)
                TextButton(
                  onPressed: onUse,
                  child: Text(
                    tr(context, 'Use'),
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              IconButton(
                tooltip: tr(context, 'Forget'),
                onPressed: onForget,
                icon: Icon(
                  Icons.delete_outline,
                  size: 16,
                  color: AppTheme.muted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _ago(BuildContext context, DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return tr(context, 'just now');
    if (d.inHours < 1) {
      return tr(context, '{minutes} min ago', {'minutes': d.inMinutes});
    }
    if (d.inDays < 1) return tr(context, '{hours} h ago', {'hours': d.inHours});
    return tr(context, '{days} d ago', {'days': d.inDays});
  }
}
