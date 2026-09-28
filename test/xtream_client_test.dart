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
      expect(
        XtreamClient.normaliseServer('http://host:8080/'),
        'http://host:8080',
      );
      expect(XtreamClient.normaliseServer(' https://host '), 'https://host');
    });
  });

  test('successful login parses the account block', () async {
    final body = jsonEncode({
      'user_info': {
        'username': 'someone',
        'auth': 1,
        'status': 'Active',
        'exp_date':
            '${DateTime.now().add(const Duration(days: 365)).millisecondsSinceEpoch ~/ 1000}',
        'max_connections': '2',
        'active_cons': '1',
        'is_trial': '0',
        'allowed_output_formats': ['m3u8', 'ts'],
      },
      'server_info': {
        'url': 'panel.example',
        'port': '8080',
        'server_protocol': 'http',
      },
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
      body: jsonEncode({
        'user_info': {'auth': 0, 'status': 'Disabled'},
      }),
    );
    final client = XtreamClient(
      server: 'http://127.0.0.1:${server.port}',
      username: 'x',
      password: 'y',
    );
    await expectLater(
      client.login(),
      throwsA(
        isA<XtreamException>().having(
          (e) => e.kind,
          'kind',
          XtreamErrorKind.rejected,
        ),
      ),
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
      throwsA(
        isA<XtreamException>().having(
          (e) => e.kind,
          'kind',
          XtreamErrorKind.expired,
        ),
      ),
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
      throwsA(
        isA<XtreamException>()
            .having((e) => e.kind, 'kind', XtreamErrorKind.http)
            .having((e) => e.statusCode, 'status', 403),
      ),
    );
    await server.close(force: true);
  });

  test(
    'a panel redirect never forwards credentials to another origin',
    () async {
      var forwarded = 0;
      final destination = await HttpServer.bind(
        InternetAddress.loopbackIPv4,
        0,
      );
      destination.listen((request) async {
        forwarded++;
        request.response.headers.contentType = ContentType.json;
        request.response.write('{"user_info":{"auth":1}}');
        await request.response.close();
      });
      final source = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      source.listen((request) async {
        request.response.statusCode = HttpStatus.found;
        request.response.headers.set(
          HttpHeaders.locationHeader,
          'http://127.0.0.1:${destination.port}/player_api.php',
        );
        await request.response.close();
      });
      try {
        final client = XtreamClient(
          server: 'http://127.0.0.1:${source.port}',
          username: 'u',
          password: 'p',
        );
        await expectLater(
          client.login(),
          throwsA(
            isA<XtreamException>()
                .having((e) => e.kind, 'kind', XtreamErrorKind.http)
                .having((e) => e.statusCode, 'status', HttpStatus.found),
          ),
        );
        expect(forwarded, 0);
      } finally {
        await source.close(force: true);
        await destination.close(force: true);
      }
    },
  );

  for (final status in [401, 403, 500]) {
    test('JSON HTTP $status is classified as HTTP, not account data', () async {
      final body = jsonEncode({
        'user_info': {'auth': 1, 'status': 'Active'},
        'error': 'Access denied',
      });
      final server = await startPanel(body: body, status: status);
      try {
        final client = XtreamClient(
          server: 'http://127.0.0.1:${server.port}',
          username: 'x',
          password: 'y',
        );
        await expectLater(
          client.login(),
          throwsA(
            isA<XtreamException>()
                .having((e) => e.kind, 'kind', XtreamErrorKind.http)
                .having((e) => e.statusCode, 'statusCode', status)
                .having((e) => e.body, 'body', body),
          ),
        );
      } finally {
        await server.close(force: true);
      }
    });
  }

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
      throwsA(
        isA<XtreamException>().having(
          (e) => e.kind,
          'kind',
          XtreamErrorKind.unreachable,
        ),
      ),
    );
  });

  test('malformed server address is reported, not thrown raw', () async {
    // e.g. a typo that swallows the port: "http://10.0.2.2:8420demo"
    final client = XtreamClient(
      server: 'http://10.0.2.2:8420demodemo',
      username: 'x',
      password: 'y',
    );
    await expectLater(
      client.login(),
      throwsA(
        isA<XtreamException>()
            .having((e) => e.kind, 'kind', XtreamErrorKind.wrongServer)
            .having((e) => e.message, 'message', contains('not a valid URL')),
      ),
    );
  });

  test(
    'Cloudflare 1034 is called out as dead DNS, not bad credentials',
    () async {
      final server = await startPanel(body: 'error code: 1034', status: 403);
      final client = XtreamClient(
        server: 'http://127.0.0.1:${server.port}',
        username: 'x',
        password: 'y',
      );
      try {
        await client.login();
        fail('expected XtreamException');
      } on XtreamException catch (e) {
        expect(e.kind, XtreamErrorKind.http);
        expect(e.message, contains('1034'));
        expect(e.hint, contains('DNS record points at a placeholder'));
      }
      await server.close(force: true);
    },
  );

  test('https to plain HTTP never sends credentials over HTTP', () async {
    var httpRequests = 0;
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      httpRequests++;
      request.response.write(
        jsonEncode({
          'user_info': {'auth': 1, 'username': 'u', 'exp_date': '1790000000'},
          'server_info': {'url': '127.0.0.1'},
        }),
      );
      await request.response.close();
    });
    final client = XtreamClient(
      server: 'https://127.0.0.1:${server.port}',
      username: 'u',
      password: 'p',
      timeout: const Duration(seconds: 3),
    );
    await expectLater(
      client.login(),
      throwsA(
        isA<XtreamException>().having(
          (e) => e.kind,
          'kind',
          XtreamErrorKind.tlsMismatch,
        ),
      ),
    );
    expect(httpRequests, 0);
    expect(client.effectiveServer, 'https://127.0.0.1:${server.port}');
    await server.close(force: true);
  }, timeout: const Timeout(Duration(seconds: 60)));

  test('untrusted TLS certificate does not retry a login over HTTP', () async {
    // Generates an untrusted certificate for the local panel. Requires openssl.
    final directory = await Directory.systemTemp.createTemp('spectre-tls-');
    HttpServer? server;
    try {
      final cert = '${directory.path}/cert.pem';
      final key = '${directory.path}/key.pem';
      final result = await Process.run('openssl', [
        'req',
        '-x509',
        '-newkey',
        'rsa:2048',
        '-nodes',
        '-keyout',
        key,
        '-out',
        cert,
        '-days',
        '1',
        '-subj',
        '/CN=localhost',
      ]);
      expect(result.exitCode, 0, reason: '${result.stderr}');
      final context = SecurityContext()
        ..useCertificateChain(cert)
        ..usePrivateKey(key);
      server = await HttpServer.bindSecure(
        InternetAddress.loopbackIPv4,
        0,
        context,
      );
      server.listen((request) async {
        request.response.write('{}');
        await request.response.close();
      });
      final client = XtreamClient(
        server: 'https://127.0.0.1:${server.port}',
        username: 'private-user',
        password: 'private-password',
        timeout: const Duration(seconds: 3),
      );
      await expectLater(
        client.login(),
        throwsA(
          isA<XtreamException>().having(
            (e) => e.kind,
            'kind',
            XtreamErrorKind.tlsMismatch,
          ),
        ),
      );
      expect(client.effectiveServer, 'https://127.0.0.1:${server.port}');
    } finally {
      await server?.close(force: true);
      await directory.delete(recursive: true);
    }
  }, timeout: const Timeout(Duration(seconds: 60)));

  test('a placeholder DNS address is reported before anything else', () async {
    // Closed port (nothing listening) + a resolver saying 1.1.1.1: the honest
    // answer is "that address cannot host a panel", not "cannot reach".
    final probe = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final port = probe.port;
    await probe.close(force: true);
    final client = XtreamClient(
      server: 'http://panel.example:$port',
      username: 'u',
      password: 'p',
      timeout: const Duration(seconds: 3),
      resolvedAddressesOverride: const ['1.1.1.1'],
    );
    await expectLater(
      client.login(),
      throwsA(
        isA<XtreamException>()
            .having((e) => e.kind, 'kind', XtreamErrorKind.deadDns)
            .having(
              (e) => e.message,
              'message',
              contains('placeholder address'),
            )
            .having((e) => e.body, 'body', '1.1.1.1'),
      ),
    );
  }, timeout: const Timeout(Duration(seconds: 60)));

  test('stream URL shapes follow the Xtream specification', () {
    final client = XtreamClient(
      server: 'http://panel:8080',
      username: 'user',
      password: 'pass',
    );
    final live = StreamItem(id: '12', name: 'Channel', kind: 'live');
    final vod = StreamItem(
      id: '99',
      name: 'Movie',
      kind: 'movie',
      containerExtension: 'mkv',
    );
    expect(client.liveUrl(live), 'http://panel:8080/live/user/pass/12.ts');
    expect(
      client.liveUrl(live, extension: 'm3u8'),
      'http://panel:8080/live/user/pass/12.m3u8',
    );
    expect(client.vodUrl(vod), 'http://panel:8080/movie/user/pass/99.mkv');
    expect(
      client.seriesEpisodeUrl('7', 'mp4'),
      'http://panel:8080/series/user/pass/7.mp4',
    );
    expect(
      client.playlistUrl(hls: true),
      'http://panel:8080/get.php?username=user&password=pass&type=m3u_plus&output=m3u8',
    );
  });

  test('stream and export URLs encode credentials as single components', () {
    const user = 'a/b ?#%&+ \u00103';
    const password = 'p/@?#%&+= \u00130';
    final client = XtreamClient(
      server: 'https://panel.example:8443',
      username: user,
      password: password,
    );
    final live = StreamItem(id: 'id/42', name: 'Channel', kind: 'live');
    final vod = StreamItem(
      id: 'id/99',
      name: 'Movie',
      kind: 'movie',
      containerExtension: 'm?k/v',
    );

    for (final url in [
      client.liveUrl(live, extension: 'm3/u8'),
      client.vodUrl(vod),
      client.seriesEpisodeUrl('id/7', 'm?4'),
    ]) {
      expect(url, contains('a%2Fb'));
      expect(url, contains('p%2F%40'));
      final uri = Uri.parse(url);
      expect(uri.scheme, 'https');
      expect(uri.host, 'panel.example');
      expect(uri.pathSegments[1], user);
      expect(uri.pathSegments[2], password);
      expect(uri.pathSegments.length, 4);
      expect(uri.query, isEmpty);
      expect(uri.fragment, isEmpty);
    }
    expect(
      Uri.parse(client.liveUrl(live, extension: 'm3/u8')).pathSegments.last,
      'id/42.m3/u8',
    );
    expect(Uri.parse(client.vodUrl(vod)).pathSegments.last, 'id/99.m?k/v');
    expect(
      Uri.parse(client.seriesEpisodeUrl('id/7', 'm?4')).pathSegments.last,
      'id/7.m?4',
    );

    final playlist = Uri.parse(client.playlistUrl(hls: true));
    expect(playlist.pathSegments, ['get.php']);
    expect(playlist.queryParameters, {
      'username': user,
      'password': password,
      'type': 'm3u_plus',
      'output': 'm3u8',
    });
    final epg = Uri.parse(client.epgUrl());
    expect(epg.pathSegments, ['xmltv.php']);
    expect(epg.queryParameters, {'username': user, 'password': password});
  });

  test(
    'local panel receives encoded stream and export credentials intact',
    () async {
      const user = 'user/one# two';
      const password = 'p&ss?%/word';
      final received = <Uri>[];
      final panel = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      panel.listen((request) async {
        received.add(request.uri);
        request.response.write('ok');
        await request.response.close();
      });
      final transport = HttpClient();
      try {
        final client = XtreamClient(
          server: 'http://127.0.0.1:${panel.port}',
          username: user,
          password: password,
        );
        final urls = [
          client.liveUrl(StreamItem(id: 'id/5', name: 'c', kind: 'live')),
          client.vodUrl(StreamItem(id: 'id/7', name: 'm', kind: 'movie')),
          client.seriesEpisodeUrl('id/8', 'mp4'),
          client.playlistUrl(),
          client.epgUrl(),
        ];
        for (final url in urls) {
          final response = await (await transport.getUrl(Uri.parse(url)))
              .close();
          await response.drain<void>();
          expect(response.statusCode, 200);
        }
        expect(received.length, urls.length);
        for (final uri in received.take(3)) {
          expect(uri.pathSegments[1], user);
          expect(uri.pathSegments[2], password);
          expect(uri.pathSegments.length, 4);
          expect(uri.query, isEmpty);
        }
        for (final uri in received.skip(3)) {
          expect(uri.queryParameters['username'], user);
          expect(uri.queryParameters['password'], password);
        }
      } finally {
        transport.close(force: true);
        await panel.close(force: true);
      }
    },
  );
}
