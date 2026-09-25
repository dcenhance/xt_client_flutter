import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'l10n_catalog.dart';

/// The archive's app languages. English is the source/fallback language.
const supportedLanguageTags = <String>[
  'en',
  'de',
  'es',
  'fr',
  'it',
  'pt',
  'nl',
  'pl',
  'cs',
  'ru',
  'uk',
  'tr',
  'ar',
  'hi',
  'id',
  'ja',
  'ko',
  'zh',
  'sv',
  'el',
  'zh-Hant',
];

const languageNames = <String, String>{
  'en': 'English',
  'de': 'Deutsch',
  'es': 'Español',
  'fr': 'Français',
  'it': 'Italiano',
  'pt': 'Português',
  'nl': 'Nederlands',
  'pl': 'Polski',
  'cs': 'Čeština',
  'ru': 'Русский',
  'uk': 'Українська',
  'tr': 'Türkçe',
  'ar': 'العربية',
  'hi': 'हिन्दी',
  'id': 'Bahasa Indonesia',
  'ja': '日本語',
  'ko': '한국어',
  'zh': '简体中文',
  'sv': 'Svenska',
  'el': 'Ελληνικά',
  'zh-Hant': '繁體中文',
};

final supportedAppLocales = supportedLanguageTags
    .map(localeForTag)
    .toList(growable: false);

Locale localeForTag(String tag) => tag == 'zh-Hant'
    ? const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant')
    : Locale(tag);

String languageTagFor(Locale locale) {
  if (locale.languageCode == 'zh' &&
      (locale.scriptCode == 'Hant' ||
          const {'TW', 'HK', 'MO'}.contains(locale.countryCode))) {
    return 'zh-Hant';
  }
  return supportedLanguageTags.contains(locale.languageCode)
      ? locale.languageCode
      : 'en';
}

/// Empty means follow the device. Kept in sync with the persisted app preference.
String preferredLanguageTag = '';

String _effectiveTag() {
  if (preferredLanguageTag.isNotEmpty) return preferredLanguageTag;
  final locales = ui.PlatformDispatcher.instance.locales;
  return locales.isEmpty ? 'en' : languageTagFor(locales.first);
}

String _format(String source, String tag, Map<String, Object?> params) {
  var result = localizedCatalog[tag]?[source] ?? source;
  for (final entry in params.entries) {
    result = result.replaceAll('{${entry.key}}', '${entry.value}');
  }
  return result;
}

/// Look up copy using the effective MaterialApp locale, not the system locale.
String tr(
  BuildContext context,
  String source, [
  Map<String, Object?> params = const {},
]) {
  final locale = Localizations.maybeLocaleOf(context);
  return _format(
    source,
    locale == null ? _effectiveTag() : languageTagFor(locale),
    params,
  );
}

/// For labels and errors assembled in the non-widget application layer.
String trCurrent(String source, [Map<String, Object?> params = const {}]) =>
    _format(source, _effectiveTag(), params);
