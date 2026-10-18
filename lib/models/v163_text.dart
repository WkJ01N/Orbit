import 'package:flutter/widgets.dart';
import 'package:orbit/models/orbit_feature_text.dart';

class V163Text extends OrbitFeatureText {
  const V163Text(super.locale);
  factory V163Text.of(BuildContext context) =>
      V163Text(Localizations.localeOf(context));

  String get fallbackDescription => pick(
    'Use fallback fonts when glyphs are missing',
    '当字体缺失时使用替补字体',
    '當字型缺失時使用替補字型',
  );
  String endedCourses(int count) =>
      pick('View ended courses ($count)', '查看已结束课程（$count）', '查看已結束課程（$count）');
  String get semesterHint => pick(
    'Choose a semester or enter a new name; leave blank to infer from dates',
    '选择学期或填写新名称，留空按日期推断',
    '選擇學期或填寫新名稱，留空按日期推斷',
  );
  String get quickActions => pick('Course quick actions', '课程快捷栏', '課程快捷欄');
  String get quickActionsHint => pick(
    'Hold a course or exam and slide to an action',
    '长按课程或考试，滑动选择功能',
    '長按課程或考試，滑動選擇功能',
  );
  String get edgeMode => pick('Actions near an edge', '边缘处理方式', '邊緣處理方式');
  String get merge => pick('Merge onto available sides', '合并到可用侧', '合併到可用側');
  String get floatInward => pick('Float inward', '向内悬浮', '向內懸浮');
  String get actionPositions => pick('Action positions', '功能位置', '功能位置');
  String get resetPositions => pick('Reset positions', '恢复默认位置', '恢復預設位置');
  List<String> get directions => [
    pick('Top', '上', '上'),
    pick('Right', '右', '右'),
    pick('Bottom', '下', '下'),
    pick('Left', '左', '左'),
  ];
}
