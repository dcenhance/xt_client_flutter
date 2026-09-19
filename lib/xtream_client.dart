/// Minimal, dependency-light Xtream-Codes API client.
///
/// Speaks exactly the protocol the Spectre/XCIPTV app uses:
///   GET <server>/player_api.php?username=..&password=..[&action=..]
/// plus the derived playlists and stream URLs.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'models.dart';

/// What went wrong, in a way the UI can explain to a human.
enum XtreamErrorKind { unreachable, http, badResponse, rejected, expired, wrongServer }

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
      case XtreamErrorKind.wrongServer:
        return 'Either the address is not a valid URL (expected http://host:8080) or something '
            'answered that is not an Xtream panel (no JSON).';
      case XtreamErrorKind.http:
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
  XtreamClient({required this.server, required this.username, required this.password});

  final String server; // normalised, e.g. http://host:8080
  final String username;
  final String password;

  static const _timeout = Duration(seconds: 20);

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
    return Uri.parse('$server/player_api.php').replace(queryParameters: params);
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
    http.Response res;
    try {
      res = await http
          .get(uri, headers: {'User-Agent': 'XtreamPlayer/0.1 (Flutter)'})
          .timeout(_timeout);
    } on TimeoutException {
      throw XtreamException(XtreamErrorKind.unreachable, 'Timed out talking to $server');
    } on SocketException catch (e) {
      throw XtreamException(
        XtreamErrorKind.unreachable,
        'Cannot reach $server: ${e.osError?.message ?? e.message}',
      );
    } on HttpException catch (e) {
      throw XtreamException(XtreamErrorKind.unreachable, 'HTTP failure to $server: ${e.message}');
    } catch (e) {
      throw XtreamException(XtreamErrorKind.unreachable, 'Cannot reach $server: $e');
    }

    final body = res.body.trim();
    final looksJson = body.startsWith('{') || body.startsWith('[');
    if (!looksJson) {
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
    final data = await _getJson(_api());
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
        info.message ?? 'Panel refused username/password',
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
    return '$server/live/$username/$password/${item.id}.$ext';
  }

  String vodUrl(StreamItem item) =>
      '$server/movie/$username/$password/${item.id}.${item.containerExtension ?? 'mp4'}';

  String seriesEpisodeUrl(String episodeId, String extension) =>
      '$server/series/$username/$password/$episodeId.$extension';

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
      '$server/get.php?username=$username&password=$password&type=m3u_plus&output=${hls ? 'm3u8' : 'ts'}';

  String epgUrl() => '$server/xmltv.php?username=$username&password=$password';
}