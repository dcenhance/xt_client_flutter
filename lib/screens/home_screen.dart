import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../main.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets/app_mark.dart';
import '../widgets/dpad_field.dart';
import '../widgets/focus_ring.dart';
import 'player_screen.dart';
import 'settings_sheet.dart';

/// Opens an item: series go to the season sheet, everything else to the player.
void _openItem(BuildContext context, StreamItem item) {
  if (item.kind == 'series') {
    showSeriesSheet(context, item);
    return;
  }
  Navigator.of(context)
      .push(MaterialPageRoute(builder: (_) => PlayerScreen(item: item)));
}

/// Compact layouts have no persistent search field. Open a real input rather
/// than focusing a node that is not mounted in the tree.
Future<void> _showContentSearch(
  BuildContext context,
  TextEditingController controller,
) {
  final focus = dpadTextFocusNode(controller: controller);
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Search'),
      content: TextField(
        controller: controller,
        focusNode: focus,
        autofocus: true,
        decoration: InputDecoration(
          hintText: 'Channels, movies, series',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: IconButton(
            tooltip: 'Clear search',
            icon: const Icon(Icons.clear),
            onPressed: () {
              controller.clear();
              appState.setSearch('');
            },
          ),
        ),
        onChanged: appState.setSearch,
        onSubmitted: (_) => Navigator.of(dialogContext).pop(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('Done'),
        ),
      ],
    ),
  ).whenComplete(focus.dispose);
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _searchController = TextEditingController();
  // D-pad save: a remote must be able to leave the search box again.
  late final _searchFocus = dpadTextFocusNode(controller: _searchController);
  final _gridFocus = FocusNode();
  bool _searchOpen = false;
  int _mobileIndex = 0;

  static const _mobileTabs = <(String, IconData)>[
    ('Live TV', Icons.live_tv_outlined),
    ('Movies', Icons.movie_outlined),
    ('Series', Icons.video_library_outlined),
    ('Account', Icons.person_outline),
  ];

  static const _mobileTabsToContent = <ContentTab>[
    ContentTab.live,
    ContentTab.movies,
    ContentTab.series,
  ];

  @override
  void initState() {
    super.initState();
    _searchController.text = appState.search;
    appState.addListener(_syncSearch);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (appState.items.isEmpty && appState.client != null) {
        appState.loadContent(appState.tab);
      }
    });
  }

  @override
  void dispose() {
    appState.removeListener(_syncSearch);
    _searchController.dispose();
    _searchFocus.dispose();
    _gridFocus.dispose();
    super.dispose();
  }

  void _syncSearch() {
    if (_searchController.text != appState.search) {
      _searchController.value = TextEditingValue(
        text: appState.search,
        selection: TextSelection.collapsed(offset: appState.search.length),
      );
    }
  }

  /// Bottom-navigation shell used on Android and iOS.
  void _open(BuildContext context, StreamItem item) => _openItem(context, item);

  /// Every shell gets the same traversal policy, so arrows and TAB walk out of
  /// the toolbar and into the content on a remote or keyboard.
  Widget _shell(Widget child) =>
      FocusTraversalGroup(policy: ReadingOrderTraversalPolicy(), child: child);

  void _selectMobileTab(int index) {
    setState(() => _mobileIndex = index);
    if (index < _mobileTabsToContent.length) {
      appState.setTab(_mobileTabsToContent[index]);
    }
  }

  Widget _mobileShell(BuildContext context, AccountInfo? a) {
    final onContent = _mobileIndex < _mobileTabsToContent.length;
    return Scaffold(
      appBar: AppBar(
        // One clean line: the mark and what this tab holds. The subscription
        // details live in Account, not squeezed into the title bar.
        titleSpacing: 14,
        title: Row(
          children: [
            AppMark(size: 22),
            const SizedBox(width: 10),
            Text(onContent ? _mobileTabs[_mobileIndex].$1 : 'Account'),
          ],
        ),
        actions: [
          if (appState.guest)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(right: 4),
                child: _GuestChip(),
              ),
            ),
          if (onContent) ...[
            IconButton(
              tooltip: 'Search',
              icon: Icon(
                appState.search.isEmpty ? Icons.search : Icons.search_off,
              ),
              onPressed: () {
                setState(() => _searchOpen = !_searchOpen);
                if (_searchOpen) _searchFocus.requestFocus();
              },
            ),
            PopupMenuButton<String>(
              tooltip: 'View & refresh',
              icon: const Icon(Icons.tune),
              onSelected: (choice) {
                switch (choice) {
                  case 'view':
                    appState.setViewMode(
                      appState.viewMode == ViewMode.grid
                          ? ViewMode.list
                          : ViewMode.grid,
                    );
                    break;
                  case 'density':
                    appState.setDensity(
                      appState.density == Density.compact
                          ? Density.comfortable
                          : Density.compact,
                    );
                    break;
                  case 'reload':
                    appState.loadContent(appState.tab, refresh: true);
                    break;
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'view',
                  child: Text(
                    appState.viewMode == ViewMode.grid
                        ? 'List view'
                        : 'Grid view',
                  ),
                ),
                PopupMenuItem(
                  value: 'density',
                  child: Text(
                    appState.density == Density.compact
                        ? 'Comfortable spacing'
                        : 'Compact spacing',
                  ),
                ),
                const PopupMenuItem(value: 'reload', child: Text('Reload')),
              ],
            ),
            const SizedBox(width: 4),
          ],
        ],
      ),
      body: onContent
          ? Column(
              children: [
                if (_searchOpen)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                    child: _SearchField(
                      controller: _searchController,
                      focusNode: _searchFocus,
                    ),
                  ),
                _CategoryChips(),
                const Divider(height: 1),
                Expanded(child: _ContentArea(gridFocus: _gridFocus)),
                if (appState.busy) const LinearProgressIndicator(minHeight: 2),
              ],
            )
          : const SettingsPage(),
      bottomNavigationBar: NavigationBar(
        height: 62,
        backgroundColor: AppTheme.surface,
        indicatorColor: AppTheme.accent.withValues(alpha: 0.18),
        selectedIndex: _mobileIndex,
        onDestinationSelected: _selectMobileTab,
        destinations: [
          for (final (label, icon) in _mobileTabs)
            NavigationDestination(icon: Icon(icon), label: label),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: appState,
      builder: (context, _) {
        final a = appState.account;
        final narrow = MediaQuery.sizeOf(context).width < 720;
        // Alternative shells, pickable in Settings and available on every
        // platform — the classic one keeps its per-platform split below.
        switch (appState.layout) {
          case LayoutStyle.sidebar:
            return _shell(
              _SidebarShell(
                account: a,
                narrow: narrow,
                onOpen: _open,
                searchController: _searchController,
                searchFocus: _searchFocus,
                gridFocus: _gridFocus,
              ),
            );
          case LayoutStyle.showcase:
            return _shell(
              _ShowcaseShell(
                account: a,
                narrow: narrow,
                onOpen: _open,
                searchController: _searchController,
                searchFocus: _searchFocus,
                gridFocus: _gridFocus,
              ),
            );
          case LayoutStyle.dashboard:
            return _shell(
              _DashboardShell(
                narrow: narrow,
                onOpen: _open,
                searchController: _searchController,
                searchFocus: _searchFocus,
                gridFocus: _gridFocus,
              ),
            );
          case LayoutStyle.cinema:
            return _shell(
              _CinemaShell(
                narrow: narrow,
                onOpen: _open,
                searchController: _searchController,
              ),
            );
          case LayoutStyle.masterDetail:
            return _shell(
              _MasterDetailShell(
                account: a,
                narrow: narrow,
                onOpen: _open,
                searchController: _searchController,
                searchFocus: _searchFocus,
                gridFocus: _gridFocus,
              ),
            );
          case LayoutStyle.classic:
            break;
        }
        // Phones and tablets get a bottom navigation shell; desktops keep the
        // tab strip + category rail.
        if (Platform.isAndroid || Platform.isIOS) {
          return _mobileShell(context, a);
        }
        return CallbackShortcuts(
          bindings: {
            const SingleActivator(LogicalKeyboardKey.keyF, control: true): () =>
                _searchFocus.requestFocus(),
            const SingleActivator(LogicalKeyboardKey.slash): () =>
                _searchFocus.requestFocus(),
          },
          child: FocusTraversalGroup(
            policy: ReadingOrderTraversalPolicy(),
            child: Scaffold(
              appBar: AppBar(
                title: narrow
                    ? const Text(
                        'Spectre',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      )
                    : Row(
                        children: [
                          const Text('Spectre'),
                          if (!narrow) const SizedBox(width: 16),
                          if (!narrow && a != null) _AccountChip(account: a),
                          if (!narrow && appState.guest) const _GuestChip(),
                          const Spacer(),
                        ],
                      ),
                actions: [
                  if (narrow)
                    IconButton(
                      tooltip: 'Search',
                      icon: Icon(
                        appState.search.isEmpty
                            ? Icons.search
                            : Icons.search_off,
                      ),
                      onPressed: () {
                        setState(() => _searchOpen = !_searchOpen);
                        if (_searchOpen) _searchFocus.requestFocus();
                      },
                    )
                  else
                    SizedBox(
                      width: 250,
                      child: _SearchField(
                        controller: _searchController,
                        focusNode: _searchFocus,
                      ),
                    ),
                  if (!narrow)
                    IconButton(
                      tooltip: appState.viewMode == ViewMode.grid
                          ? 'List view (fits more)'
                          : 'Grid view',
                      icon: Icon(
                        appState.viewMode == ViewMode.grid
                            ? Icons.view_list_outlined
                            : Icons.grid_view_outlined,
                      ),
                      onPressed: () => appState.setViewMode(
                        appState.viewMode == ViewMode.grid
                            ? ViewMode.list
                            : ViewMode.grid,
                      ),
                    ),
                  if (!narrow)
                    IconButton(
                      tooltip: appState.density == Density.compact
                          ? 'Comfortable spacing'
                          : 'Compact spacing (fits more)',
                      icon: Icon(
                        appState.density == Density.compact
                            ? Icons.density_medium
                            : Icons.density_small,
                      ),
                      onPressed: () => appState.setDensity(
                        appState.density == Density.compact
                            ? Density.comfortable
                            : Density.compact,
                      ),
                    ),
                  if (!narrow)
                    IconButton(
                      tooltip: 'Reload',
                      icon: const Icon(Icons.refresh),
                      onPressed: () =>
                          appState.loadContent(appState.tab, refresh: true),
                    ),
                  if (narrow)
                    PopupMenuButton<String>(
                      tooltip: 'View & refresh',
                      icon: const Icon(Icons.tune),
                      onSelected: (choice) {
                        switch (choice) {
                          case 'view':
                            appState.setViewMode(
                              appState.viewMode == ViewMode.grid
                                  ? ViewMode.list
                                  : ViewMode.grid,
                            );
                          case 'density':
                            appState.setDensity(
                              appState.density == Density.compact
                                  ? Density.comfortable
                                  : Density.compact,
                            );
                          case 'reload':
                            appState.loadContent(appState.tab, refresh: true);
                        }
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(
                          value: 'view',
                          child: Text('Toggle list / grid'),
                        ),
                        PopupMenuItem(
                          value: 'density',
                          child: Text('Toggle spacing'),
                        ),
                        PopupMenuItem(value: 'reload', child: Text('Reload')),
                      ],
                    ),
                  IconButton(
                    tooltip: 'Account & settings',
                    icon: const Icon(Icons.settings_outlined),
                    onPressed: () => showSettingsSheet(context),
                  ),
                  const SizedBox(width: 6),
                ],
              ),
              body: Column(
                children: [
                  if (narrow && a != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: _AccountChip(account: a),
                      ),
                    ),
                  if (narrow && _searchOpen)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                      child: _SearchField(
                        controller: _searchController,
                        focusNode: _searchFocus,
                      ),
                    ),
                  _TabBar(),
                  Expanded(
                    child: narrow
                        ? Column(
                            children: [
                              _CategoryChips(),
                              const Divider(height: 1),
                              Expanded(
                                child: _ContentArea(gridFocus: _gridFocus),
                              ),
                            ],
                          )
                        : Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _CategoryRail(),
                              const VerticalDivider(width: 1),
                              Expanded(
                                child: _ContentArea(gridFocus: _gridFocus),
                              ),
                            ],
                          ),
                  ),
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 7,
                    ),
                    child: Row(
                      children: [
                        if (!narrow)
                          const Expanded(
                            child: KeyHintBar(
                              hints: [
                                ('↑ ↓ ← →', 'move'),
                                ('OK / Enter', 'open'),
                                ('Esc', 'back'),
                                ('Ctrl+F', 'search'),
                              ],
                            ),
                          ),
                        Text(
                          '${appState.visibleItems.length} of ${appState.items.length} items',
                          style: TextStyle(fontSize: 11, color: AppTheme.muted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _AccountChip extends StatelessWidget {
  const _AccountChip({required this.account});

  final AccountInfo account;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppTheme.border),
      ),
      child: Text(
        '${account.username} · ${account.expired ? "EXPIRED" : "expires ${account.expiryLabel}"} · '
        '${account.activeConnections}/${account.maxConnections} conn',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 11,
          color: account.expired ? AppTheme.danger : AppTheme.ok,
        ),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller, required this.focusNode});

  final TextEditingController controller;
  final FocusNode focusNode;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        onChanged: appState.setSearch,
        decoration: InputDecoration(
          hintText: 'Search…',
          prefixIcon: Icon(Icons.search, size: 16, color: AppTheme.muted),
          suffixIcon: appState.search.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.close, size: 15),
                  onPressed: () {
                    controller.clear();
                    appState.setSearch('');
                  },
                ),
        ),
        style: const TextStyle(fontSize: 13),
      ),
    );
  }
}

