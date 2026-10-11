import 'package:flutter/widgets.dart';
import 'package:orbit/models/orbit_feature_text.dart';
import 'package:orbit/models/sync_content.dart';

class SyncUpdateText extends OrbitFeatureText {
  const SyncUpdateText(super.locale);
  factory SyncUpdateText.of(BuildContext context) =>
      SyncUpdateText(Localizations.localeOf(context));
  String get content => pick('Sync content', '同步内容', '同步內容');
  String category(SyncCategory c) => switch (c) {
    SyncCategory.courses => pick('Courses', '课程', '課程'),
    SyncCategory.deadlines => 'DDL',
    SyncCategory.statistics => pick('Statistics', '统计信息', '統計資訊'),
    SyncCategory.templates => pick('Import templates', '导入模板', '匯入範本'),
    SyncCategory.semesters => pick('Semesters', '学期', '學期'),
    SyncCategory.periods => pick('Period schedules', '作息', '作息'),
    SyncCategory.appearance => pick(
      'Appearance and language',
      '外观与语言',
      '外觀與語言',
    ),
    SyncCategory.colors => pick('Course colors', '课程配色', '課程配色'),
    SyncCategory.display => pick('Timetable display', '课表展示', '課表顯示'),
    SyncCategory.reminders => pick(
      'Ordinary reminders and rules',
      '普通提醒与自定义规则',
      '一般提醒與自訂規則',
    ),
    SyncCategory.strong => pick('Strong reminders', '强提醒', '強提醒'),
    SyncCategory.archive => pick('Archive preferences', '归档偏好', '封存偏好'),
  };
  String get device =>
      pick('Set separately on each device', '每台设备分别设置', '每台裝置分別設定');
  String get shared => pick('Use one account scope', '账号统一设置', '帳號統一設定');
  String get scopeHint => pick(
    'Turning a category off keeps local and cloud data. Strong reminders are local by default.',
    '关闭类别会保留本地和云端数据。强提醒默认仅在本机设置。',
    '關閉類別會保留本機及雲端資料。強提醒預設僅在本機設定。',
  );
  String get sharedConfirm => pick(
    'Use the categories selected on this device as the account scope? This applies after an online save succeeds.',
    '以当前设备所选的类别作为账号统一范围？联网保存成功后生效。',
    '以目前裝置所選的類別作為帳號統一範圍？連線儲存成功後生效。',
  );
  String get preview =>
      pick('Review full snapshot merge', '预览完整快照合并', '預覽完整快照合併');
  String mergeCounts(int local, int remote) => pick(
    'Upload $local local items; receive $remote cloud items. Deletion markers are included.',
    '上传 $local 项本地记录；接收 $remote 项云端记录（包括删除标记）。',
    '上傳 $local 筆本機記錄；接收 $remote 筆雲端記錄（含刪除標記）。',
  );
  String get local => pick('Keep local', '保留本地', '保留本機');
  String get cloud => pick('Use cloud', '使用云端', '使用雲端');
  String get cancel => pick('Cancel', '取消', '取消');
  String get confirm => pick('Confirm', '确认', '確認');
  String get check => pick('Check for updates', '检查更新', '檢查更新');
  String get autoCheck =>
      pick('Check daily on launch or resume', '启动或回前台时每日检查一次', '啟動或回前景時每日檢查一次');
  String get current => pick('Current version', '当前版本', '目前版本');
  String get available => pick('Update available', '发现新版本', '發現新版本');
  String get latest =>
      pick('No newer stable release', '暂无更新的正式版本', '暫無更新的正式版本');
  String get download => pick('Download', '下载', '下載');
  String get install => pick('Install / open package', '安装／打开安装包', '安裝／開啟安裝包');
  String get probe => pick('Test download latency', '测试下载延迟', '測試下載延遲');
  @override
  String get automatic => pick(
    'Choose fastest available automatically',
    '自动选择最快可用来源',
    '自動選擇最快可用來源',
  );
  String get source => pick('Download source', '下载来源', '下載來源');
  @override
  String get custom =>
      pick('Add custom HTTPS prefix', '添加自定义 HTTPS 镜像前缀', '新增自訂 HTTPS 鏡像前綴');
  String get unverified => pick(
    'Official size or SHA-256 is missing. Installation is unavailable.',
    '缺少官方文件大小或 SHA-256，无法安装。',
    '缺少官方檔案大小或 SHA-256，無法安裝。',
  );
  String get verified => pick(
    'Size and SHA-256 verified',
    '文件大小及 SHA-256 校验通过',
    '檔案大小及 SHA-256 驗證通過',
  );
  String get installPermission => pick(
    'Allow Orbit to install apps in the system screen, then return and tap Install again.',
    '请在系统页面允许 Orbit 安装应用，然后返回再次点击安装。',
    '請在系統頁面允許 Orbit 安裝應用程式，然後返回再次點擊安裝。',
  );
  String get zipHelp => pick(
    'Exit Orbit, then extract the ZIP and replace the program files. Your user data is kept separately.',
    '请先退出 Orbit，再解压 ZIP 并替换程序文件，应用用户数据会保留。',
    '請先退出 Orbit，再解壓縮 ZIP 並替換程式檔案，應用程式使用者資料會保留。',
  );
  @override
  String get failed => pick('Failed; tap to retry', '失败，请重试', '失敗，請重試');
  String get soundHint => pick(
    'A synced sound is unavailable here. Select a sound on this device.',
    '同步的声音无法在本机使用，已回退默认声音，请重新选择。',
    '同步的聲音無法在本機使用，已回退預設聲音，請重新選擇。',
  );
}
