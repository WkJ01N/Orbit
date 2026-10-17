import 'package:flutter/widgets.dart';
import 'package:orbit/models/schedule_display_settings.dart';

class NavigationAssistText {
  NavigationAssistText(this.locale);
  final Locale locale;
  static NavigationAssistText of(BuildContext context) =>
      NavigationAssistText(Localizations.localeOf(context));
  String pick(String en, String hans, String hant) =>
      locale.languageCode != 'zh'
      ? en
      : locale.scriptCode == 'Hant' ||
            ['TW', 'HK', 'MO'].contains(locale.countryCode)
      ? hant
      : hans;

  String get position =>
      pick('Back-to-top button position', '回到顶部按钮位置', '回到頂部按鈕位置');
  String get smartHint => pick(
    'Estimates your hand from touch and motion. Uses the center when uncertain; you can choose a fixed position.',
    '结合触摸和设备运动估计操作用手；无法判断时居中，也可选择固定位置。',
    '結合觸控和裝置動作估計操作用手；無法判斷時置中，也可選擇固定位置。',
  );
  String positionLabel(BackToTopPosition value) => switch (value) {
    BackToTopPosition.left => pick('Left', '居左', '置左'),
    BackToTopPosition.center => pick('Center', '居中', '置中'),
    BackToTopPosition.right => pick('Right', '居右', '置右'),
    BackToTopPosition.smart => pick('Smart', '智能', '智慧'),
  };
  String get openTimetable =>
      pick('Open WeMust timetable', '打开 WeMust 课表', '開啟 WeMust 課表');
  String get fallback => pick(
    'Not at the timetable? Open WeMust',
    '未到课表？打开 WeMust',
    '未到課表？開啟 WeMust',
  );
  String get manualPath => pick(
    'In WeMust, open Class Timetable. Sign in there if needed, then complete check-in.',
    '请在 WeMust 中打开“课表”；如需登录，请先登录，再完成打卡。',
    '請在 WeMust 中開啟「課表」；如需登入，請先登入，再完成打卡。',
  );
  String get notInstalled =>
      pick('WeMust is not installed.', '尚未安装 WeMust。', '尚未安裝 WeMust。');
  String get failed => pick(
    'Could not open WeMust. Please open it manually.',
    '无法打开 WeMust，请手动打开。',
    '無法開啟 WeMust，請手動開啟。',
  );
}
