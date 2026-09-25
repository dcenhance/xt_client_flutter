/// Data models for the Xtream-Codes API.
library;

import 'dart:convert';

import 'l10n.dart';

class AccountInfo {
  final bool authenticated;
  final String? status;
  final String username;
  final String? message;
  final DateTime? expiresAt;
  final int maxConnections;
  final int activeConnections;
  final bool isTrial;
  final List<String> allowedOutputFormats;
  final String? serverUrl;
  final String? serverPort;
  final String? httpsPort;
  final String? serverProtocol;
  final String? timezone;

  AccountInfo({
    required this.authenticated,
    required this.username,
    this.status,
    this.message,
    this.expiresAt,
    this.maxConnections = 0,
    this.activeConnections = 0,
    this.isTrial = false,
    this.allowedOutputFormats = const ['ts'],
    this.serverUrl,
    this.serverPort,
    this.httpsPort,
    this.serverProtocol,
    this.timezone,
  });

  bool get expired => expiresAt != null && expiresAt!.isBefore(DateTime.now());

  String get expiryLabel {
    if (expiresAt == null) return trCurrent('unlimited');
    final d = expiresAt!;
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}.${two(d.month)}.${d.year} ${two(d.hour)}:${two(d.minute)}';
  }

  static DateTime? _date(dynamic value) {
    if (value == null) return null;
    final s = value.toString();
    if (s.isEmpty || s == 'null') return null;
    final asInt = int.tryParse(s);
    if (asInt != null && asInt > 0) {
      return DateTime.fromMillisecondsSinceEpoch(asInt * 1000);
    }
    return DateTime.tryParse(s);
  }

  factory AccountInfo.fromJson(Map<String, dynamic> json, {String? username}) {
    final user = (json['user_info'] as Map?)?.cast<String, dynamic>() ?? {};
    final server = (json['server_info'] as Map?)?.cast<String, dynamic>() ?? {};
    final auth = user['auth'];
    final formats =
        (user['allowed_output_formats'] as List?)
            ?.map((e) => e.toString())
            .toList() ??
        const ['ts'];
    return AccountInfo(
      authenticated: auth == 1 || auth == '1' || auth == true,
      username: (user['username'] ?? username ?? '').toString(),
      status: user['status']?.toString(),
      message: user['message']?.toString(),
      expiresAt: _date(user['exp_date']),
      maxConnections: int.tryParse('${user['max_connections'] ?? 0}') ?? 0,
      activeConnections: int.tryParse('${user['active_cons'] ?? 0}') ?? 0,
      isTrial: '${user['is_trial'] ?? 0}' == '1',
      allowedOutputFormats: formats.isEmpty ? const ['ts'] : formats,
      serverUrl: server['url']?.toString(),
      serverPort: server['port']?.toString(),
      httpsPort: server['https_port']?.toString(),
      serverProtocol: server['server_protocol']?.toString(),
      timezone: server['timezone']?.toString(),
    );
  }
}

class Category {
  final String id;
  final String name;
  Category({required this.id, required this.name});

  factory Category.fromJson(Map<String, dynamic> j) => Category(
    id: (j['category_id'] ?? '').toString(),
    name: (j['category_name'] ?? trCurrent('Unknown')).toString(),
  );
}

/// A live channel, movie or series episode-less entry.
class StreamItem {
  final String id;
  final String name;
  final String? icon;
  final String? categoryId;
  final String kind; // live | movie | series
  final String? containerExtension;
  final String? epgChannelId;
  final String? plot;
  final String? genre;
  final String? rating;
  final bool hasArchive;

  StreamItem({
    required this.id,
    required this.name,
    required this.kind,
    this.icon,
    this.categoryId,
    this.containerExtension,
    this.epgChannelId,
    this.plot,
    this.genre,
    this.rating,
    this.hasArchive = false,
  });

  factory StreamItem.fromLive(Map<String, dynamic> j) => StreamItem(
    id: (j['stream_id'] ?? '').toString(),
    name: (j['name'] ?? trCurrent('Unnamed')).toString(),
    icon: _clean(j['stream_icon']),
    categoryId: j['category_id']?.toString(),
    kind: 'live',
    epgChannelId: j['epg_channel_id']?.toString(),
    hasArchive: '${j['tv_archive'] ?? 0}' == '1',
  );

  factory StreamItem.fromVod(Map<String, dynamic> j) => StreamItem(
    id: (j['stream_id'] ?? '').toString(),
    name: (j['name'] ?? trCurrent('Unnamed')).toString(),
    icon: _clean(j['stream_icon']),
    categoryId: j['category_id']?.toString(),
    kind: 'movie',
    containerExtension: (j['container_extension'] ?? 'mp4').toString(),
    rating: j['rating']?.toString(),
    genre: j['genre']?.toString(),
  );

  factory StreamItem.fromSeries(Map<String, dynamic> j) => StreamItem(
    id: (j['series_id'] ?? '').toString(),
    name: (j['name'] ?? trCurrent('Unnamed')).toString(),
    icon: _clean(j['cover'] ?? j['stream_icon']),
    categoryId: j['category_id']?.toString(),
    kind: 'series',
    plot: j['plot']?.toString(),
    genre: j['genre']?.toString(),
    rating: j['rating']?.toString(),
  );

  static String? _clean(dynamic v) {
    final s = v?.toString();
    if (s == null || s.isEmpty || s == 'null') return null;
    return s;
  }
}

class EpgEntry {
  final String title;
  final String description;
  final DateTime? start;
  final DateTime? end;
  EpgEntry({
    required this.title,
    required this.description,
    this.start,
    this.end,
  });

  /// "18:00–19:00", or an empty string when the panel sent no timestamps.
  String get timeLabel {
    String two(int v) => v.toString().padLeft(2, '0');
    if (start == null) return '';
    final from = '${two(start!.hour)}:${two(start!.minute)}';
    if (end == null) return from;
    return '$from–${two(end!.hour)}:${two(end!.minute)}';
  }

  factory EpgEntry.fromJson(Map<String, dynamic> j) => EpgEntry(
    title: _b64(j['title']),
    description: _b64(j['description']),
    start: _ts(j['start_timestamp']),
    end: _ts(j['stop_timestamp']),
  );

  static DateTime? _ts(dynamic v) {
    final i = int.tryParse('${v ?? ''}');
    return i == null ? null : DateTime.fromMillisecondsSinceEpoch(i * 1000);
  }

  static String _b64(dynamic v) {
    if (v == null) return '';
    try {
      return Uri.decodeComponent(
        String.fromCharCodes(base64Decode(v.toString().trim())),
      );
    } catch (_) {
      return v.toString();
    }
  }
}
