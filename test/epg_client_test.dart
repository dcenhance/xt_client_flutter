import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:xtream_player/models.dart';
import 'package:xtream_player/store.dart';
import 'package:xtream_player/xtream_client.dart';

/// No widget binding in this file on purpose: a widget test stubs every HTTP
/// request with a 400, so the panel-facing tests live on their own.
void main() {
  _storeEpg();

  late HttpServer server;
  final epgCalls = <String>[];

  setUp(() async {
    epgCalls.clear();
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      final action = request.uri.queryParameters['action'] ?? '';
      request.response.headers.contentType = ContentType.json;
      switch (action) {
        case 'get_live_categories':
          request.response.write(
            jsonEncode([
              {'category_id': '1', 'category_name': 'News'},
            ]),
          );
        case 'get_short_epg':
          epgCalls.add(request.uri.queryParameters['stream_id'] ?? '');
          request.response.write(
            jsonEncode({
              'epg_listings': [
                {
                  'title': base64.encode(utf8.encode('Synthetic News Hour')),
                  'description': base64.encode(utf8.encode('for tests')),
                  'start_timestamp': '1784563200',
                  'stop_timestamp': '1784566800',
                },
              ],
            }),
          );
        default:
          request.response.write(
            jsonEncode({
              'user_info': {'auth': 1, 'username': 'demo'},
            }),
          );
      }
      await request.response.close();
    });
  });

  tearDown(() async => server.close(force: true));

  test('the client parses a now/next reply from a real panel', () async {
    final c = XtreamClient(
      server: 'http://127.0.0.1:${server.port}',
      username: 'demo',
      password: 'demo',
    );
    final entries = await c.shortEpg('101');
    expect(entries, hasLength(1));
    expect(entries.first.title, 'Synthetic News Hour');
    expect(entries.first.timeLabel, isNotEmpty);
    expect(epgCalls, contains('101'));
  });

  test('EpgEntry.timeLabel renders the slot', () {
    final e = EpgEntry(
      title: 'x',
      description: '',
      start: DateTime(2026, 9, 19, 18, 0),
      end: DateTime(2026, 9, 19, 19, 0),
    );
    expect(e.timeLabel, '18:00–19:00');
    expect(EpgEntry(title: 'x', description: '').timeLabel, '');
  });
}

// The player still uses the EPG cache for live channel now/next data.
void _storeEpg() {
  test('loadEpgFor caches now/next for a live channel and skips VOD', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final asked = <String>[];
    server.listen((request) async {
      final action = request.uri.queryParameters['action'] ?? '';
      request.response.headers.contentType = ContentType.json;
      if (action == 'get_short_epg') {
        asked.add(request.uri.queryParameters['stream_id'] ?? '');
        request.response.write(
          jsonEncode({
            'epg_listings': [
              {
                'title': base64.encode(utf8.encode('Synthetic News Hour')),
                'description': base64.encode(utf8.encode('for tests')),
                'start_timestamp': '1784563200',
                'stop_timestamp': '1784566800',
              },
            ],
          }),
        );
      } else {
        request.response.write(
          jsonEncode({
            'user_info': {'auth': 1, 'username': 'demo'},
          }),
        );
      }
      await request.response.close();
    });

    final state = AppState()
      ..client = XtreamClient(
        server: 'http://127.0.0.1:${server.port}',
        username: 'demo',
        password: 'demo',
      );
    final live = StreamItem(id: '101', name: 'Channel One', kind: 'live');
    final movie = StreamItem(id: '555', name: 'A Film', kind: 'movie');

    await state.loadEpgFor(live);
    expect(state.epgCache['101'], hasLength(1));
    expect(state.epgCache['101']!.first.title, 'Synthetic News Hour');
    expect(state.epgCache['101']!.first.timeLabel, isNotEmpty);

    // Second call is a cache hit, and VOD never asks.
    await state.loadEpgFor(live);
    await state.loadEpgFor(movie);
    expect(asked, ['101']);
    expect(state.epgCache.containsKey('555'), isFalse);

    await server.close(force: true);
  }, timeout: const Timeout(Duration(seconds: 60)));
}
