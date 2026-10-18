import 'package:flutter/widgets.dart';
import 'package:orbit/models/orbit_feature_text.dart';

class V162Text extends OrbitFeatureText {
  const V162Text(super.locale);
  factory V162Text.of(BuildContext context) =>
      V162Text(Localizations.localeOf(context));
  String get exam => pick('Exam', '考试', '考試');
  String get addExam => pick('Add exam', '添加考试', '新增考試');
  String get editExam => pick('Edit exam', '编辑考试', '編輯考試');
  String get exams => pick('Exams completed', '已完成考试', '已完成考試');
  String get examHint => pick(
    'Choose a course or enter a name. Set the date, time and location yourself.',
    '可选择已有课程或填写考试名称，请手动设置考试日期、时间和地点。',
    '可選擇已有課程或填寫考試名稱，請手動設定考試日期、時間及地點。',
  );
  String get examRequired => pick(
    'Enter an exam name and location, and choose its date, start and end time.',
    '请填写考试名称和地点，并选择日期、开始时间和结束时间。',
    '請填寫考試名稱及地點，並選擇日期、開始時間及結束時間。',
  );
  String get leadInvalid => pick(
    'Enter a whole number from 0 to 10080 minutes.',
    '提醒提前时间须为 0 至 10080 的整数分钟。',
    '提醒提前時間須為 0 至 10080 的整數分鐘。',
  );
  String get reminder => pick('Exam reminder', '考试提醒', '考試提醒');
  String get strong => pick('Strong reminder', '强提醒', '強提醒');
  String get lead => pick('Minutes before exam', '考试前多少分钟提醒', '考試前多少分鐘提醒');
  String get nextDay => pick('Ends the following day', '次日结束', '次日結束');
  String get allSemesters => pick('All semesters', '全部学期', '全部學期');
  String get currentSemester => pick('This semester', '本学期', '本學期');
  String get semester => pick('Semester', '学期', '學期');
  String get manageSemesters => pick('Manage semesters', '管理学期', '管理學期');
  String get unknownSemester => pick('Unidentified semester', '未识别学期', '未識別學期');
  String get allCourses => pick('All finished courses', '全部已学完课程', '全部已學完課程');
  String get viewAll => pick('View all', '查看全部', '查看全部');
  String get lifetime => pick('Lifetime', '累计', '累計');
  String get name => pick('Name', '名称', '名稱');
  String get start => pick('Start date', '开始日期', '開始日期');
  String get end => pick('End date', '结束日期', '結束日期');
  String get save => pick('Save', '保存', '儲存');
  String get cancel => pick('Cancel', '取消', '取消');
  String get invalidRange => pick(
    'Check the name and dates. Semester dates must not overlap.',
    '请检查名称和日期，学期日期不能重叠。',
    '請檢查名稱及日期，學期日期不能重疊。',
  );
  String get assign => pick('Change semester', '修改学期归属', '修改學期歸屬');
  String get fallbacks => pick('Fallback fonts', '替补字体', '替補字型');
  String get fallbackHint => pick(
    'Up to 3 fonts. Lower numbers take priority for missing characters; the system font is always last.',
    '最多三种，数字越小、位置越靠上越优先补缺，最后使用系统默认字体。',
    '最多三種，數字越小、位置越靠上越優先補缺，最後使用系統預設字型。',
  );
  String get addFallback => pick('Add fallback font', '添加替补字体', '新增替補字型');
  String get systemFallback =>
      pick('Use system fallback only', '仅使用系统补缺', '僅使用系統補缺');
  String get noChinese => pick(
    'This font has no Chinese characters. Choose fallback fonts or use the system font for missing characters.',
    '此字体不含中文字形，请选择替补字体，或明确选择使用系统字体补缺。',
    '此字型不含中文字形，請選擇替補字型，或明確選擇使用系統字型補缺。',
  );
  String get animationTitle =>
      pick('Startup & page animations', '启动与页面动画', '啟動與頁面動畫');
  String get brandAnimation =>
      pick('Brand startup animation', '品牌启动动画', '品牌啟動動畫');
  String get pageAnimations => pick('Page entrances', '页面入场动画', '頁面入場動畫');
  String get animationTriggers =>
      pick('Play entrances when', '入场动画播放时机', '入場動畫播放時機');
  String get onStartup => pick('Starting the app', '启动应用时', '啟動應用程式時');
  String get onResume => pick('Returning to foreground', '切回前台时', '切回前景時');
  String get onSwitch => pick(
    'Switching pages or returning from a subpage',
    '切换页面或从二级页返回时',
    '切換頁面或從次級頁返回時',
  );
}
