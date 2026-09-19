// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get importAuto => '自動識別';

  @override
  String get importTemplates => '識別模板';

  @override
  String get importPlans => '學期與作息';

  @override
  String get importListLayout => '課程列表';

  @override
  String get importGridLayout => '週課表網格';

  @override
  String get importLegacyLayout => 'Orbit 13 欄格式';

  @override
  String get importTemplateName => '模板名稱';

  @override
  String get importBuiltIn => '內建模板 · 複製後編輯';

  @override
  String get importCopy => '複製';

  @override
  String get importShareTemplate => '匯出模板 JSON';

  @override
  String get importLoadTemplate => '匯入模板 JSON';

  @override
  String get importLayoutStep => '佈局與區域';

  @override
  String get importFieldsStep => '欄位映射';

  @override
  String get importRegexStep => '提取規則';

  @override
  String get importTestStep => '測試與預覽';

  @override
  String get importHeaderRow => '表頭列（從 1 開始）';

  @override
  String get importFirstRow => '課程起始列';

  @override
  String get importLastRow => '課程結束列（留空至表末）';

  @override
  String get importFirstColumn => '課程起始欄（從 1 開始）';

  @override
  String get importLastColumn => '課程結束欄';

  @override
  String get importWeekdayColumns => '欄:星期，例如 2:1,3:2';

  @override
  String get importPeriodRows => '列:節次，例如 2:1-2;3:3-4';

  @override
  String get importColumnSource => '指定欄';

  @override
  String get importTextSource => '課程區塊文字';

  @override
  String get importFixedSource => '固定值';

  @override
  String get importWeekdaySource => '網格星期';

  @override
  String get importPeriodsSource => '網格節次';

  @override
  String get importColumnNumber => '欄號（從 1 開始）';

  @override
  String get importFixedValue => '固定值';

  @override
  String get importPattern => '正規表示式（留空使用原文）';

  @override
  String get importCaptureGroup => '擷取群組編號或名稱';

  @override
  String get importCaseSensitive => '區分大小寫';

  @override
  String get importMultiLine => '多行錨點';

  @override
  String get importDotAll => '點號匹配換行';

  @override
  String get importUnicode => 'Unicode 模式';

  @override
  String get importBlockPattern => '課程區塊分隔／匹配正規式';

  @override
  String get importRepeatBlocks => '重複匹配課程區塊';

  @override
  String get importTestText => '範例課程文字';

  @override
  String get importRunTest => '執行測試';

  @override
  String get importOriginal => '原文';

  @override
  String get importMatches => '匹配與擷取群組';

  @override
  String get importExtracted => '提取欄位';

  @override
  String get importSave => '儲存';

  @override
  String get importNext => '下一步';

  @override
  String get importBack => '上一步';

  @override
  String get importSemesterName => '學期名稱';

  @override
  String get importFirstMonday => '第一週週一（YYYY-MM-DD）';

  @override
  String get importTotalWeeks => '總週數（1–30）';

  @override
  String get importPeriodPlanName => '作息方案名稱';

  @override
  String get importPeriodTimeInput => '節次,開始,結束，每列一節，例如 1,08:00,08:45';

  @override
  String get importDefaultWeeks => '檔案缺少週次時適用的週次（如 1-18）';

  @override
  String get importConfirmContext => '確認本次匯入的學期、週次與作息';

  @override
  String get importTemporaryContext => '臨時調整僅用於本次匯入；儲存方案請進入方案管理。';

  @override
  String get importEncoding => 'CSV 編碼';

  @override
  String get importDelimiter => 'CSV 分隔符';

  @override
  String get importComma => '逗號';

  @override
  String get importSemicolon => '分號';

  @override
  String get importTab => '定位字元';

  @override
  String get importPreview => '解析與預覽';

  @override
  String get importSkipErrors => '明確略過識別失敗的課程';

  @override
  String get importSkipDescription => '失敗的課程不會匯入，請先檢查每條錯誤。';

  @override
  String get importCancelTask => '取消解析';

  @override
  String get importSelectSheet => '選擇要匯入的工作表';

  @override
  String get importRawTable => '原表預覽 — 點選儲存格選擇座標';

  @override
  String get importChooseCoordinate => '將所選儲存格設為';

  @override
  String get importNoSelection => '尚未選擇工作表';

  @override
  String get importNone => '不使用';

  @override
  String get importValid => '有效';

  @override
  String get importDuplicates => '重複';

  @override
  String get importErrors => '失敗';

  @override
  String get importDeleteConfirm => '刪除此已儲存的模板或方案？';

  @override
  String get importHelp =>
      '列表需課程名、日期（或星期和週次）及起止時間（或節次）。網格以星期為欄、節次為列；同格多課可用空列分隔或設定課程區塊規則。按週課表需確認學期和作息。';

  @override
  String get importFieldCourseName => '課程名';

  @override
  String get importFieldCourseCode => '課程編號';

  @override
  String get importFieldSection => '班別';

  @override
  String get importFieldRoom => '教室';

  @override
  String get importFieldTeachers => '教師';

  @override
  String get importFieldFaculty => '學院';

  @override
  String get importFieldClassType => '課堂類型';

  @override
  String get importFieldSemester => '學期';

  @override
  String get importFieldDate => '日期';

  @override
  String get importFieldWeekday => '星期';

  @override
  String get importFieldWeeks => '週次';

  @override
  String get importFieldPeriods => '節次';

  @override
  String get importFieldStartTime => '開始時間';

  @override
  String get importFieldEndTime => '結束時間';

  @override
  String get importErrorAmbiguous => '有多個候選模板，請明確選擇。';

  @override
  String get importErrorTemplateInvalid => '模板或區域設定無效。';

  @override
  String get importErrorTemplateVersion => '不支援此模板版本。';

  @override
  String get importErrorCaptureGroup => '擷取群組編號或名稱無效。';

  @override
  String get importErrorMissingName => '缺少課程名。';

  @override
  String get importErrorSemesterInvalid => '請檢查學期名稱、週一日期和總週數。';

  @override
  String get importErrorPeriodInvalid => '節次或作息方案無效。';

  @override
  String get importErrorInvalidTime => '時間無效，結束時間必須晚於開始。';

  @override
  String get importErrorInvalidDate => '日期無效。';

  @override
  String get importErrorInvalidWeekday => '星期必須為週一至週日。';

  @override
  String get importErrorWeekdayMismatch => '星期與日期不一致。';

  @override
  String get importErrorInvalidWeeks => '週次無效或超出學期範圍。';

  @override
  String get importErrorWeeksRequired => '檔案缺少週次，請確認適用週次。';

  @override
  String get importErrorContextRequired => '請確認學期與所需作息方案。';

  @override
  String get importErrorUnknownPeriod => '部分節次沒有對應時間。';

  @override
  String get importErrorHorizontalMerge => '不支援跨多個星期欄合併的課程格。';

  @override
  String get importErrorZeroLength => '課程區塊規則不能匹配空文字。';

  @override
  String get importErrorNoMatch => '未匹配到課程區塊。';

  @override
  String get importErrorUnmatchedText => '課程區塊規則遺漏了部分文字，請修正规則。';

  @override
  String get importErrorIdConflict => '相同課次編號對應不同內容，請修正或明確略過。';

  @override
  String get importErrorNoSessions => '沒有識別到有效課程。';

  @override
  String get importErrorNoSheet => '檔案沒有工作表。';

  @override
  String get importErrorUnsupportedFile => '僅支援 XLSX 和 CSV 檔案。';

  @override
  String get importErrorEncodingFailed => 'CSV 解碼失敗，請切換編碼或轉換檔案。';

  @override
  String get importErrorTimeout => '解析逾時，設定已保留。';

  @override
  String get importErrorCancelled => '解析已取消。';

  @override
  String get importErrorWorkerFailed => '解析工作失敗，請重試。';

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
  String get gridBatchDeleteConfirm2Content => '所選課程將移入回收站並保留 7 天，確定繼續？';

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
  String get gridNoSessionsThisWeekSubtitle => '切換至其他週查看課程';

  @override
  String get actionRetry => '重試';

  @override
  String get importViewGrid => '查看課表';

  @override
  String resyncPartialFailed(int count) {
    return '$count 條提醒未能排定';
  }

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
  String get gridEmptySubtitle => '請前往「匯入」頁面選擇 XLSX 或 CSV 課表檔案';

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
  String upcomingWeekMonday(String date) {
    return '$date';
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
  String get importPickTitle => '選擇 XLSX / CSV 課表檔案';

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
  String get settingsCategoryGeneral => '一般';

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
  String get themeStyleTitle => '課程配色';

  @override
  String get themeStyleSubtitle => '使用統一強調色或為不同課程自動配色';

  @override
  String get themeStyleStandard => '統一顏色';

  @override
  String get themeStyleColorful => '自動分色';

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
  String get themeModeTitle => '深淺色模式';

  @override
  String get themeModeSubtitle => '選擇淺色、深色或跟隨系統';

  @override
  String get themeModeSystem => '跟隨系統';

  @override
  String get themeModeLight => '淺色';

  @override
  String get themeModeDark => '深色';

  @override
  String get weekStartDayTitle => '週起始日';

  @override
  String get weekStartDaySubtitle => '課表每週從哪一天開始顯示';

  @override
  String get weekStartMonday => '週一';

  @override
  String get weekStartSunday => '週日';

  @override
  String get gridDensityTitle => '課表顯示密度';

  @override
  String get gridDensitySubtitle => '調整課表行高與字體大小';

  @override
  String get gridDensityCompact => '緊湊';

  @override
  String get gridDensityStandard => '標準';

  @override
  String get gridDensityComfortable => '寬鬆';

  @override
  String get scheduleNarrowLayoutTitle => '窄螢幕課表佈局';

  @override
  String get scheduleNarrowLayoutSubtitle => '選擇一屏整週或經典單日／多日自適應佈局';

  @override
  String get scheduleNarrowLayoutCompactWeek => '緊湊整週';

  @override
  String get scheduleNarrowLayoutAdaptive => '經典自適應';

  @override
  String get scheduleMultiDayCountTitle => '多日模式顯示天數';

  @override
  String scheduleMultiDayCountSubtitle(int maxCount) {
    return '目前視窗最多可清晰顯示 $maxCount 天';
  }

  @override
  String scheduleDayCountOption(int count) {
    return '$count 天';
  }

  @override
  String get scheduleShowEmptyDaysTitle => '顯示無課程日期';

  @override
  String get scheduleShowEmptyDaysSubtitle => '僅用於經典自適應佈局；關閉後將在有課程的日期之間切換';

  @override
  String get upcomingShowCourseDateTitle => '在倒數旁顯示日期';

  @override
  String get upcomingShowCourseDateSubtitle => '在接下來課程列表中顯示課程日期';

  @override
  String get upcomingDateDisplayTitle => '課程日期格式';

  @override
  String get upcomingDateDisplaySubtitle => '選擇要顯示的日期資訊';

  @override
  String get upcomingDateDisplayDateAndWeekday => '日期 + 星期';

  @override
  String get upcomingDateDisplayDateOnly => '僅日期';

  @override
  String get upcomingDateDisplayWeekdayOnly => '僅星期';

  @override
  String get scheduleJumpToNearestCourse => '跳到最近課程';

  @override
  String scheduleCourseCount(int count) {
    return '$count 節課';
  }

  @override
  String get classLeadCustomizeTemplates => '自訂課前提醒文案';

  @override
  String get classLeadCustomizeTemplatesSubtitle => '留空使用預設文案';

  @override
  String get classLeadTemplateSheetTitle => '課前提醒文案';

  @override
  String get classLeadTitleLabel => '標題';

  @override
  String get classLeadBodyLabel => '正文';

  @override
  String classLeadTemplatePlaceholderHint(
    String courseToken,
    String roomToken,
    String timeToken,
    String minutesToken,
  ) {
    return '可用 $courseToken、$roomToken、$timeToken、$minutesToken。留空使用預設文案。';
  }

  @override
  String get checkInCustomizeTemplates => '自訂打卡提醒文案';

  @override
  String get checkInCustomizeTemplatesSubtitle => '留空使用預設文案';

  @override
  String get checkInTemplateSheetTitle => '打卡提醒文案';

  @override
  String get checkInTitleLabel => '標題';

  @override
  String get checkInBodyLabel => '正文';

  @override
  String checkInTemplatePlaceholderHint(
    String courseToken,
    String roomToken,
    String timeToken,
  ) {
    return '可用 $courseToken、$roomToken、$timeToken。留空使用預設文案。';
  }

  @override
  String get sessionColor => '課程顏色';

  @override
  String get sessionColorShort => '顏色';

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
  String get fieldFaculty => '學院名稱';

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
  String get countdownSoonLabel => '即將開始';

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
      '提醒透過背景定時提醒觸發，無需保持應用在前台。建議完成以下設定以提高可靠性。';

  @override
  String get androidCheckReminderPermissions => '檢查提醒權限';

  @override
  String get androidPermissionsChecked => '已請求通知與精確鬧鐘權限';

  @override
  String get androidBatteryOptimization => '電池最佳化豁免';

  @override
  String get androidBatteryOptimizationSubtitleOn => '已豁免電池最佳化，背景提醒更可靠';

  @override
  String get androidBatteryOptimizationSubtitleOff => '開啟後可提高背景提醒可靠性';

  @override
  String get androidBatteryOptimizationDisableConfirmTitle => '關閉電池最佳化豁免？';

  @override
  String get androidBatteryOptimizationDisableConfirmContent =>
      '將跳轉到系統設定以恢復電池最佳化，背景提醒可能變得不穩定。';

  @override
  String get androidAutostartHint =>
      'OriginOS / iQOO 請允許自啟動和背景高耗電，並在最近任務中鎖定 Orbit。';

  @override
  String get debugTitle => '偵錯';

  @override
  String get debugSubtitle => '通知與背景提醒診斷工具';

  @override
  String get androidTestImmediateReminder => '立即測試通知';

  @override
  String get androidTestImmediateReminderSubtitle => '立即驗證通知權限和訊息顯示。';

  @override
  String get androidTestImmediateReminderShown => '測試通知已傳送。';

  @override
  String get androidTestBackgroundReminder => '測試背景提醒（1 分鐘）';

  @override
  String get androidTestBackgroundReminderSubtitle =>
      '註冊與課程提醒相同的原生鬧鐘。一分鐘後重新開啟 Orbit，可檢查註冊、接收與通知階段。';

  @override
  String get androidTestBackgroundReminderScheduled =>
      '階段 1 已通過：一分鐘測試鬧鐘已註冊。離開 Orbit 並等待，然後查看提醒診斷記錄。';

  @override
  String androidTestBackgroundReminderScheduledAt(String time) {
    return '階段 1 已通過：Android 已註冊 $time 的鬧鐘。離開 Orbit 並等待，然後查看提醒診斷記錄。';
  }

  @override
  String get androidTestBackgroundNotificationTitle => 'Orbit 背景提醒測試';

  @override
  String get androidTestBackgroundNotificationBody =>
      '背景提醒已成功觸發，Orbit 不在前台時也可以正常傳送提醒。';

  @override
  String get androidTestBackgroundReminderFailed => '無法註冊測試提醒，請檢查精確鬧鐘權限。';

  @override
  String get androidTestReminderNotificationsDenied => '通知權限未開啟，請允許通知後重試。';

  @override
  String get androidTestReminderExactAlarmsDenied => '精確鬧鐘權限未開啟，請允許後重試。';

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
  String get deleteEndedConfirm2Content => '已結束課程將移入回收站並保留 7 天，確定繼續？';

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
  String get confirmClearContent => '所有已匯入的課表資料將移入回收站並保留 7 天。';

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
  String get nextDayRemindWhenNoClass => '無課時也提醒';

  @override
  String get nextDayRemindWhenNoClassSubtitle => '明天沒有課程時仍發送確認通知';

  @override
  String get nextDayCustomizeTemplates => '自訂提醒文案';

  @override
  String get nextDayCustomizeTemplatesSubtitle => '可編輯標題與正文，留空則使用預設';

  @override
  String get nextDayTemplateSheetTitle => '次日提醒文案';

  @override
  String get nextDayWithClassTitleLabel => '有課標題';

  @override
  String get nextDayWithClassBodyLabel => '有課正文';

  @override
  String get nextDayNoClassTitleLabel => '無課標題';

  @override
  String get nextDayNoClassBodyLabel => '無課正文';

  @override
  String nextDayTemplatePlaceholderHint(
    String countToken,
    String timeToken,
    String dateToken,
  ) {
    return '有課正文可用 $countToken、$timeToken、$dateToken；無課正文可用 $dateToken。留空使用預設文案。';
  }

  @override
  String get nextDayTemplateReset => '恢復預設';

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
  String get deleteSession => '刪除課程';

  @override
  String get deleteSessionShort => '刪除';

  @override
  String get courseColorDefault => '預設顏色';

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

  @override
  String get exportScheduleJson => '匯出 JSON 備份';

  @override
  String get exportScheduleJsonSubtitle => '儲存全部課表資料，用於還原或遷移';

  @override
  String get exportScheduleXlsx => '匯出為 xlsx';

  @override
  String get exportScheduleXlsxSubtitle => '以與匯入相同的格式匯出';

  @override
  String get restoreFromBackup => '從備份還原';

  @override
  String get restoreFromBackupSubtitle => '從 JSON 備份檔案匯入課表';

  @override
  String exportDone(int count) {
    return '已匯出 $count 節課';
  }

  @override
  String exportFailed(String error) {
    return '匯出失敗：$error';
  }

  @override
  String get exportNothingToExport => '沒有可匯出的課表資料';

  @override
  String get restoreConfirmTitle => '還原備份？';

  @override
  String restoreConfirmContent(int count) {
    return '將合併備份中的 $count 節課。';
  }

  @override
  String restoreDone(int count) {
    return '已還原 $count 節課';
  }

  @override
  String restoreFailed(String error) {
    return '還原失敗：$error';
  }

  @override
  String get backupInvalidFormat => '備份檔案格式無效';

  @override
  String get backupUnsupportedVersion => '不支援的備份版本';

  @override
  String get addSession => '新增課程';

  @override
  String get addSessionTitle => '新增課程';

  @override
  String get fieldDate => '日期';

  @override
  String get fieldCourseCode => '科目編號';

  @override
  String get fieldSection => '班別';

  @override
  String get defaultClassType => '一般課堂';

  @override
  String get sessionCreated => '已新增課程';

  @override
  String get sessionCreateRequiredFields => '科目名稱和課室為必填項';

  @override
  String get sessionTimeConflict => '該時段已有其他課程';

  @override
  String sessionSavedWithOverride(int count) {
    return '已儲存，並覆蓋了 $count 節時間衝突的課程。';
  }

  @override
  String get importStrategyTitle => '偵測到重複週次';

  @override
  String importStrategyMessage(int count) {
    return '本次匯入有 $count 個週次已存在課程，請選擇匯入方式。';
  }

  @override
  String get importStrategyReplaceWeek => '整週取代';

  @override
  String get importStrategyReplaceWeekDesc => '刪除這些週次原有的全部課程，再匯入新課程。';

  @override
  String get importStrategyMerge => '合併並覆蓋衝突';

  @override
  String get importStrategyMergeDesc => '保留其他課程，僅取代與匯入課程時間重疊的課程。';

  @override
  String get actionCreate => '建立';

  @override
  String sessionSaveFailed(String error) {
    return '儲存失敗：$error';
  }

  @override
  String deleteFailed(String error) {
    return '刪除失敗：$error';
  }

  @override
  String get languageChangedResynced => '語言已更新，提醒已重新同步';

  @override
  String get searchSessions => '搜尋課程';

  @override
  String get searchHint => '按科目、課室或教師搜尋';

  @override
  String get searchNoResults => '沒有符合的課程';

  @override
  String searchFailed(String error) {
    return '搜尋失敗：$error';
  }

  @override
  String searchResultsTruncated(int count) {
    return '僅顯示前 $count 條結果';
  }

  @override
  String gridBatchDeleteFailed(String error) {
    return '批量刪除失敗：$error';
  }

  @override
  String clearAllFailed(String error) {
    return '清除課表失敗：$error';
  }

  @override
  String launchAtStartupFailed(String error) {
    return '更新開機啟動設定失敗：$error';
  }

  @override
  String get sectionSchedule => '課表';

  @override
  String get gridDefaultWeekTitle => '預設週次';

  @override
  String get gridDefaultWeekSubtitle => '開啟課表時顯示的週次';

  @override
  String get gridDefaultWeekSmart => '智能';

  @override
  String get gridDefaultWeekCurrent => '本週';

  @override
  String get gridDefaultWeekEarliest => '最早有課週';

  @override
  String get exportInProgress => '正在匯出…';

  @override
  String get importFormatTitle => '課表檔案格式';

  @override
  String get importFormatSubtitle => 'XLSX / CSV 課程列表與週課表網格';

  @override
  String get importFormatColumn => '欄';

  @override
  String get importFormatField => '欄位';

  @override
  String get importFormatExample => '範例';

  @override
  String get importFormatClassType => '課堂類型';

  @override
  String get importFormatClassTypeExample => '一般課堂';

  @override
  String get importFormatRoom => '課室';

  @override
  String get importFormatRoomExample => 'A001';

  @override
  String get importFormatCapacity => '人數';

  @override
  String get importFormatCapacityExample => '67';

  @override
  String get importFormatFaculty => '學院名稱';

  @override
  String get importFormatFacultyExample => '範例學院';

  @override
  String get importFormatDate => '日期';

  @override
  String get importFormatDateExample => '2026-07-27';

  @override
  String get importFormatWeekday => '星期';

  @override
  String get importFormatWeekdayExample => '1（週一）~ 7（週日）';

  @override
  String get importFormatCourseName => '科目名稱';

  @override
  String get importFormatCourseNameExample => '物理';

  @override
  String get importFormatCourseCode => '科目編號';

  @override
  String get importFormatCourseCodeExample => 'P0721';

  @override
  String get importFormatSection => '班別名稱';

  @override
  String get importFormatSectionExample => 'EX1';

  @override
  String get importFormatStartTime => '開始時間';

  @override
  String get importFormatStartTimeExample => '12:30';

  @override
  String get importFormatEndTime => '結束時間';

  @override
  String get importFormatEndTimeExample => '15:20';

  @override
  String get importFormatTeachers => '教師';

  @override
  String get importFormatTeachersExample => 'Miku,null';

  @override
  String get importFormatSemester => '學期';

  @override
  String get importFormatSemesterExample => '2606';

  @override
  String get xlsxErrorNoSheet => '檔案中找不到工作表';

  @override
  String get xlsxErrorEmptySheet => '課表內容為空';

  @override
  String get xlsxErrorNoSessions => '未解析到任何課程資料';

  @override
  String xlsxErrorInsufficientColumns(String detail) {
    return '資料欄不足（$detail 欄）';
  }

  @override
  String xlsxErrorInvalidDate(String detail) {
    return '無法解析日期：$detail';
  }

  @override
  String xlsxErrorInvalidTime(String detail) {
    return '無法解析時間：$detail';
  }

  @override
  String reminderSyncFailed(String error) {
    return '提醒同步失敗：$error';
  }

  @override
  String get reminderResyncFailedBanner => '提醒未能同步，請點「重新同步提醒」重試。';

  @override
  String get reminderScheduleVerifyFailed =>
      '提醒已儲存，但 Android 未能將其加入待處理佇列。請檢查通知、精確鬧鐘和電池設定後重新同步。';

  @override
  String get reminderScheduleVerifyFailedBanner =>
      'Android 未能將提醒加入待處理佇列。請檢查通知、精確鬧鐘和電池設定後重新同步。';

  @override
  String reminderScheduledCount(int count) {
    return '已排定 $count 則提醒';
  }

  @override
  String reminderRegisteredAlarmCount(int count) {
    return '已註冊 $count 條背景定時提醒';
  }

  @override
  String get androidNotificationsEnabled => '通知已開啟';

  @override
  String get androidNotificationsDisabled => '通知未開啟';

  @override
  String get androidExactAlarmsEnabled => '精確鬧鐘已允許';

  @override
  String get androidExactAlarmsDisabled => '精確鬧鐘未允許';

  @override
  String get actionUndo => '復原';

  @override
  String get trashTitle => '最近刪除';

  @override
  String get trashSubtitle => '刪除的課程將保留 7 天';

  @override
  String get trashEmpty => '沒有最近刪除的課程';

  @override
  String trashDeletedAt(Object time) {
    return '刪除於 $time';
  }

  @override
  String get trashRestoreSelected => '還原所選';

  @override
  String get trashRestoreAll => '全部還原';

  @override
  String get trashEmptyAction => '清空回收站';

  @override
  String get trashEmptyConfirm1Title => '清空回收站？';

  @override
  String get trashEmptyConfirm1Content => '所有最近刪除的課程都將被永久移除。';

  @override
  String get trashEmptyConfirm2Title => '確認永久刪除？';

  @override
  String get trashEmptyConfirm2Content => '此操作無法復原。';

  @override
  String trashRestoreResult(Object restored, Object skipped) {
    return '已還原 $restored 節，略過 $skipped 節衝突課程';
  }

  @override
  String get courseScopeTitle => '套用範圍';

  @override
  String get courseScopeSingle => '僅本節';

  @override
  String get courseScopeFromSelected => '本節及以後';

  @override
  String get courseScopeAll => '全部同課程';

  @override
  String courseOperationSummary(
    Object conflicts,
    Object count,
    Object end,
    Object start,
  ) {
    return '共 $count 節，日期為 $start 至 $end，將覆蓋 $conflicts 節衝突課程。';
  }

  @override
  String courseBatchUpdated(Object count) {
    return '已更新 $count 節課程';
  }

  @override
  String courseBatchDeleted(Object count) {
    return '已刪除 $count 節課程';
  }

  @override
  String get backupIncludesSettings => '包含外觀、課表、提醒和課程顏色設置';

  @override
  String restorePreviewSummary(
    Object count,
    Object end,
    Object start,
    Object version,
  ) {
    return '備份 v$version · $count 節課程 · $start 至 $end';
  }

  @override
  String get restoreCoursesOption => '還原課程';

  @override
  String get restoreSettingsOption => '還原應用設置';

  @override
  String get restoreModeMerge => '合併並覆蓋衝突';

  @override
  String get restoreModeReplace => '取代目前課表';

  @override
  String get restoreNothingSelected => '請選擇要還原的課程或應用設置';

  @override
  String get restoreSettingsDone => '應用設置已還原';

  @override
  String get addSessionChoiceTitle => '添加課程';

  @override
  String get addSingleSession => '添加單節課程';

  @override
  String get addBatchSessions => '批量添加課程';

  @override
  String get batchAddTitle => '批量添加課程';

  @override
  String get batchFirstWeekMonday => '第 1 週週一';

  @override
  String get batchTotalWeeks => '學期總週數';

  @override
  String get batchSelectedWeeks => '上課週次';

  @override
  String get batchMeetings => '每週安排';

  @override
  String get batchAddMeeting => '添加每週安排';

  @override
  String get batchRemoveMeeting => '刪除此安排';

  @override
  String get batchSelectAll => '全選';

  @override
  String get batchSelectOdd => '單週';

  @override
  String get batchSelectEven => '雙週';

  @override
  String get batchClearWeeks => '清空';

  @override
  String batchMeetingTitle(Object index) {
    return '安排 $index';
  }

  @override
  String batchWeekOption(Object week) {
    return '第 $week 週';
  }

  @override
  String get batchRequiredFields => '請填寫課程名稱及每個安排的教室';

  @override
  String get batchNoWeeks => '請至少選擇一個上課週次';

  @override
  String get batchNoMeetings => '請至少添加一個每週安排';

  @override
  String get batchInvalidTime => '每個安排的結束時間必須晚於開始時間';

  @override
  String get batchMeetingOverlap => '同一天的每週安排不能互相重疊';

  @override
  String get batchPreviewTitle => '確認批量添加';

  @override
  String batchPreviewSummary(Object conflicts, Object generated) {
    return '將生成 $generated 節課程，其中 $conflicts 節已有時間衝突。';
  }

  @override
  String get batchSkipConflicts => '跳過衝突';

  @override
  String get batchOverwriteConflicts => '覆蓋衝突';

  @override
  String batchCreateResult(Object created, Object overwritten, Object skipped) {
    return '已添加 $created 節，跳過 $skipped 節，覆蓋 $overwritten 節衝突課程';
  }

  @override
  String get courseScopeMeetingFromSelected => '此安排從本節起';

  @override
  String get courseScopeMeetingAll => '此安排的全部週次';

  @override
  String get courseScopeCourseCommon => '整門課程的公共信息';

  @override
  String get backToTop => '返回頂部';

  @override
  String get scheduleVerticalScaleTitle => '課表縱向高度縮放';

  @override
  String get scheduleVerticalScaleSubtitle =>
      '調低可壓縮課表高度，顯示更多課程。與顯示密度組合生效；短課程或較大字體可能限制壓縮程度，以保留課程名和時間刻度的可讀性。';

  @override
  String get scheduleVerticalScaleReset => '恢復預設';

  @override
  String get customReminders => '提醒时间自定义';

  @override
  String get customRemindersSubtitle => '按课程设置独立时间、筛选、文案和重复发送';

  @override
  String get reminderStrong => '强提醒';

  @override
  String get reminderStrongConfig => '强提醒配置';

  @override
  String get reminderStrongDescription => '循环声音提醒；遵循系统音量、勿扰和通知权限';

  @override
  String get reminderCatchUp => '补发';

  @override
  String get reminderCatchUpNotice => '此消息为补发，非实时提醒';

  @override
  String get reminderOriginalTime => '原计划时间';

  @override
  String get reminderDeliveredTime => '补发时间';

  @override
  String get reminderAcknowledge => '已知晓';

  @override
  String get reminderStop => '停止';

  @override
  String get reminderAdd => '添加规则';

  @override
  String get reminderEdit => '编辑规则';

  @override
  String get reminderCopy => '复制';

  @override
  String get reminderDelete => '删除';

  @override
  String get reminderSave => '保存';

  @override
  String get reminderDiscard => '放弃未保存的更改？';

  @override
  String get reminderKeepEditing => '继续编辑';

  @override
  String get reminderName => '规则名称';

  @override
  String get reminderBasis => '时间基准';

  @override
  String get reminderStart => '课程开始';

  @override
  String get reminderEnd => '课程结束';

  @override
  String get reminderDate => '课程日期的固定时刻';

  @override
  String get reminderBefore => '提前';

  @override
  String get reminderAfter => '延后';

  @override
  String get reminderDays => '天';

  @override
  String get reminderHours => '小时';

  @override
  String get reminderMinutes => '分钟';

  @override
  String get reminderSeconds => '秒';

  @override
  String get reminderScope => '课程范围';

  @override
  String get reminderAll => '全部课程';

  @override
  String get reminderSeries => '课程系列';

  @override
  String get reminderSessions => '单节课程';

  @override
  String get reminderWeekdays => '星期筛选';

  @override
  String get reminderTypes => '课程类型筛选';

  @override
  String get reminderDateRange => '课程日期范围';

  @override
  String get reminderClearFilter => '清除日期筛选';

  @override
  String get reminderTitle => '通知标题';

  @override
  String get reminderBody => '通知正文';

  @override
  String get reminderCount => '发送次数（1–100，包含首次）';

  @override
  String get reminderInterval => '重复间隔（秒，至少 1）';

  @override
  String get reminderUntilAck => '确认后停止，最多发送指定次数';

  @override
  String get reminderInherit => '继承全局设置';

  @override
  String get reminderNormal => '普通提醒';

  @override
  String get reminderPreview => '匹配课程与发送预览';

  @override
  String get reminderTimingNotice => '秒级时间为计划时间，系统可能延迟发送。新建或重新启用后只安排未来发送。';

  @override
  String get reminderInvalid => '请检查数字范围、必填名称及无效占位符';

  @override
  String get reminderSound => '声音';

  @override
  String get reminderVibration => '震动';

  @override
  String get reminderDuration => '持续时间（5–300 秒）';

  @override
  String get reminderSystemSound => '选择系统铃声';

  @override
  String get reminderImportSound => '导入音频（MP3／M4A／WAV，最多 5 MiB）';

  @override
  String get reminderPreviewSound => '试听 / 停止';

  @override
  String get reminderOverride => '单独配置强提醒';

  @override
  String get reminderEmpty => '尚无自定义提醒规则';

  @override
  String get reminderSoundFallback => '缺失或不支持的声音已回退到系统默认音。';

  @override
  String get reminderMaintenanceFailed => '后台维护注册失败，完全退出后的后续排程可能无法补充。请重试。';

  @override
  String get reminderStrongDegraded => '强提醒无法播放，已保留普通通知。请检查系统限制和声音配置。';

  @override
  String get reminderVariableLabels =>
      '课程名|教室|课程日期|星期|开始时间|结束时间|教师|课程代码|发送序号|总次数|计划发送时间';

  @override
  String get reminderWeekdayNames => '星期一|星期二|星期三|星期四|星期五|星期六|星期日';

  @override
  String get reminderDiscardAction => '放弃更改';

  @override
  String get reminderAudioInvalid => '音频不可播放，或文件格式、大小不符合要求。';

  @override
  String get reminderDateOffset => '課程日期偏移';

  @override
  String get reminderSameDay => '課程當天';

  @override
  String get reminderFixedTime => '固定時刻（時／分／秒）';

  @override
  String get reminderFilterWeekdays => '週一|週二|週三|週四|週五|週六|週日';

  @override
  String get reminderPreviousDay => '前一天';

  @override
  String get reminderNextDay => '後一天';

  @override
  String get scheduleFitPage => '自適應頁面';

  @override
  String get scheduleFitPageHint => '完整顯示 08:00–22:00；空間不足時省略課程文字，點擊查看詳情。';

  @override
  String get themeMulticolor => '多色配色';

  @override
  String get themeMulticolorOff => '原有配色';

  @override
  String get themeSchemeNames => '鮮明|富表現力|彩虹|果沙|內容|忠實|中性|黑白';

  @override
  String get templateLeadMinutes => '提前分鐘';

  @override
  String get templateCourseCount => '課程數量';

  @override
  String get palettePrimary => '主色';

  @override
  String get paletteSecondary => '輔色';

  @override
  String get paletteTertiary => '第三色';

  @override
  String get paletteColors => '課程調色盤';

  @override
  String get paletteCustom => '自訂搭配';

  @override
  String get paletteDuplicate => '調色盤已包含此顏色';

  @override
  String get paletteUsePrimary => '設為主色';

  @override
  String get paletteUseSecondary => '設為輔色';

  @override
  String get paletteUseTertiary => '設為第三色';

  @override
  String get paletteMoveEarlier => '前移';

  @override
  String get paletteMoveLater => '後移';

  @override
  String get paletteReset => '恢復多色配色預設設定？';

  @override
  String get palettePreview => '效果預覽';

  @override
  String get paletteSingle => '單色';

  @override
  String get paletteMode => '介面配色';

  @override
  String get paletteAutomatic => '依方案自動產生';

  @override
  String get notificationWarning => '未開啟通知權限，無法接收提醒。';

  @override
  String get notificationOpen => '去開啟';

  @override
  String get notificationIgnore => '忽略且不再提示';

  @override
  String get notificationIgnoreTitle => '忽略通知權限警告？';

  @override
  String get notificationIgnoreBody => '未開啟通知權限，提醒功能將不會生效。你可以在設定中恢復此警告。';

  @override
  String get notificationIgnoreConfirm => '確認忽略';

  @override
  String get notificationRestore => '顯示權限警告';

  @override
  String get notificationRestoreDescription => '在本裝置未開啟通知權限時提示';

  @override
  String get notificationCheckFailed => '無法查詢通知權限';

  @override
  String get notificationAllowed => '通知權限已開啟';

  @override
  String get notificationPermissions => '通知權限';

  @override
  String get strongTargets => '強提醒適用範圍';

  @override
  String get strongClassLead => '課前提醒';

  @override
  String get strongCheckIn => '簽到提醒';

  @override
  String get strongSummary => '次日彙總';

  @override
  String get strongCustom => '自訂規則';

  @override
  String get strongCourses => '課程範圍';

  @override
  String get strongAllRules => '所有繼承規則，包括之後新增的規則';

  @override
  String get strongRuleOverrideNotice => '規則明確設定為強提醒或普通提醒時，優先於此處的範圍設定。';

  @override
  String get strongSummaryNotice => '限定課程範圍時，彙總包含任一選中課程才使用強提醒。';

  @override
  String get settingsNavigationGroup => '日期導覽';

  @override
  String get settingsLayoutGroup => '課表版面';

  @override
  String get settingsMaintenanceGroup => '權限與維護';

  @override
  String get settingsDangerGroup => '資料刪除';

  @override
  String get settingsDiagnosticsGroup => '診斷';

  @override
  String get settingsBackupGroup => '備份與匯出';

  @override
  String get paletteEdit => '編輯顏色';

  @override
  String get paletteHint => '點擊顏色選擇操作，長按刪除。';

  @override
  String get actionConfirm => '確認';

  @override
  String get paletteTonalSpot => '柔和';

  @override
  String get paletteHue => '色相';

  @override
  String get paletteChroma => '鮮豔度';

  @override
  String get paletteTone => '明度';

  @override
  String get paletteScheme => '配色方案';

  @override
  String get paletteSchemeDescriptions =>
      '柔和协调的三色|鲜明且有对比的三色|旋转色相的表现力三色|均衡分布的三色色谱|清新的相邻色搭配|保留种子特色的柔和对比|保留种子特色的互补对比|低饱和，颜色区别较轻|灰阶，不使用色相对比';

  @override
  String get androidEnhancedReminder => '增強提醒模式';

  @override
  String get androidEnhancedReminderSubtitle =>
      '存在未來提醒時顯示一則安靜的常駐通知，提高部分手機上的提醒可靠性。';

  @override
  String get androidEnhancedReminderLimit =>
      '真正的強制停止仍會阻止 Android 傳送鬧鐘，直至再次開啟 Orbit。';

  @override
  String get androidEnhancedReminderChannel => '提醒可靠性';

  @override
  String get androidEnhancedReminderNotificationTitle => '增強提醒已開啟';

  @override
  String get androidEnhancedReminderNotificationBody => 'Orbit 正在保護之後的課程提醒。';

  @override
  String get androidEnhancedReminderDisable => '關閉';

  @override
  String get androidOriginOsSettings => 'OriginOS 背景設定';

  @override
  String get androidOriginOsSettingsSubtitle =>
      '請開啟自動啟動和背景高耗電、取消電池限制，並在最近任務中鎖定 Orbit。';

  @override
  String get androidOpenAutostartSettings => '開啟設定';

  @override
  String get androidForcedStopDetected => 'Orbit 曾被強制停止';

  @override
  String get androidForcedStopDetectedSubtitle =>
      '最近任務清理器停止了 Orbit 並取消了鬧鐘。請完成下方 OriginOS 設定後重新執行一分鐘測試。';

  @override
  String get androidReminderReliability => '提醒註冊狀態';

  @override
  String androidReminderReliabilityStatus(int registered, int stored) {
    return '$stored 個未來提醒中有 $registered 個已註冊到 Android。';
  }

  @override
  String get androidReminderDiagnostics => '提醒診斷記錄';

  @override
  String get androidReminderDiagnosticsEmpty => '尚未記錄原生提醒事件。';
}

