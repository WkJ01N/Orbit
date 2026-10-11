import 'package:flutter/widgets.dart';
import 'package:orbit/models/orbit_feature_text.dart';

class StatisticsText extends OrbitFeatureText {
  const StatisticsText(super.locale);
  factory StatisticsText.of(BuildContext context) =>
      StatisticsText(Localizations.localeOf(context));
  String get title => pick('Statistics', '统计信息', '統計資訊');
  String get activeDays => pick('Days used', '实际使用天数', '實際使用天數');
  String get firstUsed => pick('First used on', '首次使用日期', '首次使用日期');
  String get sessions => pick('Classes attended', '已上课次', '已上課次');
  String get duration => pick('Total class time', '累计上课时长', '累計上課時長');
  String get deadlines => pick('DDL completed', 'DDL 完成总数', 'DDL 完成總數');
  String get learned => pick('Courses finished', '学完的课程', '學完的課程');
  String get noLearnedCourses =>
      pick('No finished courses yet', '暂时没有学完的课程', '暫時沒有學完的課程');
  String get statisticsHint => pick(
    'Class totals follow your timetable; they do not verify attendance.',
    '课程统计按课表自动计算，不代表实际出勤记录。',
    '課程統計依課表自動計算，不代表實際出席紀錄。',
  );
  String get deleteWithStatistics => pick(
    'Also remove statistics for these classes',
    '同时删除对应统计信息',
    '同時刪除對應統計資訊',
  );
  String get mergeGuest => pick(
    'Merge guest statistics into this account',
    '将游客统计合并到此账号',
    '將訪客統計合併至此帳號',
  );
  String get include =>
      pick('Count toward statistics when completed', '完成后计入统计', '完成後計入統計');
  String get selectStatistics => pick('Restore statistics', '恢复统计信息', '還原統計資訊');
  String minutes(int n) => pick(
    '${n ~/ 60} h ${n % 60} min',
    '${n ~/ 60} 小时 ${n % 60} 分钟',
    '${n ~/ 60} 小時 ${n % 60} 分鐘',
  );
}
