import 'dart:async';
import 'dart:io';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbit/core/routing/app_tab.dart';
import 'package:orbit/features/grid/week_calendar_utils.dart';
import 'package:orbit/features/deadline/deadline_ui.dart';
import 'package:orbit/features/session/session_detail_sheet.dart';
import 'package:orbit/providers/app_providers.dart';
import 'package:orbit/providers/notification_providers.dart';
import 'package:orbit/services/reminder_scheduler.dart';
import 'package:orbit/services/tray_service.dart';

class OrbitNotificationListener extends ConsumerStatefulWidget {
  const OrbitNotificationListener({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<OrbitNotificationListener> createState() =>
      _OrbitNotificationListenerState();
}

class _OrbitNotificationListenerState
    extends ConsumerState<OrbitNotificationListener>
    with WidgetsBindingObserver {
  bool _launchPayloadLoaded = false;
  bool _initialPayloadChecked = false;
  Timer? _foregroundResync;
  bool _resyncRunning = false;
  bool _clockPaused = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _launchPayloadLoaded = ref.read(pendingNotificationPayloadProvider) != null;
    ReminderScheduler.shared.registerNotificationTapHandler(
      (payload) => ref.read(notificationTapHandlerProvider)(payload),
    );
  }

  @override
  void dispose() {
    _foregroundResync?.cancel();
    ReminderScheduler.shared.registerNotificationTapHandler(null);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _clockPaused = false;
      ref.read(currentTimeProvider.notifier).syncNow();
      _foregroundResync?.cancel();
      // Let the restored window paint before maintenance and coalesce focus
      // changes. A hidden window does not need minute-by-minute UI rebuilds.
      _foregroundResync = Timer(const Duration(milliseconds: 350), () {
        _foregroundResync = null;
        unawaited(_maybeResyncOnForeground());
      });
    } else {
      _foregroundResync?.cancel();
      if (state == AppLifecycleState.inactive && _clockPaused) {
        _clockPaused = false;
        ref.read(currentTimeProvider.notifier).syncNow();
      }
      if (state == AppLifecycleState.hidden ||
          state == AppLifecycleState.paused ||
          state == AppLifecycleState.detached) {
        _clockPaused = true;
        ref.read(currentTimeProvider.notifier).pauseTicks();
      }
    }
  }

  Future<void> _maybeResyncOnForeground() async {
    if (!mounted ||
        _resyncRunning ||
        (!Platform.isAndroid && !Platform.isWindows)) {
      return;
    }
    _resyncRunning = true;
    try {
      final scheduler = ref.read(reminderSchedulerProvider);
      if (!await scheduler.shouldResyncOnForeground() || !mounted) return;
      if (!ref.read(reminderSettingsProvider).hasValue) return;
      await ref.read(reminderSettingsProvider.notifier).resyncReminders();
    } catch (error, stack) {
      debugPrint('Foreground reminder sync failed: $error\n$stack');
    } finally {
      _resyncRunning = false;
    }
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
      try {
        final payload = await ref
            .read(reminderSchedulerProvider)
            .getLaunchNotificationPayload();
        if (payload != null && mounted) {
          ref.read(pendingNotificationPayloadProvider.notifier).state = payload;
        }
      } catch (error, stack) {
        debugPrint('Notification launch payload failed: $error\n$stack');
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

    if (!_initialPayloadChecked) {
      _initialPayloadChecked = true;
      final initial = ref.read(pendingNotificationPayloadProvider);
      if (initial != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _handlePayload(context, initial);
          ref.read(pendingNotificationPayloadProvider.notifier).state = null;
        });
      }
    }
    return widget.child;
  }

  Future<void> _handlePayload(BuildContext context, String payload) async {
    if (payload.startsWith('{')) {
      final data = jsonDecode(payload) as Map<String, dynamic>;
      if (data['action'] == 'ack') {
        await ReminderScheduler.shared.acknowledgeOccurrence(
          ref.read(appDatabaseProvider),
          data['rule'] as String,
          data['session'] as String,
        );
        await ref.read(reminderSettingsProvider.notifier).resyncReminders();
        return;
      }
      if (data['identity'] is String && data['index'] is int) {
        await ref
            .read(appDatabaseProvider)
            .markReminderProcessed(
              data['rule'] as String,
              data['identity'] as String,
              data['index'] as int,
            );
      }
      payload = data['session'] as String;
    }
    // On Windows the window may be hidden in the tray; surface it so tapping a
    // notification has a visible effect instead of silently routing.
    if (Platform.isWindows) {
      await showMainWindow();
    }

    if (payload.startsWith('deadline:')) {
      final deadline = await ref
          .read(appDatabaseProvider)
          .getDeadlineById(payload.substring('deadline:'.length));
      if (deadline != null && context.mounted) {
        await showDeadlineDetails(context, deadline);
      }
      return;
    }

    if (payload.startsWith('next_day')) {
      navigateToAppTab(ref, AppTab.upcoming);
      return;
    }

    final sessionId = payload.startsWith('checkin_')
        ? payload.substring('checkin_'.length)
        : payload;

    final session = await ref
        .read(scheduleRepositoryProvider)
        .getSessionById(sessionId);
    if (!context.mounted || session == null) {
      navigateToAppTab(ref, AppTab.upcoming);
      return;
    }

    ref.read(selectedWeekStartProvider.notifier).state = weekStartFor(
      session.date,
    );
    navigateToAppTab(ref, AppTab.grid);

    if (!context.mounted) {
      return;
    }

    await SessionDetailSheet.show(context, session);
  }
}
