import 'package:orbit/models/course_session.dart';

bool isSessionFullyInRange(
  CourseSession session,
  DateTime rangeStart,
  DateTime rangeEnd,
) {
  return !session.startAt.isBefore(rangeStart) &&
      !session.endAt.isAfter(rangeEnd);
}
