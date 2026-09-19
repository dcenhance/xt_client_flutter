import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:xtream_player/models.dart';
import 'package:xtream_player/xtream_client.dart';

/// Spins up a tiny fake Xtream panel so the client is tested against real HTTP
/// instead of mocks — the same request shape the phone app makes.
Future<HttpServer> startPanel({required String body, int status = 200}) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  server.listen((request) async {
    request.response.statusCode = status;
    request.response.headers.contentType = ContentType.json;
    request.response.write(body);
    await request.response.close();
  });
  return server;
}

void main() {
  group('XtreamClient.normaliseServer', () {
    test('adds scheme and strips trailing slash', () {
      expect(XtreamClient.normaliseServer('host:8080'), 'http://host:8080');
      expect(XtreamClient.normaliseServer('http://host:8080/'), 'http://host:8080');
      expect(XtreamClient.normaliseServer(' https://host '), 'https://host');
    });
  });

  test('successful login parses the account block', () async {
    final body = jsonEncode({
      'user_info': {
        'username': 'someone',
        'auth': 1,
        'status': 'Active',
        'exp_date': '1790000000',
        'max_connections': '2',
        'active_cons': '1',
        'is_trial': '0',
        'allowed_output_formats': ['m3u8', 'ts'],
      },
      'server_info': {'url': 'panel.example', 'port': '8080', 'server_protocol': 'http'},
    });
    final server = await startPanel(body: body);
    final client = XtreamClient(
      server: 'http://127.0.0.1:${server.port}',
      username: 'someone',
      password: 'secret',
    );
    final info = await client.login();
    expect(info.authenticated, isTrue);
    expect(info.maxConnections, 2);
    expect(info.allowedOutputFormats, contains('m3u8'));
    expect(info.expired, isFalse);
    await server.close(force: true);
  });

  test('auth:0 is reported as rejected credentials', () async {
    final server = await startPanel(
      body: jsonEncode({'user_info': {'auth': 0, 'status': 'Disabled'}}),
    );
    final client = XtreamClient(
      server: 'http://127.0.0.1:${server.port}',
      username: 'x',
      password: 'y',
    );
    await expectLater(
      client.login(),
      throwsA(isA<XtreamException>()
          .having((e) => e.kind, 'kind', XtreamErrorKind.rejected)),
    );
    await server.close(force: true);
  });

  test('expired account is reported as expired', () async {
    final server = await startPanel(
      body: jsonEncode({
        'user_info': {'auth': 0, 'status': 'Expired', 'exp_date': '1600000000'},
      }),
    );
    final client = XtreamClient(
      server: 'http://127.0.0.1:${server.port}',
      username: 'x',
      password: 'y',
    );
    await expectLater(
      client.login(),
      throwsA(isA<XtreamException>()
          .having((e) => e.kind, 'kind', XtreamErrorKind.expired)),
    );
    await server.close(force: true);
  });

  test('Cloudflare-style 403 is an HTTP error, not bad credentials', () async {
    final server = await startPanel(body: 'error code: 1034', status: 403);
    final client = XtreamClient(
      server: 'http://127.0.0.1:${server.port}',
      username: 'x',
      password: 'y',
    );
    await expectLater(
      client.login(),
      throwsA(isA<XtreamException>()
          .having((e) => e.kind, 'kind', XtreamErrorKind.http)
          .having((e) => e.statusCode, 'status', 403)),
    );
    await server.close(force: true);
  });

  test('closed port is reported as unreachable', () async {
    final probe = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final port = probe.port;
    await probe.close(force: true);
    final client = XtreamClient(
      server: 'http://127.0.0.1:$port',
      username: 'x',
      password: 'y',
    );
    await expectLater(
      client.login(),
      throwsA(isA<XtreamException>()
          .having((e) => e.kind, 'kind', XtreamErrorKind.unreachable)),
    );
  });

  test('stream URL shapes follow the Xtream specification', () {
    final client = XtreamClient(
      server: 'http://panel:8080',
      username: 'user',
      password: 'pass',
    );
    final live = StreamItem(id: '12', name: 'Channel', kind: 'live');
    final vod = StreamItem(id: '99', name: 'Movie', kind: 'movie', containerExtension: 'mkv');
    expect(client.liveUrl(live), 'http://panel:8080/live/user/pass/12.ts');
    expect(client.liveUrl(live, extension: 'm3u8'), 'http://panel:8080/live/user/pass/12.m3u8');
    expect(client.vodUrl(vod), 'http://panel:8080/movie/user/pass/99.mkv');
    expect(client.seriesEpisodeUrl('7', 'mp4'), 'http://panel:8080/series/user/pass/7.mp4');
    expect(
      client.playlistUrl(hls: true),
      'http://panel:8080/get.php?username=user&password=pass&type=m3u_plus&output=m3u8',
    );
  });
}