/// Horizontal category strip used on narrow (phone / portrait) layouts.
class _CategoryChips extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cats = appState.categories;
    return SizedBox(
      height: 46,
      child: FocusTraversalGroup(
        policy: OrderedTraversalPolicy(),
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          children: [
            FocusTraversalOrder(
              order: const NumericFocusOrder(0),
              child: _CategoryChip(
                label: 'All',
                selected: appState.selectedCategoryId == null,
                onSelect: () => appState.selectCategory(null),
              ),
            ),
            for (var i = 0; i < cats.length; i++)
              FocusTraversalOrder(
                order: NumericFocusOrder(i + 1),
                child: _CategoryChip(
                  label: cats[i].name,
                  selected: appState.selectedCategoryId == cats[i].id,
                  onSelect: () => appState.selectCategory(cats[i].id),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.selected,
    required this.onSelect,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FocusRing(
        borderRadius: 14,
        onSelect: onSelect,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: selected
                ? AppTheme.accent.withValues(alpha: 0.16)
                : AppTheme.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? AppTheme.accent : AppTheme.border,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              color: selected ? AppTheme.accent : AppTheme.text,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }
}

class _TabBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    const labels = {
      ContentTab.live: ('Live TV', Icons.live_tv_outlined),
      ContentTab.movies: ('Movies', Icons.movie_outlined),
      ContentTab.series: ('Series', Icons.video_library_outlined),
    };
    return Container(
      height: 46,
      decoration: BoxDecoration(
        color: AppTheme.surface,
        border: Border(bottom: BorderSide(color: AppTheme.border)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final entry in labels.entries)
              FocusRing(
                borderRadius: 4,
                onSelect: () => appState.setTab(entry.key),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  margin: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: appState.tab == entry.key
                        ? AppTheme.accent.withValues(alpha: 0.14)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        entry.value.$2,
                        size: 16,
                        color: appState.tab == entry.key
                            ? AppTheme.accent
                            : AppTheme.muted,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        entry.value.$1,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: appState.tab == entry.key
                              ? FontWeight.w600
                              : FontWeight.w400,
                          color: appState.tab == entry.key
                              ? AppTheme.accent
                              : AppTheme.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (appState.busy)
              const Padding(
                padding: EdgeInsets.only(right: 16),
                child: SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CategoryRail extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cats = appState.categories;
    return Container(
      width: 210,
      color: AppTheme.surface,
      child: FocusTraversalGroup(
        policy: OrderedTraversalPolicy(),
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 6),
          children: [
            FocusTraversalOrder(
              order: const NumericFocusOrder(0),
              child: _CategoryRow(
                label: 'All',
                selected: appState.selectedCategoryId == null,
                count: appState.items.length,
                onSelect: () => appState.selectCategory(null),
              ),
            ),
            const Divider(height: 9),
            for (var i = 0; i < cats.length; i++)
              FocusTraversalOrder(
                order: NumericFocusOrder(i + 1),
                child: _CategoryRow(
                  label: cats[i].name,
                  selected: appState.selectedCategoryId == cats[i].id,
                  onSelect: () => appState.selectCategory(cats[i].id),
                ),
              ),
            if (cats.isEmpty && !appState.busy)
              Padding(
                padding: EdgeInsets.all(14),
                child: Text(
                  'No categories',
                  style: TextStyle(fontSize: 12, color: AppTheme.muted),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    required this.label,
    required this.selected,
    required this.onSelect,
    this.count,
  });

  final String label;
  final bool selected;
  final int? count;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    return FocusRing(
      borderRadius: 3,
      onSelect: onSelect,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        color: selected
            ? AppTheme.accent.withValues(alpha: 0.12)
            : Colors.transparent,
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12.5,
                  color: selected ? AppTheme.accent : AppTheme.text,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
            if (count != null)
              Text(
                '$count',
                style: TextStyle(fontSize: 10.5, color: AppTheme.muted),
              ),
          ],
        ),
      ),
    );
  }
}

class _ContentArea extends StatelessWidget {
  const _ContentArea({required this.gridFocus});

  final FocusNode gridFocus;

  @override
  Widget build(BuildContext context) {
    if (appState.error != null) {
      return _ErrorPanel(message: appState.error!, hint: appState.errorHint);
    }
    final items = appState.visibleItems;
    final st = appState;
    final compact = st.density == Density.compact;
    if (appState.busy && items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (items.isEmpty) {
      return Center(
        child: Text(
          'Nothing to show for this category.',
          style: TextStyle(fontSize: 13, color: AppTheme.muted),
        ),
      );
    }
    return FocusTraversalGroup(
      policy: ReadingOrderTraversalPolicy(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // A wide, poster-led strip on top — the part that makes a catalogue
          // feel curated rather than dumped in a grid. Hidden while searching
          // and inside a category, where the flat list is what you want.
          if (!compact &&
              st.viewMode == ViewMode.grid &&
              st.search.trim().isEmpty &&
              st.selectedCategoryId == null &&
              items.length > 6)
            _FeaturedRow(
              title: st.tab == ContentTab.live ? 'On now' : 'Featured',
              items: items.take(14).toList(),
              onOpen: (item) => _open(context, item),
            ),
          Expanded(
            child: st.viewMode == ViewMode.list
                ? ListView.builder(
                    padding: EdgeInsets.all(compact ? 6 : 10),
                    itemCount: items.length,
                    itemBuilder: (context, i) => _StreamRow(
                      item: items[i],
                      dense: compact,
                      autofocus: i == 0,
                      onSelect: () => _open(context, items[i]),
                    ),
                  )
                : GridView.builder(
                    padding: EdgeInsets.all(compact ? 8 : 14),
                    gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: compact ? 146 : 190,
                      childAspectRatio: compact ? 1.02 : 0.78,
                      mainAxisSpacing: compact ? 7 : 12,
                      crossAxisSpacing: compact ? 7 : 12,
                    ),
                    itemCount: items.length,
                    itemBuilder: (context, i) {
                      final item = items[i];
                      return _StreamCard(
                        item: item,
                        compact: compact,
                        autofocus: i == 0,
                        onSelect: () => _open(context, item),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _open(BuildContext context, StreamItem item) => _openItem(context, item);
}

class _GuestChip extends StatelessWidget {
  const _GuestChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppTheme.accent.withValues(alpha: 0.12),
        border: Border.all(color: AppTheme.accent.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.lock_open, size: 12, color: AppTheme.accent),
          SizedBox(width: 5),
          Text(
            'no login — open panel',
            style: TextStyle(fontSize: 11, color: AppTheme.accent),
          ),
        ],
      ),
    );
  }
}

/// The poster tile. Art fills the top, a soft gradient under the caption keeps
/// the text readable on bright artwork, and the whole tile lifts on focus.
class _StreamCard extends StatelessWidget {
  const _StreamCard({
    required this.item,
    required this.onSelect,
    this.compact = false,
    this.autofocus = false,
  });

  final StreamItem item;
  final VoidCallback onSelect;
  final bool compact;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    return FocusRing(
      borderRadius: AppTheme.cardRadius,
      autofocus: autofocus,
      onSelect: onSelect,
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.card,
          borderRadius: BorderRadius.circular(AppTheme.cardRadius),
          border: Border.all(color: AppTheme.border),
          boxShadow: [
            BoxShadow(
              color: AppTheme.background.withValues(alpha: 0.5),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Container(color: AppTheme.surface),
                  if (item.icon == null)
                    Center(
                      child: Icon(
                        item.kind == 'series'
                            ? Icons.video_library_outlined
                            : (item.kind == 'live'
                                  ? Icons.sensors
                                  : Icons.movie_outlined),
                        color: AppTheme.border,
                        size: 30,
                      ),
                    )
                  else
                    Image.network(
                      item.icon!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Center(
                        child: Icon(
                          Icons.broken_image_outlined,
                          color: AppTheme.border,
                          size: 26,
                        ),
                      ),
                      loadingBuilder: (c, child, p) => p == null
                          ? child
                          : Center(
                              child: SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            ),
                    ),
                  // Warm sheen so flat artwork does not look like a dead tile.
                  DecoratedBox(
                    decoration: BoxDecoration(gradient: AppTheme.scrim()),
                  ),
                  if (item.kind == 'live')
                    Positioned(
                      left: 6,
                      top: 6,
                      child: _Pill(label: 'LIVE', color: AppTheme.accent2),
                    ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                compact ? 8 : 10,
                compact ? 6 : 8,
                compact ? 8 : 10,
                compact ? 8 : 10,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    maxLines: compact ? 1 : 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: compact ? 11.5 : 12.5,
                      color: AppTheme.text,
                      fontWeight: FontWeight.w600,
                      height: 1.25,
                    ),
                  ),
                  if (!compact)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        item.kind == 'series'
                            ? 'Series'
                            : (item.kind == 'live' ? 'Live channel' : 'Movie'),
                        style: TextStyle(fontSize: 10.5, color: AppTheme.muted),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Small coloured label used on live tiles.
class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.6,
          color: AppTheme.isDark ? const Color(0xFF15100B) : Colors.white,
        ),
      ),
    );
  }
}

/// Horizontal poster strip at the top of a catalogue, with a section heading.
class _FeaturedRow extends StatelessWidget {
  const _FeaturedRow({
    required this.title,
    required this.items,
    required this.onOpen,
  });

  final String title;
  final List<StreamItem> items;
  final void Function(StreamItem) onOpen;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              Container(
                width: 3,
                height: 15,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [AppTheme.accent, AppTheme.accent2],
                  ),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.text,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 196,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            itemCount: items.length,
            itemBuilder: (context, i) => Padding(
              padding: const EdgeInsets.only(right: 10),
              child: SizedBox(
                width: 132,
                child: _StreamCard(
                  item: items[i],
                  autofocus: i == 0,
                  onSelect: () => onOpen(items[i]),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
      ],
    );
  }
}

/// Dense one-line row: fits roughly four times as many channels as a card and is
/// what you want on a TV list or a long movie catalogue.
class _StreamRow extends StatelessWidget {
  const _StreamRow({
    required this.item,
    required this.onSelect,
    this.dense = false,
    this.autofocus = false,
  });

  final StreamItem item;
  final VoidCallback onSelect;
  final bool dense;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    return FocusRing(
      autofocus: autofocus,
      onSelect: onSelect,
      child: Container(
        margin: EdgeInsets.symmetric(vertical: dense ? 1 : 2),
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: dense ? 3 : 5),
        decoration: BoxDecoration(
          color: AppTheme.card,
          borderRadius: BorderRadius.circular(5),
          border: Border.all(color: AppTheme.border),
        ),
        child: Row(
          children: [
            SizedBox(
              width: dense ? 34 : 44,
              height: dense ? 26 : 32,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: Container(
                  color: const Color(0xFF0B0D10),
                  child: item.icon == null
                      ? Icon(Icons.tv, color: AppTheme.border, size: 15)
                      : Image.network(
                          item.icon!,
                          fit: BoxFit.contain,
                          errorBuilder: (_, _, _) =>
                              Icon(Icons.tv, color: AppTheme.border, size: 15),
                          loadingBuilder: (c, child, p) =>
                              p == null ? child : const SizedBox.shrink(),
                        ),
                ),
              ),
            ),
            SizedBox(width: dense ? 8 : 10),
            Expanded(
              child: Text(
                item.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: dense ? 12 : 13,
                  color: AppTheme.text,
                ),
              ),
            ),
            if (item.kind == 'series')
              Padding(
                padding: EdgeInsets.only(left: 6),
                child: Icon(
                  Icons.video_library_outlined,
                  size: 13,
                  color: AppTheme.muted,
                ),
              ),
            if (item.kind == 'live')
              Padding(
                padding: EdgeInsets.only(left: 6),
                child: Icon(Icons.sensors, size: 13, color: AppTheme.accent),
              ),
          ],
        ),
      ),
    );
  }
}

class _ErrorPanel extends StatelessWidget {
  const _ErrorPanel({required this.message, this.hint});

  final String message;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppTheme.danger.withValues(alpha: 0.07),
            border: Border.all(color: AppTheme.danger.withValues(alpha: 0.4)),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, color: AppTheme.danger, size: 26),
              const SizedBox(height: 12),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.danger, fontSize: 13),
              ),
              if (hint != null) ...[
                const SizedBox(height: 10),
                Text(
                  hint!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppTheme.muted,
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () =>
                    appState.loadContent(appState.tab, refresh: true),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Series picker: loads episodes for the chosen series, plays the one selected.
void showSeriesSheet(BuildContext context, StreamItem series) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppTheme.surface,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => _SeriesSheet(series: series),
  );
}

