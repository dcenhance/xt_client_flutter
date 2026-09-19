import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:xtream_player/panels.dart';
import 'package:xtream_player/store.dart';
import 'package:xtream_player/xtream_client.dart';

/// The panel is not something the user picks before logging in: the app walks
/// the panels it knows and stops at the first one that accepts the account.
class _DiscoveringState extends AppState {
  _DiscoveringState(this.candidates);

  final List<String> candidates;

  @override
  List<String> candidatesFor({String? preferred}) => candidates;
}

Future<HttpServer> panel({required bool accepts}) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  server.listen((request) async {
    final action = request.uri.queryParameters['action'] ?? '';
    request.response.headers.contentType = ContentType.json;
    if (action.isEmpty) {
      request.response.write(jsonEncode({
        'user_info': {
          'auth': accepts ? 1 : 0,
          'username': 'u',
          'status': 'Active',
          'exp_date': '2000000000',
          'max_connections': '2',
          'active_cons': '1',
          'allowed_output_formats': ['m3u8'],
        },
        'server_info': {'url': '127.0.0.1', 'port': '${server.port}'},
      }));
    } else {
      request.response.write(jsonEncode([]));
    }
    await request.response.close();
  });
  return server;
}

void main() {
  test('with no server typed, the first panel that accepts the login wins', () async {
    final dead = await panel(accepts: false);
    final good = await panel(accepts: true);

    final state = _DiscoveringState([
      'http://127.0.0.1:${dead.port}',
      'http://127.0.0.1:${good.port}',
    ]);

    final ok = await state.signIn(username: 'u', password: 'p');

    expect(ok, isTrue);
    expect(state.account, isNotNull);
    expect(state.server, 'http://127.0.0.1:${good.port}');
    // The panel that worked is remembered for next time, in front.
    expect(state.workingServers.first, 'http://127.0.0.1:${good.port}');
    expect(state.discoveryNote, isNull);

    await dead.close(force: true);
    await good.close(force: true);
  }, timeout: const Timeout(Duration(seconds: 60)));

  test('candidates start with the remembered panels and cover every preset', () {
    final state = AppState()
      ..workingServers = ['http://remembered.example:8080']
      ..logins = [
        SavedLogin(
          server: 'http://account.example:8080',
          username: 'u',
          password: 'p',
          label: '',
        ),
      ];

    final list = state.candidatesFor();

    expect(list.first, 'http://remembered.example:8080');
    for (final p in kPanelPresets) {
      expect(list, contains(XtreamClient.normaliseServer(p.url)));
    }
    // A typed address is tried before anything the app remembers.
    expect(state.candidatesFor(preferred: 'typed.example:99').first,
        'http://typed.example:99');
  });

  test('a remembered login carries the panel name for the UI', () {
    final l = SavedLogin(
      server: XtreamClient.normaliseServer(kPanelPresets.first.url),
      username: 'juppborken',
      password: 'x',
      label: '',
    );
    expect(l.displayName, 'juppborken · ${kPanelPresets.first.name}');
    expect(l.host, isNotEmpty);
  });
}
