import 'package:flutter/material.dart';

import '../main.dart';
import '../theme.dart';
import 'focus_ring.dart';

/// The app mark, in whichever variant the user picked in Settings.
class AppMark extends StatelessWidget {
  const AppMark({super.key, this.size = 32, this.glow = false});

  final double size;
  final bool glow;

  static const variants = <(String, String)>[
    ('orbit', 'Orbit'),
    ('belt', 'Belt'),
    ('monogram', 'Monogram'),
    ('prism', 'Prism'),
    ('aperture', 'Aperture'),
    ('constellation', 'Stars'),
  ];

  /// Variant ids in order, for validation when reading prefs.
  static List<String> get ids => [for (final v in variants) v.$1];

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: appState,
      builder: (context, _) {
        final id = ids.contains(appState.markVariant) ? appState.markVariant : ids.first;
        final image = ClipRRect(
          borderRadius: BorderRadius.circular(size * 0.28),
          child: Image.asset('assets/marks/$id.png', width: size, height: size),
        );
        if (!glow) return image;
        return DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(size * 0.28),
            boxShadow: [
              BoxShadow(
                color: AppTheme.accent.withValues(alpha: 0.22),
                blurRadius: size * 0.4,
                spreadRadius: size * 0.04,
              ),
            ],
          ),
          child: image,
        );
      },
    );
  }
}

/// Picker for the mark, used in Settings.
class MarkPicker extends StatelessWidget {
  const MarkPicker({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: appState,
      builder: (context, _) => Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          for (final (id, name) in AppMark.variants)
            _MarkTile(
              id: id,
              name: name,
              selected: appState.markVariant == id,
              onSelect: () => appState.setMarkVariant(id),
            ),
        ],
      ),
    );
  }
}

class _MarkTile extends StatelessWidget {
  const _MarkTile({
    required this.id,
    required this.name,
    required this.selected,
    required this.onSelect,
  });

  final String id;
  final String name;
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
          width: 108,
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
            children: [
              Image.asset('assets/marks/$id.png', width: 62, height: 62),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.text)),
                  ),
                  if (selected) ...[
                    const SizedBox(width: 4),
                    Icon(Icons.check_circle, size: 13, color: AppTheme.accent),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}