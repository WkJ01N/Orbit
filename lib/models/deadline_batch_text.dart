import 'package:flutter/widgets.dart';
import 'package:orbit/models/orbit_feature_text.dart';

class DeadlineBatchText extends OrbitFeatureText {
  const DeadlineBatchText(super.locale);
  factory DeadlineBatchText.of(BuildContext c) =>
      DeadlineBatchText(Localizations.localeOf(c));
  String get single => pick('Single', '单个', '單個');
  String get batch => pick('Batch', '批量', '批次');
  String get reuse => pick('Reuse an existing DDL', '从现有 DDL 复用', '從現有 DDL 複用');
  String get daily => pick('Days', '日', '日');
  String get weekly => pick('Weeks', '周', '週');
  String get monthly => pick('Months', '月', '月');
  String get every => pick('Repeat every', '重复间隔', '重複間隔');
  String get interval => pick('Interval (1–365)', '间隔数（1–365）', '間隔數（1–365）');
  String get taskCount =>
      pick('Number of tasks (1–1000)', '生成次数（1–1000）', '產生次數（1–1000）');
  String get until => pick('End date', '结束日期', '結束日期');
  String get useCount => pick('End after a number of tasks', '按次数结束', '依次數結束');
  String get preview => pick('Preview and create', '预览并生成', '預覽並產生');
  String get duplicate =>
      pick('Already exists; select to add again', '已存在，勾选可再次添加', '已存在，勾選可再次新增');
  String get none => pick('No tasks selected', '尚未选择任务', '尚未選擇任務');
  String get missing => pick(
    'These months do not contain the selected day. Choose a date for each month.',
    '以下月份不存在所选日期，请逐月选择日期。',
    '以下月份不存在所選日期，請逐月選擇日期。',
  );
  String get invalid => pick(
    'Check the interval, count and end date. At most 1000 tasks per batch.',
    '请检查间隔、次数和结束日期，每批最多生成 1000 条。',
    '請檢查間隔、次數與結束日期，每批最多產生 1000 筆。',
  );
  String previewCount(int n) =>
      pick('$n tasks selected', '已选择 $n 条任务', '已選擇 $n 筆任務');
}
