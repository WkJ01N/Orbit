import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbit/core/routing/app_tab.dart';
import 'package:orbit/features/grid/week_calendar_utils.dart';
import 'package:orbit/features/session/session_detail_sheet.dart';
import 'package:orbit/providers/app_providers.dart';
import 'package:orbit/providers/notification_providers.dart';
import 'package:orbit/services/reminder_scheduler.dart';

class OrbitNotificationListener extends ConsumerStatefulWidget {
  const OrbitNotificationListener({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<OrbitNotificationListener> createState() =>
      _OrbitNotificationListenerState();
}

class _OrbitNotificationListenerState
    extends ConsumerState<OrbitNotificationListener> with WidgetsBindingObserver {
  bool _launchPayloadLoaded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    ReminderScheduler.shared.registerNotificationTapHandler(
      (payload) => ref.read(notificationTapHandlerProvider)(payload),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _maybeResyncOnForeground();
    }
  }

  Future<void> _maybeResyncOnForeground() async {
    if (!Platform.isAndroid && !Platform.isWindows) {
      return;
    }
    if (!ReminderScheduler.shared.shouldResyncOnForeground()) {
      return;
    }
    if (!ref.read(reminderSettingsProvider).hasValue) {
      return;
    }
    await ref.read(reminderSettingsProvider.notifier).resyncReminders();
  }

  void _scheduleLaunchPayloadLoad() {
    if (_launchPayloadLoaded) {
      return;
    }
    _launchPayloadLoaded = true;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) {
        return;
      }
      final payload =
          await ReminderScheduler.shared.getLaunchNotificationPayload();
      if (payload != null && mounted) {
        ref.read(pendingNotificationPayloadProvider.notifier).state = payload;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(reminderSettingsProvider, (previous, next) {
      if (next.hasValue) {
        _scheduleLaunchPayloadLoad();
      }
    });
    if (ref.read(reminderSettingsProvider).hasValue) {
      _scheduleLaunchPayloadLoad();
    }

    ref.listen<String?>(pendingNotificationPayloadProvider, (previous, next) {
      if (next != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) {
            return;
          }
          _handlePayload(context, next);
          ref.read(pendingNotificationPayloadProvider.notifier).state = null;
        });
      }
    });

    return widget.child;
  }

  Future<void> _handlePayload(BuildContext context, String payload) async {
    if (payload.startsWith('next_day')) {
      navigateToAppTab(ref, AppTab.upcoming);
      return;
    }

    final sessionId = payload.startsWith('checkin_')
        ? payload.substring('checkin_'.length)
        : payload;

    final session =
        await ref.read(scheduleRepositoryProvider).getSessionById(sessionId);
    if (!context.mounted || session == null) {
      navigateToAppTab(ref, AppTab.upcoming);
      return;
    }

    ref.read(selectedWeekStartProvider.notifier).state =
        weekStartFor(session.date);
    navigateToAppTab(ref, AppTab.grid);

    if (!context.mounted) {
      return;
    }

    await SessionDetailSheet.show(context, session);
  }
}
