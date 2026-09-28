import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' hide Category;
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';
import 'l10n.dart';
import 'panels.dart';
import 'theme.dart';
import 'xtream_client.dart';

enum ContentTab { live, movies, series }

/// How much content fits on screen. Persisted.
enum ViewMode { grid, list }

enum Density { comfortable, compact }

/// Whole-app layout, pickable in Settings. Not tied to the platform: a desktop
/// can run the Dashboard shell and a phone the Sidebar one.
enum LayoutStyle { classic, sidebar, showcase, dashboard, cinema, masterDetail }

/// A login the app keeps between sessions, so the user does not have to retype
/// it and a panel can be re-picked later without asking for credentials again.
class SavedLogin {
  SavedLogin({
    required this.server,
    required this.username,
    required this.password,
    required this.label,
    DateTime? lastUsed,
  }) : lastUsed = lastUsed ?? DateTime.now();

  String server;
  String username;
  String password;
  String label;
  DateTime lastUsed;

  String get key => '$username@$server';

  Map<String, dynamic> toJson() => {
    'server': server,
    'username': username,
    'password': password,
    'label': label,
    'lastUsed': lastUsed.toIso8601String(),
  };

  static SavedLogin fromJson(Map<String, dynamic> j) => SavedLogin(
    server: (j['server'] ?? '') as String,
    username: (j['username'] ?? '') as String,
    password: (j['password'] ?? '') as String,
    label: (j['label'] ?? '') as String,
    lastUsed:
        DateTime.tryParse((j['lastUsed'] ?? '') as String) ??
        DateTime.fromMillisecondsSinceEpoch(0),
  );

  /// "juppborken · EUROPE 1"
  String get displayName {
    final preset = kPanelPresets.where((p) => p.url == server).toList();
    final place = preset.isNotEmpty ? preset.first.name : host;
    return '$username · $place';
  }

  String get host => Uri.tryParse(server)?.host ?? server;
}

class AppState extends ChangeNotifier {
  static const _kServer = 'server';
  static const _kUser = 'user';
  static const _kPass = 'pass';
  static const _kRemember = 'remember';
  static const _kViewMode = 'view_mode';
  static const _kDensity = 'density';
  static const _kTheme = 'theme';
  static const _kLogins = 'logins';
  static const _kWorking = 'working_servers';
  static const _kLayout = 'layout';
  static const _kLanguage = 'language_tag';

  SharedPreferences? _prefs;

  String server = '';
  String username = '';
  String password = '';
  bool remember = true;
  ViewMode viewMode = ViewMode.grid;
  Density density = Density.comfortable;
  String themeId = kGoldenOled.id;
  LayoutStyle layout = LayoutStyle.classic;
  String languageTag = '';

  /// True when browsing a panel that answers without credentials.
  bool guest = false;

  bool busy = false;
  String? error;
  String? errorHint;
  AccountInfo? account;

  /// Shown while the app walks the candidate panels during a login.
  String? discoveryNote;

  /// Servers that have accepted this account before, newest first — tried
  /// before anything else so the usual login is a single request.
  List<String> workingServers = const [];

  List<SavedLogin> logins = [];

  /// Now/next cached on demand for the player.
  final Map<String, List<EpgEntry>> epgCache = {};
  final Set<String> epgPending = {};

  ContentTab tab = ContentTab.live;
  List<Category> categories = const [];
  List<StreamItem> items = const [];
  String? selectedCategoryId;
  String search = '';
  final Map<ContentTab, List<StreamItem>> _cache = {};
  final Map<ContentTab, List<Category>> _categoryCache = {};
  final Map<String, List<StreamItem>> _catCache = {};
  int _contentEpoch = 0;
  int _visibleRequest = 0;
  int _sessionEpoch = 0;

  XtreamClient? client;

