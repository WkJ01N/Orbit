import 'package:flutter/widgets.dart';

/// Copy shared by the archive, course picker and reminder additions.
class OrbitFeatureText {
  const OrbitFeatureText(this.locale);
  final Locale locale;
  factory OrbitFeatureText.of(BuildContext context) =>
      OrbitFeatureText(Localizations.localeOf(context));
  String pick(String en, String hans, String hant) =>
      locale.languageCode != 'zh'
      ? en
      : locale.scriptCode == 'Hant' || locale.countryCode == 'TW'
      ? hant
      : hans;
  String get archive => pick('Archive', '归档', '歸檔');
  String get courses => pick('Courses', '课程', '課程');
  String get singleArchive => pick('Archive this class', '归档本次课', '歸檔本次課');
  String get seriesArchive =>
      pick('Archive ended classes of this course', '归档该课程已结束课次', '歸檔該課程已結束課次');
  String get archiveAllEnded =>
      pick('Archive all ended classes', '归档所有已结束课程', '歸檔所有已結束課程');
  String get archiveAllEndedHint => pick(
    'Keep past classes in Archive; ongoing and future classes stay unchanged.',
    '将已结束课次保存到归档，保留正在进行及未来课次。',
    '將已結束課次儲存至歸檔，保留正在進行及未來課次。',
  );
  String get noEndedToArchive =>
      pick('No ended classes to archive.', '暂无可归档的已结束课程。', '暫無可歸檔的已結束課程。');
  String archivedClasses(int count) =>
      pick('Archived $count classes.', '已归档 $count 个课次。', '已歸檔 $count 個課次。');
  String get hide => pick('Hide', '隐藏', '隱藏');
  String get show => pick('Show', '重新显示', '重新顯示');
  String get restore => pick('Unarchive', '取消归档', '取消歸檔');
  String get hideArchive =>
      pick('Hide in schedule and Upcoming', '在课表与接下来中隐藏', '在課表與接下來中隱藏');
  String count(int n) => pick('$n records', '$n 条记录', '$n 筆記錄');
  String get empty => pick('No archived records', '暂无归档记录', '暫無歸檔記錄');
  String get search => pick('Search name or code', '搜索名称或编号', '搜尋名稱或編號');
  String get settings => pick('Archive settings', '归档设置', '歸檔設定');
  String get group => pick('Group classes by course', '按课程合并显示', '按課程合併顯示');
  String get groupHint => pick(
    'Each course takes one row. Individual classes use more space.',
    '每门课程只占一栏；逐次展示会占用更多空间。',
    '每門課程只佔一欄；逐次展示會佔用更多空間。',
  );
  String sortName(String name) => switch (name) {
    'archivedAt' => pick('Archive time', '归档时间', '歸檔時間'),
    'eventTime' => pick('Class / due time', '课程／截止时间', '課程／截止時間'),
    'name' => pick('Name', '名称', '名稱'),
    _ => pick('Custom order (drag)', '自定义顺序（拖动）', '自訂順序（拖曳）'),
  };
  String get descending =>
      pick('Descending (newest first)', '降序（从新到旧）', '降冪（從新到舊）');
  String get ascending =>
      pick('Ascending (oldest first)', '升序（从旧到新）', '升冪（從舊到新）');
  String get autoCourses =>
      pick('Automatically archive ended classes', '自动归档已结束课程', '自動歸檔已結束課程');
  String get autoDeadlines => pick(
    'Automatically archive completed DDLs',
    '自动归档已完成 DDL',
    '自動歸檔已完成 DDL',
  );
  String get delay =>
      pick('Delay after ending / completion', '结束／完成后的延迟', '結束／完成後的延遲');
  String get customDays =>
      pick('Custom days (0–36500)', '自定义天数（0–36500）', '自訂天數（0–36500）');
  String days(int n) => n == 0
      ? pick('Immediately', '立即', '立即')
      : n == 1
      ? pick('24 hours', '24 小时', '24 小時')
      : pick('$n days', '$n 天', '$n 天');
  String get custom => pick('Custom…', '自定义…', '自訂…');
  String get hideAuto =>
      pick('Hide when automatically archived', '自动归档时隐藏', '自動歸檔時隱藏');
  String get autoHint => pick(
    'Checked while running and on next launch. Unarchived records stay paused until completion or end time changes.',
    '运行中和下次启动时检查；手动取消归档后暂停自动归档，直到重新完成或结束时间变化。',
    '執行中和下次啟動時檢查；手動取消歸檔後暫停自動歸檔，直到重新完成或結束時間變更。',
  );
  String get failed =>
      pick('Could not save. Please retry.', '保存失败，请重试。', '儲存失敗，請重試。');
  String get refresh => pick('Refresh', '刷新', '重新整理');
  String get refreshFailed => pick(
    'Refresh failed. Your previous list is retained.',
    '刷新失败，已保留原列表。',
    '重新整理失敗，已保留原清單。',
  );
  String get existing => pick('Choose existing course', '选择现有课程', '選擇現有課程');
  String get newCourse => pick('New course', '新建课程', '新增課程');
  String get archivedCourses => pick('Archived courses', '已归档课程', '已歸檔課程');
  String get noCourses => pick('No existing courses', '暂无现有课程', '暫無現有課程');
  String get onlyFirst =>
      pick('Strong reminders only for the first class', '仅第一节课强提醒', '僅第一節課強提醒');
  String get firstPeriod => pick('First timetable period', '课表第一节次', '課表第一節次');
  String get beforeTime =>
      pick('Earliest class before cutoff', 'N 点前最早的一节课', 'N 點前最早的一節課');
  String get cutoff => pick('Cutoff time (N)', '截止时刻（N）', '截止時刻（N）');
  String get plan => pick('Timetable plan', '作息方案', '作息方案');
  String get automatic => pick('Recognize automatically', '自动识别', '自動識別');
  String get firstHint => pick(
    'Unrecognized periods fall back to the cutoff rule. Explicit rule overrides and summaries keep their existing behavior.',
    '节次无法识别时使用 N 点规则；明确指定强提醒的规则及次日摘要保留原行为。',
    '節次無法識別時使用 N 點規則；明確指定強提醒的規則及次日摘要保留原行為。',
  );
  String get strongTest =>
      pick('Test strong reminder now', '立即测试强提醒', '立即測試強提醒');
  String get backgroundStrongTest =>
      pick('Test strong reminder in one minute', '一分钟后后台强提醒测试', '一分鐘後背景強提醒測試');
  String get stopTest => pick('Stop reminder tests', '停止提醒测试', '停止提醒測試');
  String get testHint => pick(
    'Uses your sound, vibration and duration, regardless of course filters or the global switch.',
    '使用当前声音、震动及持续时间，不受课程筛选或总开关限制。',
    '使用目前聲音、震動及持續時間，不受課程篩選或總開關限制。',
  );
  String get testShown => pick('Test reminder sent', '已发送测试提醒', '已傳送測試提醒');
  String get testStopped =>
      pick('Reminder tests stopped', '已停止提醒测试', '已停止提醒測試');
  String get selectAll => pick('Select all', '全选', '全選');
  String get clearSelection => pick('Clear selection', '取消选择', '取消選取');
}
