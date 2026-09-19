import 'dart:convert';
import 'package:crypto/crypto.dart';

String normalizeImportIdentity(String value) =>
    value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
String courseImportIdentity(
  String name,
  String section,
  List<String> teachers,
  String faculty,
) => jsonEncode([
  normalizeImportIdentity(name),
  normalizeImportIdentity(section),
  [...teachers.map(normalizeImportIdentity)]..sort(),
  normalizeImportIdentity(faculty),
]);
String generatedImportCourseCode(String identity) =>
    'IMPORT|${sha256.convert(utf8.encode(identity))}';
