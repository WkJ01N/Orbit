import 'package:flutter/widgets.dart';
import 'package:orbit/models/background_settings.dart';

class BackgroundText {
  BackgroundText(BuildContext context)
    : locale = Localizations.localeOf(context);
  final Locale locale;
  String t(String en, String zh, [String? hant]) => locale.languageCode == 'en'
      ? en
      : locale.scriptCode == 'Hans' || locale.countryCode == 'CN'
      ? zh
      : hant ?? zh;
  String get title => t('Page backgrounds', '页面背景', '頁面背景');
  String page(BackgroundPage page) => switch (page) {
    BackgroundPage.grid => t('Schedule', '课表', '課表'),
    BackgroundPage.upcoming => t('Upcoming', '接下来', '接下來'),
    BackgroundPage.import => t('Import', '导入', '匯入'),
    BackgroundPage.settings => t('Settings', '设置', '設定'),
  };
  String region(BackgroundRegionId r) => switch (r) {
    BackgroundRegionId.header => t('Title bar', '标题栏', '標題列'),
    BackgroundRegionId.week => t('Week selector', '周选择栏', '週選擇列'),
    BackgroundRegionId.dates => t('Dates', '星期日期栏', '星期日期列'),
    BackgroundRegionId.timeRail => t('Time scale', '时间刻度栏', '時間刻度列'),
    BackgroundRegionId.content => t('Content', '内容区', '內容區'),
    BackgroundRegionId.categories => t('Categories', '分类栏', '分類列'),
    BackgroundRegionId.navigation => t('Navigation', '主导航', '主導覽'),
  };
}
