import 'package:flutter/widgets.dart';

class TypographyText {
  TypographyText(BuildContext context)
    : locale = Localizations.localeOf(context);
  final Locale locale;
  String t(String en, String hans, String hant) => locale.languageCode != 'zh'
      ? en
      : locale.scriptCode == 'Hans' || locale.countryCode == 'CN'
      ? hans
      : hant;
  String get title => t('Fonts', '字体', '字型');
  String get app => t('App interface font', '应用界面字体', '應用程式介面字型');
  String get launch => t('Startup wordmark font', '开屏字标字体', '啟動畫面字標字型');
  String get independent => t(
    'Interface and startup fonts are selected independently.',
    '界面字体与开屏字体分别设置，互不影响。',
    '介面字型與啟動畫面字型分別設定，互不影響。',
  );
  String get system => t('System default', '系统默认', '系統預設');
  String name(String id, [String? imported]) => switch (id) {
    'system' => system,
    'nunito' => t('Original wordmark · Nunito', '原字标 · Nunito', '原字標 · Nunito'),
    'rounded' => t('Resource Han Rounded', '资源圆体', '資源圓體'),
    'huninn' => t('jf open huninn', 'jf open 粉圆', 'jf open 粉圓'),
    'maiyuan' => t('Kingnam Maiyuan', '荆南麦圆', '荊南麥圓'),
    _ => imported ?? t('Imported font', '导入字体', '匯入字型'),
  };
  String get importFont =>
      t('Import TTF / OTF', '导入 TTF / OTF 字体', '匯入 TTF / OTF 字型');
  String get importHint => t(
    'Up to 50 MiB per file. Fonts in use are included in full backups; cloud sync does not carry fonts.',
    '每个文件不超过 50MiB；已使用字体随完整备份迁移，字体不参与云同步。',
    '每個檔案不超過 50MiB；使用中的字型隨完整備份遷移，字型不參與雲端同步。',
  );
  String get imported => t('Imported fonts', '导入的字体', '匯入的字型');
  String get apply => t('Use this font', '使用此字体', '使用此字型');
  String get preview => t('Font preview', '字体预览', '字型預覽');
  String get rename => t('Rename', '重命名', '重新命名');
  String get delete => t('Delete', '删除', '刪除');
  String get cancel => t('Cancel', '取消', '取消');
  String get save => t('Save', '保存', '儲存');
  String get deleteHint => t(
    'If this font is in use, the interface will return to System default and the startup wordmark to Nunito.',
    '如果此字体正在使用，删除后界面将恢复系统默认，开屏字标将恢复 Nunito。',
    '如果此字型正在使用，刪除後介面將恢復系統預設，啟動畫面字標將恢復 Nunito。',
  );
  String get failed => t(
    'Could not load or save this font. Choose a valid TTF / OTF file under 50 MiB.',
    '字体加载或保存失败，请选择有效且不超过 50MiB 的 TTF / OTF 文件。',
    '字型載入或儲存失敗，請選擇有效且不超過 50MiB 的 TTF / OTF 檔案。',
  );
  String get warning => t(
    'A saved font is unavailable. A default font is being used; select a font again.',
    '已选字体不可用，已使用默认字体，请重新选择。',
    '所選字型無法使用，已改用預設字型，請重新選擇。',
  );
}
