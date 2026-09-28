import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xtream_player/models.dart';
import 'package:xtream_player/store.dart';
import 'package:xtream_player/xtream_client.dart';

class _Catalogue extends XtreamClient {
  _Catalogue()
    : super(server: 'http://example.invalid', username: 'u', password: 'p');

  Future<List<Category>> liveCats = Future.value(const []);
  Future<List<Category>> movieCats = Future.value(const []);
  Future<List<StreamItem>> liveAll = Future.value(const []);
  Future<List<StreamItem>> movieAll = Future.value(const []);
  Future<List<EpgEntry>> epg = Future.value(const []);
  final Map<String, Future<List<StreamItem>>> liveByCategory = {};
  int movieCalls = 0;

  @override
  Future<List<Category>> liveCategories() => liveCats;
  @override
  Future<List<Category>> vodCategories() => movieCats;
  @override
  Future<List<Category>> seriesCategories() async => const [];
  @override
  Future<List<StreamItem>> liveStreams({String? categoryId}) =>
      categoryId == null ? liveAll : liveByCategory[categoryId]!;
  @override
  Future<List<StreamItem>> vodStreams({String? categoryId}) {
    movieCalls++;
    return movieAll;
  }

  @override
  Future<List<StreamItem>> series({String? categoryId}) async => const [];
  @override
  Future<List<EpgEntry>> shortEpg(String streamId, {int limit = 2}) => epg;
}

StreamItem _item(String name) => StreamItem(id: name, name: name, kind: 'live');
Category _cat(String name) => Category(id: name, name: name);

