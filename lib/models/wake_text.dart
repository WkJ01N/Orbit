import 'package:flutter/widgets.dart';
import 'package:orbit/models/orbit_feature_text.dart';

class WakeText extends OrbitFeatureText {
  const WakeText(super.locale);
  factory WakeText.of(BuildContext context) =>
      WakeText(Localizations.localeOf(context));
  String get strong => pick('Strong reminder', '强提醒', '強提醒');
  String get guide => pick(
    'Open Orbit and finish the task to stop this reminder.',
    '点击打开 Orbit，完成答题后结束提醒。',
    '點擊開啟 Orbit，完成答題後結束提醒。',
  );
  String get ready => pick("I'm awake / I understand", '我醒了／我知道了', '我醒了／我知道了');
  String get task => pick('Stop reminder with', '停止提醒方式', '停止提醒方式');
  String get arithmetic => pick('Two simple sums', '两道简单心算', '兩道簡單心算');
  String get sequence =>
      pick('Tap 1–6 in order, twice', '按顺序点击 1–6，共两轮', '依序點擊 1–6，共兩輪');
  String get prepare =>
      pick('Preparation time (seconds)', '准备时间（秒）', '準備時間（秒）');
  String get answer => pick('Task time (seconds)', '答题时间（秒）', '答題時間（秒）');
  String get roundDuration =>
      pick('Sound per round (seconds)', '每轮响铃时长（秒）', '每輪響鈴時長（秒）');
  String get timing => pick(
    'Three rounds at most, 15 seconds apart. Opening Orbit temporarily silences the reminder; finish the task before the countdown ends.',
    '最多三轮，轮间暂停 15 秒。打开 Orbit 暂时静音，请在倒计时内完成任务。',
    '最多三輪，輪間暫停 15 秒。開啟 Orbit 暫時靜音，請在倒數內完成任務。',
  );
  String seconds(int n) => pick('$n seconds remaining', '剩余 $n 秒', '剩餘 $n 秒');
  String get retry => pick('Retry task', '重新答题', '重新答題');
  String get timeout => pick(
    'Time expired. The reminder has resumed.',
    '已超时，提醒已恢复。',
    '已逾時，提醒已恢復。',
  );
  String get wrong =>
      pick('Try this step again.', '答案不正确，请重试当前步骤。', '答案不正確，請重試目前步驟。');
  String get submit => pick('Confirm answer', '确认答案', '確認答案');
  String get emergency => pick(
    'Hold 5 seconds to stop without confirmation',
    '长按 5 秒紧急停止（记为未确认）',
    '長按 5 秒緊急停止（記為未確認）',
  );
  String get unconfirmed => pick('Not confirmed', '未确认', '未確認');
  String get completed =>
      pick('Confirmed. Reminder stopped.', '已确认，提醒已停止。', '已確認，提醒已停止。');
  String step(int n, int total) =>
      pick('Step $n / $total', '第 $n / $total 步', '第 $n / $total 步');
}