/// The translations for Chinese, using the Han script (`zh_Hans`).
class AppLocalizationsZhHans extends AppLocalizationsZh {
  AppLocalizationsZhHans() : super('zh_Hans');

  @override
  String get importAuto => '自动识别';

  @override
  String get importTemplates => '识别模板';

  @override
  String get importPlans => '学期与作息';

  @override
  String get importListLayout => '课程列表';

  @override
  String get importGridLayout => '周课表网格';

  @override
  String get importLegacyLayout => 'Orbit 13 列格式';

  @override
  String get importTemplateName => '模板名称';

  @override
  String get importBuiltIn => '内置模板 · 复制后编辑';

  @override
  String get importCopy => '复制';

  @override
  String get importShareTemplate => '导出模板 JSON';

  @override
  String get importLoadTemplate => '导入模板 JSON';

  @override
  String get importLayoutStep => '布局与区域';

  @override
  String get importFieldsStep => '字段映射';

  @override
  String get importRegexStep => '提取规则';

  @override
  String get importTestStep => '测试与预览';

  @override
  String get importHeaderRow => '表头行（从 1 开始）';

  @override
  String get importFirstRow => '课程起始行';

  @override
  String get importLastRow => '课程结束行（留空至表末）';

  @override
  String get importFirstColumn => '课程起始列（从 1 开始）';

