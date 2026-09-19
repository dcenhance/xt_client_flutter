/// In-app connectivity diagnostics.
///
/// The point is to answer, inside the app and with the user's own credentials:
///   * does the hostname resolve, and to what?
///   * is it a placeholder address (dead DNS record)?
///   * which ports answer like an Xtream panel, and do they accept this account?
///
/// Nothing here leaves the device except the login requests to the host the user
/// typed (and to the same host on other ports, when the typed port fails).
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'xtream_client.dart';

class PortProbe {
  final int port;
  final bool reachable;
  final int? statusCode;
  final bool xtreamLike;
  final bool authenticated;
  final String detail;

  PortProbe({
    required this.port,
    required this.reachable,
    this.statusCode,
    this.xtreamLike = false,
    this.authenticated = false,
    required this.detail,
  });

  String get label {
    if (!reachable) return 'port $port — no answer';
    if (authenticated) return 'port $port — Xtream panel, login accepted';
    if (xtreamLike) return 'port $port — Xtream panel, login refused';
    return 'port $port — HTTP $statusCode, not Xtream';
  }
}

class DiagnosticsResult {
  final String host;
  final int typedPort;
  final bool schemeIsHttps;
  final List<String> addresses;
  final bool placeholderDns;
  final List<PortProbe> probes;
  final String verdict;

  DiagnosticsResult({
    required this.host,
    required this.typedPort,
    required this.schemeIsHttps,
    required this.addresses,
    required this.placeholderDns,
    required this.probes,
    required this.verdict,
  });

  /// A host:port that accepted the login, if any probe found one.
  String? get workingHost {
    for (final p in probes) {
      if (p.authenticated) {
        final scheme = schemeIsHttps ? 'https' : 'http';
        return '$scheme://$host:${p.port}';
      }
    }
    return null;
  }

  List<String> get report {
    final lines = <String>[];
    lines.add('DNS: $host → ${addresses.isEmpty ? "no address" : addresses.join(", ")}');
    if (placeholderDns) {
      lines.add('That address is a placeholder, not a server.');
    }
    for (final p in probes) {
      lines.add(p.label);
      if (p.detail.isNotEmpty) lines.add('    ${p.detail}');
    }
    lines.add('');
    lines.add(verdict);
    return lines;
  }
}

class Diagnostics {
  /// Ports tried when the typed one does not answer like a panel.
  static const candidatePorts = <int>[8080, 80, 8880, 8000, 25461, 2095, 9000];

  static const _probeTimeout = Duration(seconds: 8);

  static Future<DiagnosticsResult> run({
    required String server,
    required String username,
    required String password,
    Duration timeout = _probeTimeout,
    List<String>? resolvedAddressesOverride,
  }) async {
    final normalised = XtreamClient.normaliseServer(server);
    final uri = Uri.tryParse(normalised);
    final host = uri?.host ?? '';
    final schemeIsHttps = (uri?.scheme ?? 'http') == 'https';
    final typedPort = (uri != null && uri.hasPort)
        ? uri.port
        : (schemeIsHttps ? 443 : 80);

    final addresses = <String>[];
    var placeholder = false;
    if (resolvedAddressesOverride != null) {
      addresses.addAll(resolvedAddressesOverride);
      placeholder = resolvedAddressesOverride.any(placeholderAddresses.contains);
    } else if (host.isNotEmpty) {
      try {
        final lookups = await InternetAddress.lookup(host);
        for (final a in lookups) {
          addresses.add(a.address);
          if (placeholderAddresses.contains(a.address)) placeholder = true;
        }
      } on SocketException catch (e) {
        addresses.add('lookup failed: ${e.osError?.message ?? e.message}');
      }
    }

    final ports = <int>{typedPort, ...candidatePorts};
    final probes = await Future.wait(
      ports.map((p) => _probe(
            host: host,
            port: p,
            https: schemeIsHttps && p == typedPort,
            username: username,
            password: password,
            timeout: timeout,
          )),
    );
    probes.sort((a, b) => a.port == typedPort
        ? -1
        : b.port == typedPort
            ? 1
            : a.port.compareTo(b.port));

    return DiagnosticsResult(
      host: host,
      typedPort: typedPort,
      schemeIsHttps: schemeIsHttps,
      addresses: addresses,
      placeholderDns: placeholder,
      probes: probes,
      verdict: _verdict(
        placeholder: placeholder,
        host: host,
        typedPort: typedPort,
        probes: probes,
      ),
    );
  }

