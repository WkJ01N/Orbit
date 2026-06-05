// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => 'Orbit 課表';

  @override
  String get navGrid => '課表';

  @override
  String get navUpcoming => '接下來';

  @override
  String get navImport => '匯入';

  @override
  String get navSettings => '設置';

  @override
  String get gridTitle => '課表';

  @override
  String get gridPrevWeek => '上一週';

  @override
  String get gridNextWeek => '下一週';

  @override
  String get gridThisWeek => '本週';

  @override
  String gridLoadFailed(String error) {
    return '載入失敗：$error';
  }

  @override
  String get gridImportHint => '請先至「匯入」頁面匯入課表';

  @override
  String get gridBatchDelete => '批量刪除';

  @override
  String get gridBatchDeleteTitle => '批量刪除課程';

  @override
  String get gridBatchDeleteStart => '開始';

  @override
  String get gridBatchDeleteEnd => '結束';

  @override
  String gridBatchDeletePreview(int count) {
    return '將刪除 $count 節課';
  }

  @override
  String get gridBatchDeleteConfirm1Title => '刪除區間內的課程？';

  @override
  String gridBatchDeleteConfirm1Content(int count) {
    return '將刪除完全落在所選時間區間內的 $count 節課程。';
  }

  @override
  String get gridBatchDeleteConfirm2Title => '確認刪除';

  @override
  String get gridBatchDeleteConfirm2Content => '刪除後無法復原，確定繼續？';

  @override
  String get gridBatchDeleteNone => '所選區間內沒有完全包含的課程';

  @override
  String gridBatchDeleteDone(int count) {
    return '已刪除 $count 節課程';
  }

  @override
  String get gridBatchDeleteInvalidRange => '結束時間必須晚於開始時間';

  @override
  String get gridWeekPickerYear => '切換年份';

  @override
  String get gridWeekPickerMonth => '切換月份';

  @override
  String get gridNoSessionsThisWeek => '本週無課程';

  @override
  String get gridTimeColumn => '時間';

  @override
  String get weekdayMon => '週一';

  @override
  String get weekdayTue => '週二';

  @override
  String get weekdayWed => '週三';

  @override
  String get weekdayThu => '週四';

  @override
  String get weekdayFri => '週五';

  @override
  String get weekdaySat => '週六';

  @override
  String get weekdaySun => '週日';

  @override
  String get gridNoSessionsThisWeekSubtitle => '切換至其他週或匯入課表';

  @override
  String get actionRetry => '重試';

  @override
  String get importViewGrid => '查看課表';

  @override
  String resyncPartialFailed(int count) {
    return '$count 條提醒未能排定';
  }

  @override
  String get androidBatteryOptimizationGuided => '已引導設定';

  @override
  String get trayInitFailed => '系統匣不可用';

  @override
  String importPickMissingPath(String name) {
    return '無法讀取檔案：$name';
  }

  @override
  String get upcomingGoToGrid => '查看課表';

  @override
  String gridUntilTime(String time) {
    return '至 $time';
  }

  @override
  String get gridEmptyTitle => '尚未匯入課表';

  @override
  String get gridEmptySubtitle => '請前往「匯入」頁面選擇課表 xlsx 檔案';

  @override
  String get gridImportNow => '立即匯入';

  @override
  String get upcomingTitle => '接下來的課程';

  @override
  String upcomingLoadFailed(String error) {
    return '載入失敗：$error';
  }

  @override
  String get groupToday => '今天';

  @override
  String get groupTomorrow => '明天';

  @override
  String get groupThisWeek => '本週';

  @override
  String groupLater(String date) {
    return '$date 以後';
  }

  @override
  String get inClass => '上課中';

  @override
  String get upcomingEmptyTitle => '暫無即將到來的課程';

  @override
  String get upcomingEmptySubtitle => '所有課程已結束，或尚未匯入課表';

  @override
  String get importTitle => '匯入課表';

  @override
  String get importInProgress => '正在匯入課表…';

  @override
  String get importConfirm => '確認匯入';

  @override
  String get importCancel => '取消';

  @override
  String get importPickTitle => '選擇 xlsx 課表檔案';

  @override
  String get importPickSubtitle => '可同時選擇多個週次的課表';

  @override
  String importSuccess(int count) {
    return '成功匯入 $count 節課';
  }

  @override
  String importFailed(String error) {
    return '匯入失敗：$error';
  }

  @override
  String importPickFailed(String error) {
    return '選擇檔案失敗：$error';
  }

  @override
  String importParseFailed(String error) {
    return '解析失敗 ($error)';
  }

  @override
  String sessionCount(int count) {
    return '$count 節課';
  }

  @override
  String get settingsTitle => '設置';

  @override
  String settingsLoadFailed(String error) {
    return '載入設置失敗：$error';
  }

  @override
  String get sectionReminders => '課程提醒';

  @override
  String get sectionData => '資料管理';

  @override
  String get sectionLanguage => '語言';

  @override
  String get sectionAppearance => '外觀';

  @override
  String get themeColorTitle => '主題色';

  @override
  String get themeColorSubtitle => '選擇應用強調色';

  @override
  String get themeColorCustom => '自訂';

  @override
  String get themeColorCustomTitle => '自訂顏色';

  @override
  String get themeColorInvalidHex => '請輸入有效的 6 位十六進制顏色（如 39C5BB）';

  @override
  String get actionApply => '套用';

  @override
  String get sectionSystem => '系統';

  @override
  String get launchAtStartup => '開機啟動';

  @override
  String get launchAtStartupSubtitle => 'Windows 啟動後最小化到系統托盤';

  @override
  String get editSession => '編輯課程';

  @override
  String get editSessionShort => '編輯';

  @override
  String get addSessionNote => '新增備註';

  @override
  String get addSessionNoteShort => '備註';

  @override
  String get sessionNoteTitle => '課程備註';

  @override
  String get sessionNoteHint => '為該節課新增個人備註';

  @override
  String get editSessionTitle => '編輯課程詳情';

  @override
  String get fieldCourseName => '課程名稱';

  @override
  String get fieldRoom => '課室';

  @override
  String get fieldTeachers => '授課教師（逗號分隔）';

  @override
  String get fieldStartTime => '開始時間';

  @override
  String get fieldEndTime => '結束時間';

  @override
  String get sessionUpdated => '課程已更新';

  @override
  String get sessionNoteSaved => '備註已保存';

  @override
  String get editSessionEndBeforeStart => '結束時間必須晚於開始時間';

  @override
  String countdownStartsIn(int days, int hours, int minutes) {
    return '$days天$hours時$minutes分';
  }

  @override
  String countdownSoon(String countdown) {
    return '即將開始 · $countdown';
  }

  @override
  String get enableReminders => '啟用上課提醒';

  @override
  String get enableRemindersSubtitle => '在上課前發送系統通知';

  @override
  String get leadTimeTitle => '提前提醒時間';

  @override
  String leadTimeSubtitle(int minutes) {
    return '提前 $minutes 分鐘通知';
  }

  @override
  String leadTimeOption(int minutes) {
    return '$minutes 分鐘';
  }

  @override
  String get resyncReminders => '重新同步提醒';

  @override
  String get resyncRemindersSubtitle => '重新根據目前課表排定所有提醒';

  @override
  String get sectionAndroidBackground => '背景提醒（Android）';

  @override
  String get androidBackgroundSubtitle =>
      '提醒透過系統鬧鐘觸發，無需保持應用在前台。建議完成以下設定以提高可靠性。';

  @override
  String get androidCheckReminderPermissions => '檢查提醒權限';

  @override
  String get androidPermissionsChecked => '已請求通知與精確鬧鐘權限';

  @override
  String get androidBatteryOptimization => '電池最佳化豁免';

  @override
  String get androidBatteryOptimizationHint => '點擊允許忽略電池最佳化';

  @override
  String get androidBatteryOptimizationDone => '已設定電池最佳化豁免';

  @override
  String get androidAutostartHint => '部分機型還需在系統設定中開啟自啟動並允許背景執行。';

  @override
  String get deleteEndedSessions => '刪除已結束的課程';

  @override
  String get deleteEndedSessionsSubtitle => '移除已經上完的課節記錄';

  @override
  String get deleteEndedConfirm1Title => '刪除已結束的課程？';

  @override
  String deleteEndedConfirm1Content(int count) {
    return '將刪除 $count 節已結束的課程記錄。';
  }

  @override
  String get deleteEndedConfirm2Title => '確認刪除';

  @override
  String get deleteEndedConfirm2Content => '刪除後無法復原，確定繼續？';

  @override
  String get deleteEndedNone => '沒有已結束的課程';

  @override
  String deleteEndedDone(int count) {
    return '已刪除 $count 節已結束的課程';
  }

  @override
  String get clearAllData => '清除所有課表';

  @override
  String get clearAllDataSubtitle => '刪除已匯入的全部課程資料';

  @override
  String settingsVersion(String version) {
    return '版本 $version';
  }

  @override
  String get settingsGithub => 'GitHub 倉庫';

  @override
  String get settingsGithubOpenFailed => '無法開啟連結';

  @override
  String get appTagline => 'Orbit — 課表提醒應用';

  @override
  String get resyncDone => '提醒已重新排定';

  @override
  String get confirmClearTitle => '確認清除';

  @override
  String get confirmClearContent => '此操作將刪除所有已匯入的課表資料，且無法復原。';

  @override
  String get actionCancel => '取消';

  @override
  String get actionClear => '清除';

  @override
  String get dataCleared => '課表資料已清除';

  @override
  String get languageTitle => '應用語言';

  @override
  String get languageSubtitle => '選擇介面顯示語言';

  @override
  String get langZhHant => '繁體中文';

  @override
  String get langZhHans => '簡體中文';

  @override
  String get langEn => 'English';

  @override
  String get languageChangedHint => '語言已更新，可點「重新同步提醒」以更新通知文案。';

  @override
  String get notificationChannelName => '課程提醒';

  @override
  String get notificationChannelDesc => '上課前提醒通知';

  @override
  String notificationTitle(int minutes) {
    return '即將上課（$minutes 分鐘後）';
  }

  @override
  String notificationBody(String course, String room) {
    return '$course @ $room';
  }

  @override
  String notificationTime(String time) {
    return '時間：$time';
  }

  @override
  String notificationRoom(String room) {
    return '課室：$room';
  }

  @override
  String notificationTeachers(String teachers) {
    return '教師：$teachers';
  }

  @override
  String get teachersNotProvided => '未提供';

  @override
  String get sectionAdvancedReminders => '進階提醒';

  @override
  String get enableNextDaySummary => '次日課表確認';

  @override
  String get enableNextDaySummarySubtitle => '在前一晚通知次日第一節課時間與課程數量';

  @override
  String get nextDaySummaryTimeTitle => '確認通知時間';

  @override
  String nextDaySummaryTimeSubtitle(String time) {
    return '於前一天 $time 發送';
  }

  @override
  String get enableSystemAlarm => '系統鬧鐘（Android）';

  @override
  String get enableSystemAlarmSubtitle => '一鍵開啟系統時鐘，為次日第一節課設定鬧鐘';

  @override
  String get systemAlarmLeadTitle => '鬧鐘提前時間';

  @override
  String systemAlarmLeadSubtitle(int minutes) {
    return '比第一節課提前 $minutes 分鐘響鈴';
  }

  @override
  String get setTomorrowAlarm => '為明天設定鬧鐘';

  @override
  String get alarmSetSuccess => '已開啟系統鬧鐘設定';

  @override
  String get alarmSetFailed => '無法開啟系統鬧鐘';

  @override
  String get alarmNoClassTomorrow => '明天沒有課程';

  @override
  String get enableCheckInReminder => '打卡提醒';

  @override
  String get enableCheckInReminderSubtitle => '在課程開始時提醒透過校園 App 藍牙打卡';

  @override
  String get checkInDisableConfirm1Title => '要關閉打卡提醒嗎？';

  @override
  String get checkInDisableConfirm1Content => '關閉後可能錯過校園 App 藍牙打卡提醒。';

  @override
  String get checkInDisableConfirm2Title => '確定要關閉嗎？';

  @override
  String get checkInDisableConfirm2Content => '沒有提醒時，可能會忘記準時打卡。';

  @override
  String get checkInDisableConfirm3Title => '最後確認';

  @override
  String get checkInDisableConfirm3Content => '這將關閉所有打卡提醒，確定繼續？';

  @override
  String get actionContinue => '繼續';

  @override
  String get actionConfirmDisable => '關閉';

  @override
  String get actionDelete => '刪除';

  @override
  String get deleteSession => '刪除此節課';

  @override
  String get deleteSessionShort => '刪除';

  @override
  String get deleteSessionConfirmTitle => '確認刪除此節課？';

  @override
  String deleteSessionConfirmContent(
    String course,
    String date,
    String time,
    String room,
  ) {
    return '$course\n$date $time · $room';
  }

  @override
  String get sessionDeleted => '已刪除該節課程';

  @override
  String get trayShow => '顯示 Orbit';

  @override
  String get trayExit => '退出';

  @override
  String get trayHiddenHint => 'Orbit 已在背景執行，可從工作列托盤圖示顯示或退出。';

  @override
  String notificationCheckInTitle(String course, String room) {
    return '請打卡：$course @ $room';
  }

  @override
  String notificationCheckInBody(String course) {
    return '請開啟校園 App 完成 $course 藍牙打卡';
  }

  @override
  String get notificationNextDayTitle => '明日課表';

  @override
  String notificationNextDayBody(int count, String time) {
    return '明天共 $count 節課，第一節 $time 開始。';
  }

  @override
  String get notificationNextDayNoClassTitle => '明日課表';

  @override
  String get notificationNextDayNoClassBody => '明天沒有課程安排。';
}