  @override
  String get importLastColumn => '课程结束列';

  @override
  String get importWeekdayColumns => '列:星期，例如 2:1,3:2';

  @override
  String get importPeriodRows => '行:节次，例如 2:1-2;3:3-4';

  @override
  String get importColumnSource => '指定列';

  @override
  String get importTextSource => '课程块文字';

  @override
  String get importFixedSource => '固定值';

  @override
  String get importWeekdaySource => '网格星期';

  @override
  String get importPeriodsSource => '网格节次';

  @override
  String get importColumnNumber => '列号（从 1 开始）';

  @override
  String get importFixedValue => '固定值';

  @override
  String get importPattern => '正则表达式（留空使用原文）';

  @override
  String get importCaptureGroup => '捕获组编号或名称';

  @override
  String get importCaseSensitive => '区分大小写';

  @override
  String get importMultiLine => '多行锚点';

  @override
  String get importDotAll => '点号匹配换行';

  @override
  String get importUnicode => 'Unicode 模式';

  @override
  String get importBlockPattern => '课程块分隔／匹配正则';

  @override
  String get importRepeatBlocks => '重复匹配课程块';

  @override
  String get importTestText => '示例课程文字';

  @override
  String get importRunTest => '运行测试';

  @override
  String get importOriginal => '原文';

  @override
  String get importMatches => '匹配与捕获组';

  @override
  String get importExtracted => '提取字段';

  @override
  String get importSave => '保存';

  @override
  String get importNext => '下一步';

  @override
  String get importBack => '上一步';

  @override
  String get importSemesterName => '学期名称';

  @override
  String get importFirstMonday => '第一周周一（YYYY-MM-DD）';

  @override
  String get importTotalWeeks => '总周数（1–30）';

  @override
  String get importPeriodPlanName => '作息方案名称';

  @override
  String get importPeriodTimeInput => '节次,开始,结束，每行一节，例如 1,08:00,08:45';

  @override
  String get importDefaultWeeks => '文件缺少周次时适用的周次（如 1-18）';

  @override
  String get importConfirmContext => '确认本次导入的学期、周次与作息';

  @override
  String get importTemporaryContext => '临时调整仅用于本次导入；保存方案请进入方案管理。';

  @override
  String get importEncoding => 'CSV 编码';

  @override
  String get importDelimiter => 'CSV 分隔符';

  @override
  String get importComma => '逗号';

  @override
  String get importSemicolon => '分号';

  @override
  String get importTab => '制表符';

  @override
  String get importPreview => '解析与预览';

  @override
  String get importSkipErrors => '明确跳过识别失败的课程';

  @override
  String get importSkipDescription => '失败的课程不会导入，请先检查每条错误。';

  @override
  String get importCancelTask => '取消解析';

  @override
  String get importSelectSheet => '选择要导入的工作表';

  @override
  String get importRawTable => '原表预览 — 点击单元格选择坐标';

  @override
  String get importChooseCoordinate => '将所选单元格设为';

  @override
  String get importNoSelection => '尚未选择工作表';

  @override
  String get importNone => '不使用';

  @override
  String get importValid => '有效';

  @override
  String get importDuplicates => '重复';

  @override
  String get importErrors => '失败';

  @override
  String get importDeleteConfirm => '删除此已保存的模板或方案？';

  @override
  String get importHelp =>
      '列表需课程名、日期（或星期和周次）及起止时间（或节次）。网格以星期为列、节次为行；同格多课可用空行分隔或配置课程块规则。按周课表需确认学期和作息。';

  @override
  String get importFieldCourseName => '课程名';

  @override
  String get importFieldCourseCode => '课程编号';

  @override
  String get importFieldSection => '班别';

