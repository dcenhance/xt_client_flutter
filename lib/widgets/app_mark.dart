import 'package:flutter/material.dart';

import '../theme.dart';

/// The app mark — always the Spectre eagle, the same artwork the launcher icon
/// uses. One brand, no variants to choose from: the account page no longer
/// offers a mark picker.
class AppMark extends StatelessWidget {
  const AppMark({super.key, this.size = 32, this.glow = false});

  final double size;
  final bool glow;

  /// The single branding asset, shared with the launcher icon and the archive.
  static const asset = 'assets/branding/spectre_icon.png';

  @override
  Widget build(BuildContext context) {
    final image = ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.28),
      child: Image.asset(asset, width: size, height: size, filterQuality: FilterQuality.high),
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
  }
}