/// The translations for Chinese, using the Han script (`zh_Hans`).
class AppLocalizationsZhHans extends AppLocalizationsZh {
  AppLocalizationsZhHans() : super('zh_Hans');

  @override
  String get appTitle => 'Orbit 课表';

  @override
  String get navGrid => '课表';

  @override
  String get navUpcoming => '接下来';

  @override
  String get navImport => '导入';

  @override
  String get navSettings => '设置';

  @override
  String get gridTitle => '课表';

  @override
  String get gridPrevWeek => '上一周';

  @override
  String get gridNextWeek => '下一周';

  @override
  String get gridThisWeek => '本周';

  @override
  String gridLoadFailed(String error) {
    return '加载失败：$error';
  }

  @override
  String get gridImportHint => '请先到「导入」页面导入课表';

  @override
  String get gridBatchDelete => '批量删除';

  @override
  String get gridBatchDeleteTitle => '批量删除课程';

  @override
  String get gridBatchDeleteStart => '开始';

  @override
  String get gridBatchDeleteEnd => '结束';

  @override
  String gridBatchDeletePreview(int count) {
    return '将删除 $count 节课';
  }

  @override
  String get gridBatchDeleteConfirm1Title => '删除区间内的课程？';

  @override
  String gridBatchDeleteConfirm1Content(int count) {
    return '将删除完全落在所选时间区间内的 $count 节课程。';
  }

