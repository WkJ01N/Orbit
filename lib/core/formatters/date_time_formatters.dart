import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

String formatShortDate(DateTime date) {
  return DateFormat('M/d').format(date);
}

String formatIsoDate(DateTime date) {
  return DateFormat('yyyy-MM-dd').format(date);
}

String formatDateTimeMinute(DateTime value) {
  return DateFormat('yyyy/M/d HH:mm').format(value);
}

String formatTimeHm(DateTime value) {
  return '${value.hour.toString().padLeft(2, '0')}:'
      '${value.minute.toString().padLeft(2, '0')}';
}

DateTime combineDateAndTime(DateTime date, TimeOfDay time) {
  return DateTime(date.year, date.month, date.day, time.hour, time.minute);
}
