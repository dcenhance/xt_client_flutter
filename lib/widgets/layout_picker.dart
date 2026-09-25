import 'package:flutter/material.dart';

import '../l10n.dart';
import '../main.dart';
import '../store.dart';
import '../theme.dart';
import 'focus_ring.dart';

/// Layout picker: each tile draws a miniature wireframe of the shell it applies,
/// so the choice is obvious before tapping it.
class LayoutPicker extends StatelessWidget {
  const LayoutPicker({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: appState,
      builder: (context, _) => Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          for (final style in LayoutStyle.values)
            _LayoutTile(
              style: style,
              name: switch (style) {
                LayoutStyle.classic => tr(context, 'Classic'),
                LayoutStyle.sidebar => tr(context, 'Sidebar'),
                LayoutStyle.showcase => tr(context, 'Showcase'),
                LayoutStyle.dashboard => tr(context, 'Dashboard'),
                LayoutStyle.cinema => tr(context, 'Cinema'),
                LayoutStyle.masterDetail => tr(context, 'Master-detail'),
              },
              blurb: switch (style) {
                LayoutStyle.classic => tr(
                  context,
                  'Tab strip and category rail on desktop, bottom nav on phones',
                ),
                LayoutStyle.sidebar => tr(
                  context,
                  'Permanent vertical navigation, phone and desktop alike',
                ),
                LayoutStyle.showcase => tr(
                  context,
                  'Big hero banner over per-category poster rails',
                ),
                LayoutStyle.dashboard => tr(
                  context,
                  'Compact section tiles with artwork and a remote-friendly focus path',
                ),
                LayoutStyle.cinema => tr(
                  context,
                  'Fixed artwork behind a scrolling hero and category shelves',
                ),
                LayoutStyle.masterDetail => tr(
                  context,
                  'Category column on the left, content on the right',
                ),
              },
              selected: appState.layout == style,
              onSelect: () => appState.setLayout(style),
            ),
        ],
      ),
    );
  }
}

class _LayoutTile extends StatelessWidget {
  const _LayoutTile({
    required this.style,
    required this.name,
    required this.blurb,
    required this.selected,
    required this.onSelect,
  });

  final LayoutStyle style;
  final String name;
  final String blurb;
  final bool selected;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    return FocusRing(
      borderRadius: 16,
      onSelect: onSelect,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onSelect,
        child: Container(
          width: 186,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppTheme.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? AppTheme.accent : AppTheme.border,
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 86,
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.border),
                ),
                padding: const EdgeInsets.all(6),
                child: _Wireframe(style: style),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.text,
                      ),
                    ),
                  ),
                  if (selected)
                    Icon(Icons.check_circle, size: 15, color: AppTheme.accent),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                blurb,
                maxLines: 3,
                style: TextStyle(
                  fontSize: 10.5,
                  color: AppTheme.muted,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The miniature drawing for one shell.
class _Wireframe extends StatelessWidget {
  const _Wireframe({required this.style});

  final LayoutStyle style;

  Widget bar({double? w, double h = 6, bool accent = false}) => Container(
    width: w,
    height: h,
    decoration: BoxDecoration(
      color: accent ? AppTheme.accent : AppTheme.border,
      borderRadius: BorderRadius.circular(2),
    ),
  );

  Widget tile({bool accent = false}) => Expanded(
    child: Container(
      decoration: BoxDecoration(
        color: accent ? AppTheme.accent.withValues(alpha: 0.35) : AppTheme.card,
        border: Border.all(color: AppTheme.border),
        borderRadius: BorderRadius.circular(3),
      ),
    ),
  );

  Widget row(List<Widget> kids) => Expanded(
    child: Row(
      children: [
        for (int i = 0; i < kids.length; i++) ...[
          if (i > 0) const SizedBox(width: 4),
          kids[i],
        ],
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    switch (style) {
      case LayoutStyle.classic:
        return Column(
          children: [
            Row(
              children: [
                bar(w: 40, accent: true),
                const Spacer(),
                bar(w: 26),
                const SizedBox(width: 4),
                bar(w: 12),
              ],
            ),
            const SizedBox(height: 5),
            row([bar(w: 12), bar(w: 26), bar(w: 26)]),
            const SizedBox(height: 4),
            row([tile(), tile(), tile()]),
          ],
        );
      case LayoutStyle.sidebar:
        return Row(
          children: [
            Container(
              width: 34,
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
              decoration: BoxDecoration(
                color: AppTheme.card,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: AppTheme.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  bar(w: 20, accent: true),
                  const SizedBox(height: 4),
                  bar(w: 24),
                  const SizedBox(height: 3),
                  bar(w: 18),
                  const SizedBox(height: 3),
                  bar(w: 22),
                ],
              ),
            ),
            const SizedBox(width: 5),
            Expanded(
              child: Column(
                children: [
                  row([tile(), tile()]),
                  const SizedBox(height: 4),
                  row([tile(), tile()]),
                ],
              ),
            ),
          ],
        );
      case LayoutStyle.showcase:
        return Column(
          children: [
            Container(
              height: 30,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppTheme.accent.withValues(alpha: 0.45),
                    AppTheme.card,
                  ],
                ),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(height: 4),
            row([tile(), tile(), tile(), tile()]),
            const SizedBox(height: 4),
            row([tile(), tile(), tile(), tile()]),
          ],
        );
      case LayoutStyle.cinema:
        return Column(
          children: [
            Container(
              height: 46,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppTheme.card,
                    AppTheme.accent.withValues(alpha: 0.25),
                  ],
                ),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                bar(w: 26, accent: true),
                const SizedBox(width: 4),
                bar(w: 18),
              ],
            ),
            const SizedBox(height: 4),
            row([tile(), tile(), tile(), tile()]),
          ],
        );
      case LayoutStyle.masterDetail:
        return Row(
          children: [
            Container(
              width: 40,
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
              decoration: BoxDecoration(
                color: AppTheme.card,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: AppTheme.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  bar(w: 30, accent: true),
                  const SizedBox(height: 3),
                  bar(w: 26),
                  const SizedBox(height: 3),
                  bar(w: 22),
                  const SizedBox(height: 3),
                  bar(w: 28),
                  const SizedBox(height: 3),
                  bar(w: 18),
                ],
              ),
            ),
            const SizedBox(width: 5),
            Expanded(
              child: Column(
                children: [
                  row([tile(), tile()]),
                  const SizedBox(height: 4),
                  row([tile(), tile()]),
                  const SizedBox(height: 4),
                  row([tile(), tile()]),
                ],
              ),
            ),
          ],
        );

      case LayoutStyle.dashboard:
        return Column(
          children: [
            Row(
              children: [bar(w: 34, accent: true), const Spacer(), bar(w: 10)],
            ),
            const SizedBox(height: 5),
            row([tile(accent: true), tile(accent: true)]),
            const SizedBox(height: 4),
            row([tile(accent: true), tile()]),
          ],
        );
    }
  }
}