  @override
  String get importFieldRoom => '教室';

  @override
  String get importFieldTeachers => '教师';

  @override
  String get importFieldFaculty => '学院';

  @override
  String get importFieldClassType => '课堂类型';

  @override
  String get importFieldSemester => '学期';

  @override
  String get importFieldDate => '日期';

  @override
  String get importFieldWeekday => '星期';

  @override
  String get importFieldWeeks => '周次';

  @override
  String get importFieldPeriods => '节次';

  @override
  String get importFieldStartTime => '开始时间';

  @override
  String get importFieldEndTime => '结束时间';

  @override
  String get importErrorAmbiguous => '有多个候选模板，请明确选择。';

  @override
  String get importErrorTemplateInvalid => '模板或区域配置无效。';

  @override
  String get importErrorTemplateVersion => '不支持此模板版本。';

  @override
  String get importErrorCaptureGroup => '捕获组编号或名称无效。';

  @override
  String get importErrorMissingName => '缺少课程名。';

  @override
  String get importErrorSemesterInvalid => '请检查学期名称、周一日期和总周数。';

  @override
  String get importErrorPeriodInvalid => '节次或作息方案无效。';

  @override
  String get importErrorInvalidTime => '时间无效，结束时间必须晚于开始。';

  @override
  String get importErrorInvalidDate => '日期无效。';

  @override
  String get importErrorInvalidWeekday => '星期必须为周一至周日。';

  @override
  String get importErrorWeekdayMismatch => '星期与日期不一致。';

  @override
  String get importErrorInvalidWeeks => '周次无效或超出学期范围。';

  @override
  String get importErrorWeeksRequired => '文件缺少周次，请确认适用周次。';

  @override
  String get importErrorContextRequired => '请确认学期与所需作息方案。';

  @override
  String get importErrorUnknownPeriod => '部分节次没有对应时间。';

  @override
  String get importErrorHorizontalMerge => '不支持跨多个星期列合并的课程格。';

  @override
  String get importErrorZeroLength => '课程块规则不能匹配空文字。';

  @override
  String get importErrorNoMatch => '未匹配到课程块。';

  @override
  String get importErrorUnmatchedText => '课程块规则遗漏了部分文字，请修正规则。';

  @override
  String get importErrorIdConflict => '相同课次编号对应不同内容，请修正或明确跳过。';

  @override
  String get importErrorNoSessions => '没有识别到有效课程。';

  @override
  String get importErrorNoSheet => '文件没有工作表。';

  @override
  String get importErrorUnsupportedFile => '仅支持 XLSX 和 CSV 文件。';

  @override
  String get importErrorEncodingFailed => 'CSV 解码失败，请切换编码或转换文件。';

  @override
  String get importErrorTimeout => '解析超时，配置已保留。';

  @override
  String get importErrorCancelled => '解析已取消。';

  @override
  String get importErrorWorkerFailed => '解析任务失败，请重试。';

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
  String get gridBatchDeleteConfirm2Content => '所选课程将移入回收站并保留 7 天，确定继续？';

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
  String get gridNoSessionsThisWeekSubtitle => '切换到其他周查看课程';

  @override
  String get actionRetry => '重试';

  @override
  String get importViewGrid => '查看课表';

