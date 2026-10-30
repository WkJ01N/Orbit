import 'package:flutter/material.dart';
import 'package:orbit/l10n/app_localizations.dart';

const defaultLocale = Locale.fromSubtags(
  languageCode: 'zh',
  scriptCode: 'Hant',
);

const supportedAppLocales = [
  Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
  Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans'),
  Locale('en'),
];

/// Whether [locale] reads as Traditional Chinese.
///
/// An explicit script wins; a bare `zh` falls back to the region, and every
/// other Chinese locale is simplified. One rule for the whole app keeps a
/// single screen from mixing simplified and traditional glyphs (zh-HK, zh-MO
/// and a bare `zh` used to resolve differently per feature).
bool isTraditionalChinese(Locale locale) {
  if (locale.languageCode != 'zh') {
    return false;
  }
  final script = locale.scriptCode;
  if (script != null) {
    return script == 'Hant';
  }
  return const {'TW', 'HK', 'MO'}.contains(locale.countryCode);
}

/// Picks [en], [hans] or [hant] for [locale] using [isTraditionalChinese].
/// Separates list items the way readers of [locale] expect them.
String localeListSeparator(Locale locale) =>
    locale.languageCode == 'zh' ? '\u3001' : ', ';
String pickLocalized(Locale locale, String en, String hans, String hant) {
  if (locale.languageCode != 'zh') {
    return en;
  }
  return isTraditionalChinese(locale) ? hant : hans;
}

String localeStorageKey(Locale locale) {
  if (locale.languageCode == 'en') {
    return 'en';
  }
  if (locale.scriptCode == 'Hans') {
    return 'zh_Hans';
  }
  return 'zh_Hant';
}

Locale localeFromStorage(String? value) {
  switch (value) {
    case 'en':
      return const Locale('en');
    case 'zh_Hans':
      return const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans');
    case 'zh_Hant':
    default:
      return defaultLocale;
  }
}

AppLocalizations lookupL10n(Locale locale) {
  return lookupAppLocalizations(locale);
}

String weekdayLabel(AppLocalizations l10n, int weekday) {
  switch (weekday) {
    case 1:
      return l10n.weekdayMon;
    case 2:
      return l10n.weekdayTue;
    case 3:
      return l10n.weekdayWed;
    case 4:
      return l10n.weekdayThu;
    case 5:
      return l10n.weekdayFri;
    case 6:
      return l10n.weekdaySat;
    case 7:
      return l10n.weekdaySun;
    default:
      return '';
  }
}

String languageOptionLabel(AppLocalizations l10n, Locale locale) {
  final key = localeStorageKey(locale);
  switch (key) {
    case 'en':
      return l10n.langEn;
    case 'zh_Hans':
      return l10n.langZhHans;
    default:
      return l10n.langZhHant;
  }
}