void main() {
  test(
    'late tab response cannot change visible catalogue or tab cache',
    () async {
      final old = Completer<List<Category>>();
      final c = _Catalogue()
        ..liveCats = old.future
        ..movieCats = Future.value([_cat('movies')])
        ..movieAll = Future.value([_item('new')]);
      final state = AppState()..client = c;
      final first = state.loadContent(ContentTab.live);
      state.setTab(ContentTab.movies);
      await Future<void>.delayed(Duration.zero);
      expect(state.tab, ContentTab.movies);
      expect(state.categories.single.name, 'movies');
      expect(state.items.single.name, 'new');
      old.complete([_cat('old')]);
      await first;
      expect(state.tab, ContentTab.movies);
      expect(state.categories.single.name, 'movies');
      expect(state.items.single.name, 'new');
      expect(state.countFor(ContentTab.live), isNull);
      expect(state.busy, isFalse);
    },
  );

  test(
    'late category response cannot override a newer category or All',
    () async {
      final a = Completer<List<StreamItem>>();
      final b = Completer<List<StreamItem>>();
      final c = _Catalogue()
        ..liveAll = Future.value([_item('all')])
        ..liveByCategory['a'] = a.future
        ..liveByCategory['b'] = b.future;
      final state = AppState()..client = c;
      await state.loadContent(ContentTab.live);
      state.selectCategory('a');
      await Future<void>.delayed(Duration.zero);
      state.selectCategory('b');
      await Future<void>.delayed(Duration.zero);
      b.complete([_item('b')]);
      await Future<void>.delayed(Duration.zero);
      a.complete([_item('a')]);
      await Future<void>.delayed(Duration.zero);
      expect(state.selectedCategoryId, 'b');
      expect(state.items.single.name, 'b');
      state.selectCategory('a');
      expect(state.items, isEmpty); // stale A was not cached
      state.selectCategory(null);
      expect(state.items.single.name, 'all');
      expect(state.busy, isFalse);
    },
  );

  test('logout discards late visible response, error and preload', () async {
    final lateCats = Completer<List<Category>>();
    final latePreload = Completer<List<StreamItem>>();
    final c = _Catalogue()
      ..liveCats = lateCats.future
      ..movieAll = latePreload.future;
    final state = AppState()..client = c;
    final visible = state.loadContent(ContentTab.live);
    final preload = state.ensureLoaded(ContentTab.movies);
    await Future<void>.delayed(Duration.zero);
    await state.logout();
    lateCats.completeError(
      XtreamException(XtreamErrorKind.unreachable, 'old error'),
    );
    latePreload.complete([_item('old')]);
    await Future.wait([visible, preload]);
    expect(state.client, isNull);
    expect(state.items, isEmpty);
    expect(state.categories, isEmpty);
    expect(state.countFor(ContentTab.movies), isNull);
    expect(state.loadingFor(ContentTab.movies), isFalse);
    expect(state.error, isNull);
  });

  test(
    'old preload completion cannot clear a new account pending flag',
    () async {
      final oldItems = Completer<List<StreamItem>>();
      final newItems = Completer<List<StreamItem>>();
      final oldClient = _Catalogue()..movieAll = oldItems.future;
      final newClient = _Catalogue()..movieAll = newItems.future;
      final state = AppState()..client = oldClient;
      final old = state.ensureLoaded(ContentTab.movies);
      await Future<void>.delayed(Duration.zero);
      await state.logout();
      state.client = newClient;
      final fresh = state.ensureLoaded(ContentTab.movies);
      await Future<void>.delayed(Duration.zero);
      oldItems.complete([_item('stale')]);
      await old;
      expect(state.loadingFor(ContentTab.movies), isTrue);
      expect(state.countFor(ContentTab.movies), isNull);
      newItems.complete([_item('fresh')]);
      await fresh;
      expect(state.loadingFor(ContentTab.movies), isFalse);
      expect(state.itemsFor(ContentTab.movies).single.name, 'fresh');
    },
  );

  test('late EPG response cannot repopulate another session or clear its pending flag', () async {
    final oldResult = Completer<List<EpgEntry>>();
    final freshResult = Completer<List<EpgEntry>>();
    final oldClient = _Catalogue()..epg = oldResult.future;
    final freshClient = _Catalogue()..epg = freshResult.future;
    final state = AppState()..client = oldClient;
    final channel = _item('channel');
    final old = state.loadEpgFor(channel);
    await state.logout();
    state.client = freshClient;
    final fresh = state.loadEpgFor(channel);
    oldResult.complete([EpgEntry(title: 'old', description: '')]);
    await old;
    expect(state.epgPending, contains(channel.id));
    expect(state.epgCache[channel.id], isNull);
    freshResult.complete([EpgEntry(title: 'fresh', description: '')]);
    await fresh;
    expect(state.epgCache[channel.id]!.single.title, 'fresh');
    expect(state.epgPending, isEmpty);
  });

  test('preload failure remains uncached and a later call retries', () async {
    final c = _Catalogue()..movieAll = Future.error(StateError('temporary'));
    final state = AppState()..client = c;
    await state.ensureLoaded(ContentTab.movies);
    expect(state.countFor(ContentTab.movies), isNull);
    expect(state.loadingFor(ContentTab.movies), isFalse);
    c.movieAll = Future.value([_item('retry')]);
    await state.ensureLoaded(ContentTab.movies);
    expect(c.movieCalls, 2);
    expect(state.itemsFor(ContentTab.movies).single.name, 'retry');
  });

  test('refresh wins over an earlier same-tab response', () async {
    final oldItems = Completer<List<StreamItem>>();
    final c = _Catalogue()..liveAll = oldItems.future;
    final state = AppState()..client = c;
    final old = state.loadContent(ContentTab.live);
    await Future<void>.delayed(Duration.zero);
    c.liveAll = Future.value([_item('fresh')]);
    await state.loadContent(ContentTab.live, refresh: true);
    oldItems.complete([_item('stale')]);
    await old;
    expect(state.items.single.name, 'fresh');
    expect(state.itemsFor(ContentTab.live).single.name, 'fresh');
    expect(state.busy, isFalse);
  });

  test('reselecting the current tab resets its category and visible items together', () async {
    final c = _Catalogue()
      ..liveCats = Future.value([_cat('sports')])
      ..liveAll = Future.value([_item('all')])
      ..liveByCategory['sports'] = Future.value([_item('sports')]);
    final state = AppState()..client = c;
    await state.loadContent(ContentTab.live);
    await state.loadContent(ContentTab.live, categoryId: 'sports');
    expect(state.items.single.name, 'sports');
    state.setTab(ContentTab.live);
    expect(state.selectedCategoryId, isNull);
    expect(state.items.single.name, 'all');
  });

  test(
    'refresh invalidates cached category items and clears its selection',
    () async {
      final c = _Catalogue()
        ..liveCats = Future.value([_cat('sports')])
        ..liveAll = Future.value([_item('all')])
        ..liveByCategory['sports'] = Future.value([_item('old')]);
      final state = AppState()..client = c;
      await state.loadContent(ContentTab.live);
      await state.loadContent(ContentTab.live, categoryId: 'sports');
      expect(state.items.single.name, 'old');
      await state.loadContent(ContentTab.live, refresh: true);
      expect(state.selectedCategoryId, isNull);
      expect(state.items.single.name, 'all');
      c.liveByCategory['sports'] = Future.value([_item('new')]);
      await state.loadContent(ContentTab.live, categoryId: 'sports');
      expect(state.items.single.name, 'new');
    },
  );

  test(
    'turning remember off removes existing secrets without another login',
    () async {
      SharedPreferences.setMockInitialValues({});
      final state = AppState();
      await state.init();
      final saved = SavedLogin(
        server: 'http://127.0.0.1:1',
        username: 'u',
        password: 'stored',
        label: '',
      );
      state.logins.add(saved);
      state.setCredentials(server: saved.server, username: saved.username);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('pass', 'legacy');
      await prefs.setString('logins', jsonEncode([saved.toJson()]));
      expect(state.logins, hasLength(1));
      state.setCredentials(remember: false);
      await Future<void>.delayed(Duration.zero);
      expect(state.logins, isEmpty);
      expect(prefs.getBool('remember'), isFalse);
      expect(prefs.getString('pass'), isNull);
      expect(jsonDecode(prefs.getString('logins')!), isEmpty);
    },
  );

  test('turning remember off preserves unrelated saved accounts', () async {
    SharedPreferences.setMockInitialValues({});
    final state = AppState();
    await state.init();
    final current = SavedLogin(
      server: 'http://127.0.0.1:11',
      username: 'current',
      password: 'current-password',
      label: '',
    );
    final other = SavedLogin(
      server: 'http://127.0.0.1:12',
      username: 'other',
      password: 'other-password',
      label: '',
    );
    state.logins.addAll([current, other]);
    state.setCredentials(server: current.server, username: current.username);
    state.setCredentials(remember: false);
    await Future<void>.delayed(Duration.zero);
    expect(state.logins, [same(other)]);
    final prefs = await SharedPreferences.getInstance();
    final saved = jsonDecode(prefs.getString('logins')!) as List;
    expect(saved, hasLength(1));
    expect((saved.single as Map)['username'], 'other');
  });

  test(
    'remember=false login stores no password and never auto-signs in',
    () async {
      SharedPreferences.setMockInitialValues({});
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      var logins = 0;
      server.listen((request) async {
        request.response.headers.contentType = ContentType.json;
        if (!request.uri.queryParameters.containsKey('action')) {
          logins++;
          request.response.write(
            jsonEncode({
              'user_info': {'auth': 1, 'username': 'u'},
            }),
          );
        } else {
          request.response.write('[]');
        }
        await request.response.close();
      });
      try {
        final state = AppState();
        await state.init();
        state.setCredentials(remember: false);
        expect(
          await state.signIn(
            username: 'u',
            password: 'secret',
            server: 'http://127.0.0.1:${server.port}',
          ),
          isTrue,
        );
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString('pass'), isNull);
        expect(jsonDecode(prefs.getString('logins')!), isEmpty);
        expect(prefs.getBool('remember'), isFalse);
        expect(state.logins, isEmpty);
        expect(logins, 1);
        final restarted = AppState();
        await restarted.init();
        expect(restarted.loggedIn, isFalse);
        expect(restarted.password, isEmpty);
        expect(logins, 1);
      } finally {
        await server.close(force: true);
      }
    },
  );

  test('remember=false cleans legacy and saved secrets on init', () async {
    SharedPreferences.setMockInitialValues({
      'remember': false,
      'server': 'http://127.0.0.1:1',
      'user': 'u',
      'pass': 'legacy-secret',
      'logins': jsonEncode([
        SavedLogin(
          server: 'http://127.0.0.1:1',
          username: 'u',
          password: 'saved-secret',
          label: '',
        ).toJson(),
      ]),
    });
    final state = AppState();
    await state.init();
    final prefs = await SharedPreferences.getInstance();
    expect(state.loggedIn, isFalse);
    expect(state.logins, isEmpty);
    expect(prefs.getString('pass'), isNull);
    expect(jsonDecode(prefs.getString('logins')!), isEmpty);
  });

  test('logout while login is pending cannot restore the session', () async {
    SharedPreferences.setMockInitialValues({});
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final received = Completer<void>();
    final reply = Completer<void>();
    server.listen((request) async {
      if (!request.uri.queryParameters.containsKey('action')) {
        received.complete();
        await reply.future;
        request.response.headers.contentType = ContentType.json;
        request.response.write('{"user_info":{"auth":1,"username":"u"}}');
      } else {
        request.response.write('[]');
      }
      await request.response.close();
    });
    try {
      final state = AppState();
      await state.init();
      final pending = state.signIn(
        username: 'u',
        password: 'secret',
        server: 'http://127.0.0.1:${server.port}',
      );
      await received.future;
      await state.logout();
      reply.complete();
      expect(await pending, isFalse);
      expect(state.loggedIn, isFalse);
      expect(state.client, isNull);
      expect(state.logins, isEmpty);
      expect(state.busy, isFalse);
    } finally {
      await server.close(force: true);
    }
  });

  test(
    'forgetting last login clears legacy secret so it cannot reappear',
    () async {
      SharedPreferences.setMockInitialValues({});
      final initialized = AppState();
      await initialized.init();
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((request) async {
        request.response.headers.contentType = ContentType.json;
        request.response.write(
          request.uri.queryParameters.containsKey('action')
              ? '[]'
              : '{"user_info":{"auth":1,"username":"u"}}',
        );
        await request.response.close();
      });
      try {
        expect(
          await initialized.signIn(
            username: 'u',
            password: 'secret',
            server: 'http://127.0.0.1:${server.port}',
          ),
          isTrue,
        );
        expect(initialized.logins, hasLength(1));
        await initialized.forget(initialized.logins.single);
        expect(initialized.logins, isEmpty);
        expect(
          (await SharedPreferences.getInstance()).getString('pass'),
          isNull,
        );
        // There must be no attempted auto-login on restart, even with a host
        // that would still accept the legacy credentials.
        final restarted = AppState();
        await restarted.init();
        expect(restarted.logins, isEmpty);
        expect(restarted.loggedIn, isFalse);
      } finally {
        await server.close(force: true);
      }
    },
  );
}