  @override
  String get gridBatchDeleteConfirm2Title => '确认删除';

  @override
  String get gridBatchDeleteConfirm2Content => '删除后无法恢复，确定继续？';

  @override
  String get gridBatchDeleteNone => '所选区间内没有完全包含的课程';

  @override
  String gridBatchDeleteDone(int count) {
    return '已删除 $count 节课程';
  }

  @override
  String get gridBatchDeleteInvalidRange => '结束时间必须晚于开始时间';

  @override
  String get gridWeekPickerYear => '切换年份';

  @override
  String get gridWeekPickerMonth => '切换月份';

  @override
  String get gridNoSessionsThisWeek => '本周无课程';

  @override
  String get gridTimeColumn => '时间';

  @override
  String get weekdayMon => '周一';

  @override
  String get weekdayTue => '周二';

  @override
  String get weekdayWed => '周三';

  @override
  String get weekdayThu => '周四';

  @override
  String get weekdayFri => '周五';

  @override
  String get weekdaySat => '周六';

  @override
  String get weekdaySun => '周日';

  @override
  String get gridNoSessionsThisWeekSubtitle => '切换到其他周或导入课表';

  @override
  String get actionRetry => '重试';

  @override
  String get importViewGrid => '查看课表';

  @override
  String resyncPartialFailed(int count) {
    return '$count 条提醒未能排定';
  }

