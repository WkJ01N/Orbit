import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
  test('courseColorKey 优先使用课程编号', () {
    expect(
      courseColorKey(_session(code: 'PHYS101', name: '物理')),
      'PHYS101',
    );
  });

  test('courseColorKey 编号为空时回退课程名', () {
    expect(
      courseColorKey(_session(code: '  ', name: ' 物理 ')),
      '物理',
    );
  });

  test('contrastForegroundFor 根据亮度选择前景色', () {
    expect(contrastForegroundFor(Colors.white), Colors.black87);
    expect(contrastForegroundFor(Colors.black), Colors.white);
  });
}