class _SeriesSheet extends StatefulWidget {
  const _SeriesSheet({required this.series});

  final StreamItem series;

  @override
  State<_SeriesSheet> createState() => _SeriesSheetState();
}

class _SeriesSheetState extends State<_SeriesSheet> {
  List<StreamItem> _episodes = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final c = appState.client;
    if (c == null) {
      setState(() {
        _loading = false;
        _error = 'Sign in to load episodes.';
      });
      return;
    }
    try {
      final eps = await c.seriesEpisodes(widget.series);
      if (!mounted) return;
      setState(() {
        _episodes = eps;
        _loading = false;
        if (eps.isEmpty) _error = 'This series has no episodes listed.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not load episodes. Check your connection and retry.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return FocusTraversalGroup(
      policy: OrderedTraversalPolicy(),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.72,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  if (widget.series.icon != null)
                    Image.network(
                      widget.series.icon!,
                      width: 54,
                      height: 76,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) =>
                          const SizedBox(width: 54, height: 76),
                    ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.series.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          [
                            widget.series.genre,
                            widget.series.rating,
                          ].where((e) => e != null && e.isNotEmpty).join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12, color: AppTheme.muted),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _error!,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppTheme.muted,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton(
                            onPressed: _load,
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: _episodes.length,
                      itemBuilder: (context, i) {
                        final ep = _episodes[i];
                        return FocusTraversalOrder(
                          order: NumericFocusOrder(i.toDouble()),
                          child: FocusRing(
                            borderRadius: 3,
                            onSelect: () {
                              Navigator.pop(context);
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => PlayerScreen(
                                    item: ep,
                                    overrideUrl: appState.client!
                                        .seriesEpisodeUrl(
                                          ep.id,
                                          ep.containerExtension ?? 'mp4',
                                        ),
                                  ),
                                ),
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 11,
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      ep.name,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: AppTheme.text,
                                      ),
                                    ),
                                  ),
                                  Icon(
                                    Icons.play_arrow,
                                    size: 17,
                                    color: AppTheme.accent,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
// ---------------------------------------------------------------------------
// Alternative shells. All of them live on appState and the widgets above, and
// none of them care which platform they run on.
// ---------------------------------------------------------------------------

/// Shared top-of-content toolbar: search, view mode, density, reload.
class _ContentToolbar extends StatelessWidget {
  const _ContentToolbar({required this.controller, required this.focusNode});

  final TextEditingController controller;
  final FocusNode focusNode;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 12, 6),
      child: LayoutBuilder(
        builder: (context, bounds) => bounds.maxWidth < 300
            ? Row(
                children: [
                  IconButton(
                    tooltip: 'Search',
                    icon: const Icon(Icons.search),
                    onPressed: () => _showContentSearch(context, controller),
                  ),
                  PopupMenuButton<String>(
                    tooltip: 'View, refresh & account',
                    icon: const Icon(Icons.more_vert),
                    onSelected: (choice) {
                      switch (choice) {
                        case 'view':
                          appState.setViewMode(
                            appState.viewMode == ViewMode.grid
                                ? ViewMode.list
                                : ViewMode.grid,
                          );
                        case 'density':
                          appState.setDensity(
                            appState.density == Density.compact
                                ? Density.comfortable
                                : Density.compact,
                          );
                        case 'reload':
                          appState.loadContent(appState.tab, refresh: true);
                        case 'account':
                          showSettingsSheet(context);
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                        value: 'view',
                        child: Text('Toggle list / grid'),
                      ),
                      PopupMenuItem(
                        value: 'density',
                        child: Text('Toggle spacing'),
                      ),
                      PopupMenuItem(value: 'reload', child: Text('Reload')),
                      PopupMenuItem(
                        value: 'account',
                        child: Text('Account & settings'),
                      ),
                    ],
                  ),
                ],
              )
            : Row(
                children: [
                  Expanded(
                    child: _SearchField(
                      controller: controller,
                      focusNode: focusNode,
                    ),
                  ),
                  const SizedBox(width: 6),
                  IconButton(
                    tooltip: appState.viewMode == ViewMode.grid
                        ? 'List view'
                        : 'Grid view',
                    icon: Icon(
                      appState.viewMode == ViewMode.grid
                          ? Icons.view_list_outlined
                          : Icons.grid_view_outlined,
                    ),
                    onPressed: () => appState.setViewMode(
                      appState.viewMode == ViewMode.grid
                          ? ViewMode.list
                          : ViewMode.grid,
                    ),
                  ),
                  IconButton(
                    tooltip: appState.density == Density.compact
                        ? 'Comfortable'
                        : 'Compact',
                    icon: Icon(
                      appState.density == Density.compact
                          ? Icons.density_medium
                          : Icons.density_small,
                    ),
                    onPressed: () => appState.setDensity(
                      appState.density == Density.compact
                          ? Density.comfortable
                          : Density.compact,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Reload',
                    icon: const Icon(Icons.refresh),
                    onPressed: () =>
                        appState.loadContent(appState.tab, refresh: true),
                  ),
                  IconButton(
                    tooltip: 'Account & settings',
                    icon: const Icon(Icons.settings_outlined),
                    onPressed: () => showSettingsSheet(context),
                  ),
                ],
              ),
      ),
    );
  }
}

/// Layout: Sidebar — permanent vertical navigation, on every platform.
class _SidebarShell extends StatelessWidget {
  const _SidebarShell({
    required this.account,
    required this.narrow,
    required this.onOpen,
    required this.searchController,
    required this.searchFocus,
    required this.gridFocus,
  });

  final AccountInfo? account;
  final bool narrow;
  final void Function(BuildContext, StreamItem) onOpen;
  final TextEditingController searchController;
  final FocusNode searchFocus;
  final FocusNode gridFocus;

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    // Icon-only rail below ~820 px: a full rail plus a toolbar does not fit.
    final compact = w < 820;
    final width = compact ? 72.0 : 236.0;
    const items = <(String, IconData, ContentTab)>[
      ('Live TV', Icons.live_tv_outlined, ContentTab.live),
      ('Movies', Icons.movie_outlined, ContentTab.movies),
      ('Series', Icons.video_library_outlined, ContentTab.series),
    ];
    return Scaffold(
      body: Row(
        children: [
          Container(
            width: width,
            decoration: BoxDecoration(
              color: AppTheme.surface,
              border: Border(right: BorderSide(color: AppTheme.border)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(compact ? 16 : 18, 20, 16, 18),
                  child: compact
                      ? AppMark(size: 34)
                      : Row(
                          children: [
                            AppMark(size: 30),
                            const SizedBox(width: 10),
                            Text(
                              'Spectre',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.text,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ],
                        ),
                ),
                for (final (label, icon, tab) in items)
                  _SidebarItem(
                    label: label,
                    icon: icon,
                    compact: compact,
                    selected: appState.tab == tab,
                    badge: tab == appState.tab && appState.items.isNotEmpty
                        ? '${appState.items.length}'
                        : null,
                    onTap: () => appState.setTab(tab),
                  ),
                _SidebarItem(
                  label: 'Account',
                  icon: Icons.person_outline,
                  compact: compact,
                  selected: false,
                  onTap: () => showSettingsSheet(context),
                ),
                const Spacer(),
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    compact ? 10 : 14,
                    0,
                    compact ? 10 : 14,
                    16,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (account != null && !compact)
                        _AccountChip(account: account!),
                      if (appState.guest)
                        const Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: _GuestChip(),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Column(
              children: [
                _ContentToolbar(
                  controller: searchController,
                  focusNode: searchFocus,
                ),
                _CategoryChips(),
                const Divider(height: 1),
                Expanded(child: _ContentArea(gridFocus: gridFocus)),
                if (appState.busy) const LinearProgressIndicator(minHeight: 2),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  const _SidebarItem({
    required this.label,
    required this.icon,
    required this.selected,
    required this.compact,
    required this.onTap,
    this.badge,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final bool compact;
  final VoidCallback onTap;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      child: FocusRing(
        borderRadius: 12,
        onSelect: onTap,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 12 : 12,
              vertical: 11,
            ),
            decoration: BoxDecoration(
              color: selected
                  ? AppTheme.accent.withValues(alpha: 0.16)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected
                    ? AppTheme.accent.withValues(alpha: 0.5)
                    : Colors.transparent,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 19,
                  color: selected ? AppTheme.accent : AppTheme.muted,
                ),
                if (!compact) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 13.5,
                        color: selected ? AppTheme.accent : AppTheme.text,
                        fontWeight: selected
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                  ),
                  if (badge != null)
                    Text(
                      badge!,
                      style: TextStyle(fontSize: 11, color: AppTheme.muted),
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Layout: Showcase — hero banner plus one poster rail per category.
class _ShowcaseShell extends StatelessWidget {
  const _ShowcaseShell({
    required this.account,
    required this.narrow,
    required this.onOpen,
    required this.searchController,
    required this.searchFocus,
    required this.gridFocus,
  });

  final AccountInfo? account;
  final bool narrow;
  final void Function(BuildContext, StreamItem) onOpen;
  final TextEditingController searchController;
  final FocusNode searchFocus;
  final FocusNode gridFocus;

  @override
  Widget build(BuildContext context) {
    final items = appState.items;
    // Prefer an item that has artwork: a banner with a logo beats a bare gradient.
    final hero = items.isEmpty
        ? null
        : items.firstWhere((i) => i.icon != null, orElse: () => items.first);
    final w = MediaQuery.sizeOf(context).width;
    final showWordmark = w >= 1040;
    final showSearchField = w >= 900;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 12, 4),
              child: Row(
                children: [
                  if (w >= 420) ...[
                    AppMark(size: 28),
                    const SizedBox(width: 10),
                  ],
                  if (showWordmark)
                    Text(
                      'Spectre',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.text,
                      ),
                    ),
                  if (w >= 420) const SizedBox(width: 14),
                  _NavPills(labels: w >= 950),
                  const Spacer(),
                  if (showSearchField) ...[
                    SizedBox(
                      width: 220,
                      child: _SearchField(
                        controller: searchController,
                        focusNode: searchFocus,
                      ),
                    ),
                    const SizedBox(width: 4),
                  ] else
                    IconButton(
                      tooltip: 'Search',
                      icon: const Icon(Icons.search),
                      onPressed: () =>
                          _showContentSearch(context, searchController),
                    ),
                  if (w >= 420)
                    IconButton(
                      tooltip: 'Reload',
                      icon: const Icon(Icons.refresh),
                      onPressed: () =>
                          appState.loadContent(appState.tab, refresh: true),
                    ),
                  IconButton(
                    tooltip: 'Account & settings',
                    icon: const Icon(Icons.settings_outlined),
                    onPressed: () => showSettingsSheet(context),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _CategoryRails(
                onOpen: onOpen,
                header: hero != null && appState.error == null
                    ? SizedBox(
                        height: narrow ? 240 : 250,
                        child: _HeroBanner(
                          item: hero,
                          onPlay: () => onOpen(context, hero),
                          onBrowse: () => appState.selectCategory(null),
                        ),
                      )
                    : null,
              ),
            ),
            if (appState.busy) const LinearProgressIndicator(minHeight: 2),
          ],
        ),
      ),
    );
  }
}

/// Nav as pills instead of a tab strip.
class _NavPills extends StatelessWidget {
  const _NavPills({required this.labels});

  final bool labels;

  @override
  Widget build(BuildContext context) {
    const items = <(String, IconData, ContentTab)>[
      ('Live', Icons.live_tv_outlined, ContentTab.live),
      ('Movies', Icons.movie_outlined, ContentTab.movies),
      ('Series', Icons.video_library_outlined, ContentTab.series),
    ];
    return Wrap(
      spacing: 6,
      children: [
        for (final (label, icon, tab) in items)
          FocusRing(
            borderRadius: 20,
            onSelect: () => appState.setTab(tab),
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => appState.setTab(tab),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 13,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: appState.tab == tab
                      ? AppTheme.accent.withValues(alpha: 0.18)
                      : Colors.transparent,
                  border: Border.all(
                    color: appState.tab == tab
                        ? AppTheme.accent
                        : AppTheme.border,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      icon,
                      size: 15,
                      color: appState.tab == tab
                          ? AppTheme.accent
                          : AppTheme.muted,
                    ),
                    if (labels) ...[
                      const SizedBox(width: 7),
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: appState.tab == tab
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: appState.tab == tab
                              ? AppTheme.accent
                              : AppTheme.text,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _HeroBanner extends StatelessWidget {
  const _HeroBanner({
    required this.item,
    required this.onPlay,
    required this.onBrowse,
  });

  Widget _heroGlyph(StreamItem item) => Center(
    child: Icon(
      item.kind == 'series'
          ? Icons.video_library_outlined
          : (item.kind == 'live' ? Icons.sensors : Icons.movie_outlined),
      size: 104,
      color: AppTheme.accent.withValues(alpha: 0.5),
    ),
  );

  final StreamItem item;
  final VoidCallback onPlay;
  final VoidCallback onBrowse;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Container(
              decoration: BoxDecoration(gradient: AppTheme.headerGradient()),
            ),
            // Channel logos are small and wide, posters are tall: contained on
            // the right with a glow reads better than a blown-up crop. When the
            // panel has no artwork (or it 404s) a tinted glyph keeps the banner
            // looking designed instead of empty.
            Align(
              alignment: Alignment.centerRight,
              child: FractionallySizedBox(
                widthFactor: 0.5,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.accent.withValues(alpha: 0.18),
                          blurRadius: 44,
                          spreadRadius: 8,
                        ),
                      ],
                    ),
                    child: item.icon == null
                        ? _heroGlyph(item)
                        : Image.network(
                            item.icon!,
                            fit: BoxFit.contain,
                            errorBuilder: (_, _, _) => _heroGlyph(item),
                          ),
                  ),
                ),
              ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    AppTheme.background.withValues(alpha: 0.96),
                    AppTheme.background.withValues(alpha: 0.72),
                    AppTheme.background.withValues(alpha: 0.18),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 18, 22, 18),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.auto_awesome,
                        size: 13,
                        color: AppTheme.accent,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        appState.tab == ContentTab.live ? 'ON NOW' : 'FEATURED',
                        style: TextStyle(
                          fontSize: 11,
                          letterSpacing: 1.6,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.accent,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    item.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.text,
                    ),
                  ),
                  if (item.genre != null && item.genre!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      item.genre!,
                      maxLines: 1,
                      style: TextStyle(fontSize: 12, color: AppTheme.muted),
                    ),
                  ],
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    children: [
                      FilledButton.icon(
                        onPressed: onPlay,
                        icon: const Icon(Icons.play_arrow_rounded, size: 20),
                        label: const Text('Play'),
                      ),
                      OutlinedButton(
                        onPressed: onBrowse,
                        child: const Text('Browse all'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Below the hero: one horizontal rail per category, like a streaming shelf.
class _CategoryRails extends StatelessWidget {
  const _CategoryRails({required this.onOpen, this.header});

  final void Function(BuildContext, StreamItem) onOpen;
  final Widget? header;

  @override
  Widget build(BuildContext context) {
    final cats = appState.categories;
    final items = appState.visibleItems;
    if (items.isEmpty) {
      return Center(
        child: appState.busy
            ? const CircularProgressIndicator()
            : Text(appState.error ?? 'No titles match this view'),
      );
    }
    // Every item stays reachable: a shelf scrolls lazily, including sparse
    // categories and items whose category is absent from the panel's list.
    final rails = <(String, List<StreamItem>)>[];
    final knownIds = cats.map((c) => c.id).toSet();
    for (final c in cats) {
      final inCat = items.where((i) => i.categoryId == c.id).toList();
      if (inCat.isNotEmpty) rails.add((c.name, inCat));
    }
    final uncategorized = items
        .where((i) => !knownIds.contains(i.categoryId))
        .toList();
    if (uncategorized.isNotEmpty) {
      rails.add((cats.isEmpty ? 'All titles' : 'Other', uncategorized));
    }
    return ListView(
      padding: const EdgeInsets.only(bottom: 14),
      children: [
        ?header,
        for (final (title, list) in rails)
          _FeaturedRow(
            title: title,
            items: list,
            onOpen: (item) => onOpen(context, item),
          ),
      ],
    );
  }
}

/// Layout: Dashboard — large tiles you step into, aimed at a TV remote.
class _DashboardShell extends StatefulWidget {
  const _DashboardShell({
    required this.narrow,
    required this.onOpen,
    required this.searchController,
    required this.searchFocus,
    required this.gridFocus,
  });

  final bool narrow;
  final void Function(BuildContext, StreamItem) onOpen;
  final TextEditingController searchController;
  final FocusNode searchFocus;
  final FocusNode gridFocus;

  @override
  State<_DashboardShell> createState() => _DashboardShellState();
}

class _DashboardShellState extends State<_DashboardShell> {
  bool _entered = false;
  final _sectionFocus = FocusNode(debugLabel: 'dashboard-section');
  final _tileFocus = <ContentTab, FocusNode>{
    for (final tab in ContentTab.values)
      tab: FocusNode(debugLabel: 'dashboard-${tab.name}'),
  };

  void _leaveSection() {
    if (!_entered) return;
    final tab = appState.tab;
    setState(() => _entered = false);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _tileFocus[tab]?.requestFocus();
    });
  }

  @override
  void dispose() {
    _sectionFocus.dispose();
    for (final node in _tileFocus.values) {
      node.dispose();
    }
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    // Fill the caches so each tile can show its own artwork, without switching
    // the visible tab away from Live TV.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final t in ContentTab.values) {
        appState.ensureLoaded(t);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_entered,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leaveSection();
      },
      child: CallbackShortcuts(
        bindings: _entered
            ? <ShortcutActivator, VoidCallback>{
                const SingleActivator(LogicalKeyboardKey.escape): _leaveSection,
                const SingleActivator(LogicalKeyboardKey.goBack): _leaveSection,
                const SingleActivator(LogicalKeyboardKey.browserBack):
                    _leaveSection,
                const SingleActivator(LogicalKeyboardKey.gameButtonB):
                    _leaveSection,
              }
            : const <ShortcutActivator, VoidCallback>{},
        child: Focus(
          focusNode: _sectionFocus,
          child: Scaffold(
            body: SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 12, 6),
                    child: Row(
                      children: [
                        if (_entered)
                          IconButton(
                            tooltip: 'Back to sections',
                            icon: const Icon(Icons.arrow_back),
                            onPressed: _leaveSection,
                          )
                        else
                          AppMark(size: 30),
                        const SizedBox(width: 10),
                        if (!widget.narrow) ...[
                          Text(
                            _entered ? appState.tabLabel : 'Spectre',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.text,
                            ),
                          ),
                          const SizedBox(width: 14),
                        ],
                        const Spacer(),
                        SizedBox(
                          width: widget.narrow ? 150 : 240,
                          child: _SearchField(
                            controller: widget.searchController,
                            focusNode: widget.searchFocus,
                          ),
                        ),
                        IconButton(
                          tooltip: 'Account & settings',
                          icon: const Icon(Icons.settings_outlined),
                          onPressed: () => showSettingsSheet(context),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: !_entered
                        ? _DashboardTiles(
                            narrow: widget.narrow,
                            focusNodes: _tileFocus,
                            onEnter: (tab) {
                              appState.setTab(tab);
                              setState(() => _entered = true);
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                if (mounted) _sectionFocus.requestFocus();
                              });
                            },
                          )
                        : Column(
                            children: [
                              _CategoryChips(),
                              const Divider(height: 1),
                              Expanded(
                                child: _ContentArea(
                                  gridFocus: widget.gridFocus,
                                ),
                              ),
                            ],
                          ),
                  ),
                  if (appState.busy)
                    const LinearProgressIndicator(minHeight: 2),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DashboardTiles extends StatelessWidget {
  const _DashboardTiles({
    required this.narrow,
    required this.focusNodes,
    required this.onEnter,
  });

  final bool narrow;
  final Map<ContentTab, FocusNode> focusNodes;
  final void Function(ContentTab) onEnter;

  @override
  Widget build(BuildContext context) {
    const tiles = <(String, IconData, ContentTab, String)>[
      (
        'Live TV',
        Icons.live_tv_outlined,
        ContentTab.live,
        'Channels, now and next',
      ),
      (
        'Movies',
        Icons.movie_outlined,
        ContentTab.movies,
        'The on-demand library',
      ),
      (
        'Series',
        Icons.video_library_outlined,
        ContentTab.series,
        'Seasons and episodes',
      ),
    ];
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
      children: [
        GridView.count(
          crossAxisCount: narrow ? 1 : 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: narrow ? 2.2 : 1.65,
          children: [
            for (final (idx, (label, icon, tab, blurb)) in tiles.indexed)
              _SectionTile(
                autofocus: idx == 0,
                focusNode: focusNodes[tab],
                label: label,
                icon: icon,
                blurb: blurb,
                // Real artwork from the first few entries of that section.
                items: appState.previewFor(tab, take: narrow ? 4 : 5),
                count: appState.countFor(tab),
                loading: appState.loadingFor(tab),
                onTap: () => onEnter(tab),
              ),
          ],
        ),
      ],
    );
  }
}

/// A section tile: the first few posters of that section as a mosaic, darkened
/// so the label stays readable, with a count once the catalogue is known.
class _SectionTile extends StatelessWidget {
  const _SectionTile({
    required this.label,
    required this.icon,
    required this.blurb,
    required this.onTap,
    this.items = const [],
    this.count,
    this.loading = false,
    this.autofocus = false,
    this.focusNode,
  });

  final String label;
  final IconData icon;
  final String blurb;
  final VoidCallback onTap;
  final List<StreamItem> items;
  final int? count;
  final bool loading;
  final bool autofocus;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    return FocusRing(
      focusNode: focusNode,
      borderRadius: 18,
      autofocus: autofocus,
      onSelect: onTap,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: AppTheme.card,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppTheme.border),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (items.isNotEmpty)
                _ArtMosaic(items: items)
              else
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppTheme.accent.withValues(alpha: 0.18),
                        AppTheme.card,
                      ],
                    ),
                  ),
                ),
              // Scrim: keeps the text legible over bright posters.
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AppTheme.background.withValues(alpha: 0.12),
                      AppTheme.background.withValues(alpha: 0.30),
                      AppTheme.background.withValues(alpha: 0.90),
                    ],
                    stops: const [0.0, 0.45, 1.0],
                  ),
                ),
              ),
              if (loading)
                const Align(
                  alignment: Alignment.topRight,
                  child: Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppTheme.background.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(13),
                        border: Border.all(
                          color: AppTheme.accent.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Icon(icon, color: AppTheme.accent, size: 21),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.text,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          count == null ? blurb : '$count  ·  $blurb',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12, color: AppTheme.muted),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// First few posters as a wall. Wide-and-short tiles get a single row, squarer
/// ones a 2x2 (or 3x2) grid — either way it looks like content, not a gradient.
class _ArtMosaic extends StatelessWidget {
  const _ArtMosaic({required this.items});

  final List<StreamItem> items;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final wide = c.maxWidth / c.maxHeight > 2.0;
        final tiles = items.take(wide ? 4 : 6).toList();
        if (wide) {
          return Row(
            children: [
              for (final it in tiles)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 2),
                    child: _Art(
                      url: it.icon,
                      label: it.name,
                      contain: it.kind == 'live',
                    ),
                  ),
                ),
            ],
          );
        }
        final perRow = items.length > 4 && items.first.kind == 'live'
            ? 3
            : (tiles.length <= 4 ? 2 : 3);
        final rows = (tiles.length / perRow).ceil();
        return Column(
          children: [
            for (var r = 0; r < rows; r++)
              Expanded(
                child: Row(
                  children: [
                    for (var i = 0; i < perRow; i++)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(1),
                          child: r * perRow + i < tiles.length
                              ? _Art(
                                  url: tiles[r * perRow + i].icon,
                                  label: tiles[r * perRow + i].name,
                                  contain: tiles[r * perRow + i].kind == 'live',
                                )
                              : const SizedBox.shrink(),
                        ),
                      ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

class _Art extends StatelessWidget {
  const _Art({required this.url, this.label, this.contain = false});

  final String? url;
  final String? label;

  /// Channel logos are square with transparent padding, so they are *contained*
  /// over a soft tile; posters are cropped to fill.
  final bool contain;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        gradient: contain
            ? RadialGradient(
                colors: [
                  AppTheme.accent.withValues(alpha: 0.10),
                  AppTheme.surface,
                ],
              )
            : null,
      ),
      child: url == null || url!.isEmpty
          ? _label()
          : Padding(
              padding: EdgeInsets.all(contain ? 3 : 0),
              child: Image.network(
                url!,
                fit: contain ? BoxFit.contain : BoxFit.cover,
                // Ask for a small decode: these are thumbnails, not full posters.
                cacheWidth: 320,
                errorBuilder: (_, _, _) => _label(),
                loadingBuilder: (c, child, p) =>
                    p == null ? child : const SizedBox.shrink(),
              ),
            ),
    );
  }

  /// No artwork (or it 404s): print the name over the soft tile, so a wall of
  /// live channels still reads as content instead of empty boxes.
  Widget _label() => Center(
    child: Padding(
      padding: const EdgeInsets.all(6),
      child: Text(
        label ?? '',
        textAlign: TextAlign.center,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 10,
          height: 1.2,
          fontWeight: FontWeight.w700,
          color: AppTheme.muted,
        ),
      ),
    ),
  );
}

/// Layout: Cinema — fixed artwork behind a scrollable hero and category shelves.
class _CinemaShell extends StatelessWidget {
  const _CinemaShell({
    required this.narrow,
    required this.onOpen,
    required this.searchController,
  });

  final bool narrow;
  final void Function(BuildContext, StreamItem) onOpen;
  final TextEditingController searchController;

  @override
  Widget build(BuildContext context) {
    final items = appState.visibleItems;
    final hero = items.isEmpty
        ? null
        : items.firstWhere((i) => i.icon != null, orElse: () => items.first);
    final width = MediaQuery.sizeOf(context).width;
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(gradient: AppTheme.headerGradient()),
          ),
          if (hero?.icon != null)
            Image.network(
              hero!.icon!,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppTheme.background.withValues(alpha: 0.82),
                  AppTheme.background.withValues(alpha: 0.72),
                  AppTheme.background.withValues(alpha: 0.96),
                ],
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 12, 4),
                  child: Row(
                    children: [
                      if (width >= 380) ...[
                        AppMark(size: 28),
                        const SizedBox(width: 10),
                      ],
                      if (width >= 1040)
                        Text(
                          'Spectre',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.text,
                          ),
                        ),
                      SizedBox(width: narrow ? 6 : 16),
                      _NavPills(labels: width >= 950),
                      const Spacer(),
                      IconButton(
                        tooltip: 'Search',
                        icon: const Icon(Icons.search),
                        onPressed: () =>
                            _showContentSearch(context, searchController),
                      ),
                      IconButton(
                        tooltip: 'Account & settings',
                        icon: const Icon(Icons.settings_outlined),
                        onPressed: () => showSettingsSheet(context),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _CategoryRails(
                    onOpen: onOpen,
                    header: hero != null && appState.error == null
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(height: narrow ? 96 : 156),
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  22,
                                  0,
                                  22,
                                  18,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      appState.tab == ContentTab.live
                                          ? 'ON NOW'
                                          : 'FEATURED',
                                      style: TextStyle(
                                        fontSize: 11,
                                        letterSpacing: 1.8,
                                        fontWeight: FontWeight.w700,
                                        color: AppTheme.accent,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      hero.name,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: narrow ? 21 : 26,
                                        fontWeight: FontWeight.w700,
                                        color: AppTheme.text,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Wrap(
                                      spacing: 10,
                                      runSpacing: 8,
                                      children: [
                                        FilledButton.icon(
                                          onPressed: () =>
                                              onOpen(context, hero),
                                          icon: const Icon(
                                            Icons.play_arrow_rounded,
                                            size: 20,
                                          ),
                                          label: const Text('Play'),
                                        ),
                                        OutlinedButton(
                                          onPressed: () =>
                                              appState.selectCategory(null),
                                          child: const Text('Browse all'),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          )
                        : null,
                  ),
                ),
                if (appState.busy) const LinearProgressIndicator(minHeight: 2),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Layout: Master-detail — a category column on the left, content on the right.
class _MasterDetailShell extends StatelessWidget {
  const _MasterDetailShell({
    required this.account,
    required this.narrow,
    required this.onOpen,
    required this.searchController,
    required this.searchFocus,
    required this.gridFocus,
  });

  final AccountInfo? account;
  final bool narrow;
  final void Function(BuildContext, StreamItem) onOpen;
  final TextEditingController searchController;
  final FocusNode searchFocus;
  final FocusNode gridFocus;

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final listWidth = w < 900 ? 190.0 : 268.0;
    final cats = appState.categories;
    return Scaffold(
      body: Row(
        children: [
          Container(
            width: listWidth,
            decoration: BoxDecoration(
              color: AppTheme.surface,
              border: Border(right: BorderSide(color: AppTheme.border)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 16, 14, 10),
                  child: Row(
                    children: [
                      AppMark(size: 24),
                      const SizedBox(width: 9),
                      Text(
                        'Spectre',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.text,
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                _MasterTabs(),
                const Divider(height: 1),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    children: [
                      _MasterRow(
                        label: 'All',
                        count: appState.items.length,
                        selected: appState.selectedCategoryId == null,
                        onTap: () => appState.selectCategory(null),
                      ),
                      for (final c in cats)
                        _MasterRow(
                          label: c.name,
                          selected: appState.selectedCategoryId == c.id,
                          onTap: () => appState.selectCategory(c.id),
                        ),
                    ],
                  ),
                ),
                if (account != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 14),
                    child: _AccountChip(account: account!),
                  ),
              ],
            ),
          ),
          Expanded(
            child: Column(
              children: [
                _ContentToolbar(
                  controller: searchController,
                  focusNode: searchFocus,
                ),
                Expanded(child: _ContentArea(gridFocus: gridFocus)),
                if (appState.busy) const LinearProgressIndicator(minHeight: 2),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Vertical section switcher for the master-detail rail — a horizontal tab
/// strip does not fit in a 190-268 px column.
class _MasterTabs extends StatelessWidget {
  const _MasterTabs();

  @override
  Widget build(BuildContext context) {
    const items = <(String, IconData, ContentTab)>[
      ('Live TV', Icons.live_tv_outlined, ContentTab.live),
      ('Movies', Icons.movie_outlined, ContentTab.movies),
      ('Series', Icons.video_library_outlined, ContentTab.series),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Column(
        children: [
          for (final (label, icon, tab) in items)
            FocusRing(
              borderRadius: 10,
              onSelect: () => appState.setTab(tab),
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => appState.setTab(tab),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: appState.tab == tab
                        ? AppTheme.accent.withValues(alpha: 0.16)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        icon,
                        size: 16,
                        color: appState.tab == tab
                            ? AppTheme.accent
                            : AppTheme.muted,
                      ),
                      const SizedBox(width: 9),
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: appState.tab == tab
                              ? AppTheme.accent
                              : AppTheme.text,
                          fontWeight: appState.tab == tab
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _MasterRow extends StatelessWidget {
  const _MasterRow({
    required this.label,
    required this.selected,
    required this.onTap,
    this.count,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final int? count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
      child: FocusRing(
        borderRadius: 10,
        onSelect: onTap,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: BoxDecoration(
              color: selected
                  ? AppTheme.accent.withValues(alpha: 0.16)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: selected ? AppTheme.accent : AppTheme.text,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                    ),
                  ),
                ),
                if (count != null)
                  Text(
                    '$count',
                    style: TextStyle(fontSize: 11, color: AppTheme.muted),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
