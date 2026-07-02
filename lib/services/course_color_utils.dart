import 'package:flutter/material.dart';
import 'package:orbit/models/course_session.dart';

/// Stable key for per-course color overrides (code preferred, name fallback).
String courseColorKey(CourseSession session) {
  final code = session.courseCode.trim();
  if (code.isNotEmpty) {
    return code;
  }
  return session.courseName.trim();
}

Color contrastForegroundFor(Color background) {
  return background.computeLuminance() > 0.5 ? Colors.black87 : Colors.white;
}