  /// Loads a tab's catalogue into the cache *without* switching to it, so the
  /// Dashboard can show real artwork for Movies and Series while Live TV is on
  /// screen. Cheap: two requests per tab, once.
  Future<void> ensureLoaded(ContentTab t) async {
    if (_cache.containsKey(t) || _preloading.contains(t)) return;
    final c = client;
    if (c == null) return;
    final epoch = _contentEpoch;
    bool current() => _contentEpoch == epoch && identical(client, c);
    _preloading.add(t);
    notifyListeners();
    try {
      if (!_categoryCache.containsKey(t)) {
        final cats = switch (t) {
          ContentTab.live => await c.liveCategories(),
          ContentTab.movies => await c.vodCategories(),
          ContentTab.series => await c.seriesCategories(),
        };
        if (!current()) return;
        _categoryCache[t] = cats;
      }
      final list = switch (t) {
        ContentTab.live => await c.liveStreams(),
        ContentTab.movies => await c.vodStreams(),
        ContentTab.series => await c.series(),
      };
      if (!current()) return;
      _cache[t] = list;
    } catch (_) {
      // A failed preload is not an empty catalogue: a later attempt can retry.
    } finally {
      if (current()) {
        _preloading.remove(t);
        notifyListeners();
      }
    }
  }

  /// Items of a tab with artwork — what the Dashboard tiles show as a mosaic.
  List<StreamItem> previewFor(ContentTab t, {int take = 4}) {
    final list = _cache[t];
    if (list == null) return const [];
    final withArt = list.where((i) => (i.icon ?? '').isNotEmpty).toList();
    return withArt.take(take).toList();
  }

  /// How much is in a tab, or null while it has never been loaded.
  int? countFor(ContentTab t) => _cache[t]?.length;

  /// Every entry of a tab the app already holds. The visible tab falls back to
  /// [items] so a freshly loaded catalogue is searchable before its cache
  /// entry settles.
  List<StreamItem> itemsFor(ContentTab t) =>
      _cache[t] ?? (t == tab ? items : const []);

  /// Entries matching [search] across every section. The Dashboard overview
  /// shows no tab of its own, so its search field cannot filter one list.
  List<StreamItem> get searchMatches {
    final q = search.trim().toLowerCase();
    if (q.isEmpty) return const [];
    return [
      for (final t in ContentTab.values)
        ...itemsFor(t).where((i) => i.name.toLowerCase().contains(q)),
    ];
  }

  /// How many entries the search is drawn from — the denominator of its count.
  int get searchableCount =>
      ContentTab.values.fold(0, (sum, t) => sum + itemsFor(t).length);

  bool loadingFor(ContentTab t) => _preloading.contains(t);

  final Set<ContentTab> _preloading = {};

  List<StreamItem> get visibleItems {
    final q = search.trim().toLowerCase();
    if (q.isEmpty) return items;
    return items.where((i) => i.name.toLowerCase().contains(q)).toList();
  }

  bool get loggedIn => account != null || guest;

  String get tabLabel => switch (tab) {
    ContentTab.live => trCurrent('Live TV'),
    ContentTab.movies => trCurrent('Movies'),
    ContentTab.series => trCurrent('Series'),
  };

  SavedLogin? get activeLogin {
    for (final l in logins) {
      if (l.server == server && l.username == username) return l;
    }
    return null;
  }

