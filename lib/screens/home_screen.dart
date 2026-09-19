import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../main.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets/focus_ring.dart';
import 'player_screen.dart';
import 'settings_sheet.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (appState.items.isEmpty && appState.client != null) {
        appState.loadContent(appState.tab);
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    _gridFocus.dispose();
    super.dispose();
  }

  /// Bottom-navigation shell used on Android and iOS.
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
        title: onContent
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_mobileTabs[_mobileIndex].$1),
                  if (a != null)
                    Text(
                      a.expired
                          ? 'EXPIRED ${a.expiryLabel}'
                          : 'expires ${a.expiryLabel} · ${a.activeConnections}/${a.maxConnections} conn',
                      style: TextStyle(
                        fontSize: 10.5,
                        color: a.expired ? AppTheme.danger : AppTheme.muted,
                      ),
                    ),
                ],
              )
            : const Text('Account'),
        actions: [
          if (onContent) ...[
            IconButton(
              tooltip: 'Search',
              icon: Icon(appState.search.isEmpty ? Icons.search : Icons.search_off),
              onPressed: () {
                setState(() => _searchOpen = !_searchOpen);
                if (_searchOpen) _searchFocus.requestFocus();
              },
            ),
            IconButton(
              tooltip: 'Reload',
              icon: const Icon(Icons.refresh),
              onPressed: () => appState.loadContent(appState.tab, refresh: true),
            ),
          ],
        ],
      ),
      body: onContent
          ? Column(
              children: [
                if (_searchOpen)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                    child: _SearchField(controller: _searchController, focusNode: _searchFocus),
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
            title: Row(
              children: [
                const Text('Xtream Player'),
                const SizedBox(width: 16),
                if (!narrow && a != null) _AccountChip(account: a),
                const Spacer(),
              ],
            ),
            actions: [
              if (narrow)
                IconButton(
                  tooltip: 'Search',
                  icon: Icon(appState.search.isEmpty ? Icons.search : Icons.search_off),
                  onPressed: () {
                    setState(() => _searchOpen = !_searchOpen);
                    if (_searchOpen) _searchFocus.requestFocus();
                  },
                )
              else
                SizedBox(width: 250, child: _SearchField(
                  controller: _searchController,
                  focusNode: _searchFocus,
                )),
              IconButton(
                tooltip: 'Reload',
                icon: const Icon(Icons.refresh),
                onPressed: () => appState.loadContent(appState.tab, refresh: true),
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
                  child: Align(alignment: Alignment.centerLeft, child: _AccountChip(account: a)),
                ),
              if (narrow && _searchOpen)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                  child: _SearchField(controller: _searchController, focusNode: _searchFocus),
                ),
              _TabBar(),
              Expanded(
                child: narrow
                    ? Column(
                        children: [
                          _CategoryChips(),
                          const Divider(height: 1),
                          Expanded(child: _ContentArea(gridFocus: _gridFocus)),
                        ],
                      )
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _CategoryRail(),
                          const VerticalDivider(width: 1),
                          Expanded(child: _ContentArea(gridFocus: _gridFocus)),
                        ],
                      ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                child: Row(
                  children: [
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
                      style: const TextStyle(fontSize: 11, color: AppTheme.muted),
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
          prefixIcon: const Icon(Icons.search, size: 16, color: AppTheme.muted),
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
  const _CategoryChip({required this.label, required this.selected, required this.onSelect});

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
            color: selected ? AppTheme.accent.withValues(alpha: 0.16) : AppTheme.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: selected ? AppTheme.accent : AppTheme.border),
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
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border(bottom: BorderSide(color: AppTheme.border)),
      ),
      child: Row(
        children: [
          for (final entry in labels.entries)
            FocusRing(
              borderRadius: 4,
              onSelect: () => appState.setTab(entry.key),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                decoration: BoxDecoration(
                  color: appState.tab == entry.key
                      ? AppTheme.accent.withValues(alpha: 0.14)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  children: [
                    Icon(entry.value.$2,
                        size: 16,
                        color: appState.tab == entry.key ? AppTheme.accent : AppTheme.muted),
                    const SizedBox(width: 8),
                    Text(
                      entry.value.$1,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: appState.tab == entry.key ? FontWeight.w600 : FontWeight.w400,
                        color: appState.tab == entry.key ? AppTheme.accent : AppTheme.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const Spacer(),
          if (appState.busy)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: SizedBox(
                  width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
            ),
        ],
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
              const Padding(
                padding: EdgeInsets.all(14),
                child: Text('No categories',
                    style: TextStyle(fontSize: 12, color: AppTheme.muted)),
              ),
          ],
        ),
      ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({required this.label, required this.selected, required this.onSelect, this.count});

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
        color: selected ? AppTheme.accent.withValues(alpha: 0.12) : Colors.transparent,
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
              Text('$count', style: const TextStyle(fontSize: 10.5, color: AppTheme.muted)),
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
    if (appState.busy && items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (items.isEmpty) {
      return const Center(
        child: Text('Nothing to show for this category.',
            style: TextStyle(fontSize: 13, color: AppTheme.muted)),
      );
    }
    return FocusTraversalGroup(
      policy: ReadingOrderTraversalPolicy(),
      child: GridView.builder(
        padding: const EdgeInsets.all(14),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 190,
          childAspectRatio: 0.78,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
        ),
        itemCount: items.length,
        itemBuilder: (context, i) {
          final item = items[i];
          return _StreamCard(
            item: item,
            onSelect: () => _open(context, item),
          );
        },
      ),
    );
  }

  void _open(BuildContext context, StreamItem item) {
    if (item.kind == 'series') {
      showSeriesSheet(context, item);
      return;
    }
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => PlayerScreen(item: item),
    ));
  }
}

class _StreamCard extends StatelessWidget {
  const _StreamCard({required this.item, required this.onSelect});

  final StreamItem item;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    return FocusRing(
      onSelect: onSelect,
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.card,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppTheme.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Container(
                color: const Color(0xFF0B0D10),
                child: item.icon == null
                    ? const Center(
                        child: Icon(Icons.tv, color: AppTheme.border, size: 34))
                    : Image.network(
                        item.icon!,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const Center(
                          child: Icon(Icons.tv, color: AppTheme.border, size: 34)),
                        loadingBuilder: (c, child, p) =>
                            p == null ? child : const Center(
                              child: SizedBox(
                                width: 16, height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            ),
                      ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(9, 7, 9, 9),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: AppTheme.text, height: 1.3),
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
              const Icon(Icons.error_outline, color: AppTheme.danger, size: 26),
              const SizedBox(height: 12),
              Text(message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppTheme.danger, fontSize: 13)),
              if (hint != null) ...[
                const SizedBox(height: 10),
                Text(hint!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppTheme.muted, fontSize: 12, height: 1.5)),
              ],
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => appState.loadContent(appState.tab, refresh: true),
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
    final c = appState.client;
    if (c == null) return;
    try {
      final eps = await c.seriesEpisodes(widget.series);
      setState(() {
        _episodes = eps;
        _loading = false;
        if (eps.isEmpty) _error = 'This series has no episodes listed.';
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = '$e';
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
                    Image.network(widget.series.icon!,
                        width: 54, height: 76, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const SizedBox(width: 54, height: 76)),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.series.name,
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 6),
                        Text(
                          [widget.series.genre, widget.series.rating]
                              .where((e) => e != null && e.isNotEmpty)
                              .join(' · '),
                          style: const TextStyle(fontSize: 12, color: AppTheme.muted),
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
                          child: Text(_error!,
                              style: const TextStyle(color: AppTheme.muted, fontSize: 13)))
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
                                  Navigator.of(context).push(MaterialPageRoute(
                                    builder: (_) => PlayerScreen(
                                      item: ep,
                                      overrideUrl: appState.client!.seriesEpisodeUrl(
                                          ep.id, ep.containerExtension ?? 'mp4'),
                                    ),
                                  ));
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 11),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(ep.name,
                                            style: const TextStyle(
                                                fontSize: 13, color: AppTheme.text)),
                                      ),
                                      const Icon(Icons.play_arrow,
                                          size: 17, color: AppTheme.accent),
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