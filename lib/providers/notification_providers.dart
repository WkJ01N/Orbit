import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

final foregroundReminderMaintenanceSupportedProvider = Provider<bool>(
  (ref) => Platform.isAndroid || Platform.isWindows,
);

final pendingNotificationPayloadProvider = StateProvider<String?>(
  (ref) => null,
);

final notificationTapHandlerProvider = Provider<void Function(String?)>(
  (ref) => (payload) {
    ref.read(pendingNotificationPayloadProvider.notifier).state = payload;
  },
);
