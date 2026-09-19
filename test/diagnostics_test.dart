import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:xtream_player/diagnostics.dart';
import 'package:xtream_player/panels.dart';
import 'package:xtream_player/xtream_client.dart'
    show placeholderAddresses, probeAnonymous, XtreamClient;

/// Diagnostics must not lie: a placeholder DNS record, a live panel that refuses
/// the login, and a working panel all have to produce different verdicts.
Future<HttpServer> panel({required String body, int status = 200, bool respond = true}) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  server.listen((request) async {
    if (!respond) {
      request.response.statusCode = status;
      await request.response.close();
      return;
    }
    request.response.statusCode = status;
    request.response.headers.contentType = ContentType.json;
    request.response.write(body);
    await request.response.close();
  });
  return server;
}

void main() {
  _presets();
  _anonymousProbe();

  test('placeholder addresses are detected', () {
    expect(placeholderAddresses.contains('1.1.1.1'), isTrue);
    expect(placeholderAddresses.contains('198.51.100.1'), isTrue);
  });

  test('a live panel that accepts the login is found and reported', () async {
    final server = await panel(
      body: jsonEncode({
        'user_info': {'auth': 1, 'username': 'u', 'status': 'Active'},
        'server_info': {'url': '127.0.0.1'},
      }),
    );
    final result = await Diagnostics.run(
      server: 'http://127.0.0.1:${server.port}',
      username: 'u',
      password: 'p',
      timeout: const Duration(seconds: 2),
    );
    expect(result.placeholderDns, isFalse);
    expect(result.probes.any((p) => p.authenticated), isTrue);
    expect(result.workingHost, 'http://127.0.0.1:${server.port}');
    expect(result.verdict, contains('Login works'));
    await server.close(force: true);
  }, timeout: const Timeout(Duration(seconds: 60)));

  test('panel that refuses the login says so instead of blaming the network', () async {
    final server = await panel(body: jsonEncode({'user_info': {'auth': 0}}));
    final result = await Diagnostics.run(
      server: 'http://127.0.0.1:${server.port}',
      username: 'u',
      password: 'wrong',
      timeout: const Duration(seconds: 2),
    );
    expect(result.workingHost, isNull);
    expect(result.verdict, contains('refused these credentials'));
    await server.close(force: true);
  }, timeout: const Timeout(Duration(seconds: 60)));

  test('a Cloudflare 1034 body is explained as a placeholder record', () async {
    final server = await panel(body: 'error code: 1034\n', status: 403);
    final result = await Diagnostics.run(
      server: 'http://127.0.0.1:${server.port}',
      username: 'u',
      password: 'p',
      timeout: const Duration(seconds: 2),
    );
    final details = result.probes.map((p) => p.detail).join(' ');
    expect(details, contains('1034'));
    expect(result.probes.every((p) => !p.xtreamLike), isTrue);
    expect(result.workingHost, isNull);
    await server.close(force: true);
  }, timeout: const Timeout(Duration(seconds: 60)));

  test('placeholder DNS outranks the generic "host answered" verdict', () async {
    // Simulates exactly the fornationx.com case: Cloudflare answers on every port
    // with a 1034 page while DNS points at 1.1.1.1.
    final server = await panel(body: 'error code: 1034\n', status: 403);
    final result = await Diagnostics.run(
      server: 'http://127.0.0.1:${server.port}',
      username: 'u',
      password: 'p',
      timeout: const Duration(seconds: 2),
      resolvedAddressesOverride: const ['1.1.1.1'],
    );
    expect(result.placeholderDns, isTrue);
    expect(result.verdict, contains('resolves to a placeholder address'));
    expect(result.workingHost, isNull);
    await server.close(force: true);
  }, timeout: const Timeout(Duration(seconds: 60)));

  test('testServers reports which host accepts the login', () async {
    final good = await panel(
      body: jsonEncode({
        'user_info': {
          'auth': 1,
          'exp_date': '1790000000',
          'max_connections': '1',
          'active_cons': '0',
        },
      }),
    );
    final bad = await panel(body: jsonEncode({'user_info': {'auth': 0}}));
    final results = await testServers(
      servers: [
        'http://127.0.0.1:${good.port}',
        'http://127.0.0.1:${bad.port}',
        '# a comment line',
        '',
      ],
      username: 'u',
      password: 'p',
      timeout: const Duration(seconds: 2),
    );
    expect(results.length, 2, reason: 'comments and blanks are skipped');
    expect(results.first.ok, isTrue);
    expect(results.first.note, contains('login ok'));
    expect(results.last.ok, isFalse);
    await good.close(force: true);
    await bad.close(force: true);
  }, timeout: const Timeout(Duration(seconds: 60)));

  test('non-resolving host produces a clear verdict, not an exception', () async {
    final result = await Diagnostics.run(
      server: 'http://this-host-does-not-exist.invalid:8080',
      username: 'u',
      password: 'p',
      timeout: const Duration(seconds: 3),
    );
    expect(result.addresses.join(' '), contains('lookup failed'));
    expect(result.verdict, isNotEmpty);
  }, timeout: const Timeout(Duration(seconds: 120)));
}
// ---- panel presets -------------------------------------------------------

void _presets() {
  test('the Spectre panel list is reproduced with usable URLs', () {
    expect(kPanelPresets, hasLength(5));
    for (final p in kPanelPresets) {
      expect(p.name, isNotEmpty);
      expect(Uri.parse(XtreamClient.normaliseServer(p.url)).host, isNotEmpty);
      expect(p.url, startsWith('http'));
      expect(p.url, contains(':8080'));
    }
    expect(presetUrlsAsText().split('\n'), hasLength(5));
    expect(kPanelPresets.first.name, 'EUROPE 1');
  });
}

void _anonymousProbe() {
  test('a panel that answers without credentials is reported as open', () async {
    final server = await panel(
      body: jsonEncode([
        {'category_id': '1', 'category_name': 'News'},
        {'category_id': '2', 'category_name': 'Sports'},
      ]),
    );
    final probe = await probeAnonymous(
        server: 'http://127.0.0.1:${server.port}',
        timeout: const Duration(seconds: 4));
    expect(probe.reachable, isTrue);
    expect(probe.xtreamLike, isTrue);
    expect(probe.open, isTrue);
    expect(probe.liveCategories, 2);
    expect(probe.label, contains('OPEN'));
    await server.close(force: true);
  }, timeout: const Timeout(Duration(seconds: 60)));

  test('a panel that keeps its lists private is not reported as open', () async {
    final server = await panel(body: jsonEncode([]));
    final probe = await probeAnonymous(
        server: 'http://127.0.0.1:${server.port}',
        timeout: const Duration(seconds: 4));
    expect(probe.reachable, isTrue);
    expect(probe.open, isFalse);
    expect(probe.label, contains('private'));
    await server.close(force: true);
  }, timeout: const Timeout(Duration(seconds: 60)));

  test('a malformed address is reported as a bad address, not a raw exception', () async {
    final probe = await probeAnonymous(
        server: 'http://127.0.0.1:8421r', timeout: const Duration(seconds: 2));
    expect(probe.open, isFalse);
    expect(probe.note, contains('not a valid URL'));
    expect(probe.note, isNot(contains('FormatException')));
  }, timeout: const Timeout(Duration(seconds: 30)));

  test('a host that answers nothing is reported as unreachable, not open', () async {
    final probe = await probeAnonymous(
        server: 'http://127.0.0.1:59999', timeout: const Duration(seconds: 2));
    expect(probe.open, isFalse);
    expect(probe.reachable, isFalse);
  }, timeout: const Timeout(Duration(seconds: 60)));
}