  @override
  String get androidBatteryOptimizationGuided => '已引导设置';

  @override
  String get trayInitFailed => '系统托盘不可用';

  @override
  String importPickMissingPath(String name) {
    return '无法读取文件：$name';
  }

  @override
  String get upcomingGoToGrid => '查看课表';

  @override
  String gridUntilTime(String time) {
    return '至 $time';
  }

  @override
  String get gridEmptyTitle => '尚未导入课表';

  @override
  String get gridEmptySubtitle => '请前往「导入」页面选择课表 xlsx 文件';

  @override
  String get gridImportNow => '立即导入';

  @override
  String get upcomingTitle => '接下来的课程';

  @override
  String upcomingLoadFailed(String error) {
    return '加载失败：$error';
  }

  @override
  String get groupToday => '今天';

  @override
  String get groupTomorrow => '明天';

  @override
  String get groupThisWeek => '本周';

  @override
  String groupLater(String date) {
    return '$date 以后';
  }

  @override
  String get inClass => '上课中';

  @override
  String get upcomingEmptyTitle => '暂无即将到来的课程';

  @override
  String get upcomingEmptySubtitle => '所有课程已结束，或尚未导入课表';

  @override
  String get importTitle => '导入课表';

  @override
  String get importInProgress => '正在导入课表…';

  @override
  String get importConfirm => '确认导入';

  @override
  String get importCancel => '取消';

  @override
  String get importPickTitle => '选择 xlsx 课表文件';

  @override
  String get importPickSubtitle => '可同时选择多个周次的课表';

  @override
  String importSuccess(int count) {
    return '成功导入 $count 节课';
  }

  @override
  String importFailed(String error) {
    return '导入失败：$error';
  }

  @override
  String importPickFailed(String error) {
    return '选择文件失败：$error';
  }

  @override
  String importParseFailed(String error) {
    return '解析失败 ($error)';
  }

  @override
  String sessionCount(int count) {
    return '$count 节课';
  }

  @override
  String get settingsTitle => '设置';

  @override
  String settingsLoadFailed(String error) {
    return '加载设置失败：$error';
  }

  @override
  String get sectionReminders => '课程提醒';

  @override
  String get sectionData => '数据管理';

  @override
  String get sectionLanguage => '语言';

  @override
  String get sectionAppearance => '外观';

  @override
  String get themeColorTitle => '主题色';

  @override
  String get themeColorSubtitle => '选择应用强调色';

  @override
  String get themeColorCustom => '自定义';

  @override
  String get themeColorCustomTitle => '自定义颜色';

  @override
  String get themeColorInvalidHex => '请输入有效的 6 位十六进制颜色（如 39C5BB）';

  @override
  String get actionApply => '应用';

  @override
  String get sectionSystem => '系统';

  @override
  String get launchAtStartup => '开机启动';

  @override
  String get launchAtStartupSubtitle => 'Windows 启动后最小化到系统托盘';

  @override
  String get editSession => '编辑课程';

  @override
  String get editSessionShort => '编辑';

  @override
  String get addSessionNote => '添加备注';

  @override
  String get addSessionNoteShort => '备注';

  @override
  String get sessionNoteTitle => '课程备注';

  @override
  String get sessionNoteHint => '为该节课添加个人备注';

  @override
  String get editSessionTitle => '编辑课程详情';

  @override
  String get fieldCourseName => '课程名称';

  @override
  String get fieldRoom => '教室';

  @override
  String get fieldTeachers => '授课教师（逗号分隔）';

  @override
  String get fieldStartTime => '开始时间';

  @override
  String get fieldEndTime => '结束时间';

  @override
  String get sessionUpdated => '课程已更新';

  @override
  String get sessionNoteSaved => '备注已保存';

  @override
  String get editSessionEndBeforeStart => '结束时间必须晚于开始时间';

  @override
  String countdownStartsIn(int days, int hours, int minutes) {
    return '$days天$hours时$minutes分';
  }

  @override
  String countdownSoon(String countdown) {
    return '即将开始 · $countdown';
  }

  @override
  String get enableReminders => '启用上课提醒';

  @override
  String get enableRemindersSubtitle => '在上课前发送系统通知';

  @override
  String get leadTimeTitle => '提前提醒时间';

