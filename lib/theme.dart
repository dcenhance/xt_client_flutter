import 'package:flutter/material.dart';

/// A colour scheme for the whole app.
///
/// The palette is deliberately a value object rather than a pile of constants:
/// the user picks one in Settings, the choice is persisted, and every widget
/// reads the live values through [AppTheme]'s static getters — so a theme change
/// repaints everything without touching individual widgets.
class AppPalette {
  final String id;
  final String name;
  final String blurb;
  final Color background;
  final Color surface;
  final Color card;
  final Color border;
  final Color text;
  final Color muted;
  final Color accent;
  final Color accent2;
  final Color danger;
  final Color ok;
  final List<Color> hero;
  final Brightness brightness;

  const AppPalette({
    required this.id,
    required this.name,
    required this.blurb,
    required this.background,
    required this.surface,
    required this.card,
    required this.border,
    required this.text,
    required this.muted,
    required this.accent,
    required this.accent2,
    required this.danger,
    required this.ok,
    required this.hero,
    this.brightness = Brightness.dark,
  });

  bool get isDark => brightness == Brightness.dark;

  /// Colour used for text/icons drawn on top of [accent].
  Color get onAccent =>
      accent.computeLuminance() > 0.55 ? const Color(0xFF15100B) : Colors.white;
}

/// Warm, low-contrast and a little golden — the default look.
const kAmberNoir = AppPalette(
  id: 'amber',
  name: 'Amber Noir',
  blurb: 'Warm dark, gold and rose',
  background: Color(0xFF0D0B0E),
  surface: Color(0xFF151216),
  card: Color(0xFF1D181F),
  border: Color(0xFF2E262F),
  text: Color(0xFFF3EDE7),
  muted: Color(0xFFA99EA6),
  accent: Color(0xFFFFB26B),
  accent2: Color(0xFFFF7A9A),
  danger: Color(0xFFF08A80),
  ok: Color(0xFF7BD08A),
  hero: [Color(0xFF2A1B22), Color(0xFF1A1418)],
);

/// Deep blue night with a cyan edge — cool but not flat.
const kMidnight = AppPalette(
  id: 'midnight',
  name: 'Midnight',
  blurb: 'Deep blue, ice accents',
  background: Color(0xFF080B14),
  surface: Color(0xFF0F1420),
  card: Color(0xFF161D2E),
  border: Color(0xFF243049),
  text: Color(0xFFEAF0FF),
  muted: Color(0xFF96A3BF),
  accent: Color(0xFF7FA6FF),
  accent2: Color(0xFF5FE0C8),
  danger: Color(0xFFF08A80),
  ok: Color(0xFF6FD79A),
  hero: [Color(0xFF16224A), Color(0xFF0D1220)],
);

/// True black with gold — for OLED panels and a jewellery feel.
const kGoldenOled = AppPalette(
  id: 'oled',
  name: 'Golden OLED',
  blurb: 'Pure black, gold leaf',
  background: Color(0xFF000000),
  surface: Color(0xFF070707),
  card: Color(0xFF0E0E10),
  border: Color(0xFF232024),
  text: Color(0xFFF5F2EA),
  muted: Color(0xFF9C9689),
  accent: Color(0xFFE7C275),
  accent2: Color(0xFF9FD8C4),
  danger: Color(0xFFE58C7F),
  ok: Color(0xFF8BCB8B),
  hero: [Color(0xFF1C1710), Color(0xFF0A0A0A)],
);

/// Forest green with copper — quiet, warm, a bit retro.
const kForest = AppPalette(
  id: 'forest',
  name: 'Forest',
  blurb: 'Deep green, copper',
  background: Color(0xFF080D0B),
  surface: Color(0xFF0F1613),
  card: Color(0xFF16201B),
  border: Color(0xFF24322A),
  text: Color(0xFFEDF3EE),
  muted: Color(0xFF94A79B),
  accent: Color(0xFFE0A96D),
  accent2: Color(0xFF7FD1A8),
  danger: Color(0xFFE88C7D),
  ok: Color(0xFF74C88F),
  hero: [Color(0xFF152A21), Color(0xFF0B1210)],
);

/// Plum and violet — the loudest of the dark options.
const kViolet = AppPalette(
  id: 'violet',
  name: 'Plum',
  blurb: 'Plum, violet, pink',
  background: Color(0xFF0C0912),
  surface: Color(0xFF150F1D),
  card: Color(0xFF1D1428),
  border: Color(0xFF2F2340),
  text: Color(0xFFF4EEFA),
  muted: Color(0xFFA79BB8),
  accent: Color(0xFFC79BFF),
  accent2: Color(0xFFFF8FC7),
  danger: Color(0xFFF08A80),
  ok: Color(0xFF8BD3A8),
  hero: [Color(0xFF2A1650), Color(0xFF150E20)],
);

