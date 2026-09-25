import 'package:flutter/material.dart';

import '../l10n.dart';
import '../main.dart';
import '../theme.dart';
import 'focus_ring.dart';

/// Swatch picker for the app palette. Each tile previews the colours it would
/// apply — background, card, both accents — because names alone say very little.
class ThemePicker extends StatelessWidget {
  const ThemePicker({super.key, this.wrap = true});

  /// Horizontal scroller (settings sheet) or wrapped grid (wide pages).
  final bool wrap;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: appState,
      builder: (context, _) {
        final tiles = [
          for (final p in kPalettes)
            _ThemeTile(
              palette: p,
              selected: p.id == appState.themeId,
              onSelect: () => appState.setTheme(p.id),
            ),
        ];
        if (!wrap) {
          return SizedBox(
            height: 108,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final t in tiles)
                  Padding(padding: const EdgeInsets.only(right: 10), child: t),
              ],
            ),
          );
        }
        return Wrap(spacing: 10, runSpacing: 10, children: tiles);
      },
    );
  }
}

class _ThemeTile extends StatelessWidget {
  const _ThemeTile({
    required this.palette,
    required this.selected,
    required this.onSelect,
  });

  final AppPalette palette;
  final bool selected;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    return FocusRing(
      borderRadius: 14,
      onSelect: onSelect,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onSelect,
        child: Container(
          width: 152,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: palette.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? palette.accent : palette.border,
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Preview: a poster-ish block over the theme background.
              Container(
                height: 40,
                decoration: BoxDecoration(
                  color: palette.background,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 6),
                    Container(
                      width: 26,
                      height: 28,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [palette.accent, palette.accent2],
                        ),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            height: 5,
                            width: 60,
                            decoration: BoxDecoration(
                              color: palette.text.withValues(alpha: 0.8),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                          const SizedBox(height: 5),
                          Container(
                            height: 5,
                            width: 40,
                            decoration: BoxDecoration(
                              color: palette.muted,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      palette.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: palette.text,
                      ),
                    ),
                  ),
                  if (selected)
                    Icon(Icons.check_circle, size: 15, color: palette.accent),
                ],
              ),
              const SizedBox(height: 1),
              Text(
                switch (palette.id) {
                  'amber' => tr(context, 'Warm dark, gold and rose'),
                  'midnight' => tr(context, 'Deep blue, ice accents'),
                  'oled' => tr(context, 'Pure black, gold leaf'),
                  'forest' => tr(context, 'Deep green, copper'),
                  'violet' => tr(context, 'Plum, violet, pink'),
                  'light' => tr(context, 'Paper white, ink text'),
                  _ => tr(context, palette.blurb),
                },
                maxLines: 2,
                style: TextStyle(
                  fontSize: 10.5,
                  color: palette.muted,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