  @override
  String resyncPartialFailed(int count) {
    return '$count 条提醒未能排定';
  }

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
  String get gridEmptySubtitle => '请前往「导入」页面选择 XLSX 或 CSV 课表文件';

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
  String upcomingWeekMonday(String date) {
    return '$date';
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
  String get importPickTitle => '选择 XLSX / CSV 课表文件';

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
  String get settingsCategoryGeneral => '常规';

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
  String get themeStyleTitle => '课程配色';

  @override
  String get themeStyleSubtitle => '使用统一强调色或为不同课程自动配色';

  @override
  String get themeStyleStandard => '统一颜色';

  @override
  String get themeStyleColorful => '自动分色';

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
  String get themeModeTitle => '深浅色模式';

  @override
  String get themeModeSubtitle => '选择浅色、深色或跟随系统';

  @override
  String get themeModeSystem => '跟随系统';

  @override
  String get themeModeLight => '浅色';

  @override
  String get themeModeDark => '深色';

  @override
  String get weekStartDayTitle => '周起始日';

  @override
  String get weekStartDaySubtitle => '课表每周从哪一天开始显示';

  @override
  String get weekStartMonday => '周一';

  @override
  String get weekStartSunday => '周日';

  @override
  String get gridDensityTitle => '课表显示密度';

  @override
  String get gridDensitySubtitle => '调整课表行高与字体大小';

  @override
  String get gridDensityCompact => '紧凑';

  @override
  String get gridDensityStandard => '标准';

  @override
  String get gridDensityComfortable => '宽松';

  @override
  String get scheduleNarrowLayoutTitle => '窄屏课表布局';

  @override
  String get scheduleNarrowLayoutSubtitle => '选择一屏整周或经典单日/多日自适应布局';

  @override
  String get scheduleNarrowLayoutCompactWeek => '紧凑整周';

  @override
  String get scheduleNarrowLayoutAdaptive => '经典自适应';

  @override
  String get scheduleMultiDayCountTitle => '多日模式显示天数';

  @override
  String scheduleMultiDayCountSubtitle(int maxCount) {
    return '当前窗口最多可清晰显示 $maxCount 天';
  }

  @override
  String scheduleDayCountOption(int count) {
    return '$count 天';
  }

  @override
  String get scheduleShowEmptyDaysTitle => '显示无课程日期';

  @override
  String get scheduleShowEmptyDaysSubtitle => '仅用于经典自适应布局；关闭后将在有课程的日期之间切换';

  @override
  String get upcomingShowCourseDateTitle => '在倒计时旁显示日期';

  @override
  String get upcomingShowCourseDateSubtitle => '在接下来课程列表中显示课程日期';

  @override
  String get upcomingDateDisplayTitle => '课程日期格式';

  @override
  String get upcomingDateDisplaySubtitle => '选择要显示的日期信息';

  @override
  String get upcomingDateDisplayDateAndWeekday => '日期 + 星期';

  @override
  String get upcomingDateDisplayDateOnly => '仅日期';

  @override
  String get upcomingDateDisplayWeekdayOnly => '仅星期';

  @override
  String get scheduleJumpToNearestCourse => '跳到最近课程';

  @override
  String scheduleCourseCount(int count) {
    return '$count 节课';
  }

  @override
  String get classLeadCustomizeTemplates => '自定义课前提醒文案';

  @override
  String get classLeadCustomizeTemplatesSubtitle => '留空使用默认文案';

  @override
  String get classLeadTemplateSheetTitle => '课前提醒文案';

  @override
  String get classLeadTitleLabel => '标题';

  @override
  String get classLeadBodyLabel => '正文';

  @override
  String classLeadTemplatePlaceholderHint(
    String courseToken,
    String roomToken,
    String timeToken,
    String minutesToken,
  ) {
    return '可用 $courseToken、$roomToken、$timeToken、$minutesToken。留空使用默认文案。';
  }

  @override
  String get checkInCustomizeTemplates => '自定义打卡提醒文案';

  @override
  String get checkInCustomizeTemplatesSubtitle => '留空使用默认文案';

  @override
  String get checkInTemplateSheetTitle => '打卡提醒文案';

  @override
  String get checkInTitleLabel => '标题';

  @override
  String get checkInBodyLabel => '正文';

  @override
  String checkInTemplatePlaceholderHint(
    String courseToken,
    String roomToken,
    String timeToken,
  ) {
    return '可用 $courseToken、$roomToken、$timeToken。留空使用默认文案。';
  }

  @override
  String get sessionColor => '课程颜色';

  @override
  String get sessionColorShort => '颜色';

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
  String get fieldFaculty => '学院名称';

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
  String get countdownSoonLabel => '即将开始';

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
      '提醒通过后台定时提醒触发，无需保持应用在前台。建议完成以下设置以提高可靠性。';

  @override
  String get androidCheckReminderPermissions => '检查提醒权限';

  @override
  String get androidPermissionsChecked => '已请求通知与精确闹钟权限';

  @override
  String get androidBatteryOptimization => '电池优化豁免';

  @override
  String get androidBatteryOptimizationSubtitleOn => '已豁免电池优化，后台提醒更可靠';

  @override
  String get androidBatteryOptimizationSubtitleOff => '开启后可提高后台提醒可靠性';

  @override
  String get androidBatteryOptimizationDisableConfirmTitle => '关闭电池优化豁免？';

  @override
  String get androidBatteryOptimizationDisableConfirmContent =>
      '将跳转到系统设置以恢复电池优化，后台提醒可能变得不稳定。';

  @override
  String get androidAutostartHint =>
      'OriginOS / iQOO 请允许自启动和后台高耗电，并在最近任务中锁定 Orbit。';

  @override
  String get debugTitle => '调试';

  @override
  String get debugSubtitle => '通知与后台提醒诊断工具';

  @override
  String get androidTestImmediateReminder => '立即测试通知';

  @override
  String get androidTestImmediateReminderSubtitle => '立即验证通知权限和消息显示。';

  @override
  String get androidTestImmediateReminderShown => '测试通知已发送。';

  @override
  String get androidTestBackgroundReminder => '测试后台提醒（1 分钟）';

  @override
  String get androidTestBackgroundReminderSubtitle =>
      '注册与课程提醒相同的原生闹钟。一分钟后重新打开 Orbit，可检查注册、接收与通知阶段。';

  @override
  String get androidTestBackgroundReminderScheduled =>
      '阶段 1 已通过：一分钟测试闹钟已注册。离开 Orbit 并等待，然后查看提醒诊断记录。';

  @override
  String androidTestBackgroundReminderScheduledAt(String time) {
    return '阶段 1 已通过：Android 已注册 $time 的闹钟。离开 Orbit 并等待，然后查看提醒诊断记录。';
  }

  @override
  String get androidTestBackgroundNotificationTitle => 'Orbit 后台提醒测试';

  @override
  String get androidTestBackgroundNotificationBody =>
      '后台提醒已成功触发，Orbit 不在前台时也可以正常发送提醒。';

  @override
  String get androidTestBackgroundReminderFailed => '无法注册测试提醒，请检查精确闹钟权限。';

  @override
  String get androidTestReminderNotificationsDenied => '通知权限未开启，请允许通知后重试。';

  @override
  String get androidTestReminderExactAlarmsDenied => '精确闹钟权限未开启，请允许后重试。';

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
  String get deleteEndedConfirm2Content => '已结束课程将移入回收站并保留 7 天，确定继续？';

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
  String get confirmClearContent => '所有已导入的课表数据将移入回收站并保留 7 天。';

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
  String get nextDayRemindWhenNoClass => '无课时也提醒';

  @override
  String get nextDayRemindWhenNoClassSubtitle => '明天没有课程时仍发送确认通知';

  @override
  String get nextDayCustomizeTemplates => '自定义提醒文案';

  @override
  String get nextDayCustomizeTemplatesSubtitle => '可编辑标题与正文，留空则使用默认';

  @override
  String get nextDayTemplateSheetTitle => '次日提醒文案';

  @override
  String get nextDayWithClassTitleLabel => '有课标题';

  @override
  String get nextDayWithClassBodyLabel => '有课正文';

  @override
  String get nextDayNoClassTitleLabel => '无课标题';

  @override
  String get nextDayNoClassBodyLabel => '无课正文';

  @override
  String nextDayTemplatePlaceholderHint(
    String countToken,
    String timeToken,
    String dateToken,
  ) {
    return '有课正文可用 $countToken、$timeToken、$dateToken；无课正文可用 $dateToken。留空使用默认文案。';
  }

  @override
  String get nextDayTemplateReset => '恢复默认';

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
  String get deleteSession => '删除课程';

  @override
  String get deleteSessionShort => '删除';

  @override
  String get courseColorDefault => '默认颜色';

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

  @override
  String get exportScheduleJson => '导出 JSON 备份';

  @override
  String get exportScheduleJsonSubtitle => '保存全部课表数据，用于恢复或迁移';

  @override
  String get exportScheduleXlsx => '导出为 xlsx';

  @override
  String get exportScheduleXlsxSubtitle => '以与导入相同的格式导出';

  @override
  String get restoreFromBackup => '从备份恢复';

  @override
  String get restoreFromBackupSubtitle => '从 JSON 备份文件导入课表';

  @override
  String exportDone(int count) {
    return '已导出 $count 节课';
  }

  @override
  String exportFailed(String error) {
    return '导出失败：$error';
  }

  @override
  String get exportNothingToExport => '没有可导出的课表数据';

  @override
  String get restoreConfirmTitle => '恢复备份？';

  @override
  String restoreConfirmContent(int count) {
    return '将合并备份中的 $count 节课。';
  }

  @override
  String restoreDone(int count) {
    return '已恢复 $count 节课';
  }

  @override
  String restoreFailed(String error) {
    return '恢复失败：$error';
  }

  @override
  String get backupInvalidFormat => '备份文件格式无效';

  @override
  String get backupUnsupportedVersion => '不支持的备份版本';

  @override
  String get addSession => '添加课程';

  @override
  String get addSessionTitle => '添加课程';

  @override
  String get fieldDate => '日期';

  @override
  String get fieldCourseCode => '科目编号';

  @override
  String get fieldSection => '班别';

  @override
  String get defaultClassType => '一般课堂';

  @override
  String get sessionCreated => '已添加课程';

  @override
  String get sessionCreateRequiredFields => '科目名称和课室为必填项';

  @override
  String get sessionTimeConflict => '该时段已有其他课程';

  @override
  String sessionSavedWithOverride(int count) {
    return '已保存，并覆盖了 $count 节时间冲突的课程。';
  }

  @override
  String get importStrategyTitle => '检测到重复周次';

  @override
  String importStrategyMessage(int count) {
    return '本次导入有 $count 个周次已存在课程，请选择导入方式。';
  }

  @override
  String get importStrategyReplaceWeek => '整周替换';

  @override
  String get importStrategyReplaceWeekDesc => '删除这些周次原有的全部课程，再导入新课程。';

  @override
  String get importStrategyMerge => '合并并覆盖冲突';

  @override
  String get importStrategyMergeDesc => '保留其他课程，仅替换与导入课程时间重叠的课程。';

  @override
  String get actionCreate => '创建';

  @override
  String sessionSaveFailed(String error) {
    return '保存失败：$error';
  }

  @override
  String deleteFailed(String error) {
    return '删除失败：$error';
  }

  @override
  String get languageChangedResynced => '语言已更新，提醒已重新同步';

  @override
  String get searchSessions => '搜索课程';

  @override
  String get searchHint => '按科目、课室或教师搜索';

  @override
  String get searchNoResults => '没有匹配的课程';

  @override
  String searchFailed(String error) {
    return '搜索失败：$error';
  }

  @override
  String searchResultsTruncated(int count) {
    return '仅显示前 $count 条结果';
  }

  @override
  String gridBatchDeleteFailed(String error) {
    return '批量删除失败：$error';
  }

  @override
  String clearAllFailed(String error) {
    return '清除课表失败：$error';
  }

  @override
  String launchAtStartupFailed(String error) {
    return '更新开机启动设置失败：$error';
  }

  @override
  String get sectionSchedule => '课表';

  @override
  String get gridDefaultWeekTitle => '默认周次';

  @override
  String get gridDefaultWeekSubtitle => '打开课表时显示的周次';

  @override
  String get gridDefaultWeekSmart => '智能';

  @override
  String get gridDefaultWeekCurrent => '本周';

  @override
  String get gridDefaultWeekEarliest => '最早有课周';

  @override
  String get exportInProgress => '正在导出…';

  @override
  String get importFormatTitle => '课表文件格式';

  @override
  String get importFormatSubtitle => 'XLSX / CSV 课程列表与周课表网格';

  @override
  String get importFormatColumn => '列';

  @override
  String get importFormatField => '字段';

  @override
  String get importFormatExample => '示例';

  @override
  String get importFormatClassType => '课堂类型';

  @override
  String get importFormatClassTypeExample => '一般课堂';

  @override
  String get importFormatRoom => '课室';

  @override
  String get importFormatRoomExample => 'A001';

  @override
  String get importFormatCapacity => '人数';

  @override
  String get importFormatCapacityExample => '67';

  @override
  String get importFormatFaculty => '学院名称';

  @override
  String get importFormatFacultyExample => '示例学院';

  @override
  String get importFormatDate => '日期';

  @override
  String get importFormatDateExample => '2026-07-27';

  @override
  String get importFormatWeekday => '星期';

  @override
  String get importFormatWeekdayExample => '1（周一）~ 7（周日）';

  @override
  String get importFormatCourseName => '科目名称';

  @override
  String get importFormatCourseNameExample => '物理';

  @override
  String get importFormatCourseCode => '科目编号';

  @override
  String get importFormatCourseCodeExample => 'P0721';

  @override
  String get importFormatSection => '班别名称';

  @override
  String get importFormatSectionExample => 'EX1';

  @override
  String get importFormatStartTime => '开始时间';

  @override
  String get importFormatStartTimeExample => '12:30';

  @override
  String get importFormatEndTime => '结束时间';

  @override
  String get importFormatEndTimeExample => '15:20';

  @override
  String get importFormatTeachers => '教师';

  @override
  String get importFormatTeachersExample => 'Miku,null';

  @override
  String get importFormatSemester => '学期';

  @override
  String get importFormatSemesterExample => '2606';

  @override
  String get xlsxErrorNoSheet => '文件中找不到工作表';

  @override
  String get xlsxErrorEmptySheet => '课表内容为空';

  @override
  String get xlsxErrorNoSessions => '未解析到任何课程数据';

  @override
  String xlsxErrorInsufficientColumns(String detail) {
    return '数据列不足（$detail 列）';
  }

  @override
  String xlsxErrorInvalidDate(String detail) {
    return '无法解析日期：$detail';
  }

  @override
  String xlsxErrorInvalidTime(String detail) {
    return '无法解析时间：$detail';
  }

  @override
  String reminderSyncFailed(String error) {
    return '提醒同步失败：$error';
  }

  @override
  String get reminderResyncFailedBanner => '提醒未能同步，请点「重新同步提醒」重试。';

  @override
  String get reminderScheduleVerifyFailed =>
      '提醒已保存，但 Android 未能将其加入待处理队列。请检查通知、精确闹钟和电池设置后重新同步。';

  @override
  String get reminderScheduleVerifyFailedBanner =>
      'Android 未能将提醒加入待处理队列。请检查通知、精确闹钟和电池设置后重新同步。';

  @override
  String reminderScheduledCount(int count) {
    return '已排定 $count 条提醒';
  }

  @override
  String reminderRegisteredAlarmCount(int count) {
    return '已注册 $count 条后台定时提醒';
  }

  @override
  String get androidNotificationsEnabled => '通知已开启';

  @override
  String get androidNotificationsDisabled => '通知未开启';

  @override
  String get androidExactAlarmsEnabled => '精确闹钟已允许';

  @override
  String get androidExactAlarmsDisabled => '精确闹钟未允许';

  @override
  String get actionUndo => '撤销';

  @override
  String get trashTitle => '最近删除';

  @override
  String get trashSubtitle => '删除的课程将保留 7 天';

  @override
  String get trashEmpty => '没有最近删除的课程';

  @override
  String trashDeletedAt(Object time) {
    return '删除于 $time';
  }

  @override
  String get trashRestoreSelected => '恢复所选';

  @override
  String get trashRestoreAll => '全部恢复';

  @override
  String get trashEmptyAction => '清空回收站';

  @override
  String get trashEmptyConfirm1Title => '清空回收站？';

  @override
  String get trashEmptyConfirm1Content => '所有最近删除的课程都将被永久移除。';

  @override
  String get trashEmptyConfirm2Title => '确认永久删除？';

  @override
  String get trashEmptyConfirm2Content => '此操作无法撤销。';

  @override
  String trashRestoreResult(Object restored, Object skipped) {
    return '已恢复 $restored 节，跳过 $skipped 节冲突课程';
  }

  @override
  String get courseScopeTitle => '应用范围';

  @override
  String get courseScopeSingle => '仅本节';

  @override
  String get courseScopeFromSelected => '本节及以后';

  @override
  String get courseScopeAll => '全部同课程';

  @override
  String courseOperationSummary(
    Object conflicts,
    Object count,
    Object end,
    Object start,
  ) {
    return '共 $count 节，日期为 $start 至 $end，将覆盖 $conflicts 节冲突课程。';
  }

  @override
  String courseBatchUpdated(Object count) {
    return '已更新 $count 节课程';
  }

  @override
  String courseBatchDeleted(Object count) {
    return '已删除 $count 节课程';
  }

  @override
  String get backupIncludesSettings => '包含外观、课表、提醒和课程颜色设置';

  @override
  String restorePreviewSummary(
    Object count,
    Object end,
    Object start,
    Object version,
  ) {
    return '备份 v$version · $count 节课程 · $start 至 $end';
  }

  @override
  String get restoreCoursesOption => '恢复课程';

  @override
  String get restoreSettingsOption => '恢复应用设置';

  @override
  String get restoreModeMerge => '合并并覆盖冲突';

  @override
  String get restoreModeReplace => '替换当前课表';

  @override
  String get restoreNothingSelected => '请选择要恢复的课程或应用设置';

  @override
  String get restoreSettingsDone => '应用设置已恢复';

  @override
  String get addSessionChoiceTitle => '添加课程';

  @override
  String get addSingleSession => '添加单节课程';

  @override
  String get addBatchSessions => '批量添加课程';

  @override
  String get batchAddTitle => '批量添加课程';

  @override
  String get batchFirstWeekMonday => '第 1 周周一';

  @override
  String get batchTotalWeeks => '学期总周数';

  @override
  String get batchSelectedWeeks => '上课周次';

  @override
  String get batchMeetings => '每周安排';

  @override
  String get batchAddMeeting => '添加每周安排';

  @override
  String get batchRemoveMeeting => '删除此安排';

  @override
  String get batchSelectAll => '全选';

  @override
  String get batchSelectOdd => '单周';

  @override
  String get batchSelectEven => '双周';

  @override
  String get batchClearWeeks => '清空';

  @override
  String batchMeetingTitle(Object index) {
    return '安排 $index';
  }

  @override
  String batchWeekOption(Object week) {
    return '第 $week 周';
  }

  @override
  String get batchRequiredFields => '请填写课程名称及每个安排的教室';

  @override
  String get batchNoWeeks => '请至少选择一个上课周次';

  @override
  String get batchNoMeetings => '请至少添加一个每周安排';

  @override
  String get batchInvalidTime => '每个安排的结束时间必须晚于开始时间';

  @override
  String get batchMeetingOverlap => '同一天的每周安排不能互相重叠';

  @override
  String get batchPreviewTitle => '确认批量添加';

  @override
  String batchPreviewSummary(Object conflicts, Object generated) {
    return '将生成 $generated 节课程，其中 $conflicts 节已有时间冲突。';
  }

  @override
  String get batchSkipConflicts => '跳过冲突';

  @override
  String get batchOverwriteConflicts => '覆盖冲突';

  @override
  String batchCreateResult(Object created, Object overwritten, Object skipped) {
    return '已添加 $created 节，跳过 $skipped 节，覆盖 $overwritten 节冲突课程';
  }

  @override
  String get courseScopeMeetingFromSelected => '此安排从本节起';

  @override
  String get courseScopeMeetingAll => '此安排的全部周次';

  @override
  String get courseScopeCourseCommon => '整门课程的公共信息';

  @override
  String get backToTop => '返回顶部';

  @override
  String get scheduleVerticalScaleTitle => '课表纵向高度缩放';

  @override
  String get scheduleVerticalScaleSubtitle =>
      '调低可压缩课表高度，显示更多课程。与显示密度组合生效；短课程或较大字体可能限制压缩程度，以保留课程名和时间刻度的可读性。';

  @override
  String get scheduleVerticalScaleReset => '恢复默认';

  @override
  String get customReminders => '提醒时间自定义';

  @override
  String get customRemindersSubtitle => '按课程设置独立时间、筛选、文案和重复发送';

  @override
  String get reminderStrong => '强提醒';

  @override
  String get reminderStrongConfig => '强提醒配置';

  @override
  String get reminderStrongDescription => '循环声音提醒；遵循系统音量、勿扰和通知权限';

  @override
  String get reminderCatchUp => '补发';

  @override
  String get reminderCatchUpNotice => '此消息为补发，非实时提醒';

  @override
  String get reminderOriginalTime => '原计划时间';

  @override
  String get reminderDeliveredTime => '补发时间';

  @override
  String get reminderAcknowledge => '已知晓';

  @override
  String get reminderStop => '停止';

  @override
  String get reminderAdd => '添加规则';

  @override
  String get reminderEdit => '编辑规则';

  @override
  String get reminderCopy => '复制';

  @override
  String get reminderDelete => '删除';

  @override
  String get reminderSave => '保存';

  @override
  String get reminderDiscard => '放弃未保存的更改？';

  @override
  String get reminderKeepEditing => '继续编辑';

  @override
  String get reminderName => '规则名称';

  @override
  String get reminderBasis => '时间基准';

  @override
  String get reminderStart => '课程开始';

  @override
  String get reminderEnd => '课程结束';

  @override
  String get reminderDate => '课程日期的固定时刻';

  @override
  String get reminderBefore => '提前';

  @override
  String get reminderAfter => '延后';

  @override
  String get reminderDays => '天';

  @override
  String get reminderHours => '小时';

  @override
  String get reminderMinutes => '分钟';

  @override
  String get reminderSeconds => '秒';

  @override
  String get reminderScope => '课程范围';

  @override
  String get reminderAll => '全部课程';

  @override
  String get reminderSeries => '课程系列';

  @override
  String get reminderSessions => '单节课程';

  @override
  String get reminderWeekdays => '星期筛选';

  @override
  String get reminderTypes => '课程类型筛选';

  @override
  String get reminderDateRange => '课程日期范围';

  @override
  String get reminderClearFilter => '清除日期筛选';

  @override
  String get reminderTitle => '通知标题';

  @override
  String get reminderBody => '通知正文';

  @override
  String get reminderCount => '发送次数（1–100，包含首次）';

  @override
  String get reminderInterval => '重复间隔（秒，至少 1）';

  @override
  String get reminderUntilAck => '确认后停止，最多发送指定次数';

  @override
  String get reminderInherit => '继承全局设置';

  @override
  String get reminderNormal => '普通提醒';

  @override
  String get reminderPreview => '匹配课程与发送预览';

  @override
  String get reminderTimingNotice => '秒级时间为计划时间，系统可能延迟发送。新建或重新启用后只安排未来发送。';

  @override
  String get reminderInvalid => '请检查数字范围、必填名称及无效占位符';

  @override
  String get reminderSound => '声音';

  @override
  String get reminderVibration => '震动';

  @override
  String get reminderDuration => '持续时间（5–300 秒）';

  @override
  String get reminderSystemSound => '选择系统铃声';

  @override
  String get reminderImportSound => '导入音频（MP3／M4A／WAV，最多 5 MiB）';

  @override
  String get reminderPreviewSound => '试听 / 停止';

  @override
  String get reminderOverride => '单独配置强提醒';

  @override
  String get reminderEmpty => '尚无自定义提醒规则';

  @override
  String get reminderSoundFallback => '缺失或不支持的声音已回退到系统默认音。';

  @override
  String get reminderMaintenanceFailed => '后台维护注册失败，完全退出后的后续排程可能无法补充。请重试。';

  @override
  String get reminderStrongDegraded => '强提醒无法播放，已保留普通通知。请检查系统限制和声音配置。';

  @override
  String get reminderVariableLabels =>
      '课程名|教室|课程日期|星期|开始时间|结束时间|教师|课程代码|发送序号|总次数|计划发送时间';

  @override
  String get reminderWeekdayNames => '星期一|星期二|星期三|星期四|星期五|星期六|星期日';

  @override
  String get reminderDiscardAction => '放弃更改';

  @override
  String get reminderAudioInvalid => '音频不可播放，或文件格式、大小不符合要求。';

  @override
  String get reminderDateOffset => '课程日期偏移';

  @override
  String get reminderSameDay => '课程当天';

  @override
  String get reminderFixedTime => '固定时刻（时／分／秒）';

  @override
  String get reminderFilterWeekdays => '周一|周二|周三|周四|周五|周六|周日';

  @override
  String get reminderPreviousDay => '前一天';

  @override
  String get reminderNextDay => '后一天';

  @override
  String get scheduleFitPage => '自适应页面';

  @override
  String get scheduleFitPageHint => '完整显示 08:00–22:00；空间不足时省略课程文字，点击查看详情。';

  @override
  String get themeMulticolor => '多色配色';

  @override
  String get themeMulticolorOff => '原有配色';

  @override
  String get themeSchemeNames => '鲜明|富表现力|彩虹|果沙|内容|忠实|中性|黑白';

  @override
  String get templateLeadMinutes => '提前分钟';

  @override
  String get templateCourseCount => '课程数量';

  @override
  String get palettePrimary => '主色';

  @override
  String get paletteSecondary => '辅色';

  @override
  String get paletteTertiary => '第三色';

  @override
  String get paletteColors => '课程调色板';

  @override
  String get paletteCustom => '自定义搭配';

  @override
  String get paletteDuplicate => '调色板已包含此颜色';

  @override
  String get paletteUsePrimary => '设为主色';

  @override
  String get paletteUseSecondary => '设为辅色';

  @override
  String get paletteUseTertiary => '设为第三色';

  @override
  String get paletteMoveEarlier => '前移';

  @override
  String get paletteMoveLater => '后移';

  @override
  String get paletteReset => '恢复多色配色默认设置？';

  @override
  String get palettePreview => '效果预览';

  @override
  String get paletteSingle => '单色';

  @override
  String get paletteMode => '界面配色';

  @override
  String get paletteAutomatic => '根据方案自动生成';

  @override
  String get notificationWarning => '未开启通知权限，无法接收提醒。';

  @override
  String get notificationOpen => '去开启';

  @override
  String get notificationIgnore => '忽略且不再提示';

  @override
  String get notificationIgnoreTitle => '忽略通知权限警告？';

  @override
  String get notificationIgnoreBody => '未开启通知权限，提醒功能将不会生效。你可以在设置中恢复此警告。';

  @override
  String get notificationIgnoreConfirm => '确认忽略';

  @override
  String get notificationRestore => '显示权限警告';

  @override
  String get notificationRestoreDescription => '在本设备未开启通知权限时提示';

  @override
  String get notificationCheckFailed => '无法查询通知权限';

  @override
  String get notificationAllowed => '通知权限已开启';

  @override
  String get notificationPermissions => '通知权限';

  @override
  String get strongTargets => '强提醒适用范围';

  @override
  String get strongClassLead => '课前提醒';

  @override
  String get strongCheckIn => '签到提醒';

  @override
  String get strongSummary => '次日汇总';

  @override
  String get strongCustom => '自定义规则';

  @override
  String get strongCourses => '课程范围';

  @override
  String get strongAllRules => '所有继承规则，包括之后新增的规则';

  @override
  String get strongRuleOverrideNotice => '规则明确设置为强提醒或普通提醒时，优先于此处的范围配置。';

  @override
  String get strongSummaryNotice => '限定课程范围时，汇总包含任一选中课程才使用强提醒。';

  @override
  String get settingsNavigationGroup => '日期导航';

  @override
  String get settingsLayoutGroup => '课表布局';

  @override
  String get settingsMaintenanceGroup => '权限与维护';

  @override
  String get settingsDangerGroup => '数据删除';

  @override
  String get settingsDiagnosticsGroup => '诊断';

  @override
  String get settingsBackupGroup => '备份与导出';

  @override
  String get paletteEdit => '编辑颜色';

  @override
  String get paletteHint => '点击颜色选择操作，长按删除。';

  @override
  String get actionConfirm => '确认';

  @override
  String get paletteTonalSpot => '柔和';

  @override
  String get paletteHue => '色相';

  @override
  String get paletteChroma => '鲜艳度';

  @override
  String get paletteTone => '明度';

  @override
  String get paletteScheme => '配色方案';

  @override
  String get paletteSchemeDescriptions =>
      '柔和协调的三色|鲜明且有对比的三色|旋转色相的表现力三色|均衡分布的三色色谱|清新的相邻色搭配|保留种子特色的柔和对比|保留种子特色的互补对比|低饱和，颜色区别较轻|灰阶，不使用色相对比';

  @override
  String get androidEnhancedReminder => '增强提醒模式';

  @override
  String get androidEnhancedReminderSubtitle =>
      '存在未来提醒时显示一条安静的常驻通知，提高部分手机上的提醒可靠性。';

  @override
  String get androidEnhancedReminderLimit =>
      '真正的强制停止仍会阻止 Android 发送闹钟，直至再次打开 Orbit。';

  @override
  String get androidEnhancedReminderChannel => '提醒可靠性';

  @override
  String get androidEnhancedReminderNotificationTitle => '增强提醒已开启';

  @override
  String get androidEnhancedReminderNotificationBody => 'Orbit 正在保护之后的课程提醒。';

  @override
  String get androidEnhancedReminderDisable => '关闭';

  @override
  String get androidOriginOsSettings => 'OriginOS 后台设置';

  @override
  String get androidOriginOsSettingsSubtitle =>
      '请开启自启动和后台高耗电、取消电池限制，并在最近任务中锁定 Orbit。';

  @override
  String get androidOpenAutostartSettings => '打开设置';

  @override
  String get androidForcedStopDetected => 'Orbit 曾被强制停止';

  @override
  String get androidForcedStopDetectedSubtitle =>
      '最近任务清理器停止了 Orbit 并取消了闹钟。请完成下方 OriginOS 设置后重新运行一分钟测试。';

  @override
  String get androidReminderReliability => '提醒注册状态';

  @override
  String androidReminderReliabilityStatus(int registered, int stored) {
    return '$stored 个未来提醒中有 $registered 个已注册到 Android。';
  }

  @override
  String get androidReminderDiagnostics => '提醒诊断记录';

  @override
  String get androidReminderDiagnosticsEmpty => '尚未记录原生提醒事件。';
}

/// The translations for Chinese, using the Han script (`zh_Hant`).
class AppLocalizationsZhHant extends AppLocalizationsZh {
  AppLocalizationsZhHant() : super('zh_Hant');

