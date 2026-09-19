import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xtream_player/main.dart';
import 'package:xtream_player/models.dart';
import 'package:xtream_player/screens/home_screen.dart';
import 'package:xtream_player/store.dart';
import 'package:xtream_player/xtream_client.dart';

/// The Guide layout promises "now/next loads as you move": the EPG for a row is
/// fetched when that row takes focus, not for the whole list up front.
void main() {
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
          request.response.write(jsonEncode([
            {'category_id': '1', 'category_name': 'News'},
          ]));
        case 'get_live_streams':
          request.response.write(jsonEncode([
            {'stream_id': 101, 'name': 'Channel One', 'category_id': '1', 'stream_icon': ''},
            {'stream_id': 102, 'name': 'Channel Two', 'category_id': '1', 'stream_icon': ''},
          ]));
        case 'get_short_epg':
          epgCalls.add(request.uri.queryParameters['stream_id'] ?? '');
          request.response.write(jsonEncode({
            'epg_listings': [
              {
                'title': base64.encode(utf8.encode('Synthetic News Hour')),
                'description': base64.encode(utf8.encode('for tests')),
                'start_timestamp': '1784563200',
                'stop_timestamp': '1784566800',
              },
            ],
          }));
        default:
          request.response.write(jsonEncode({'user_info': {'auth': 1, 'username': 'demo'}}));
      }
      await request.response.close();
    });

    appState.layout = LayoutStyle.guide;
    appState.client = XtreamClient(
      server: 'http://127.0.0.1:${server.port}',
      username: 'demo',
      password: 'demo',
    );
    appState.items = [
      StreamItem(id: '101', name: 'Channel One', kind: 'live', categoryId: '1'),
      StreamItem(id: '102', name: 'Channel Two', kind: 'live', categoryId: '1'),
    ];
    appState.categories = [Category(id: '1', name: 'News')];
  });

  tearDown(() async => server.close(force: true));

  testWidgets('the guide lists rows with a now/next column', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('News'), findsWidgets);          // group header
    expect(find.text('Channel One'), findsOneWidget);
    expect(find.text('Channel Two'), findsOneWidget);
    expect(find.textContaining('Guide ·'), findsOneWidget);
    // Nothing is fetched until a row takes focus — the column shows a dash.
    expect(epgCalls, isEmpty);
    expect(find.text('—'), findsWidgets);
  });

}
