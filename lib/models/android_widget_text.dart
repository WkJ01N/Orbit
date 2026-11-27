import 'package:flutter/widgets.dart';
import 'package:orbit/core/l10n/locale_utils.dart';

class AndroidWidgetText {
  const AndroidWidgetText(this.locale);

  final Locale locale;

  factory AndroidWidgetText.of(BuildContext context) =>
      AndroidWidgetText(Localizations.localeOf(context));

  String pick(String en, String hans, String hant) =>
      pickLocalized(locale, en, hans, hant);

  String get title => pick('Home screen widgets', '桌面微件', '桌面微件');
  String get subtitle => pick(
    'Add Next class or Today\'s schedule widgets and customize their look',
    '添加「下一节课」或「今日课表」小组件，自定义透明度和 DDL 展示',
    '新增「下一節課」或「今日課表」小工具，自訂透明度與 DDL 顯示',
  );
  String get previewSection => pick('Preview', '效果预览', '效果預覽');
  String get previewNextClassBadge => pick('Next class', '下一节', '下一節');
  String get previewNextClassCountdown => pick('In 15m', '15 分钟后', '15 分鐘後');
  String get previewSampleCourse =>
      pick('Software Engineering', '软件工程导论', '軟體工程導論');
  String get previewSampleSubtitle => pick(
    '14:00 - 15:30 · A204',
    '14:00 - 15:30 · A204',
    '14:00 - 15:30 · A204',
  );
  String get previewSampleDdl => pick(
    'Lab 4 report · Today 23:59',
    '待完成 DDL：实验报告 · 今天 23:59',
    '待完成 DDL：實驗報告 · 今天 23:59',
  );

  String get addSection => pick('Add to home screen', '添加到桌面', '新增至桌面');
  String get nextClassTitle =>
      pick('Next class (compact)', '下一节课（紧凑卡片）', '下一節課（精簡卡片）');
  String get nextClassSubtitle => pick(
    'Default 4×1 (resizable to 2×2). Shows ongoing or upcoming class.',
    '默认 4×1（可调至 2×2），聚焦进行中或下一节课程与倒计时。',
    '預設 4×1（可調至 2×2），聚焦進行中或下一節課程與倒數計時。',
  );
  String get todayScheduleTitle =>
      pick('Today\'s schedule (list)', '今日课表（可滚动列表）', '今日課表（可捲動清單）');
  String get todayScheduleSubtitle => pick(
    'Default 4×3 (resizable 4×2–4×4). Lists today\'s classes and DDLs.',
    '默认 4×3（支持 4×2–4×4），可滚动浏览今日全部课表与 DDL。',
    '預設 4×3（支援 4×2–4×4），可捲動瀏覽今日全部課表與 DDL。',
  );
  String addedCount(int count) => count > 0
      ? pick(
          'Added ($count on home screen)',
          '已添加 $count 个到桌面',
          '已新增 $count 個到桌面',
        )
      : pick('Not added yet', '尚未添加', '尚未新增');
  String get addAction => pick('Add', '添加', '新增');
  String get pinAccepted => pick(
    'Follow the system prompt to place the widget on your home screen.',
    '请在系统弹窗中确认将微件添加到桌面。',
    '請在系統彈窗中確認將微件新增至桌面。',
  );
  String get pinManualHint => pick(
    'Your launcher does not support one-tap pinning. Long-press an empty space on your home screen and choose Widgets → Orbit.',
    '当前桌面启动器不支持一键添加，请长按手机桌面空白处，在「微件 / 小组件」中选择 Orbit 添加。',
    '目前桌面啟動器不支援一鍵新增，請長按手機桌面空白處，在「微件 / 小工具」中選擇 Orbit 新增。',
  );

  String get displaySection => pick('Display & content', '显示与内容', '顯示與內容');
  String get showDeadlinesTitle =>
      pick('Show upcoming DDLs', '在微件中显示近期 DDL', '在微件中顯示近期 DDL');
  String get showDeadlinesSubtitle => pick(
    'Includes overdue and upcoming uncompleted deadlines.',
    '包含已逾期及未来几天内未完成的截止任务。',
    '包含已逾期及未來幾天內未完成的截止任務。',
  );
  String get lookaheadTitle =>
      pick('DDL lookahead window', 'DDL 显示范围', 'DDL 顯示範圍');
  String lookaheadDaysLabel(int days) => switch (days) {
    1 => pick('Today only', '仅今天', '僅今天'),
    7 => pick('Next 7 days', '近 7 天', '近 7 天'),
    _ => pick('Next 3 days', '近 3 天', '近 3 天'),
  };

  String get opacityTitle => pick('Background opacity', '背景不透明度', '背景不透明度');
  String opacitySubtitle(int percent) => '$percent%';

  String get refreshTitle =>
      pick('Refresh widgets now', '立即刷新桌面微件', '立即重新整理桌面微件');
  String get refreshSubtitle => pick(
    'Data changes and class transitions also update automatically.',
    '课表变更与上下课节点会自动刷新，也可在此手动触发同步。',
    '課表變更與上下課節點會自動更新，也可於此手動觸發同步。',
  );
  String get refreshedToast =>
      pick('Widgets refreshed.', '已刷新桌面微件。', '已重新整理桌面微件。');
}