  @override
  String get importAuto => '自動識別';

  @override
  String get importTemplates => '識別模板';

  @override
  String get importPlans => '學期與作息';

  @override
  String get importListLayout => '課程列表';

  @override
  String get importGridLayout => '週課表網格';

  @override
  String get importLegacyLayout => 'Orbit 13 欄格式';

  @override
  String get importTemplateName => '模板名稱';

  @override
  String get importBuiltIn => '內建模板 · 複製後編輯';

  @override
  String get importCopy => '複製';

  @override
  String get importShareTemplate => '匯出模板 JSON';

  @override
  String get importLoadTemplate => '匯入模板 JSON';

  @override
  String get importLayoutStep => '佈局與區域';

  @override
  String get importFieldsStep => '欄位映射';

  @override
  String get importRegexStep => '提取規則';

  @override
  String get importTestStep => '測試與預覽';

  @override
  String get importHeaderRow => '表頭列（從 1 開始）';

  @override
  String get importFirstRow => '課程起始列';

  @override
  String get importLastRow => '課程結束列（留空至表末）';

  @override
  String get importFirstColumn => '課程起始欄（從 1 開始）';

  @override
  String get importLastColumn => '課程結束欄';

  @override
  String get importWeekdayColumns => '欄:星期，例如 2:1,3:2';

  @override
  String get importPeriodRows => '列:節次，例如 2:1-2;3:3-4';

  @override
  String get importColumnSource => '指定欄';

  @override
  String get importTextSource => '課程區塊文字';

  @override
  String get importFixedSource => '固定值';

  @override
  String get importWeekdaySource => '網格星期';

  @override
  String get importPeriodsSource => '網格節次';

  @override
  String get importColumnNumber => '欄號（從 1 開始）';

  @override
  String get importFixedValue => '固定值';

  @override
  String get importPattern => '正規表示式（留空使用原文）';

  @override
  String get importCaptureGroup => '擷取群組編號或名稱';

  @override
  String get importCaseSensitive => '區分大小寫';

  @override
  String get importMultiLine => '多行錨點';

  @override
  String get importDotAll => '點號匹配換行';

  @override
  String get importUnicode => 'Unicode 模式';

  @override
  String get importBlockPattern => '課程區塊分隔／匹配正規式';

  @override
  String get importRepeatBlocks => '重複匹配課程區塊';

  @override
  String get importTestText => '範例課程文字';

  @override
  String get importRunTest => '執行測試';

  @override
  String get importOriginal => '原文';

  @override
  String get importMatches => '匹配與擷取群組';

  @override
  String get importExtracted => '提取欄位';

  @override
  String get importSave => '儲存';

  @override
  String get importNext => '下一步';

  @override
  String get importBack => '上一步';

  @override
  String get importSemesterName => '學期名稱';

  @override
  String get importFirstMonday => '第一週週一（YYYY-MM-DD）';

  @override
  String get importTotalWeeks => '總週數（1–30）';

  @override
  String get importPeriodPlanName => '作息方案名稱';

  @override
  String get importPeriodTimeInput => '節次,開始,結束，每列一節，例如 1,08:00,08:45';

  @override
  String get importDefaultWeeks => '檔案缺少週次時適用的週次（如 1-18）';

  @override
  String get importConfirmContext => '確認本次匯入的學期、週次與作息';

  @override
  String get importTemporaryContext => '臨時調整僅用於本次匯入；儲存方案請進入方案管理。';

  @override
  String get importEncoding => 'CSV 編碼';

  @override
  String get importDelimiter => 'CSV 分隔符';

  @override
  String get importComma => '逗號';

  @override
  String get importSemicolon => '分號';

  @override
  String get importTab => '定位字元';

  @override
  String get importPreview => '解析與預覽';

  @override
  String get importSkipErrors => '明確略過識別失敗的課程';

  @override
  String get importSkipDescription => '失敗的課程不會匯入，請先檢查每條錯誤。';

  @override
  String get importCancelTask => '取消解析';

  @override
  String get importSelectSheet => '選擇要匯入的工作表';

  @override
  String get importRawTable => '原表預覽 — 點選儲存格選擇座標';

  @override
  String get importChooseCoordinate => '將所選儲存格設為';

  @override
  String get importNoSelection => '尚未選擇工作表';

  @override
  String get importNone => '不使用';

  @override
  String get importValid => '有效';

  @override
  String get importDuplicates => '重複';

  @override
  String get importErrors => '失敗';

  @override
  String get importDeleteConfirm => '刪除此已儲存的模板或方案？';

  @override
  String get importHelp =>
      '列表需課程名、日期（或星期和週次）及起止時間（或節次）。網格以星期為欄、節次為列；同格多課可用空列分隔或設定課程區塊規則。按週課表需確認學期和作息。';

  @override
  String get importFieldCourseName => '課程名';

  @override
  String get importFieldCourseCode => '課程編號';

  @override
  String get importFieldSection => '班別';

  @override
  String get importFieldRoom => '教室';

  @override
  String get importFieldTeachers => '教師';

  @override
  String get importFieldFaculty => '學院';

  @override
  String get importFieldClassType => '課堂類型';

  @override
  String get importFieldSemester => '學期';

  @override
  String get importFieldDate => '日期';

  @override
  String get importFieldWeekday => '星期';

  @override
  String get importFieldWeeks => '週次';

  @override
  String get importFieldPeriods => '節次';

  @override
  String get importFieldStartTime => '開始時間';

  @override
  String get importFieldEndTime => '結束時間';

  @override
  String get importErrorAmbiguous => '有多個候選模板，請明確選擇。';

  @override
  String get importErrorTemplateInvalid => '模板或區域設定無效。';

  @override
  String get importErrorTemplateVersion => '不支援此模板版本。';

  @override
  String get importErrorCaptureGroup => '擷取群組編號或名稱無效。';

  @override
  String get importErrorMissingName => '缺少課程名。';

  @override
  String get importErrorSemesterInvalid => '請檢查學期名稱、週一日期和總週數。';

  @override
  String get importErrorPeriodInvalid => '節次或作息方案無效。';

  @override
  String get importErrorInvalidTime => '時間無效，結束時間必須晚於開始。';

  @override
  String get importErrorInvalidDate => '日期無效。';

  @override
  String get importErrorInvalidWeekday => '星期必須為週一至週日。';

  @override
  String get importErrorWeekdayMismatch => '星期與日期不一致。';

  @override
  String get importErrorInvalidWeeks => '週次無效或超出學期範圍。';

  @override
  String get importErrorWeeksRequired => '檔案缺少週次，請確認適用週次。';

  @override
  String get importErrorContextRequired => '請確認學期與所需作息方案。';

  @override
  String get importErrorUnknownPeriod => '部分節次沒有對應時間。';

  @override
  String get importErrorHorizontalMerge => '不支援跨多個星期欄合併的課程格。';

  @override
  String get importErrorZeroLength => '課程區塊規則不能匹配空文字。';

  @override
  String get importErrorNoMatch => '未匹配到課程區塊。';

  @override
  String get importErrorUnmatchedText => '課程區塊規則遺漏了部分文字，請修正规則。';

  @override
  String get importErrorIdConflict => '相同課次編號對應不同內容，請修正或明確略過。';

  @override
  String get importErrorNoSessions => '沒有識別到有效課程。';

  @override
  String get importErrorNoSheet => '檔案沒有工作表。';

  @override
  String get importErrorUnsupportedFile => '僅支援 XLSX 和 CSV 檔案。';

  @override
  String get importErrorEncodingFailed => 'CSV 解碼失敗，請切換編碼或轉換檔案。';

  @override
  String get importErrorTimeout => '解析逾時，設定已保留。';

  @override
  String get importErrorCancelled => '解析已取消。';

  @override
  String get importErrorWorkerFailed => '解析工作失敗，請重試。';

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
  String get gridBatchDeleteConfirm2Content => '所選課程將移入回收站並保留 7 天，確定繼續？';

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
  String get gridNoSessionsThisWeekSubtitle => '切換至其他週查看課程';

  @override
  String get actionRetry => '重試';

  @override
  String get importViewGrid => '查看課表';