  static Future<PortProbe> _probe({
    required String host,
    required int port,
    required bool https,
    required String username,
    required String password,
    required Duration timeout,
  }) async {
    if (host.isEmpty) {
      return PortProbe(port: port, reachable: false, detail: 'no hostname given');
    }
    final scheme = https ? 'https' : 'http';
    final url = Uri.parse('$scheme://$host:$port/player_api.php').replace(queryParameters: {
      'username': username,
      'password': password,
    });

    final client = HttpClient()..connectionTimeout = timeout;
    client.badCertificateCallback = (_, _, _) => true;
    try {
      final req = await client.getUrl(url).timeout(timeout);
      final res = await req.close().timeout(timeout);
      final body = await res.transform(utf8.decoder).join().timeout(timeout);
      final looksJson = body.trimLeft().startsWith('{');
      var xtreamLike = false;
      var authenticated = false;
      if (looksJson && (body.contains('user_info') || body.contains('server_info'))) {
        xtreamLike = true;
        try {
          final decoded = jsonDecode(body);
          final auth = (decoded['user_info'] as Map?)?['auth'];
          authenticated = auth == 1 || auth == '1' || auth == true;
        } catch (_) {
          // keep xtreamLike, auth unknown
        }
      }
      var detail = '';
      if (!xtreamLike) {
        final snippet = body.trim().replaceAll(RegExp(r'\s+'), ' ').take(120);
        if (snippet.isNotEmpty) detail = 'said: "$snippet"';
        if (body.contains('1034')) {
          detail = 'Cloudflare error 1034 — the DNS record points at a placeholder, '
              'nothing is listening behind it';
        }
      }
      return PortProbe(
        port: port,
        reachable: true,
        statusCode: res.statusCode,
        xtreamLike: xtreamLike,
        authenticated: authenticated,
        detail: detail,
      );
    } on TimeoutException {
      return PortProbe(port: port, reachable: false, detail: 'timed out');
    } on SocketException catch (e) {
      return PortProbe(port: port, reachable: false, detail: e.osError?.message ?? e.message);
    } on HandshakeException catch (e) {
      return PortProbe(port: port, reachable: false, detail: 'TLS failed: ${e.message}');
    } catch (e) {
      return PortProbe(port: port, reachable: false, detail: '$e');
    } finally {
      client.close(force: true);
    }
  }

  static String _verdict({
    required bool placeholder,
    required String host,
    required int typedPort,
    required List<PortProbe> probes,
  }) {
    final working = probes.where((p) => p.authenticated).toList();
    if (working.isNotEmpty) {
      final p = working.first;
      return 'Login works on $host:$p.port — tap "Use this server" below.';
    }
    // A panel that answered and refused the login outranks every other
    // explanation: the network is fine, the credentials are the problem.
    final panelRefused = probes.where((p) => p.xtreamLike && !p.authenticated).toList();
    if (panelRefused.isNotEmpty) {
      return 'Verdict: the panel is reachable on port ${panelRefused.first.port} but refused these '
          'credentials — wrong username/password, an expired subscription, or too many connections.';
    }
    final answered = probes.where((p) => p.reachable && !p.xtreamLike).toList();
    if (placeholder) {
      // Cloudflare answers on every port with a 1034 page, so this has to be
      // checked before the generic "host answered" branch.
      return 'Verdict: $host resolves to a placeholder address (Cloudflare uses 1.1.1.1 / 1.0.0.1 '
          'when a DNS record points nowhere). No request can reach a server there, so the username '
          'and password are never even sent. This has to be fixed by whoever gave you the address — '
          'ask them for the current panel host; if an app you used before still logs in, it is '
          'talking to a different host.';
    }
    if (answered.isNotEmpty) {
      return 'Verdict: the host answers (HTTP ${answered.first.statusCode}) but not as an Xtream '
          'panel. Most often that is an IP/network gate (401/403/511/512) or a wrong port — the '
          'detail lines above say which.';
    }
    return 'Verdict: nothing answered on $host (typed port $typedPort and the usual panel ports). '
        'Either the host is offline or firewalled, or the address is wrong.';
  }
}

extension _Take on String {
  String take(int n) => length <= n ? this : '${substring(0, n)}…';
}

/// One line of "test a list of servers" output.
class CandidateResult {
  final String server;
  final bool ok;
  final String note;

  CandidateResult({required this.server, required this.ok, required this.note});
}

/// Tries the same credentials against several hosts, for the case where the
/// address in hand is dead and the provider gave (or gives) more than one.
Future<List<CandidateResult>> testServers({
  required List<String> servers,
  required String username,
  required String password,
  Duration timeout = const Duration(seconds: 12),
}) async {
  final cleaned = servers
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty && !s.startsWith('#'))
      .toList();
  final results = <CandidateResult>[];
  for (final raw in cleaned) {
    final client = XtreamClient(
      server: XtreamClient.normaliseServer(raw),
      username: username,
      password: password,
      timeout: timeout,
    );
    try {
      final info = await client.login();
      results.add(CandidateResult(
        server: client.server,
        ok: true,
        note: info.expired
            ? 'login ok but EXPIRED ${info.expiryLabel}'
            : 'login ok · expires ${info.expiryLabel} · '
                '${info.activeConnections}/${info.maxConnections} conn',
      ));
    } on XtreamException catch (e) {
      results.add(CandidateResult(server: raw, ok: false, note: e.message));
    } catch (e) {
      results.add(CandidateResult(server: raw, ok: false, note: '$e'));
    }
  }
  return results;
}