  /// Logins the app has kept, most recently used first.
  List<SavedLogin> get recentLogins {
    final copy = List<SavedLogin>.from(logins);
    copy.sort((a, b) => b.lastUsed.compareTo(a.lastUsed));
    return copy;
  }

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    languageTag = _prefs!.getString(_kLanguage) ?? '';
    if (languageTag.isNotEmpty &&
        !supportedLanguageTags.contains(languageTag)) {
      languageTag = '';
    }
    preferredLanguageTag = languageTag;
    server = _prefs!.getString(_kServer) ?? '';
    username = _prefs!.getString(_kUser) ?? '';
    remember = _prefs!.getBool(_kRemember) ?? true;
    password = remember ? (_prefs!.getString(_kPass) ?? '') : '';
    viewMode = (_prefs!.getString(_kViewMode) ?? 'grid') == 'list'
        ? ViewMode.list
        : ViewMode.grid;
    density = (_prefs!.getString(_kDensity) ?? 'comfortable') == 'compact'
        ? Density.compact
        : Density.comfortable;
    themeId = _prefs!.getString(_kTheme) ?? kGoldenOled.id;
    final savedLayout = _prefs!.getString(_kLayout) ?? 'classic';
    layout = LayoutStyle.values.firstWhere(
      (l) => l.name == savedLayout,
      orElse: () => LayoutStyle.classic,
    );
    // Guide was retired; replace the saved choice instead of restoring it on
    // every launch or leaving a layout that the picker can no longer show.
    if (savedLayout == 'guide') {
      await _prefs!.setString(_kLayout, layout.name);
    }
    AppTheme.use(themeId);
    workingServers = _prefs!.getStringList(_kWorking) ?? const [];
    _loadLogins();
    if (!remember) {
      // Do not resurrect the legacy single-login secret. Explicitly saved
      // *other* accounts are independent choices and must not be erased just
      // because this account chose not to be remembered.
      await _prefs!.remove(_kPass);
      final previousCount = logins.length;
      logins.removeWhere((l) => l.server == server && l.username == username);
      if (logins.length != previousCount) await _persistLogins();
    }

    // Migrate the single saved login of older builds into the new list.
    if (remember &&
        logins.isEmpty &&
        username.isNotEmpty &&
        password.isNotEmpty) {
      logins = [
        SavedLogin(
          server: server,
          username: username,
          password: password,
          label: '',
        ),
      ];
      await _persistLogins();
    }

    notifyListeners();