  @override
  String resyncPartialFailed(int count) {
    return '$count 條提醒未能排定';
  }

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
  String get gridEmptySubtitle => '請前往「匯入」頁面選擇 XLSX 或 CSV 課表檔案';

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
  String upcomingWeekMonday(String date) {
    return '$date';
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
  String get importPickTitle => '選擇 XLSX / CSV 課表檔案';

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
  String get settingsCategoryGeneral => '一般';

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
  String get themeStyleTitle => '課程配色';

  @override
  String get themeStyleSubtitle => '使用統一強調色或為不同課程自動配色';

  @override
  String get themeStyleStandard => '統一顏色';

  @override
  String get themeStyleColorful => '自動分色';

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
  String get themeModeTitle => '深淺色模式';

  @override
  String get themeModeSubtitle => '選擇淺色、深色或跟隨系統';

  @override
  String get themeModeSystem => '跟隨系統';

  @override
  String get themeModeLight => '淺色';

  @override
  String get themeModeDark => '深色';

  @override
  String get weekStartDayTitle => '週起始日';

  @override
  String get weekStartDaySubtitle => '課表每週從哪一天開始顯示';

  @override
  String get weekStartMonday => '週一';

  @override
  String get weekStartSunday => '週日';

  @override
  String get gridDensityTitle => '課表顯示密度';

  @override
  String get gridDensitySubtitle => '調整課表行高與字體大小';

  @override
  String get gridDensityCompact => '緊湊';

  @override
  String get gridDensityStandard => '標準';

  @override
  String get gridDensityComfortable => '寬鬆';

  @override
  String get scheduleNarrowLayoutTitle => '窄螢幕課表佈局';

  @override
  String get scheduleNarrowLayoutSubtitle => '選擇一屏整週或經典單日／多日自適應佈局';

  @override
  String get scheduleNarrowLayoutCompactWeek => '緊湊整週';

  @override
  String get scheduleNarrowLayoutAdaptive => '經典自適應';

  @override
  String get scheduleMultiDayCountTitle => '多日模式顯示天數';

  @override
  String scheduleMultiDayCountSubtitle(int maxCount) {
    return '目前視窗最多可清晰顯示 $maxCount 天';
  }

  @override
  String scheduleDayCountOption(int count) {
    return '$count 天';
  }

  @override
  String get scheduleShowEmptyDaysTitle => '顯示無課程日期';

  @override
  String get scheduleShowEmptyDaysSubtitle => '僅用於經典自適應佈局；關閉後將在有課程的日期之間切換';

  @override
  String get upcomingShowCourseDateTitle => '在倒數旁顯示日期';

  @override
  String get upcomingShowCourseDateSubtitle => '在接下來課程列表中顯示課程日期';

  @override
  String get upcomingDateDisplayTitle => '課程日期格式';

  @override
  String get upcomingDateDisplaySubtitle => '選擇要顯示的日期資訊';

  @override
  String get upcomingDateDisplayDateAndWeekday => '日期 + 星期';

  @override
  String get upcomingDateDisplayDateOnly => '僅日期';

  @override
  String get upcomingDateDisplayWeekdayOnly => '僅星期';

  @override
  String get scheduleJumpToNearestCourse => '跳到最近課程';

  @override
  String scheduleCourseCount(int count) {
    return '$count 節課';
  }

  @override
  String get classLeadCustomizeTemplates => '自訂課前提醒文案';

  @override
  String get classLeadCustomizeTemplatesSubtitle => '留空使用預設文案';

  @override
  String get classLeadTemplateSheetTitle => '課前提醒文案';

  @override
  String get classLeadTitleLabel => '標題';

  @override
  String get classLeadBodyLabel => '正文';

  @override
  String classLeadTemplatePlaceholderHint(
    String courseToken,
    String roomToken,
    String timeToken,
    String minutesToken,
  ) {
    return '可用 $courseToken、$roomToken、$timeToken、$minutesToken。留空使用預設文案。';
  }

  @override
  String get checkInCustomizeTemplates => '自訂打卡提醒文案';

  @override
  String get checkInCustomizeTemplatesSubtitle => '留空使用預設文案';

  @override
  String get checkInTemplateSheetTitle => '打卡提醒文案';

  @override
  String get checkInTitleLabel => '標題';

  @override
  String get checkInBodyLabel => '正文';

  @override
  String checkInTemplatePlaceholderHint(
    String courseToken,
    String roomToken,
    String timeToken,
  ) {
    return '可用 $courseToken、$roomToken、$timeToken。留空使用預設文案。';
  }

  @override
  String get sessionColor => '課程顏色';

  @override
  String get sessionColorShort => '顏色';

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
  String get fieldFaculty => '學院名稱';

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
  String get countdownSoonLabel => '即將開始';

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
      '提醒透過背景定時提醒觸發，無需保持應用在前台。建議完成以下設定以提高可靠性。';

  @override
  String get androidCheckReminderPermissions => '檢查提醒權限';

  @override
  String get androidPermissionsChecked => '已請求通知與精確鬧鐘權限';

  @override
  String get androidBatteryOptimization => '電池最佳化豁免';

  @override
  String get androidBatteryOptimizationSubtitleOn => '已豁免電池最佳化，背景提醒更可靠';

  @override
  String get androidBatteryOptimizationSubtitleOff => '開啟後可提高背景提醒可靠性';

  @override
  String get androidBatteryOptimizationDisableConfirmTitle => '關閉電池最佳化豁免？';

  @override
  String get androidBatteryOptimizationDisableConfirmContent =>
      '將跳轉到系統設定以恢復電池最佳化，背景提醒可能變得不穩定。';

  @override
  String get androidAutostartHint =>
      'OriginOS / iQOO 請允許自啟動和背景高耗電，並在最近任務中鎖定 Orbit。';

  @override
  String get debugTitle => '偵錯';

  @override
  String get debugSubtitle => '通知與背景提醒診斷工具';

  @override
  String get androidTestImmediateReminder => '立即測試通知';

  @override
  String get androidTestImmediateReminderSubtitle => '立即驗證通知權限和訊息顯示。';

  @override
  String get androidTestImmediateReminderShown => '測試通知已傳送。';

  @override
  String get androidTestBackgroundReminder => '測試背景提醒（1 分鐘）';

  @override
  String get androidTestBackgroundReminderSubtitle =>
      '註冊與課程提醒相同的原生鬧鐘。一分鐘後重新開啟 Orbit，可檢查註冊、接收與通知階段。';

  @override
  String get androidTestBackgroundReminderScheduled =>
      '階段 1 已通過：一分鐘測試鬧鐘已註冊。離開 Orbit 並等待，然後查看提醒診斷記錄。';

  @override
  String androidTestBackgroundReminderScheduledAt(String time) {
    return '階段 1 已通過：Android 已註冊 $time 的鬧鐘。離開 Orbit 並等待，然後查看提醒診斷記錄。';
  }

  @override
  String get androidTestBackgroundNotificationTitle => 'Orbit 背景提醒測試';

  @override
  String get androidTestBackgroundNotificationBody =>
      '背景提醒已成功觸發，Orbit 不在前台時也可以正常傳送提醒。';

  @override
  String get androidTestBackgroundReminderFailed => '無法註冊測試提醒，請檢查精確鬧鐘權限。';

  @override
  String get androidTestReminderNotificationsDenied => '通知權限未開啟，請允許通知後重試。';

  @override
  String get androidTestReminderExactAlarmsDenied => '精確鬧鐘權限未開啟，請允許後重試。';

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
  String get deleteEndedConfirm2Content => '已結束課程將移入回收站並保留 7 天，確定繼續？';

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
  String get confirmClearContent => '所有已匯入的課表資料將移入回收站並保留 7 天。';

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
  String get nextDayRemindWhenNoClass => '無課時也提醒';

  @override
  String get nextDayRemindWhenNoClassSubtitle => '明天沒有課程時仍發送確認通知';

  @override
  String get nextDayCustomizeTemplates => '自訂提醒文案';

  @override
  String get nextDayCustomizeTemplatesSubtitle => '可編輯標題與正文，留空則使用預設';

  @override
  String get nextDayTemplateSheetTitle => '次日提醒文案';

  @override
  String get nextDayWithClassTitleLabel => '有課標題';

  @override
  String get nextDayWithClassBodyLabel => '有課正文';

  @override
  String get nextDayNoClassTitleLabel => '無課標題';

  @override
  String get nextDayNoClassBodyLabel => '無課正文';

  @override
  String nextDayTemplatePlaceholderHint(
    String countToken,
    String timeToken,
    String dateToken,
  ) {
    return '有課正文可用 $countToken、$timeToken、$dateToken；無課正文可用 $dateToken。留空使用預設文案。';
  }

  @override
  String get nextDayTemplateReset => '恢復預設';

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
  String get deleteSession => '刪除課程';

  @override
  String get deleteSessionShort => '刪除';

  @override
  String get courseColorDefault => '預設顏色';

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

  @override
  String get exportScheduleJson => '匯出 JSON 備份';

  @override
  String get exportScheduleJsonSubtitle => '儲存全部課表資料，用於還原或遷移';

  @override
  String get exportScheduleXlsx => '匯出為 xlsx';

  @override
  String get exportScheduleXlsxSubtitle => '以與匯入相同的格式匯出';

  @override
  String get restoreFromBackup => '從備份還原';

  @override
  String get restoreFromBackupSubtitle => '從 JSON 備份檔案匯入課表';

  @override
  String exportDone(int count) {
    return '已匯出 $count 節課';
  }

  @override
  String exportFailed(String error) {
    return '匯出失敗：$error';
  }

  @override
  String get exportNothingToExport => '沒有可匯出的課表資料';

  @override
  String get restoreConfirmTitle => '還原備份？';

  @override
  String restoreConfirmContent(int count) {
    return '將合併備份中的 $count 節課。';
  }

  @override
  String restoreDone(int count) {
    return '已還原 $count 節課';
  }

  @override
  String restoreFailed(String error) {
    return '還原失敗：$error';
  }

  @override
  String get backupInvalidFormat => '備份檔案格式無效';

  @override
  String get backupUnsupportedVersion => '不支援的備份版本';

  @override
  String get addSession => '新增課程';

  @override
  String get addSessionTitle => '新增課程';

  @override
  String get fieldDate => '日期';

  @override
  String get fieldCourseCode => '科目編號';

  @override
  String get fieldSection => '班別';

  @override
  String get defaultClassType => '一般課堂';

  @override
  String get sessionCreated => '已新增課程';

  @override
  String get sessionCreateRequiredFields => '科目名稱和課室為必填項';

  @override
  String get sessionTimeConflict => '該時段已有其他課程';

  @override
  String sessionSavedWithOverride(int count) {
    return '已儲存，並覆蓋了 $count 節時間衝突的課程。';
  }

  @override
  String get importStrategyTitle => '偵測到重複週次';

  @override
  String importStrategyMessage(int count) {
    return '本次匯入有 $count 個週次已存在課程，請選擇匯入方式。';
  }

  @override
  String get importStrategyReplaceWeek => '整週取代';

  @override
  String get importStrategyReplaceWeekDesc => '刪除這些週次原有的全部課程，再匯入新課程。';

  @override
  String get importStrategyMerge => '合併並覆蓋衝突';

  @override
  String get importStrategyMergeDesc => '保留其他課程，僅取代與匯入課程時間重疊的課程。';

  @override
  String get actionCreate => '建立';

  @override
  String sessionSaveFailed(String error) {
    return '儲存失敗：$error';
  }

  @override
  String deleteFailed(String error) {
    return '刪除失敗：$error';
  }

  @override
  String get languageChangedResynced => '語言已更新，提醒已重新同步';

  @override
  String get searchSessions => '搜尋課程';

  @override
  String get searchHint => '按科目、課室或教師搜尋';

  @override
  String get searchNoResults => '沒有符合的課程';

  @override
  String searchFailed(String error) {
    return '搜尋失敗：$error';
  }

  @override
  String searchResultsTruncated(int count) {
    return '僅顯示前 $count 條結果';
  }

  @override
  String gridBatchDeleteFailed(String error) {
    return '批量刪除失敗：$error';
  }

  @override
  String clearAllFailed(String error) {
    return '清除課表失敗：$error';
  }

  @override
  String launchAtStartupFailed(String error) {
    return '更新開機啟動設定失敗：$error';
  }

  @override
  String get sectionSchedule => '課表';

  @override
  String get gridDefaultWeekTitle => '預設週次';

  @override
  String get gridDefaultWeekSubtitle => '開啟課表時顯示的週次';

  @override
  String get gridDefaultWeekSmart => '智能';

  @override
  String get gridDefaultWeekCurrent => '本週';

  @override
  String get gridDefaultWeekEarliest => '最早有課週';

  @override
  String get exportInProgress => '正在匯出…';

  @override
  String get importFormatTitle => '課表檔案格式';

  @override
  String get importFormatSubtitle => 'XLSX / CSV 課程列表與週課表網格';

  @override
  String get importFormatColumn => '欄';

  @override
  String get importFormatField => '欄位';

  @override
  String get importFormatExample => '範例';

  @override
  String get importFormatClassType => '課堂類型';

  @override
  String get importFormatClassTypeExample => '一般課堂';

  @override
  String get importFormatRoom => '課室';

  @override
  String get importFormatRoomExample => 'A001';

  @override
  String get importFormatCapacity => '人數';

  @override
  String get importFormatCapacityExample => '67';

  @override
  String get importFormatFaculty => '學院名稱';

  @override
  String get importFormatFacultyExample => '範例學院';

  @override
  String get importFormatDate => '日期';

  @override
  String get importFormatDateExample => '2026-07-27';

  @override
  String get importFormatWeekday => '星期';

  @override
  String get importFormatWeekdayExample => '1（週一）~ 7（週日）';

  @override
  String get importFormatCourseName => '科目名稱';

  @override
  String get importFormatCourseNameExample => '物理';

  @override
  String get importFormatCourseCode => '科目編號';

  @override
  String get importFormatCourseCodeExample => 'P0721';

  @override
  String get importFormatSection => '班別名稱';

  @override
  String get importFormatSectionExample => 'EX1';

  @override
  String get importFormatStartTime => '開始時間';

  @override
  String get importFormatStartTimeExample => '12:30';

  @override
  String get importFormatEndTime => '結束時間';

  @override
  String get importFormatEndTimeExample => '15:20';

  @override
  String get importFormatTeachers => '教師';

  @override
  String get importFormatTeachersExample => 'Miku,null';

  @override
  String get importFormatSemester => '學期';

  @override
  String get importFormatSemesterExample => '2606';

  @override
  String get xlsxErrorNoSheet => '檔案中找不到工作表';

  @override
  String get xlsxErrorEmptySheet => '課表內容為空';

  @override
  String get xlsxErrorNoSessions => '未解析到任何課程資料';

  @override
  String xlsxErrorInsufficientColumns(String detail) {
    return '資料欄不足（$detail 欄）';
  }

  @override
  String xlsxErrorInvalidDate(String detail) {
    return '無法解析日期：$detail';
  }

  @override
  String xlsxErrorInvalidTime(String detail) {
    return '無法解析時間：$detail';
  }

  @override
  String reminderSyncFailed(String error) {
    return '提醒同步失敗：$error';
  }

  @override
  String get reminderResyncFailedBanner => '提醒未能同步，請點「重新同步提醒」重試。';

  @override
  String get reminderScheduleVerifyFailed =>
      '提醒已儲存，但 Android 未能將其加入待處理佇列。請檢查通知、精確鬧鐘和電池設定後重新同步。';

  @override
  String get reminderScheduleVerifyFailedBanner =>
      'Android 未能將提醒加入待處理佇列。請檢查通知、精確鬧鐘和電池設定後重新同步。';

  @override
  String reminderScheduledCount(int count) {
    return '已排定 $count 則提醒';
  }

  @override
  String reminderRegisteredAlarmCount(int count) {
    return '已註冊 $count 條背景定時提醒';
  }

  @override
  String get androidNotificationsEnabled => '通知已開啟';

  @override
  String get androidNotificationsDisabled => '通知未開啟';

  @override
  String get androidExactAlarmsEnabled => '精確鬧鐘已允許';

  @override
  String get androidExactAlarmsDisabled => '精確鬧鐘未允許';

  @override
  String get actionUndo => '復原';

  @override
  String get trashTitle => '最近刪除';

  @override
  String get trashSubtitle => '刪除的課程將保留 7 天';

  @override
  String get trashEmpty => '沒有最近刪除的課程';

  @override
  String trashDeletedAt(Object time) {
    return '刪除於 $time';
  }

  @override
  String get trashRestoreSelected => '還原所選';

  @override
  String get trashRestoreAll => '全部還原';

  @override
  String get trashEmptyAction => '清空回收站';

  @override
  String get trashEmptyConfirm1Title => '清空回收站？';

  @override
  String get trashEmptyConfirm1Content => '所有最近刪除的課程都將被永久移除。';

  @override
  String get trashEmptyConfirm2Title => '確認永久刪除？';

  @override
  String get trashEmptyConfirm2Content => '此操作無法復原。';

  @override
  String trashRestoreResult(Object restored, Object skipped) {
    return '已還原 $restored 節，略過 $skipped 節衝突課程';
  }

  @override
  String get courseScopeTitle => '套用範圍';

  @override
  String get courseScopeSingle => '僅本節';

  @override
  String get courseScopeFromSelected => '本節及以後';

  @override
  String get courseScopeAll => '全部同課程';

  @override
  String courseOperationSummary(
    Object conflicts,
    Object count,
    Object end,
    Object start,
  ) {
    return '共 $count 節，日期為 $start 至 $end，將覆蓋 $conflicts 節衝突課程。';
  }

  @override
  String courseBatchUpdated(Object count) {
    return '已更新 $count 節課程';
  }

  @override
  String courseBatchDeleted(Object count) {
    return '已刪除 $count 節課程';
  }

  @override
  String get backupIncludesSettings => '包含外觀、課表、提醒和課程顏色設置';

  @override
  String restorePreviewSummary(
    Object count,
    Object end,
    Object start,
    Object version,
  ) {
    return '備份 v$version · $count 節課程 · $start 至 $end';
  }

  @override
  String get restoreCoursesOption => '還原課程';

  @override
  String get restoreSettingsOption => '還原應用設置';

  @override
  String get restoreModeMerge => '合併並覆蓋衝突';

  @override
  String get restoreModeReplace => '取代目前課表';

  @override
  String get restoreNothingSelected => '請選擇要還原的課程或應用設置';

  @override
  String get restoreSettingsDone => '應用設置已還原';

  @override
  String get addSessionChoiceTitle => '添加課程';

  @override
  String get addSingleSession => '添加單節課程';

  @override
  String get addBatchSessions => '批量添加課程';

  @override
  String get batchAddTitle => '批量添加課程';

  @override
  String get batchFirstWeekMonday => '第 1 週週一';

  @override
  String get batchTotalWeeks => '學期總週數';

  @override
  String get batchSelectedWeeks => '上課週次';

  @override
  String get batchMeetings => '每週安排';

  @override
  String get batchAddMeeting => '添加每週安排';

  @override
  String get batchRemoveMeeting => '刪除此安排';

  @override
  String get batchSelectAll => '全選';

  @override
  String get batchSelectOdd => '單週';

  @override
  String get batchSelectEven => '雙週';

  @override
  String get batchClearWeeks => '清空';

  @override
  String batchMeetingTitle(Object index) {
    return '安排 $index';
  }

  @override
  String batchWeekOption(Object week) {
    return '第 $week 週';
  }

  @override
  String get batchRequiredFields => '請填寫課程名稱及每個安排的教室';

  @override
  String get batchNoWeeks => '請至少選擇一個上課週次';

  @override
  String get batchNoMeetings => '請至少添加一個每週安排';

  @override
  String get batchInvalidTime => '每個安排的結束時間必須晚於開始時間';

  @override
  String get batchMeetingOverlap => '同一天的每週安排不能互相重疊';

  @override
  String get batchPreviewTitle => '確認批量添加';

  @override
  String batchPreviewSummary(Object conflicts, Object generated) {
    return '將生成 $generated 節課程，其中 $conflicts 節已有時間衝突。';
  }

  @override
  String get batchSkipConflicts => '跳過衝突';

  @override
  String get batchOverwriteConflicts => '覆蓋衝突';

  @override
  String batchCreateResult(Object created, Object overwritten, Object skipped) {
    return '已添加 $created 節，跳過 $skipped 節，覆蓋 $overwritten 節衝突課程';
  }

  @override
  String get courseScopeMeetingFromSelected => '此安排從本節起';

  @override
  String get courseScopeMeetingAll => '此安排的全部週次';

  @override
  String get courseScopeCourseCommon => '整門課程的公共信息';

  @override
  String get backToTop => '返回頂部';

  @override
  String get scheduleVerticalScaleTitle => '課表縱向高度縮放';

  @override
  String get scheduleVerticalScaleSubtitle =>
      '調低可壓縮課表高度，顯示更多課程。與顯示密度組合生效；短課程或較大字體可能限制壓縮程度，以保留課程名和時間刻度的可讀性。';

  @override
  String get scheduleVerticalScaleReset => '恢復預設';

  @override
  String get customReminders => '提醒時間自訂';

  @override
  String get customRemindersSubtitle => '按課程設定獨立時間、篩選、文案與重複發送';

  @override
  String get reminderStrong => '強提醒';

  @override
  String get reminderStrongConfig => '強提醒設定';

  @override
  String get reminderStrongDescription => '循環聲音提醒；遵循系統音量、勿擾與通知權限';

  @override
  String get reminderCatchUp => '補發';

  @override
  String get reminderCatchUpNotice => '此訊息為補發，非即時提醒';

  @override
  String get reminderOriginalTime => '原計劃時間';

  @override
  String get reminderDeliveredTime => '補發時間';

  @override
  String get reminderAcknowledge => '已知曉';

  @override
  String get reminderStop => '停止';

  @override
  String get reminderAdd => '新增規則';

  @override
  String get reminderEdit => '編輯規則';

  @override
  String get reminderCopy => '複製';

  @override
  String get reminderDelete => '刪除';

  @override
  String get reminderSave => '儲存';

  @override
  String get reminderDiscard => '捨棄未儲存的變更？';

  @override
  String get reminderKeepEditing => '繼續編輯';

  @override
  String get reminderName => '規則名稱';

  @override
  String get reminderBasis => '時間基準';

  @override
  String get reminderStart => '課程開始';

  @override
  String get reminderEnd => '課程結束';

  @override
  String get reminderDate => '課程日期的固定時刻';

  @override
  String get reminderBefore => '提前';

  @override
  String get reminderAfter => '延後';

  @override
  String get reminderDays => '天';

  @override
  String get reminderHours => '小時';

  @override
  String get reminderMinutes => '分鐘';

  @override
  String get reminderSeconds => '秒';

  @override
  String get reminderScope => '課程範圍';

  @override
  String get reminderAll => '全部課程';

  @override
  String get reminderSeries => '課程系列';

  @override
  String get reminderSessions => '單節課程';

  @override
  String get reminderWeekdays => '星期篩選';

  @override
  String get reminderTypes => '課程類型篩選';

  @override
  String get reminderDateRange => '課程日期範圍';

  @override
  String get reminderClearFilter => '清除日期篩選';

  @override
  String get reminderTitle => '通知標題';

  @override
  String get reminderBody => '通知內文';

  @override
  String get reminderCount => '發送次數（1–100，包含首次）';

  @override
  String get reminderInterval => '重複間隔（秒，至少 1）';

  @override
  String get reminderUntilAck => '確認後停止，最多發送指定次數';

  @override
  String get reminderInherit => '繼承全域設定';

  @override
  String get reminderNormal => '一般提醒';

  @override
  String get reminderPreview => '符合課程與發送預覽';

  @override
  String get reminderTimingNotice => '秒級時間為計劃時間，系統可能延遲發送。新增或重新啟用後僅安排未來發送。';

  @override
  String get reminderInvalid => '請檢查數字範圍、必填名稱與無效預留位置';

  @override
  String get reminderSound => '聲音';

  @override
  String get reminderVibration => '震動';

  @override
  String get reminderDuration => '持續時間（5–300 秒）';

  @override
  String get reminderSystemSound => '選擇系統鈴聲';

  @override
  String get reminderImportSound => '匯入音訊（MP3／M4A／WAV，最多 5 MiB）';

  @override
  String get reminderPreviewSound => '試聽 / 停止';

  @override
  String get reminderOverride => '單獨設定強提醒';

  @override
  String get reminderEmpty => '尚無自訂提醒規則';

  @override
  String get reminderSoundFallback => '缺失或不支援的聲音已改用系統預設音。';

  @override
  String get reminderMaintenanceFailed => '背景維護註冊失敗，完全結束後的後續排程可能無法補充。請重試。';

  @override
  String get reminderStrongDegraded => '強提醒無法播放，已保留一般通知。請檢查系統限制與聲音設定。';

  @override
  String get reminderVariableLabels =>
      '課程名|教室|課程日期|星期|開始時間|結束時間|教師|課程代碼|發送序號|總次數|計劃發送時間';

  @override
  String get reminderWeekdayNames => '星期一|星期二|星期三|星期四|星期五|星期六|星期日';

  @override
  String get reminderDiscardAction => '捨棄變更';

  @override
  String get reminderAudioInvalid => '音訊無法播放，或檔案格式、大小不符合要求。';

  @override
  String get reminderDateOffset => '課程日期偏移';

  @override
  String get reminderSameDay => '課程當天';

  @override
  String get reminderFixedTime => '固定時刻（時／分／秒）';

  @override
  String get reminderFilterWeekdays => '週一|週二|週三|週四|週五|週六|週日';

  @override
  String get reminderPreviousDay => '前一天';

  @override
  String get reminderNextDay => '後一天';

  @override
  String get scheduleFitPage => '自適應頁面';

  @override
  String get scheduleFitPageHint => '完整顯示 08:00–22:00；空間不足時省略課程文字，點擊查看詳情。';

  @override
  String get themeMulticolor => '多色配色';

  @override
  String get themeMulticolorOff => '原有配色';

  @override
  String get themeSchemeNames => '鮮明|富表現力|彩虹|果沙|內容|忠實|中性|黑白';

  @override
  String get templateLeadMinutes => '提前分鐘';

  @override
  String get templateCourseCount => '課程數量';

  @override
  String get palettePrimary => '主色';

  @override
  String get paletteSecondary => '輔色';

  @override
  String get paletteTertiary => '第三色';

  @override
  String get paletteColors => '課程調色盤';

  @override
  String get paletteCustom => '自訂搭配';

  @override
  String get paletteDuplicate => '調色盤已包含此顏色';

  @override
  String get paletteUsePrimary => '設為主色';

  @override
  String get paletteUseSecondary => '設為輔色';

  @override
  String get paletteUseTertiary => '設為第三色';

  @override
  String get paletteMoveEarlier => '前移';

  @override
  String get paletteMoveLater => '後移';

  @override
  String get paletteReset => '恢復多色配色預設設定？';

  @override
  String get palettePreview => '效果預覽';

  @override
  String get paletteSingle => '單色';

  @override
  String get paletteMode => '介面配色';

  @override
  String get paletteAutomatic => '依方案自動產生';

  @override
  String get notificationWarning => '未開啟通知權限，無法接收提醒。';

  @override
  String get notificationOpen => '去開啟';

  @override
  String get notificationIgnore => '忽略且不再提示';

  @override
  String get notificationIgnoreTitle => '忽略通知權限警告？';

  @override
  String get notificationIgnoreBody => '未開啟通知權限，提醒功能將不會生效。你可以在設定中恢復此警告。';

  @override
  String get notificationIgnoreConfirm => '確認忽略';

  @override
  String get notificationRestore => '顯示權限警告';

  @override
  String get notificationRestoreDescription => '在本裝置未開啟通知權限時提示';

  @override
  String get notificationCheckFailed => '無法查詢通知權限';

  @override
  String get notificationAllowed => '通知權限已開啟';

  @override
  String get notificationPermissions => '通知權限';

  @override
  String get strongTargets => '強提醒適用範圍';

  @override
  String get strongClassLead => '課前提醒';

  @override
  String get strongCheckIn => '簽到提醒';

  @override
  String get strongSummary => '次日彙總';

  @override
  String get strongCustom => '自訂規則';

  @override
  String get strongCourses => '課程範圍';

  @override
  String get strongAllRules => '所有繼承規則，包括之後新增的規則';

  @override
  String get strongRuleOverrideNotice => '規則明確設定為強提醒或普通提醒時，優先於此處的範圍設定。';

  @override
  String get strongSummaryNotice => '限定課程範圍時，彙總包含任一選中課程才使用強提醒。';

  @override
  String get settingsNavigationGroup => '日期導覽';

  @override
  String get settingsLayoutGroup => '課表版面';

  @override
  String get settingsMaintenanceGroup => '權限與維護';

  @override
  String get settingsDangerGroup => '資料刪除';

  @override
  String get settingsDiagnosticsGroup => '診斷';

  @override
  String get settingsBackupGroup => '備份與匯出';

  @override
  String get paletteEdit => '編輯顏色';

  @override
  String get paletteHint => '點擊顏色選擇操作，長按刪除。';

  @override
  String get actionConfirm => '確認';

  @override
  String get paletteTonalSpot => '柔和';

  @override
  String get paletteHue => '色相';

  @override
  String get paletteChroma => '鮮豔度';

  @override
  String get paletteTone => '明度';

  @override
  String get paletteScheme => '配色方案';

  @override
  String get paletteSchemeDescriptions =>
      '柔和協調的三色|鮮明且有對比的三色|旋轉色相的表現力三色|均衡分布的三色色譜|清新的相鄰色搭配|保留種子特色的柔和對比|保留種子特色的互補對比|低飽和，顏色區別較輕|灰階，不使用色相對比';

  @override
  String get androidEnhancedReminder => '增強提醒模式';

  @override
  String get androidEnhancedReminderSubtitle =>
      '存在未來提醒時顯示一則安靜的常駐通知，提高部分手機上的提醒可靠性。';

  @override
  String get androidEnhancedReminderLimit =>
      '真正的強制停止仍會阻止 Android 傳送鬧鐘，直至再次開啟 Orbit。';

  @override
  String get androidEnhancedReminderChannel => '提醒可靠性';

  @override
  String get androidEnhancedReminderNotificationTitle => '增強提醒已開啟';

  @override
  String get androidEnhancedReminderNotificationBody => 'Orbit 正在保護之後的課程提醒。';

  @override
  String get androidEnhancedReminderDisable => '關閉';

  @override
  String get androidOriginOsSettings => 'OriginOS 背景設定';

  @override
  String get androidOriginOsSettingsSubtitle =>
      '請開啟自動啟動和背景高耗電、取消電池限制，並在最近任務中鎖定 Orbit。';

  @override
  String get androidOpenAutostartSettings => '開啟設定';

  @override
  String get androidForcedStopDetected => 'Orbit 曾被強制停止';

  @override
  String get androidForcedStopDetectedSubtitle =>
      '最近任務清理器停止了 Orbit 並取消了鬧鐘。請完成下方 OriginOS 設定後重新執行一分鐘測試。';

  @override
  String get androidReminderReliability => '提醒註冊狀態';

  @override
  String androidReminderReliabilityStatus(int registered, int stored) {
    return '$stored 個未來提醒中有 $registered 個已註冊到 Android。';
  }

  @override
  String get androidReminderDiagnostics => '提醒診斷記錄';

  @override
  String get androidReminderDiagnosticsEmpty => '尚未記錄原生提醒事件。';
}