  @override
  String leadTimeSubtitle(int minutes) {
    return '提前 $minutes 分钟通知';
  }

  @override
  String leadTimeOption(int minutes) {
    return '$minutes 分钟';
  }

  @override
  String get resyncReminders => '重新同步提醒';

  @override
  String get resyncRemindersSubtitle => '重新根据当前课表排定所有提醒';

  @override
  String get sectionAndroidBackground => '后台提醒（Android）';

  @override
  String get androidBackgroundSubtitle =>
      '提醒通过系统闹钟触发，无需保持应用在前台。建议完成以下设置以提高可靠性。';

  @override
  String get androidCheckReminderPermissions => '检查提醒权限';

  @override
  String get androidPermissionsChecked => '已请求通知与精确闹钟权限';

  @override
  String get androidBatteryOptimization => '电池优化豁免';

  @override
  String get androidBatteryOptimizationHint => '点击允许忽略电池优化';

  @override
  String get androidBatteryOptimizationDone => '已配置电池优化豁免';

  @override
  String get androidAutostartHint => '部分机型还需在系统设置中开启自启动并允许后台运行。';

  @override
  String get deleteEndedSessions => '删除已结束的课程';

  @override
  String get deleteEndedSessionsSubtitle => '移除已经上完的课节记录';

  @override
  String get deleteEndedConfirm1Title => '删除已结束的课程？';

  @override
  String deleteEndedConfirm1Content(int count) {
    return '将删除 $count 节已结束的课程记录。';
  }

  @override
  String get deleteEndedConfirm2Title => '确认删除';

  @override
  String get deleteEndedConfirm2Content => '删除后无法恢复，确定继续？';

  @override
  String get deleteEndedNone => '没有已结束的课程';

  @override
  String deleteEndedDone(int count) {
    return '已删除 $count 节已结束的课程';
  }

  @override
  String get clearAllData => '清除所有课表';

  @override
  String get clearAllDataSubtitle => '删除已导入的全部课程数据';

  @override
  String settingsVersion(String version) {
    return '版本 $version';
  }

  @override
  String get settingsGithub => 'GitHub 仓库';

  @override
  String get settingsGithubOpenFailed => '无法打开链接';

  @override
  String get appTagline => 'Orbit — 课表提醒应用';

  @override
  String get resyncDone => '提醒已重新排定';

  @override
  String get confirmClearTitle => '确认清除';

  @override
  String get confirmClearContent => '此操作将删除所有已导入的课表数据，且无法恢复。';

  @override
  String get actionCancel => '取消';

  @override
  String get actionClear => '清除';

  @override
  String get dataCleared => '课表数据已清除';

  @override
  String get languageTitle => '应用语言';

  @override
  String get languageSubtitle => '选择界面显示语言';

  @override
  String get langZhHant => '繁体中文';

  @override
  String get langZhHans => '简体中文';

  @override
  String get langEn => 'English';

  @override
  String get languageChangedHint => '语言已更新，可点「重新同步提醒」以更新通知文案。';

  @override
  String get notificationChannelName => '课程提醒';

  @override
  String get notificationChannelDesc => '上课前提醒通知';

  @override
  String notificationTitle(int minutes) {
    return '即将上课（$minutes 分钟后）';
  }

  @override
  String notificationBody(String course, String room) {
    return '$course @ $room';
  }

  @override
  String notificationTime(String time) {
    return '时间：$time';
  }

  @override
  String notificationRoom(String room) {
    return '教室：$room';
  }

  @override
  String notificationTeachers(String teachers) {
    return '教师：$teachers';
  }

  @override
  String get teachersNotProvided => '未提供';

  @override
  String get sectionAdvancedReminders => '高级提醒';

  @override
  String get enableNextDaySummary => '次日课表确认';

  @override
  String get enableNextDaySummarySubtitle => '在前一晚通知次日第一节课时间与课程数量';

  @override
  String get nextDaySummaryTimeTitle => '确认通知时间';

  @override
  String nextDaySummaryTimeSubtitle(String time) {
    return '于前一天 $time 发送';
  }

  @override
  String get enableSystemAlarm => '系统闹钟（Android）';

  @override
  String get enableSystemAlarmSubtitle => '一键打开系统时钟，为次日第一节课设置闹钟';

  @override
  String get systemAlarmLeadTitle => '闹钟提前时间';

  @override
  String systemAlarmLeadSubtitle(int minutes) {
    return '比第一节课提前 $minutes 分钟响铃';
  }

  @override
  String get setTomorrowAlarm => '为明天设置闹钟';

  @override
  String get alarmSetSuccess => '已打开系统闹钟设置';

  @override
  String get alarmSetFailed => '无法打开系统闹钟';

  @override
  String get alarmNoClassTomorrow => '明天没有课程';

  @override
  String get enableCheckInReminder => '打卡提醒';

  @override
  String get enableCheckInReminderSubtitle => '在课程开始时提醒通过校园 App 蓝牙打卡';

  @override
  String get checkInDisableConfirm1Title => '要关闭打卡提醒吗？';

  @override
  String get checkInDisableConfirm1Content => '关闭后可能错过校园 App 蓝牙打卡提醒。';

  @override
  String get checkInDisableConfirm2Title => '确定要关闭吗？';

