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
  String get arithmetic => pick('Arithmetic', '心算', '心算');
  String get sequence => pick('Tap numbers in order', '按顺序点击数字', '依序點擊數字');
  String get mixed => pick('Mixed mode', '混合模式', '混合模式');
  String get mixedHint => pick(
    'Each round randomly uses arithmetic or ordered numbers, with equal probability.',
    '每轮随机选择心算或顺序数字，两种各占 50% 概率。',
    '每輪隨機選擇心算或順序數字，兩種各佔 50% 機率。',
  );
  String get numberCount =>
      pick('Number count (4–25)', '数字数量（4–25）', '數字數量（4–25）');
  String get difficulty => pick('Arithmetic difficulty', '心算难度', '心算難度');
  String get simple => pick('Simple', '简单', '簡單');
  String get medium => pick('Medium', '中等', '中等');
  String get hard => pick('Hard', '困难', '困難');
  String get difficultyHint => pick(
    'Simple: two-digit ± one-digit. Medium: two-digit ± two-digit or × one-digit. Hard: three-digit ± three-digit or two-digit × two-digit.',
    '简单：两位数与个位数加减。中等：两位数加减或乘个位数。困难：三位数加减或两位数乘两位数。',
    '簡單：兩位數與個位數加減。中等：兩位數加減或乘個位數。困難：三位數加減或兩位數乘兩位數。',
  );
  String get answerMode => pick('Answer with', '答题方式', '答題方式');
  String get manualInput => pick('Enter the answer', '手动输入答案', '手動輸入答案');
  String get choice3 => pick('Choose from 3 answers', '三选一', '三選一');
  String get choice6 => pick('Choose from 6 answers', '六选一', '六選一');
  String round(int n, int total) =>
      pick('Round $n / $total', '第 $n / $total 轮', '第 $n / $total 輪');
  String sequenceHint(int count) =>
      pick('Tap 1–$count in order', '按顺序点击 1–$count', '依序點擊 1–$count');
  String get rounds => pick('Task rounds (1–10)', '任务轮数（1–10）', '任務輪數（1–10）');
  String get prepare =>
      pick('Preparation time (seconds)', '准备时间（秒）', '準備時間（秒）');
  String get answer => pick('Task time (seconds)', '答题时间（秒）', '答題時間（秒）');
  String get roundDuration =>
      pick('Sound per round (seconds)', '每轮响铃时长（秒）', '每輪響鈴時長（秒）');
  String get timing => pick(
    'Three sound rounds at most, 15 seconds apart. Opening Orbit temporarily silences the reminder; finish the task before the countdown ends.',
    '最多响铃三轮，轮间暂停 15 秒。打开 Orbit 暂时静音，请在倒计时内完成任务。',
    '最多響鈴三輪，輪間暫停 15 秒。開啟 Orbit 暫時靜音，請在倒數內完成任務。',
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
