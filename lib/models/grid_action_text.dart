import 'package:flutter/widgets.dart';
import 'package:orbit/models/orbit_feature_text.dart';
import 'package:orbit/models/schedule_display_settings.dart';

class GridActionText extends OrbitFeatureText {
  const GridActionText(super.locale);
  factory GridActionText.of(BuildContext context) =>
      GridActionText(Localizations.localeOf(context));
  String get gradient =>
      pick('Strong reminder card gradient', '强提醒卡片渐变', '強提醒卡片漸層');
  String gradientName(StrongCardGradient value) => switch (value) {
    StrongCardGradient.upperHalf => pick('Upper half', '上半', '上半'),
    StrongCardGradient.fullCard => pick('Full card', '整张', '整張'),
    StrongCardGradient.topQuarter => pick('Top quarter', '顶部', '頂部'),
  };
  String get byCourse => pick('Delete by course', '按课程删除', '按課程刪除');
  String get byRange => pick('Delete by time range', '按时间段删除', '按時間段刪除');
  String get manually => pick('Select classes manually', '手动选择删除', '手動選擇刪除');
  String get courseHint =>
      pick('Select courses across semesters', '可跨学期选择多门课程', '可跨學期選擇多門課程');
  String get rangeHint =>
      pick('Choose a time range and courses', '选择时间范围和指定课程', '選擇時間範圍和指定課程');
  String get manualHint => pick(
    'Tap timetable cards, including on other pages',
    '在课表中逐项勾选，支持跨页选择',
    '在課表中逐項勾選，支援跨頁選擇',
  );
  String get includeArchived =>
      pick('Include archived classes', '包含归档课次', '包含歸檔課次');
  String get searchCourses =>
      pick('Search course name or code', '搜索课程名称或编号', '搜尋課程名稱或編號');
  @override
  String get selectAll => pick('Select all shown courses', '全选当前列表', '全選目前列表');
  String get clearAll => pick('Clear selection', '清空选择', '清空選擇');
  String get chooseCourses => pick('Select courses', '选择课程', '選擇課程');
  String selected(int n) => pick('$n selected', '已选 $n 节课', '已選 $n 節課');
  String classCount(int n) => pick('$n classes', '$n 节课', '$n 節課');
  String archivedCount(int n) =>
      pick('$n archived', '其中 $n 节已归档', '其中 $n 節已歸檔');
  String get preview => pick('Review deletion', '查看删除预览', '查看刪除預覽');
  String deleting(int n) =>
      pick('Delete $n classes?', '即将删除 $n 节课', '即將刪除 $n 節課');
  String get list => pick('Classes to delete', '即将删除的课程', '即將刪除的課程');
  String get trashHint => pick(
    'Deleted classes go to Trash and can be restored.',
    '删除后进入回收站，可撤销或恢复。',
    '刪除後移至資源回收筒，可復原。',
  );
  String get boundary =>
      pick('Classes crossing the time boundary', '跨越时间范围边界的课程', '跨越時間範圍邊界的課程');
  String get boundaryHint => pick(
    'Choose each crossing class to include, or change the time range.',
    '请逐项选择是否删除，或重新选择时间范围。',
    '請逐項選擇是否刪除，或重新選擇時間範圍。',
  );
  String get changed => pick(
    'Classes have changed. Review the updated list and confirm again.',
    '课程数据已变化，请核对更新后的列表并重新确认。',
    '課程資料已變更，請核對更新後的清單並重新確認。',
  );
  String get cancelSelection => pick('Cancel selection', '取消选择', '取消選擇');
  String get keepSelecting => pick('Keep selecting', '继续选择', '繼續選擇');
  String cancelHint(int n) => pick(
    'Discard your selection of $n classes?',
    '已选择 $n 节课，是否取消本次选择？',
    '已選擇 $n 節課，是否取消本次選擇？',
  );
  @override
  String get noCourses => pick('No matching courses', '没有符合条件的课程', '沒有符合條件的課程');
  String get confirm => pick('Confirm deletion', '确认删除', '確認刪除');
  String get selectedHint => pick('Selected for deletion', '已选择删除', '已選擇刪除');
}
