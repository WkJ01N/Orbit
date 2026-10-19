import 'package:flutter/widgets.dart';

class LaunchText {
  LaunchText(BuildContext context) : locale = Localizations.localeOf(context);
  final Locale locale;
  String t(String en, String hans, String hant) => locale.languageCode != 'zh'
      ? en
      : locale.scriptCode == 'Hans' || locale.countryCode == 'CN'
      ? hans
      : hant;
  String get title => t('Startup & page animations', '启动与页面动画', '啟動與頁面動畫');
  String get transition => t('Page transition style', '页面过渡风格', '頁面過渡風格');
  String get compact => t('Crisp', '干净利落', '乾淨俐落');
  String get fluid => t('Fluid', '流畅', '流暢');
  String get speed => t('Transition speed', '过渡速度', '過渡速度');
  String get fast => t('Fast · 280 ms', '快速 · 280ms', '快速 · 280ms');
  String get standard => t('Standard · 360 ms', '标准 · 360ms', '標準 · 360ms');
  String get relaxed => t('Relaxed · 440 ms', '舒缓 · 440ms', '舒緩 · 440ms');
  String get icon => t('Startup icon', '启动页图标', '啟動頁圖示');
  String get iconHint => t(
    'Choose a circular image for the startup screen.',
    '选择启动画面中的圆形图标。',
    '選擇啟動畫面中的圓形圖示。',
  );
  String get choose => t('Choose image', '选择图片', '選擇圖片');
  String get crop => t('Crop startup icon', '裁剪启动页图标', '裁切啟動頁圖示');
  String get restore => t('Restore default', '恢复默认', '恢復預設');
  String get cards => t('Course entrance', '课程滑入方式', '課程滑入方式');
  String get edge => t('From timetable edges', '从课表上下边缘滑入', '從課表上下邊緣滑入');
  String get nearby => t('From nearby', '从最终位置附近滑入', '從最終位置附近滑入');
  String get stagger => t(
    'Both styles use balanced directions and staggered starts.',
    '两种方式均上下均衡、随机错峰入场。',
    '兩種方式均上下均衡、隨機錯峰入場。',
  );
  String get preview => t('Preview full animation', '预览完整动画', '預覽完整動畫');
  String get hint => t(
    'Plays on a fresh launch. System reduced-motion preferences are respected.',
    '仅全新启动播放，并遵循系统减少动画设置。',
    '僅全新啟動播放，並遵循系統減少動畫設定。',
  );
  String get failed => t(
    'Could not save. Try another image or try again.',
    '保存失败，请重试或选择其他图片。',
    '儲存失敗，請重試或選擇其他圖片。',
  );
  String get tooLarge => t(
    'Choose an image smaller than 10 MB.',
    '请选择小于 10 MB 的图片。',
    '請選擇小於 10 MB 的圖片。',
  );
}