  @override
  String get checkInDisableConfirm2Content => '没有提醒时，可能会忘记准时打卡。';

  @override
  String get checkInDisableConfirm3Title => '最后确认';

  @override
  String get checkInDisableConfirm3Content => '这将关闭所有打卡提醒，确定继续？';

  @override
  String get actionContinue => '继续';

  @override
  String get actionConfirmDisable => '关闭';

  @override
  String get actionDelete => '删除';

  @override
  String get deleteSession => '删除此节课';

  @override
  String get deleteSessionShort => '删除';

  @override
  String get deleteSessionConfirmTitle => '确认删除此节课？';

  @override
  String deleteSessionConfirmContent(
    String course,
    String date,
    String time,
    String room,
  ) {
    return '$course\n$date $time · $room';
  }

  @override
  String get sessionDeleted => '已删除该节课程';

  @override
  String get trayShow => '显示 Orbit';

  @override
  String get trayExit => '退出';

  @override
  String get trayHiddenHint => 'Orbit 已在后台运行，可从任务栏托盘图标显示或退出。';

  @override
  String notificationCheckInTitle(String course, String room) {
    return '请打卡：$course @ $room';
  }

  @override
  String notificationCheckInBody(String course) {
    return '请打开校园 App 完成 $course 蓝牙打卡';
  }

  @override
  String get notificationNextDayTitle => '明日课表';

  @override
  String notificationNextDayBody(int count, String time) {
    return '明天共 $count 节课，第一节 $time 开始。';
  }

  @override
  String get notificationNextDayNoClassTitle => '明日课表';

  @override
  String get notificationNextDayNoClassBody => '明天没有课程安排。';
}

/// The translations for Chinese, using the Han script (`zh_Hant`).
class AppLocalizationsZhHant extends AppLocalizationsZh {
  AppLocalizationsZhHant() : super('zh_Hant');

  @override
  String get appTitle => 'Orbit 課表';

  @override
  String get navGrid => '課表';

  @override
  String get navUpcoming => '接下來';

  @override
  String get navImport => '匯入';

  @override
  String get navSettings => '設置';

  @override
  String get gridTitle => '課表';

  @override
  String get gridPrevWeek => '上一週';

  @override
  String get gridNextWeek => '下一週';

  @override
  String get gridThisWeek => '本週';

  @override
  String gridLoadFailed(String error) {
    return '載入失敗：$error';
  }

  @override
  String get gridImportHint => '請先至「匯入」頁面匯入課表';

  @override
  String get gridBatchDelete => '批量刪除';

  @override
  String get gridBatchDeleteTitle => '批量刪除課程';

  @override
  String get gridBatchDeleteStart => '開始';

  @override
  String get gridBatchDeleteEnd => '結束';

  @override
  String gridBatchDeletePreview(int count) {
    return '將刪除 $count 節課';
  }

  @override
  String get gridBatchDeleteConfirm1Title => '刪除區間內的課程？';

  @override
  String gridBatchDeleteConfirm1Content(int count) {
    return '將刪除完全落在所選時間區間內的 $count 節課程。';
  }

  @override
  String get gridBatchDeleteConfirm2Title => '確認刪除';

  @override
  String get gridBatchDeleteConfirm2Content => '刪除後無法復原，確定繼續？';

  @override
  String get gridBatchDeleteNone => '所選區間內沒有完全包含的課程';

  @override
  String gridBatchDeleteDone(int count) {
    return '已刪除 $count 節課程';
  }

  @override
  String get gridBatchDeleteInvalidRange => '結束時間必須晚於開始時間';

  @override
  String get gridWeekPickerYear => '切換年份';

  @override
  String get gridWeekPickerMonth => '切換月份';

  @override
  String get gridNoSessionsThisWeek => '本週無課程';

  @override
  String get gridTimeColumn => '時間';

  @override
  String get weekdayMon => '週一';

  @override
  String get weekdayTue => '週二';

  @override
  String get weekdayWed => '週三';

  @override
  String get weekdayThu => '週四';

  @override
  String get weekdayFri => '週五';

  @override
  String get weekdaySat => '週六';

  @override
  String get weekdaySun => '週日';

  @override
  String get gridNoSessionsThisWeekSubtitle => '切換至其他週或匯入課表';

  @override
  String get actionRetry => '重試';

  @override
  String get importViewGrid => '查看課表';

  @override
  String resyncPartialFailed(int count) {
    return '$count 條提醒未能排定';
  }

  @override
  String get androidBatteryOptimizationGuided => '已引導設定';

  @override
  String get trayInitFailed => '系統匣不可用';

  @override
  String importPickMissingPath(String name) {
    return '無法讀取檔案：$name';
  }

  @override
  String get upcomingGoToGrid => '查看課表';

  @override
  String gridUntilTime(String time) {
    return '至 $time';
  }

  @override
  String get gridEmptyTitle => '尚未匯入課表';

  @override
  String get gridEmptySubtitle => '請前往「匯入」頁面選擇課表 xlsx 檔案';

  @override
  String get gridImportNow => '立即匯入';

  @override
  String get upcomingTitle => '接下來的課程';

  @override
  String upcomingLoadFailed(String error) {
    return '載入失敗：$error';
  }

  @override
  String get groupToday => '今天';

  @override
  String get groupTomorrow => '明天';

