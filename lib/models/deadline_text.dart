import 'package:flutter/material.dart';

class DeadlineText {
  const DeadlineText(this.locale);

  final Locale locale;

  factory DeadlineText.of(BuildContext context) =>
      DeadlineText(Localizations.localeOf(context));

  factory DeadlineText.fromTag(String tag) => DeadlineText(
    tag.startsWith('en')
        ? const Locale('en')
        : tag.toLowerCase().contains('hans')
        ? const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans')
        : const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
  );

  String pick(String en, String hans, String hant) =>
      locale.languageCode == 'en'
      ? en
      : locale.scriptCode?.toLowerCase() == 'hans'
      ? hans
      : hant;

  String get ddl => 'DDL';
  String get addDeadline => pick('Add DDL', '添加 DDL', '新增 DDL');
  String get editDeadline => pick('Edit DDL', '编辑 DDL', '編輯 DDL');
  String get subject => pick('Subject', '科目', '科目');
  String get chooseSubject => pick('Choose a subject', '选择科目', '選擇科目');
  String get customSubject => pick('Custom subject', '自定义科目', '自訂科目');
  String get task => pick('Task name', '任务名称', '任務名稱');
  String get dueAt => pick('Deadline', '截止时间', '截止時間');
  String get reminders => pick('Remind me before', '提前提醒', '提前提醒');
  String get customMinutes =>
      pick('Custom minutes before', '自定义提前分钟', '自訂提前分鐘');
  String get save => pick('Save', '保存', '儲存');
  String get cancel => pick('Cancel', '取消', '取消');
  String get delete => pick('Delete', '删除', '刪除');
  String get complete => pick('Mark complete', '标记完成', '標記完成');
  String get reopen => pick('Mark incomplete', '标记未完成', '標記未完成');
  String get completed => pick('Completed', '已完成', '已完成');
  String get overdue => pick('Overdue', '已逾期', '已逾期');
  String get invalid => pick(
    'Enter a subject and task, choose a future deadline and at least one reminder.',
    '请填写科目和任务、选择未来截止时间及至少一个提醒。',
    '請填寫科目和任務、選擇未來截止時間及至少一個提醒。',
  );
  String get saveFailed =>
      pick('Could not save DDL.', '无法保存 DDL。', '無法儲存 DDL。');
  String get deleteConfirm =>
      pick('Delete this DDL?', '删除这条 DDL？', '刪除這條 DDL？');
  String get none => pick('No DDL yet', '暂无 DDL', '暫無 DDL');
  String get due => pick('Due', '截止', '截止');
  String reminderTitle(String subject, String task) => pick(
    'DDL: $subject · $task',
    '赶 DDL：$subject · $task',
    '趕 DDL：$subject · $task',
  );
  String reminderBody(String due) => pick('Due $due', '截止时间：$due', '截止時間：$due');
  String leadLabel(int minutes) {
    if (minutes % 1440 == 0) {
      return pick(
        '${minutes ~/ 1440}d',
        '${minutes ~/ 1440}天',
        '${minutes ~/ 1440}天',
      );
    }
    if (minutes % 60 == 0) {
      return pick(
        '${minutes ~/ 60}h',
        '${minutes ~/ 60}小时',
        '${minutes ~/ 60}小時',
      );
    }
    return pick('${minutes}m', '$minutes分钟', '$minutes分鐘');
  }
}
