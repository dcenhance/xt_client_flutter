/// Minimal, dependency-light Xtream-Codes API client.
///
/// Speaks exactly the protocol the Spectre/XCIPTV app uses:
///   `GET <server>/player_api.php?username=..&password=..[&action=..]`
/// plus the derived playlists and stream URLs.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'models.dart';

/// Addresses that mean "this record points nowhere" rather than at a server.
/// Loopback is deliberately absent: 127.0.0.1 is a legitimate panel address.
const placeholderAddresses = {
  '1.1.1.1',
  '1.0.0.1',
  '0.0.0.0',
  '192.0.2.1',
  '198.51.100.1',
  '203.0.113.1',
};

/// What went wrong, in a way the UI can explain to a human.
enum XtreamErrorKind {
  unreachable,
  tlsMismatch,
  deadDns,
  http,
  badResponse,
  rejected,
  expired,
  wrongServer,
}

class XtreamException implements Exception {
  final XtreamErrorKind kind;
  final String message;
  final int? statusCode;
  final String? body;

  XtreamException(this.kind, this.message, {this.statusCode, this.body});

  String get hint {
    switch (kind) {
      case XtreamErrorKind.unreachable:
        return 'The host did not answer at all. Usual causes: wrong hostname/port, '
            'DNS pointing somewhere dead, firewall, or the panel not listening on that port.';
      case XtreamErrorKind.tlsMismatch:
        return 'That port speaks plain HTTP, not TLS — drop the https:// (Xtream panels are '
            'normally http://host:8080). The app already retries over http, so reaching this '
            'message means the http attempt failed too.';
      case XtreamErrorKind.deadDns:
        return 'The hostname resolves to an address that cannot run a panel (Cloudflare uses '
            '1.1.1.1 / 1.0.0.1 when a DNS record points nowhere). Nothing sent there can reach a '
            'server, so the username and password are never even transmitted. Ask whoever supplied '
            'the address for the current host, or paste their host list into "Test a list of servers".';
      case XtreamErrorKind.wrongServer:
        return 'Either the address is not a valid URL (expected http://host:8080) or something '
            'answered that is not an Xtream panel (no JSON).';
      case XtreamErrorKind.http:
        if ((body ?? '').contains('1034')) {
          return "Cloudflare error 1034 means the domain's DNS record points at a placeholder "
              'address (e.g. 1.1.1.1), so no request ever reaches a server. No client can log in '
              'until the provider fixes that record — the credentials are not the problem.';
        }
        return 'The panel answered with HTTP $statusCode but not with playlist JSON. '
            'Many panels use 401/403/511/512 for "not allowed from this IP" or "bad credentials".';
      case XtreamErrorKind.rejected:
        return 'The panel is reachable and refused these credentials: wrong username/password, '
            'expired subscription, or too many connections in use.';
      case XtreamErrorKind.expired:
        return 'The account exists but its expiry date has passed.';
      case XtreamErrorKind.badResponse:
        return 'The panel returned data this client could not parse.';
    }
  }

  @override
  String toString() => message;
}

class XtreamClient {
  XtreamClient({
    required this.server,
    required this.username,
    required this.password,
    Duration? timeout,
    this.resolvedAddressesOverride,
  }) : _timeout = timeout ?? const Duration(seconds: 20);

  final String server; // normalised, e.g. http://host:8080
  final String username;
  final String password;

  final Duration _timeout;

  /// Test seam: pretend the hostname resolved to these addresses instead of
  /// asking the system resolver.
  final List<String>? resolvedAddressesOverride;

  /// The base URL that actually worked, when it differs from what was typed
  /// (e.g. the user typed https:// and the panel only speaks http://).
  String? _effectiveServer;
  String get effectiveServer => _effectiveServer ?? server;

  bool get isHttps => server.startsWith('https://');

  /// Accepts "host:8080", "http://host:8080/", "https://host" and returns a clean base URL.
  static String normaliseServer(String raw) {
    var s = raw.trim();
    if (s.isEmpty) return s;
    if (!s.startsWith('http://') && !s.startsWith('https://')) {
      s = 'http://$s';
    }
    while (s.endsWith('/')) {
      s = s.substring(0, s.length - 1);
    }
    return s;
  }

  Uri _api([Map<String, String> extra = const {}]) {
    _ensureValidServer();
    final params = <String, String>{
      'username': username,
      'password': password,
      ...extra,
    };
    return Uri.parse('$effectiveServer/player_api.php').replace(queryParameters: params);
  }

  /// Rejects malformed addresses with a readable message instead of letting
  /// `Uri.parse` throw a raw FormatException into the UI.
  void _ensureValidServer() {
    try {
      final uri = Uri.parse(server);
      if (uri.host.isEmpty) {
        throw const FormatException('no host name');
      }
      uri.port; // forces port validation
    } on FormatException catch (e) {
      throw XtreamException(
        XtreamErrorKind.wrongServer,
        'The server address "$server" is not a valid URL (${e.message}).',
      );
    }
  }

