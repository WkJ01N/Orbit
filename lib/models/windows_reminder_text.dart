import 'package:flutter/widgets.dart';
import 'package:orbit/models/orbit_feature_text.dart';

class WindowsReminderText extends OrbitFeatureText {
  const WindowsReminderText(super.locale);
  factory WindowsReminderText.of(BuildContext context) =>
      WindowsReminderText(Localizations.localeOf(context));
  String get source => pick('Sound source', '声音来源', '聲音來源');
  String get system => pick('System sound', '系统提示音', '系統提示音');
  String get imported => pick('Imported audio', '导入音频', '匯入音訊');
  String get selectFile => pick('Select an audio file', '选择音频文件', '選擇音訊檔案');
  String get preview =>
      pick('Preview (up to 10 seconds)', '试听（最长 10 秒）', '試聽（最長 10 秒）');
  String get stopPreview => pick('Stop preview', '停止试听', '停止試聽');
  String get ringing =>
      pick('A course reminder needs confirmation', '课程强提醒待确认', '課程強提醒待確認');
  String get open => pick('Open and answer', '打开并答题', '開啟並答題');
  String get diagnostics =>
      pick('Windows reminder diagnostics', 'Windows 提醒诊断', 'Windows 提醒診斷');
  @override
  String get empty => pick('No reminder activity yet.', '暂无提醒记录。', '暫無提醒記錄。');
  String get worker => pick('Background worker', '后台提醒进程', '背景提醒程序');
  String get running => pick('Running', '运行中', '執行中');
  String get stopped => pick('Stopped', '已停止', '已停止');
  String get ok => pick('Succeeded', '成功', '成功');
  @override
  String get failed => pick('Failed', '失败', '失敗');
  @override
  String get settings => pick('Notification settings', '通知设置', '通知設定');
  String get audioOnly => pick(
    'Audio is playing; notifications are unavailable. Check notification settings.',
    '音频正在播放，但通知不可用，请检查通知设置。',
    '音訊正在播放，但通知無法使用，請檢查通知設定。',
  );
  String pending(int n) =>
      pick('$n scheduled reminders', '已安排 $n 条提醒', '已排程 $n 則提醒');
  String stage(String value) => switch (value) {
    'task' => pick('Task registration', '计划任务注册', '排程工作註冊'),
    'registration' => pick('Notification registration', '通知注册', '通知註冊'),
    'notifications' => pick('Notification permission', '通知权限', '通知權限'),
    'workerStart' => worker,
    'workerExit' => pick('Worker exit', '进程退出', '程序退出'),
    'trigger' => pick('Reminder triggered', '提醒触发', '提醒觸發'),
    'toastSubmitted' => pick('Notification submitted', '通知已提交', '通知已提交'),
    'toast' => pick('Notification delivery', '通知投递', '通知傳送'),
    'audio' => pick('Audio playback', '音频播放', '音訊播放'),
    'audioFallback' => pick('Audio fallback', '音频回退', '音訊回退'),
    _ => value,
  };
}
