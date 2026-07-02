import 'package:flutter_test/flutter_test.dart';
import 'package:orbit/l10n/app_localizations_zh.dart';
import 'package:orbit/models/course_session.dart';
import 'package:orbit/models/notification_copy.dart';
import 'package:orbit/models/reminder_settings.dart';
import 'package:orbit/services/class_notification_builder.dart';
import 'package:orbit/services/notification_template_utils.dart';

CourseSession _sampleSession() {
  final date = DateTime(2026, 6, 1);
  final startAt = DateTime(2026, 6, 1, 10, 0);
  return CourseSession(
    id: '2026-06-01|PHYS|1|10:00',
    classType: '一般課堂',
    room: 'A101',
    date: date,
    weekday: date.weekday,
    courseName: '物理',
    courseCode: 'PHYS',
    section: '1',
    startAt: startAt,
    endAt: startAt.add(const Duration(hours: 1)),
    teachers: const ['Miku'],
    faculty: 'FIE',
    semester: '2606',
  );
}

NotificationCopy _copy() {
  return NotificationCopy.fromL10n(AppLocalizationsZh());
}

void main() {
  group('applyNotificationTemplate', () {
    test('空模板回退默认文案', () {
      expect(
        applyNotificationTemplate(null, 'default', {'course': '物理'}),
        'default',
      );
      expect(
        applyNotificationTemplate('  ', 'default', {'course': '物理'}),
        'default',
      );
    });

    test('替换占位符', () {
      expect(
        applyNotificationTemplate(
          '{course} @ {room}',
          'fallback',
          {'course': '物理', 'room': 'A001'},
        ),
        '物理 @ A001',
      );
    });
  });

  group('buildClassLeadNotificationText', () {
    test('无自定义模板时使用 l10n 默认', () {
      final session = _sampleSession();
      final text = buildClassLeadNotificationText(
        session: session,
        settings: const ReminderSettings(leadMinutes: 15),
        copy: _copy(),
        leadMinutes: 15,
      );
      expect(text.title, isNotEmpty);
      expect(text.body, contains(session.courseName));
      expect(text.bigText, contains(session.room));
    });

    test('自定义模板替换变量', () {
      final session = _sampleSession();
      final text = buildClassLeadNotificationText(
        session: session,
        settings: const ReminderSettings(
          classLeadTitleTemplate: '{course} 即将开始',
          classLeadBodyTemplate: '{room} · {minutes} 分钟',
        ),
        copy: _copy(),
        leadMinutes: 15,
      );
      expect(text.title, '${session.courseName} 即将开始');
      expect(text.body, '${session.room} · 15 分钟');
    });
  });

  group('buildCheckInNotificationText', () {
    test('自定义模板替换变量', () {
      final session = _sampleSession();
      final text = buildCheckInNotificationText(
        session: session,
        settings: const ReminderSettings(
          checkInTitleTemplate: '打卡：{course}',
          checkInBodyTemplate: '{time} @ {room}',
        ),
        copy: _copy(),
      );
      expect(text.title, '打卡：${session.courseName}');
      expect(text.body, contains(session.room));
      expect(text.body, contains('10:00'));
    });
  });
}
