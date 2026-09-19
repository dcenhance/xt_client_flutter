import 'package:flutter/foundation.dart' hide Category;
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';
import 'xtream_client.dart';

enum ContentTab { live, movies, series }

/// How much content fits on screen. Persisted.
enum ViewMode { grid, list }

enum Density { comfortable, compact }

class AppState extends ChangeNotifier {
  static const _kServer = 'server';
  static const _kUser = 'user';
  static const _kPass = 'pass';
  static const _kRemember = 'remember';
  static const _kViewMode = 'view_mode';
  static const _kDensity = 'density';

  SharedPreferences? _prefs;

  String server = '';
  String username = '';
  String password = '';
  bool remember = true;
  ViewMode viewMode = ViewMode.grid;
  Density density = Density.comfortable;

  /// True when browsing a panel that answers without credentials.
  bool guest = false;

  bool busy = false;
  String? error;
  String? errorHint;
  AccountInfo? account;

  ContentTab tab = ContentTab.live;
  List<Category> categories = const [];
  List<StreamItem> items = const [];
  String? selectedCategoryId;
  String search = '';
  final Map<ContentTab, List<StreamItem>> _cache = {};
  final Map<ContentTab, List<Category>> _categoryCache = {};
  final Map<String, List<StreamItem>> _catCache = {};

  XtreamClient? client;

  List<StreamItem> get visibleItems {
    final q = search.trim().toLowerCase();
    if (q.isEmpty) return items;
    return items.where((i) => i.name.toLowerCase().contains(q)).toList();
  }

  bool get loggedIn => account != null || guest;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
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
    if (server.isNotEmpty && username.isNotEmpty && password.isNotEmpty) {
      await login(silent: true);
    }
    notifyListeners();
  }

  Future<void> setViewMode(ViewMode mode) async {
    viewMode = mode;
    await _prefs?.setString(_kViewMode, mode == ViewMode.list ? 'list' : 'grid');
    notifyListeners();
  }

  Future<void> setDensity(Density value) async {
    density = value;
    await _prefs?.setString(_kDensity, value == Density.compact ? 'compact' : 'comfortable');
    notifyListeners();
  }

  /// Browse a panel that answers without credentials. No account is claimed:
  /// if the panel refuses anonymous requests, the content lists stay empty and
  /// the error explains it.
  Future<bool> browseAsGuest(String server, {bool silent = false}) async {
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
    _cache.clear();
    _categoryCache.clear();
    _catCache.clear();
    selectedCategoryId = null;
    items = const [];
    categories = const [];
    busy = false;
    notifyListeners();
    await loadContent(tab);
    return error == null;
  }

  Future<void> logout() async {
    account = null;
    client = null;
    guest = false;
    items = const [];
    categories = const [];
    selectedCategoryId = null;
    _cache.clear();
    _categoryCache.clear();
    _catCache.clear();
    error = null;
    errorHint = null;
    final p = _prefs;
    if (p != null) {
      await p.remove(_kPass);
    }
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

  Future<bool> login({bool silent = false}) async {
    if (!silent) {
      busy = true;
      error = null;
      errorHint = null;
      notifyListeners();
    }
    try {
      final c = XtreamClient(
        server: XtreamClient.normaliseServer(server),
        username: username.trim(),
        password: password,
      );
      final info = await c.login();
      client = c;
      account = info;
      // Keep the address that actually worked (the app may have switched
      // https:// to http:// automatically).
      server = c.effectiveServer;
      await _persist();
      _cache.clear();
      _categoryCache.clear();
      selectedCategoryId = null;
      items = const [];
      categories = const [];
      error = null;
      errorHint = null;
      busy = false;
      notifyListeners();
      await loadContent(tab);
      return true;
    } on XtreamException catch (e) {
      account = null;
      client = null;
      error = e.message;
      errorHint = e.hint;
      busy = false;
      if (silent) {
        // keep stored values, just show the login screen
      } else {
        notifyListeners();
      }
      notifyListeners();
      return false;
    } catch (e) {
      account = null;
      client = null;
      error = '$e';
      errorHint = null;
      busy = false;
      notifyListeners();
      return false;
    }
  }

  void setCredentials({String? server, String? username, String? password, bool? remember}) {
    if (server != null) this.server = server;
    if (username != null) this.username = username;
    if (password != null) this.password = password;
    if (remember != null) this.remember = remember;
    notifyListeners();
  }

  void setTab(ContentTab t) {
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
    items = id == null ? (_cache[tab] ?? const []) : const [];
    notifyListeners();
    if (id != null) loadContent(tab, categoryId: id);
  }

  Future<void> loadContent(ContentTab t, {String? categoryId, bool refresh = false}) async {
    final c = client;
    if (c == null) return;
    tab = t;
    if (refresh) {
      _cache.remove(t);
      _categoryCache.remove(t);
    }
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
          _catCache[key] = list;
          items = list;
        }
      } else {
        items = cached ?? const [];
      }
    } on XtreamException catch (e) {
      error = e.message;
      errorHint = e.hint;
    } catch (e) {
      error = '$e';
    }
    busy = false;
    notifyListeners();
  }
}