/// A genuine light theme, paper-warm rather than clinical white.
const kDaylight = AppPalette(
  id: 'light',
  name: 'Daylight',
  blurb: 'Paper white, ink text',
  background: Color(0xFFF6F3EF),
  surface: Color(0xFFFFFFFF),
  card: Color(0xFFFFFFFF),
  border: Color(0xFFE0D9D1),
  text: Color(0xFF221F1D),
  muted: Color(0xFF74706C),
  accent: Color(0xFFC2601F),
  accent2: Color(0xFF8C4BC7),
  danger: Color(0xFFC0392B),
  ok: Color(0xFF2E7D4F),
  hero: [Color(0xFFFFE9D6), Color(0xFFF6F3EF)],
  brightness: Brightness.light,
);

const kPalettes = <AppPalette>[
  kGoldenOled,
  kAmberNoir,
  kMidnight,
  kForest,
  kViolet,
  kDaylight,
];

/// Live theme access. All the old `AppTheme.x` call sites keep working; they now
/// read the active palette instead of constants.
class AppTheme {
  static AppPalette _active = kGoldenOled;

  static AppPalette get palette => _active;

  static void use(String id) {
    _active = kPalettes.firstWhere(
      (p) => p.id == id,
      orElse: () => kGoldenOled,
    );
  }

  static Color get accent => _active.accent;
  static Color get accent2 => _active.accent2;
  static Color get background => _active.background;
  static Color get surface => _active.surface;
  static Color get card => _active.card;
  static Color get border => _active.border;
  static Color get text => _active.text;
  static Color get muted => _active.muted;
  static Color get danger => _active.danger;
  static Color get ok => _active.ok;
  static List<Color> get hero => _active.hero;
  static bool get isDark => _active.isDark;
  static Color get onAccent => _active.onAccent;

  /// Corner radii — bigger than before, which is most of the "softer" feel.
  static const cardRadius = 12.0;
  static const posterRadius = 10.0;

  /// Subtle vertical gradient used for headers, empty states and the featured
  /// strip so surfaces are not flat single colours.
  static LinearGradient headerGradient() => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: hero,
  );

  static LinearGradient scrim() => LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      _active.background.withValues(alpha: 0.0),
      _active.background.withValues(alpha: 0.75),
    ],
  );

  static ThemeData data() {
    final p = _active;
    final base = p.isDark
        ? ThemeData.dark(useMaterial3: true)
        : ThemeData.light(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: p.background,
      colorScheme: base.colorScheme.copyWith(
        primary: p.accent,
        secondary: p.accent2,
        surface: p.surface,
        error: p.danger,
        onPrimary: p.onAccent,
        brightness: p.brightness,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: p.surface,
        foregroundColor: p.text,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: p.text,
          fontSize: 16,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
        ),
      ),
      cardTheme: CardThemeData(
        color: p.card,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(cardRadius),
          side: BorderSide(color: p.border),
        ),
      ),
      dividerTheme: DividerThemeData(color: p.border, thickness: 1, space: 1),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.card,
        isDense: true,
        hintStyle: TextStyle(color: p.muted, fontSize: 13.5),
        labelStyle: TextStyle(color: p.muted, fontSize: 13),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: p.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: p.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: p.accent, width: 1.4),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: p.accent,
          foregroundColor: p.onAccent,
          minimumSize: const Size(0, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 14.5,
            letterSpacing: 0.2,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: p.text,
          side: BorderSide(color: p.border),
          minimumSize: const Size(0, 42),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 13.5,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: p.accent),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: p.card,
        selectedColor: p.accent.withValues(alpha: 0.22),
        side: BorderSide(color: p.border),
        labelStyle: TextStyle(color: p.text, fontSize: 12.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 64,
        backgroundColor: p.surface,
        indicatorColor: p.accent.withValues(alpha: 0.20),
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(fontSize: 11.5, color: p.text, fontWeight: FontWeight.w600),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: p.card,
        contentTextStyle: TextStyle(color: p.text, fontSize: 13),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: p.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: p.border),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: p.accent),
      tabBarTheme: TabBarThemeData(
        labelColor: p.accent,
        unselectedLabelColor: p.muted,
        indicatorColor: p.accent,
        dividerColor: p.border,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: p.card,
          border: Border.all(color: p.border),
          borderRadius: BorderRadius.circular(10),
        ),
        textStyle: TextStyle(color: p.text, fontSize: 12),
      ),
    );
  }
}