  Future<dynamic> _getJson(Uri uri) async {
    try {
      return await _getJsonRaw(uri);
    } on XtreamException catch (e) {
      // https:// to a plain-HTTP panel: retry the same host and port over http
      // instead of telling the user the host is dead.
      if (e.kind == XtreamErrorKind.tlsMismatch && uri.scheme == 'https') {
        final retry = uri.replace(scheme: 'http');
        final result = await _getJsonRaw(retry);
        _effectiveServer = 'http://${uri.host}:${uri.port}';
        return result;
      }
      rethrow;
    }
  }

  /// Resolves the host and returns a placeholder address if there is one,
  /// otherwise null. Never throws.
  Future<String?> _placeholderAddress() async {
    final host = Uri.tryParse(server)?.host ?? '';
    if (host.isEmpty) return null;
    try {
      final addresses = resolvedAddressesOverride ??
          (await InternetAddress.lookup(host)).map((a) => a.address).toList();
      for (final a in addresses) {
        if (placeholderAddresses.contains(a)) return a;
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  Future<dynamic> _getJsonRaw(Uri uri) async {
    http.Response res;
    try {
      res = await http
          .get(uri, headers: {'User-Agent': 'XtreamPlayer/0.1 (Flutter)'})
          .timeout(_timeout);
    } on TimeoutException {
      throw XtreamException(XtreamErrorKind.unreachable, 'Timed out talking to $server');
    } on HandshakeException catch (e) {
      throw XtreamException(
        XtreamErrorKind.tlsMismatch,
        'TLS handshake with ${uri.host}:${uri.port} failed: ${e.message}',
      );
    } on TlsException catch (e) {
      throw XtreamException(
        XtreamErrorKind.tlsMismatch,
        'TLS handshake with ${uri.host}:${uri.port} failed: ${e.message}',
      );
    } on SocketException catch (e) {
      throw XtreamException(
        XtreamErrorKind.unreachable,
        'Cannot reach $server: ${e.osError?.message ?? e.message}',
      );
    } on HttpException catch (e) {
      throw XtreamException(XtreamErrorKind.unreachable, 'HTTP failure to $server: ${e.message}');
    } catch (e) {
      final text = '$e';
      if (text.contains('WRONG_VERSION_NUMBER') || text.contains('HandshakeException')) {
        throw XtreamException(
          XtreamErrorKind.tlsMismatch,
          'TLS handshake with ${uri.host}:${uri.port} failed: $text',
        );
      }
      throw XtreamException(XtreamErrorKind.unreachable, 'Cannot reach $server: $text');
    }

    final body = res.body.trim();
    final looksJson = body.startsWith('{') || body.startsWith('[');
    if (!looksJson) {
      // A TLS server answering an http:// request sends a binary record header.
      if (body.isNotEmpty && (body.codeUnitAt(0) == 0x16 || body.contains('\u0016\u0003'))) {
        throw XtreamException(
          XtreamErrorKind.tlsMismatch,
          '$server answered with TLS, so it needs https://',
        );
      }
      final looksCloudflareDns =
          body.contains('error code: 1034') || body.contains('Error 1034');
      if (looksCloudflareDns) {
        throw XtreamException(
          XtreamErrorKind.http,
          "Cloudflare could not reach the origin ($server): error code 1034",
          statusCode: res.statusCode,
          body: body,
        );
      }
      if (res.statusCode >= 400) {
        throw XtreamException(
          XtreamErrorKind.http,
          'HTTP ${res.statusCode} from $server',
          statusCode: res.statusCode,
          body: body,
        );
      }
      throw XtreamException(
        XtreamErrorKind.wrongServer,
        'Non-JSON reply from $server',
        statusCode: res.statusCode,
        body: body,
      );
    }
    try {
      return jsonDecode(body);
    } catch (e) {
      throw XtreamException(XtreamErrorKind.badResponse, 'Could not parse JSON from $server');
    }
  }

  /// Logs in and returns the account block. Throws [XtreamException] when the
  /// panel is unreachable or refuses the credentials.
  Future<AccountInfo> login() async {
    _ensureValidServer();
    dynamic data;
    try {
      data = await _getJson(_api());
    } on XtreamException catch (e) {
      // Before blaming credentials, ports or TLS: check whether the hostname
      // points at a placeholder address. Then nothing can ever work.
      const overridable = {
        XtreamErrorKind.unreachable,
        XtreamErrorKind.tlsMismatch,
        XtreamErrorKind.http,
      };
      if (overridable.contains(e.kind)) {
        final dead = await _placeholderAddress();
        if (dead != null) {
          final host = Uri.tryParse(server)?.host ?? server;
          throw XtreamException(
            XtreamErrorKind.deadDns,
            'DNS for $host points at $dead, a placeholder address — no server is reachable there',
            statusCode: e.statusCode,
            body: dead,
          );
        }
      }
      rethrow;
    }
    if (data is! Map) {
      throw XtreamException(XtreamErrorKind.badResponse, 'Unexpected login response');
    }
    final info = AccountInfo.fromJson(data.cast<String, dynamic>(), username: username);
    if (!info.authenticated) {
      if (info.expired) {
        throw XtreamException(
          XtreamErrorKind.expired,
          info.message ?? 'Account expired on ${info.expiryLabel}',
        );
      }
      throw XtreamException(
        XtreamErrorKind.rejected,
        info.message != null && info.message!.isNotEmpty
            ? 'Panel refused these credentials (panel said: "${info.message}")'
            : 'Panel refused these credentials',
      );
    }
    return info;
  }

  Future<List<Category>> _categories(String action) async {
    final data = await _getJson(_api({'action': action}));
    if (data is! List) return const [];
    return data
        .whereType<Map>()
        .map((e) => Category.fromJson(e.cast<String, dynamic>()))
        .where((c) => c.id.isNotEmpty)
        .toList();
  }

  Future<List<StreamItem>> _streams(String action, {String? categoryId}) async {
    final data = await _getJson(_api({
      'action': action,
      if (categoryId != null && categoryId.isNotEmpty) 'category_id': categoryId,
    }));
    if (data is! List) return const [];
    return data.whereType<Map>().map((e) {
      final m = e.cast<String, dynamic>();
      switch (action) {
        case 'get_vod_streams':
          return StreamItem.fromVod(m);
        case 'get_series':
          return StreamItem.fromSeries(m);
        default:
          return StreamItem.fromLive(m);
      }
    }).toList();
  }

  Future<List<Category>> liveCategories() => _categories('get_live_categories');
  Future<List<Category>> vodCategories() => _categories('get_vod_categories');
  Future<List<Category>> seriesCategories() => _categories('get_series_categories');

  Future<List<StreamItem>> liveStreams({String? categoryId}) =>
      _streams('get_live_streams', categoryId: categoryId);
  Future<List<StreamItem>> vodStreams({String? categoryId}) =>
      _streams('get_vod_streams', categoryId: categoryId);
  Future<List<StreamItem>> series({String? categoryId}) =>
      _streams('get_series', categoryId: categoryId);

  /// Now/next for a channel. Returns an empty list when the panel has no EPG.
  Future<List<EpgEntry>> shortEpg(String streamId, {int limit = 2}) async {
    try {
      final data = await _getJson(_api({
        'action': 'get_short_epg',
        'stream_id': streamId,
        'limit': '$limit',
      }));
      if (data is! Map) return const [];
      final list = data['epg_listings'];
      if (list is! List) return const [];
      return list
          .whereType<Map>()
          .map((e) => EpgEntry.fromJson(e.cast<String, dynamic>()))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  String liveUrl(StreamItem item, {String? extension}) {
    final ext = extension ?? 'ts';
    return '$effectiveServer/live/$username/$password/${item.id}.$ext';
  }

  String vodUrl(StreamItem item) =>
      '$effectiveServer/movie/$username/$password/${item.id}.${item.containerExtension ?? 'mp4'}';

  String seriesEpisodeUrl(String episodeId, String extension) =>
      '$effectiveServer/series/$username/$password/$episodeId.$extension';

  /// Series episodes need one extra call: action=get_series_info&series_id=..
  Future<List<StreamItem>> seriesEpisodes(StreamItem series) async {
    final data = await _getJson(_api({
      'action': 'get_series_info',
      'series_id': series.id,
    }));
    if (data is! Map) return const [];
    final episodes = data['episodes'];
    if (episodes is! Map) return const [];
    final out = <StreamItem>[];
    for (final season in episodes.keys) {
      final list = episodes[season];
      if (list is! List) continue;
      for (final ep in list.whereType<Map>()) {
        final m = ep.cast<String, dynamic>();
        out.add(StreamItem(
          id: (m['id'] ?? '').toString(),
          name: 'S${season.padLeft(2, '0')}E${'${m['episode_num'] ?? 0}'.padLeft(2, '0')} · '
              '${m['title'] ?? 'Episode'}',
          kind: 'episode',
          containerExtension: (m['container_extension'] ?? 'mp4').toString(),
          icon: series.icon,
          plot: m['info'] is Map ? (m['info']['plot']?.toString()) : null,
        ));
      }
    }
    return out;
  }

  String playlistUrl({bool hls = false}) =>
      '$effectiveServer/get.php?username=$username&password=$password&type=m3u_plus&output=${hls ? 'm3u8' : 'ts'}';

  String epgUrl() => '$effectiveServer/xmltv.php?username=$username&password=$password';
}