  @override
  String get groupThisWeek => '本週';

  @override
  String groupLater(String date) {
    return '$date 以後';
  }

  @override
  String get inClass => '上課中';

  @override
  String get upcomingEmptyTitle => '暫無即將到來的課程';

  @override
  String get upcomingEmptySubtitle => '所有課程已結束，或尚未匯入課表';

  @override
  String get importTitle => '匯入課表';

  @override
  String get importInProgress => '正在匯入課表…';

  @override
  String get importConfirm => '確認匯入';

  @override
  String get importCancel => '取消';

  @override
  String get importPickTitle => '選擇 xlsx 課表檔案';

  @override
  String get importPickSubtitle => '可同時選擇多個週次的課表';

  @override
  String importSuccess(int count) {
    return '成功匯入 $count 節課';
  }

  @override
  String importFailed(String error) {
    return '匯入失敗：$error';
  }

  @override
  String importPickFailed(String error) {
    return '選擇檔案失敗：$error';
  }

  @override
  String importParseFailed(String error) {
    return '解析失敗 ($error)';
  }

  @override
  String sessionCount(int count) {
    return '$count 節課';
  }

  @override
  String get settingsTitle => '設置';

  @override
  String settingsLoadFailed(String error) {
    return '載入設置失敗：$error';
  }

  @override
  String get sectionReminders => '課程提醒';

  @override
  String get sectionData => '資料管理';

  @override
  String get sectionLanguage => '語言';

  @override
  String get sectionAppearance => '外觀';

  @override
  String get themeColorTitle => '主題色';

  @override
  String get themeColorSubtitle => '選擇應用強調色';

  @override
  String get themeColorCustom => '自訂';

  @override
  String get themeColorCustomTitle => '自訂顏色';

  @override
  String get themeColorInvalidHex => '請輸入有效的 6 位十六進制顏色（如 39C5BB）';

  @override
  String get actionApply => '套用';

  @override
  String get sectionSystem => '系統';

  @override
  String get launchAtStartup => '開機啟動';

  @override
  String get launchAtStartupSubtitle => 'Windows 啟動後最小化到系統托盤';

  @override
  String get editSession => '編輯課程';

  @override
  String get editSessionShort => '編輯';

  @override
  String get addSessionNote => '新增備註';

  @override
  String get addSessionNoteShort => '備註';

  @override
  String get sessionNoteTitle => '課程備註';

  @override
  String get sessionNoteHint => '為該節課新增個人備註';

  @override
  String get editSessionTitle => '編輯課程詳情';

  @override
  String get fieldCourseName => '課程名稱';

  @override
  String get fieldRoom => '課室';

  @override
  String get fieldTeachers => '授課教師（逗號分隔）';

  @override
  String get fieldStartTime => '開始時間';

  @override
  String get fieldEndTime => '結束時間';

  @override
  String get sessionUpdated => '課程已更新';

  @override
  String get sessionNoteSaved => '備註已保存';

  @override
  String get editSessionEndBeforeStart => '結束時間必須晚於開始時間';

  @override
  String countdownStartsIn(int days, int hours, int minutes) {
    return '$days天$hours時$minutes分';
  }

  @override
  String countdownSoon(String countdown) {
    return '即將開始 · $countdown';
  }

  @override
  String get enableReminders => '啟用上課提醒';

  @override
  String get enableRemindersSubtitle => '在上課前發送系統通知';

  @override
  String get leadTimeTitle => '提前提醒時間';

  @override
  String leadTimeSubtitle(int minutes) {
    return '提前 $minutes 分鐘通知';
  }

  @override
  String leadTimeOption(int minutes) {
    return '$minutes 分鐘';
  }

  @override
  String get resyncReminders => '重新同步提醒';

  @override
  String get resyncRemindersSubtitle => '重新根據目前課表排定所有提醒';

  @override
  String get sectionAndroidBackground => '背景提醒（Android）';

  @override
  String get androidBackgroundSubtitle =>
      '提醒透過系統鬧鐘觸發，無需保持應用在前台。建議完成以下設定以提高可靠性。';

  @override
  String get androidCheckReminderPermissions => '檢查提醒權限';

  @override
  String get androidPermissionsChecked => '已請求通知與精確鬧鐘權限';

  @override
  String get androidBatteryOptimization => '電池最佳化豁免';

  @override
  String get androidBatteryOptimizationHint => '點擊允許忽略電池最佳化';

  @override
  String get androidBatteryOptimizationDone => '已設定電池最佳化豁免';

  @override
  String get androidAutostartHint => '部分機型還需在系統設定中開啟自啟動並允許背景執行。';

  @override
  String get deleteEndedSessions => '刪除已結束的課程';

  @override
  String get deleteEndedSessionsSubtitle => '移除已經上完的課節記錄';

  @override
  String get deleteEndedConfirm1Title => '刪除已結束的課程？';

  @override
  String deleteEndedConfirm1Content(int count) {
    return '將刪除 $count 節已結束的課程記錄。';
  }

  @override
  String get deleteEndedConfirm2Title => '確認刪除';

  @override
  String get deleteEndedConfirm2Content => '刪除後無法復原，確定繼續？';

  @override
  String get deleteEndedNone => '沒有已結束的課程';