    // Sign back in without showing the login screen: the last account, its
    // remembered panel first.
    final auto = !remember
        ? null
        : recentLogins.isNotEmpty
        ? recentLogins.first
        : (server.isNotEmpty && username.isNotEmpty && password.isNotEmpty
              ? SavedLogin(
                  server: server,
                  username: username,
                  password: password,
                  label: '',
                )
              : null);
    if (auto != null) {
      await signIn(
        username: auto.username,
        password: auto.password,
        server: auto.server.isEmpty ? null : auto.server,
        silent: true,
      );
    }
  }

  void _loadLogins() {
    final raw = _prefs?.getString(_kLogins);
    if (raw == null || raw.isEmpty) return;
    try {
      final list = jsonDecode(raw) as List;
      logins = list
          .map((e) => SavedLogin.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (_) {
      logins = [];
    }
  }

  Future<void> _persistLogins() async {
    await _prefs?.setString(
      _kLogins,
      jsonEncode(logins.map((l) => l.toJson()).toList()),
    );
  }

  Future<void> setViewMode(ViewMode mode) async {
    viewMode = mode;
    await _prefs?.setString(
      _kViewMode,
      mode == ViewMode.list ? 'list' : 'grid',
    );
    notifyListeners();
  }

  Future<void> setDensity(Density value) async {
    density = value;
    await _prefs?.setString(
      _kDensity,
      value == Density.compact ? 'compact' : 'comfortable',
    );
    notifyListeners();
  }

  /// Pick which app mark to show, in-app and (on Android) as the launcher icon.

  /// Switch the whole app to another shell layout and remember it.
  Future<void> setLayout(LayoutStyle value) async {
    layout = value;
    await _prefs?.setString(_kLayout, value.name);
    notifyListeners();
  }

  /// Switch the whole app to another palette and remember it.
  Future<void> setTheme(String id) async {
    themeId = id;
    AppTheme.use(id);
    await _prefs?.setString(_kTheme, id);
    notifyListeners();
  }

  Future<void> setLanguageTag(String tag) async {
    if (tag.isNotEmpty && !supportedLanguageTags.contains(tag)) return;
    languageTag = tag;
    preferredLanguageTag = tag;
    notifyListeners();
    await _prefs?.setString(_kLanguage, tag);
  }

  /// Browse a panel that answers without credentials. No account is claimed:
  /// if the panel refuses anonymous requests, the content lists stay empty and
  /// the error explains it.
  Future<bool> browseAsGuest(String server) async {
    _sessionEpoch++;
    busy = true;
    error = null;
    errorHint = null;
    notifyListeners();
    final c = XtreamClient(
      server: XtreamClient.normaliseServer(server),
      username: '',
      password: '',
    );
    client = c;
    this.server = c.effectiveServer;
    guest = true;
    account = null;
    _clearContent();
    busy = false;
    notifyListeners();
    await loadContent(tab);
    return error == null;
  }

  void _clearContent() {
    _contentEpoch++;
    _visibleRequest++;
    _preloading.clear();
    epgCache.clear();
    epgPending.clear();
    _cache.clear();
    _categoryCache.clear();
    _catCache.clear();
    selectedCategoryId = null;
    items = const [];
    categories = const [];
  }

  /// Ends the session but keeps the remembered logins.
  Future<void> logout() async {
    _sessionEpoch++;
    account = null;
    client = null;
    guest = false;
    _clearContent();
    busy = false;
    discoveryNote = null;
    error = null;
    errorHint = null;
    notifyListeners();
  }

  /// Forgets one stored login for good.
  Future<void> forget(SavedLogin l) async {
    logins = logins.where((x) => x.key != l.key).toList();
    if (l.server == server && l.username == username) {
      _sessionEpoch++;
      account = null;
      client = null;
      guest = false;
      password = '';
      _clearContent();
      busy = false;
      // The legacy single-login keys must not re-create a forgotten entry.
      await _prefs?.remove(_kPass);
    }
    await _persistLogins();
    notifyListeners();
  }

  Future<void> _persist() async {
    final p = _prefs;
    if (p == null) return;
    await p.setString(_kServer, server);
    await p.setString(_kUser, username);
    await p.setBool(_kRemember, remember);
    if (remember) {
      await p.setString(_kPass, password);
    } else {
      await p.remove(_kPass);
    }
  }

  /// Where a login is attempted, in order: the server the caller named, the
  /// panels this account has worked on before, every panel the app knows, and
  /// any server from a stored login. The panel is therefore *not* something the
  /// user has to pick up front — the app finds it, and only asks when nothing
  /// answers.
  List<String> candidatesFor({String? preferred}) {
    final out = <String>[];
    void add(String? s) {
      final v = (s ?? '').trim();
      if (v.isEmpty) return;
      final norm = XtreamClient.normaliseServer(v);
      if (!out.contains(norm)) out.add(norm);
    }

    add(preferred);
    for (final s in workingServers) {
      add(s);
    }
    for (final l in recentLogins) {
      add(l.server);
    }
    for (final p in kPanelPresets) {
      add(p.url);
    }
    return out;
  }

  /// Signs in. With no [server] the remembered/known panels are tried until one
  /// accepts the account, which is what makes the panel a post-login concern.
  Future<bool> signIn({
    required String username,
    required String password,
    String? server,
    bool silent = false,
    bool discoverPanels = true,
  }) async {
    final session = ++_sessionEpoch;
    final user = username.trim();
    final explicitServer = server?.trim();
    final candidates =
        !discoverPanels && explicitServer != null && explicitServer.isNotEmpty
        ? [XtreamClient.normaliseServer(explicitServer)]
        : candidatesFor(preferred: explicitServer);
    if (!silent) {
      busy = true;
      error = null;
      errorHint = null;
      discoveryNote = candidates.length > 1
          ? trCurrent('Checking panels…')
          : null;
      notifyListeners();
    }

    XtreamException? lastError;
    for (var i = 0; i < candidates.length; i++) {
      final host = candidates[i];
      if (!silent && candidates.length > 1) {
        discoveryNote = trCurrent('Trying {panel} ({current}/{total})…', {
          'panel': panelLabel(host),
          'current': i + 1,
          'total': candidates.length,
        });
        notifyListeners();
      }
      final c = XtreamClient(server: host, username: user, password: password);
      try {
        final info = await c.login();
        if (session != _sessionEpoch) return false;
        // Only adopt the candidate after it authenticates. A failed panel
        // change must not replace the credentials or eject the old session.
        this.username = user;
        this.password = password;
        this.server = c.effectiveServer;
        client = c;
        account = info;
        guest = false;
        _clearContent();
        error = null;
        errorHint = null;
        discoveryNote = null;
        busy = false;
        await _rememberWorking(c.effectiveServer);
        if (session != _sessionEpoch) return false;
        if (remember) {
          await _upsertLogin(c.effectiveServer, this.username, this.password);
        } else {
          logins.removeWhere(
            (l) => l.server == c.effectiveServer && l.username == this.username,
          );
          await _persistLogins();
        }
        if (session != _sessionEpoch) return false;
        await _persist();
        if (session != _sessionEpoch) return false;
        notifyListeners();
        await loadContent(tab);
        return session == _sessionEpoch;
      } on XtreamException catch (e) {
        if (session != _sessionEpoch) return false;
        lastError = e;
        // auth=0 is ambiguous — a panel says that both for a wrong password and
        // for an account it does not know — so keep walking the list rather
        // than declaring the credentials wrong on the strength of one host.
        if (e.kind == XtreamErrorKind.deadDns ||
            e.kind == XtreamErrorKind.wrongServer) {
          continue;
        }
      } catch (e) {
        if (session != _sessionEpoch) return false;
        lastError = XtreamException(XtreamErrorKind.unreachable, '$e');
      }
    }

    if (session != _sessionEpoch) return false;
    // Keep an already working account and its catalogue intact on a failed
    // switch; only the attempted operation reports an error.
    busy = false;
    discoveryNote = null;
    error = lastError?.message ?? trCurrent('No panel answered.');
    errorHint =
        lastError?.hint ??
        (candidates.length > 1
            ? trCurrent(
                'Tried {count} panels. Check the username and password, or add the provider’s server address under Advanced.',
                {'count': candidates.length},
              )
            : null);
    notifyListeners();
    return false;
  }

  static String panelLabel(String server) {
    for (final p in kPanelPresets) {
      if (XtreamClient.normaliseServer(p.url) ==
          XtreamClient.normaliseServer(server)) {
        return p.name;
      }
    }
    return Uri.tryParse(server)?.host ?? server;
  }

  Future<void> _rememberWorking(String server) async {
    final list = <String>[server, ...workingServers.where((s) => s != server)];
    workingServers = list.take(8).toList();
    await _prefs?.setStringList(_kWorking, workingServers);
  }

  Future<void> _upsertLogin(String server, String user, String pass) async {
    final key = '$user@$server';
    final existing = logins.where((l) => l.key == key).toList();
    if (existing.isNotEmpty) {
      final l = existing.first;
      l.password = pass;
      l.lastUsed = DateTime.now();
    } else {
      logins.add(
        SavedLogin(
          server: server,
          username: user,
          password: pass,
          label: panelLabel(server),
        ),
      );
    }
    await _persistLogins();
  }

  /// Re-login on another panel with the same account — the post-login panel
  /// switch. Credentials come from the active login, so nothing is retyped.
  Future<bool> switchPanel(String server) async {
    if (account == null) return false;
    final user = account!.username;
    final pass = activeLogin?.password ?? password;
    return signIn(
      username: user,
      password: pass,
      server: server,
      discoverPanels: false,
    );
  }

  /// Continue an account the app has kept on its saved panel.
  Future<bool> resumeLogin(SavedLogin l) => signIn(
    username: l.username,
    password: l.password,
    server: l.server,
    discoverPanels: false,
  );

  /// Loads now/next for one channel, once. Live items only — VOD has no EPG,
  /// and asking a panel for it is a wasted round trip per row.
  Future<void> loadEpgFor(StreamItem item) async {
    if (item.kind != 'live') return;
    if (epgCache.containsKey(item.id) || epgPending.contains(item.id)) return;
    final c = client;
    if (c == null) return;
    final epoch = _contentEpoch;
    bool current() => _contentEpoch == epoch && identical(client, c);
    epgPending.add(item.id);
    try {
      final entries = await c.shortEpg(item.id, limit: 2);
      if (current()) epgCache[item.id] = entries;
    } catch (_) {
      if (current()) epgCache[item.id] = const [];
    } finally {
      if (current()) {
        epgPending.remove(item.id);
        notifyListeners();
      }
    }
  }

  void setCredentials({
    String? server,
    String? username,
    String? password,
    bool? remember,
  }) {
    if (server != null) this.server = server;
    if (username != null) this.username = username;
    if (password != null) this.password = password;
    if (remember != null) {
      this.remember = remember;
      if (!remember) {
        logins.removeWhere(
          (l) => l.server == this.server && l.username == this.username,
        );
      }
      final p = _prefs;
      if (p != null) {
        unawaited(_persistRememberChoice(p, remember));
      }
    }
    notifyListeners();
  }

  Future<void> _persistRememberChoice(SharedPreferences p, bool value) async {
    await p.setBool(_kRemember, value);
    if (!value) {
      await p.remove(_kPass);
      await _persistLogins();
    }
  }

  void setTab(ContentTab t) {
    // Selecting the active tab also resets its category. Present the matching
    // full-tab cache immediately instead of showing the old category under an
    // "All" heading until the asynchronous refresh completes.
    items = _cache[t] ?? const [];
    categories = _categoryCache[t] ?? const [];
    tab = t;
    selectedCategoryId = null;
    search = '';
    notifyListeners();
    loadContent(t);
  }

  void setSearch(String value) {
    search = value;
    notifyListeners();
  }

  void selectCategory(String? id) {
    selectedCategoryId = id;
    _visibleRequest++;
    items = id == null ? (_cache[tab] ?? const []) : const [];
    if (id == null) busy = false;
    notifyListeners();
    if (id != null) loadContent(tab, categoryId: id);
  }

  Future<void> loadContent(
    ContentTab t, {
    String? categoryId,
    bool refresh = false,
  }) async {
    final c = client;
    if (c == null) return;
    tab = t;
    selectedCategoryId = categoryId;
    if (refresh) {
      _contentEpoch++;
      _preloading.clear();
      _cache.remove(t);
      _categoryCache.remove(t);
      _catCache.removeWhere((key, _) => key.startsWith('$t:'));
    }
    final epoch = _contentEpoch;
    final request = ++_visibleRequest;
    bool current() =>
        epoch == _contentEpoch &&
        request == _visibleRequest &&
        identical(client, c) &&
        tab == t &&
        selectedCategoryId == categoryId;
    busy = true;
    error = null;
    errorHint = null;
    notifyListeners();
    try {
      final cachedCats = _categoryCache[t];
      if (cachedCats == null || categoryId == null) {
        final cats = switch (t) {
          ContentTab.live => await c.liveCategories(),
          ContentTab.movies => await c.vodCategories(),
          ContentTab.series => await c.seriesCategories(),
        };
        if (!current()) return;
        _categoryCache[t] = cats;
        categories = cats;
      }
      final cached = _cache[t];
      if (cached == null && categoryId == null) {
        final all = switch (t) {
          ContentTab.live => await c.liveStreams(),
          ContentTab.movies => await c.vodStreams(),
          ContentTab.series => await c.series(),
        };
        if (!current()) return;
        _cache[t] = all;
        items = all;
      } else if (categoryId != null) {
        final key = '$t:$categoryId';
        final hit = _catCache[key];
        if (hit != null) {
          items = hit;
        } else {
          final list = switch (t) {
            ContentTab.live => await c.liveStreams(categoryId: categoryId),
            ContentTab.movies => await c.vodStreams(categoryId: categoryId),
            ContentTab.series => await c.series(categoryId: categoryId),
          };
          if (!current()) return;
          _catCache[key] = list;
          items = list;
        }
      } else {
        items = cached ?? const [];
      }
    } on XtreamException catch (e) {
      if (!current()) return;
      error = e.message;
      errorHint = e.hint;
    } catch (e) {
      if (!current()) return;
      error = '$e';
    }
    if (!current()) return;
    busy = false;
    notifyListeners();
  }
}
