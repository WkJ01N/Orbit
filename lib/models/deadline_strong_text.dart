import 'package:flutter/widgets.dart';
import 'package:orbit/models/orbit_feature_text.dart';

class DeadlineStrongText extends OrbitFeatureText {
  const DeadlineStrongText(super.locale);
  factory DeadlineStrongText.of(BuildContext context) =>
      DeadlineStrongText(Localizations.localeOf(context));
  String get retry => pick('Retry', '重试', '重試');
  String get enable => pick('Enable strong reminders', '启用强提醒', '啟用強提醒');
  String get strong => pick('Strong reminder', '强提醒', '強提醒');
  String get normal => pick('Normal reminder', '普通提醒', '普通提醒');
  String get hint => pick(
    'Open Orbit to stop ringing. Times up to 180 minutes ahead use strong reminders by default.',
    '打开 Orbit 即可关闭。默认提前 180 分钟及以内使用强提醒，可逐项调整。',
    '開啟 Orbit 即可關閉。預設提前 180 分鐘及以內使用強提醒，可逐項調整。',
  );
  String get openHint => pick(
    'Open Orbit to stop this strong reminder.',
    '打开 Orbit 即可关闭强提醒。',
    '開啟 Orbit 即可關閉強提醒。',
  );
  String get stopped => pick(
    'DDL strong reminders stopped; future reminders kept',
    'DDL 强提醒已关闭，后续提醒保留',
    'DDL 強提醒已關閉，後續提醒保留',
  );
  String get manage => pick('Manage future reminders', '管理后续提醒', '管理後續提醒');
  String get keep => pick('Keep reminders', '保留提醒', '保留提醒');
  String get closeAll =>
      pick('Turn off all future reminders', '全部关闭后续提醒', '全部關閉後續提醒');
  String get closeSelected =>
      pick('Turn off selected reminders', '关闭所选提醒', '關閉所選提醒');
  @override
  String get restore =>
      pick('Restore disabled reminders', '恢复被关闭的提醒', '恢復被關閉的提醒');
  String get disabled => pick('Disabled', '已关闭', '已關閉');
  String get noFuture =>
      pick('No remaining future reminders', '没有剩余的未来提醒', '沒有剩餘的未來提醒');
  @override
  String get failed => pick(
    'Could not update reminders. Please retry.',
    '提醒更新失败，请重试。',
    '提醒更新失敗，請重試。',
  );
  String get hideUpcoming => pick('Hide Upcoming page', '隐藏接下来页面', '隱藏接下來頁面');
  String get hideImport => pick('Hide Import page', '隐藏导入页面', '隱藏匯入頁面');
  String get navigationHint => pick(
    'Hide the navigation entry; direct actions still open this page.',
    '仅隐藏导航入口，仍可通过直接操作打开。',
    '僅隱藏導覽入口，仍可透過直接操作開啟。',
  );
}
