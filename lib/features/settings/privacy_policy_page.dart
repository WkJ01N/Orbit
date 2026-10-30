import 'package:flutter/material.dart';
import 'package:orbit/core/background/background_scope.dart';
import 'package:orbit/core/motion/page_module.dart';

/// What Orbit does with the data a user hands it. Written for the beta the
/// account service runs on: short, specific, and free of promises the code
/// cannot keep.
class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  @override
  Widget build(BuildContext context) {
    final text = _PrivacyText.of(context);
    final style = Theme.of(context).textTheme;
    return BackgroundScaffold(
      appBar: AppBar(title: PageModule(child: Text(text.title))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          PageModule(child: Text(text.intro, style: style.bodyLarge)),
          const SizedBox(height: 20),
          for (final section in text.sections) ...[
            PageModule(child: Text(section.title, style: style.titleMedium)),
            const SizedBox(height: 6),
            PageModule(child: Text(section.body, style: style.bodyMedium)),
            const SizedBox(height: 18),
          ],
        ],
      ),
    );
  }
}

class _PrivacySection {
  const _PrivacySection(this.title, this.body);

  final String title;
  final String body;
}

class _PrivacyText {
  const _PrivacyText(this.zh, this.hant);

  final bool zh;
  final bool hant;

  factory _PrivacyText.of(BuildContext context) {
    final locale = Localizations.localeOf(context);
    final script = locale.scriptCode?.toLowerCase();
    return _PrivacyText(
      locale.languageCode == 'zh',
      script == 'hant' || locale.countryCode == 'TW',
    );
  }

  String pick(String en, String hans, String traditional) =>
      zh ? (hant ? traditional : hans) : en;

  String get title => pick('Privacy', '隐私政策', '隱私政策');

  String get intro => pick(
    'Orbit keeps your timetable on this device. Cloud sync is optional: it only '
        'sends what you switch on, and only while you are signed in.',
    'Orbit 默认把课表保存在本机。云同步是可选项，只上传你开启同步的内容，且仅在你登录时上传。',
    'Orbit 預設把課表保存在本機。雲端同步是可選項，只上傳你開啟同步的內容，且僅在你登入時上傳。',
  );

  List<_PrivacySection> get sections => [
    _PrivacySection(
      pick('What is collected', '收集哪些数据', '收集哪些資料'),
      pick(
        'Account: email address, display name, and one session record per '
            'signed-in device. Synced content: the timetable rows, templates, '
            'semesters, deadlines, settings and statistics you turn on.',
        '账号信息：邮箱、显示名称，以及每台登录设备的会话记录。同步内容：你开启同步的课表、导入模板、学期、DDL、设置与统计。',
        '帳號資訊：電子郵件、顯示名稱，以及每台登入裝置的工作階段記錄。同步內容：你開啟同步的課表、匯入範本、學期、DDL、設定與統計。',
      ),
    ),
    _PrivacySection(
      pick('Where it is stored', '数据存在哪', '資料存在哪'),
      pick(
        'Everything is written to a local SQLite database first. Uploads go to '
            'a Tencent CloudBase environment in Shanghai over HTTPS. Passwords '
            'are stored only as hashes; the app never keeps your password.',
        '所有数据先写入本机 SQLite 数据库。上传走 HTTPS，存于上海的腾讯云 CloudBase 环境。密码只以哈希形式保存，应用本身不保留密码。',
        '所有資料先寫入本機 SQLite 資料庫。上傳走 HTTPS，存於上海的騰訊雲 CloudBase 環境。密碼只以雜湊形式保存，應用本身不保留密碼。',
      ),
    ),
    _PrivacySection(
      pick('What is never used', '不会做什么', '不會做什麼'),
      pick(
        'No advertising, analytics or crash-reporting SDK is bundled, and the '
            'app does not read contacts, photos or location.',
        '应用未集成广告、统计分析或崩溃上报 SDK，也不会读取通讯录、相册或定位。',
        '應用未整合廣告、統計分析或當機回報 SDK，也不會讀取聯絡人、相簿或定位。',
      ),
    ),
    _PrivacySection(
      pick('Keeping and deleting', '保存与删除', '保存與刪除'),
      pick(
        'Server data is kept until you delete the account, which erases the '
            'synced rows and sessions. Local data stays on this device until you '
            'uninstall the app or delete it yourself.',
        '服务器数据保留到删除账号为止；删除账号会一并清除已同步的数据与会话。本地数据保留在本机，直到你卸载应用或自行删除。',
        '伺服器資料保留到刪除帳號為止；刪除帳號會一併清除已同步的資料與工作階段。本機資料保留在本機，直到你卸載應用或自行刪除。',
      ),
    ),
    _PrivacySection(
      pick('Beta notice', '测试期说明', '測試期說明'),
      pick(
        'Sync currently runs on a beta environment. Its data may be reset and it '
            'is not meant for sensitive information.',
        '云同步目前运行在 beta 环境，数据可能被重置，不适合存放敏感信息。',
        '雲端同步目前運行在 beta 環境，資料可能被重置，不適合存放敏感資訊。',
      ),
    ),
    _PrivacySection(
      pick('Your controls', '你的选择', '你的選擇'),
      pick(
        'Sync can be switched off per category in settings, and signing out '
            'stops every upload. Deleting the account is available while signed '
            'in; local data is unaffected by that choice.',
        '在设置里可以按分类关闭同步，退出登录会立即停止上传。登录后可以删除账号；删除账号不影响本机数据。',
        '在設定裡可以按分類關閉同步，登出會立即停止上傳。登入後可以刪除帳號；刪除帳號不影響本機資料。',
      ),
    ),
  ];
}