  @override
  String deleteEndedDone(int count) {
    return '已刪除 $count 節已結束的課程';
  }

  @override
  String get clearAllData => '清除所有課表';

  @override
  String get clearAllDataSubtitle => '刪除已匯入的全部課程資料';

  @override
  String settingsVersion(String version) {
    return '版本 $version';
  }

  @override
  String get settingsGithub => 'GitHub 倉庫';

  @override
  String get settingsGithubOpenFailed => '無法開啟連結';

  @override
  String get appTagline => 'Orbit — 課表提醒應用';

  @override
  String get resyncDone => '提醒已重新排定';

  @override
  String get confirmClearTitle => '確認清除';

  @override
  String get confirmClearContent => '此操作將刪除所有已匯入的課表資料，且無法復原。';

  @override
  String get actionCancel => '取消';

  @override
  String get actionClear => '清除';

  @override
  String get dataCleared => '課表資料已清除';

  @override
  String get languageTitle => '應用語言';

  @override
  String get languageSubtitle => '選擇介面顯示語言';

  @override
  String get langZhHant => '繁體中文';

  @override
  String get langZhHans => '簡體中文';

  @override
  String get langEn => 'English';

  @override
  String get languageChangedHint => '語言已更新，可點「重新同步提醒」以更新通知文案。';

  @override
  String get notificationChannelName => '課程提醒';

  @override
  String get notificationChannelDesc => '上課前提醒通知';

  @override
  String notificationTitle(int minutes) {
    return '即將上課（$minutes 分鐘後）';
  }

  @override
  String notificationBody(String course, String room) {
    return '$course @ $room';
  }

  @override
  String notificationTime(String time) {
    return '時間：$time';
  }

  @override
  String notificationRoom(String room) {
    return '課室：$room';
  }

  @override
  String notificationTeachers(String teachers) {
    return '教師：$teachers';
  }

  @override
  String get teachersNotProvided => '未提供';

  @override
  String get sectionAdvancedReminders => '進階提醒';

  @override
  String get enableNextDaySummary => '次日課表確認';

  @override
  String get enableNextDaySummarySubtitle => '在前一晚通知次日第一節課時間與課程數量';

  @override
  String get nextDaySummaryTimeTitle => '確認通知時間';

  @override
  String nextDaySummaryTimeSubtitle(String time) {
    return '於前一天 $time 發送';
  }

  @override
  String get enableSystemAlarm => '系統鬧鐘（Android）';

  @override
  String get enableSystemAlarmSubtitle => '一鍵開啟系統時鐘，為次日第一節課設定鬧鐘';

  @override
  String get systemAlarmLeadTitle => '鬧鐘提前時間';

  @override
  String systemAlarmLeadSubtitle(int minutes) {
    return '比第一節課提前 $minutes 分鐘響鈴';
  }

  @override
  String get setTomorrowAlarm => '為明天設定鬧鐘';

  @override
  String get alarmSetSuccess => '已開啟系統鬧鐘設定';

  @override
  String get alarmSetFailed => '無法開啟系統鬧鐘';

  @override
  String get alarmNoClassTomorrow => '明天沒有課程';

  @override
  String get enableCheckInReminder => '打卡提醒';

  @override
  String get enableCheckInReminderSubtitle => '在課程開始時提醒透過校園 App 藍牙打卡';

  @override
  String get checkInDisableConfirm1Title => '要關閉打卡提醒嗎？';

  @override
  String get checkInDisableConfirm1Content => '關閉後可能錯過校園 App 藍牙打卡提醒。';

  @override
  String get checkInDisableConfirm2Title => '確定要關閉嗎？';

  @override
  String get checkInDisableConfirm2Content => '沒有提醒時，可能會忘記準時打卡。';

  @override
  String get checkInDisableConfirm3Title => '最後確認';

  @override
  String get checkInDisableConfirm3Content => '這將關閉所有打卡提醒，確定繼續？';

  @override
  String get actionContinue => '繼續';

  @override
  String get actionConfirmDisable => '關閉';

  @override
  String get actionDelete => '刪除';

  @override
  String get deleteSession => '刪除此節課';

  @override
  String get deleteSessionShort => '刪除';

  @override
  String get deleteSessionConfirmTitle => '確認刪除此節課？';

  @override
  String deleteSessionConfirmContent(
    String course,
    String date,
    String time,
    String room,
  ) {
    return '$course\n$date $time · $room';
  }

  @override
  String get sessionDeleted => '已刪除該節課程';

  @override
  String get trayShow => '顯示 Orbit';

  @override
  String get trayExit => '退出';

  @override
  String get trayHiddenHint => 'Orbit 已在背景執行，可從工作列托盤圖示顯示或退出。';

  @override
  String notificationCheckInTitle(String course, String room) {
    return '請打卡：$course @ $room';
  }

  @override
  String notificationCheckInBody(String course) {
    return '請開啟校園 App 完成 $course 藍牙打卡';
  }

  @override
  String get notificationNextDayTitle => '明日課表';

  @override
  String notificationNextDayBody(int count, String time) {
    return '明天共 $count 節課，第一節 $time 開始。';
  }

  @override
  String get notificationNextDayNoClassTitle => '明日課表';

  @override
  String get notificationNextDayNoClassBody => '明天沒有課程安排。';
}
