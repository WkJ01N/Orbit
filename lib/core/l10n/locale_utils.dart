import 'package:flutter/material.dart';
import 'package:orbit/l10n/app_localizations.dart';

const defaultLocale = Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant');

const supportedAppLocales = [
  Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
  Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans'),
  Locale('en'),
];

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
