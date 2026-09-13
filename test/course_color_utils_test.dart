import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit/core/theme/app_theme.dart';
import 'package:orbit/models/course_session.dart';
import 'package:orbit/services/course_color_utils.dart';

CourseSession _session({required String code, required String name}) {
  final date = DateTime(2026, 6, 1);
  final startAt = DateTime(2026, 6, 1, 10, 0);
  return CourseSession(
    id: 'id',
    classType: '一般課堂',
    room: 'A101',
    date: date,
    weekday: date.weekday,
    courseName: name,
    courseCode: code,
    section: '1',
    startAt: startAt,
    endAt: startAt.add(const Duration(hours: 1)),
    teachers: const [],
    faculty: '',
    semester: '',
  );
}

void main() {
  test('Windows 中文主题统一使用微软雅黑 UI', () {
    final theme = AppTheme.light(useWindowsCjkFont: true);
    expect(theme.textTheme.bodyMedium?.fontFamily, 'Microsoft YaHei UI');
    expect(
      theme.textTheme.bodyMedium?.fontFamilyFallback,
      contains('Microsoft YaHei'),
    );
  });

  test('courseColorKey 优先使用课程编号', () {
    expect(courseColorKey(_session(code: 'PHYS101', name: '物理')), 'PHYS101');
  });

  test('courseColorKey 编号为空时回退课程名', () {
    expect(courseColorKey(_session(code: '  ', name: ' 物理 ')), '物理');
  });

  test('contrastForegroundFor 根据亮度选择前景色', () {
    expect(contrastForegroundFor(Colors.white), Colors.black);
    expect(contrastForegroundFor(Colors.black), Colors.white);
  });

  test('彩色主题为同一课程生成稳定颜色', () {
    final session = _session(code: 'PHYS101', name: '物理');
    final first = automaticCourseColor(session, brightness: Brightness.light);
    final second = automaticCourseColor(session, brightness: Brightness.light);
    expect(first, second);
  });

  test('课程自定义颜色优先于主题默认颜色', () {
    final session = _session(code: 'PHYS101', name: '物理');
    const custom = Color(0xFF123456);
    final resolved = resolvedCourseColor(
      session: session,
      colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
      themeStyle: AppThemeStyle.colorful,
      override: custom,
    );
    expect(resolved, custom);
  });

  test('彩色主题分别适配浅色和深色课程颜色', () {
    final session = _session(code: 'PHYS101', name: '物理');
    expect(
      automaticCourseColor(session, brightness: Brightness.light),
      isNot(automaticCourseColor(session, brightness: Brightness.dark)),
    );
  });
}
