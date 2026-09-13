import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:orbit/app.dart';
import 'package:orbit/core/widgets/adjacent_page_pager.dart';
import 'package:orbit/core/widgets/app_snack_bar.dart';
import 'package:orbit/features/settings/theme_scheme_page.dart';
import 'package:orbit/main.dart' as orbit;
import 'package:orbit/models/course_session.dart';
import 'package:orbit/models/reminder_settings.dart';
import 'package:orbit/providers/app_providers.dart';
import 'package:orbit/providers/permission_providers.dart';
import 'package:orbit/services/notification_permission_service.dart';
import 'package:orbit/services/settings_service.dart';
import 'package:orbit/core/theme/app_theme.dart';
import 'package:orbit/l10n/app_localizations.dart';

/// Run only on an isolated Android test device. The permission phase expects
/// POST_NOTIFICATIONS denied with user-fixed initially; after the READY marker,
/// grant it through adb and return to MainActivity to verify lifecycle refresh.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Android permission, theme, interrupted paging and variable list', (
    tester,
  ) async {
    final settings = SettingsService();
    await settings.saveLocale(const Locale('en'));
    await settings.savePermissionWarningIgnored(false);
    await settings.save(
      const ReminderSettings(
        enabled: false,
        checkInReminderEnabled: false,
        nextDaySummaryEnabled: false,
      ),
    );
    await settings.saveThemeStyle(AppThemeStyle.colorful);
    await settings.saveMulticolorSettings(
      const MulticolorSettings(enabled: true),
    );
    final day = DateUtils.dateOnly(DateTime.now().add(const Duration(days: 1)));
    final db = await openAppDatabase();
    await db.upsertSessions([
      for (var i = 0; i < 100; i++)
        CourseSession(
          id: 'device-validation-$i',
          courseCode: 'DV$i',
          section: '1',
          courseName: i % 3 == 0
              ? 'A variable height course title with enough text to wrap over multiple lines $i'
              : 'Device course $i',
          date: day.add(Duration(days: i)),
          weekday: day.add(Duration(days: i)).weekday,
          startAt: day.add(Duration(days: i, hours: 10)),
          endAt: day.add(Duration(days: i, hours: 12)),
          classType: 'Class',
          room: 'A101',
          teachers: const ['Test teacher'],
          faculty: 'Test',
          semester: 'Test',
        ),
    ]);
    await db.close();
    debugPrint('ORBIT_DEVICE_INIT_READY');
    await Future<void>.delayed(const Duration(seconds: 2));
    await orbit.main([]);
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(OrbitApp)),
    );
    expect(
      await container.read(notificationPermissionProvider.future),
      NotificationPermissionState.denied,
    );
    expect(find.byKey(const Key('notification-ignore')), findsOneWidget);
    await container.read(reminderSettingsProvider.future);
    debugPrint('ORBIT_DEVICE_APP_READY');

    container.read(appNavIndexProvider.notifier).state = 3;
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.widgetWithText(ListTile, 'Multicolor palette'),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'Multicolor palette'));
    await tester.pumpAndSettle();
    expect(find.byType(ThemeSchemePage), findsOneWidget);
    expect(find.byKey(const Key('notification-ignore')), findsOneWidget);
    expect(
      tester.getRect(find.byKey(const Key('notification-open'))).bottom,
      lessThan(tester.getRect(find.byType(AppBar)).top),
    );
    await tester.tap(find.byKey(const Key('notification-ignore')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(await settings.loadPermissionWarningIgnored(), false);
    await tester.tap(find.byKey(const Key('notification-ignore')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirm ignore'));
    await tester.pumpAndSettle();
    expect(await settings.loadPermissionWarningIgnored(), true);
    await container
        .read(permissionWarningIgnoredProvider.notifier)
        .setIgnored(false);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('notification-open')));
    debugPrint('ORBIT_DEVICE_PERMISSION_READY');
    var allowed = false;
    for (var i = 0; i < 120; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 250));
      if (await container.read(notificationPermissionServiceProvider).query() ==
          NotificationPermissionState.allowed) {
        allowed = true;
        break;
      }
    }
    expect(
      allowed,
      true,
      reason: 'Grant notification permission and restore MainActivity',
    );
    for (var i = 0; i < 24; i++) {
      await tester.pump(const Duration(milliseconds: 250));
      if (container.read(notificationPermissionProvider).value ==
          NotificationPermissionState.allowed) {
        break;
      }
    }
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('notification-ignore')), findsNothing);
    debugPrint('ORBIT_DEVICE_PERMISSION_PASSED');
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('settings-category-2')));
    await tester.pumpAndSettle();
    final l10n = AppLocalizations.of(
      tester.element(find.byKey(const Key('settings-category-2'))),
    )!;
    final backgroundDescription = find.text(l10n.androidBackgroundSubtitle);
    await tester.scrollUntilVisible(
      backgroundDescription,
      300,
      scrollable: find.descendant(
        of: find.byKey(const Key('settings-category-content-2')),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.pumpAndSettle();
    final backgroundCard = find.ancestor(
      of: backgroundDescription,
      matching: find.byType(Card),
    );
    final backgroundSurface = find
        .descendant(of: backgroundCard, matching: find.byType(Material))
        .first;
    expect(
      tester.getRect(backgroundDescription).top -
          tester.getRect(backgroundSurface).top,
      closeTo(16, .1),
    );
    debugPrint('ORBIT_DEVICE_BACKGROUND_SPACING_PASSED');
    container.read(appNavIndexProvider.notifier).state = 0;
    container.read(selectedScheduleDateProvider.notifier).state = day;
    await tester.pumpAndSettle();
    final before = container.read(selectedScheduleDateProvider);
    final pager = find.byType(AdjacentPagePager);
    final drag = await tester.startGesture(tester.getCenter(pager));
    await drag.moveBy(const Offset(-180, 0));
    await drag.up();
    await tester.pump(const Duration(milliseconds: 60));
    final reverse = await tester.startGesture(tester.getCenter(pager));
    await reverse.moveBy(const Offset(220, 0));
    await reverse.up();
    await tester.pumpAndSettle();
    expect(container.read(selectedScheduleDateProvider), before);
    debugPrint('ORBIT_DEVICE_PAGER_PASSED');

    container.read(appNavIndexProvider.notifier).state = 1;
    await tester.pumpAndSettle();
    final scroll = find.byKey(const Key('upcoming-scroll-view'));
    for (var i = 0; i < 6; i++) {
      await tester.fling(scroll, const Offset(0, -600), 1500);
      await tester.pump(const Duration(milliseconds: 120));
    }
    await tester.pumpAndSettle();
    final button = find
        .byKey(const ValueKey('upcoming-back-to-top-floating'))
        .hitTestable();
    final paint = tester.widget<CustomPaint>(
      find
          .descendant(
            of: button,
            matching: find.byWidgetPredicate(
              (w) =>
                  w is CustomPaint &&
                  w.painter?.runtimeType.toString() == '_ReturnToTopPainter',
            ),
          )
          .first,
    );
    expect((paint.painter as dynamic).progress, inInclusiveRange(0.0, 1.0));
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('upcoming-back-to-top-floating')).hitTestable(),
      findsNothing,
    );

    debugPrint('ORBIT_DEVICE_SCROLL_PASSED');
    final messenger = ScaffoldMessenger.of(tester.element(scroll));
    messenger.showAppSnackBar(
      const SnackBar(content: Text('Device exit animation')),
    );
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    final messageOpacity = find.ancestor(
      of: find.text('Device exit animation'),
      matching: find.byType(Opacity),
    );
    expect(
      tester.widget<Opacity>(messageOpacity).opacity,
      allOf(greaterThan(0), lessThan(1)),
    );
    final enteringY = tester.getTopLeft(find.text('Device exit animation')).dy;
    await tester.pumpAndSettle();
    final restingY = tester.getTopLeft(find.text('Device exit animation')).dy;
    expect(enteringY, greaterThan(restingY));
    await tester.tap(find.byTooltip('Close'));
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('Device exit animation'), findsOneWidget);
    expect(
      tester.widget<Opacity>(messageOpacity).opacity,
      allOf(greaterThan(0), lessThan(1)),
    );
    expect(
      tester.getTopLeft(find.text('Device exit animation')).dy,
      greaterThan(restingY),
    );
    await tester.pumpAndSettle();
    expect(find.text('Device exit animation'), findsNothing);
    // Follow real rendered frames for the operations reported by the user,
    // rather than only driving a synthetic message with a timed pump.
    binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
    final operationFrames = <String, int>{};
    Future<void> verifyOperationMessage(
      String message, {
      bool undo = false,
    }) async {
      final text = find.text(message);
      for (var i = 0; i < 1200 && text.evaluate().isEmpty; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(text, findsOneWidget);
      final opacity = find.ancestor(of: text, matching: find.byType(Opacity));
      final samples = <double>[];
      final positions = <double>[];
      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        final value = tester.widget<Opacity>(opacity).opacity;
        if (value > 0 && value < 1) {
          samples.add(value);
          positions.add(tester.getTopLeft(text).dy);
        }
        if (value == 1) break;
      }
      expect(
        samples.length,
        greaterThanOrEqualTo(3),
        reason: '$message must render several intermediate entry frames',
      );
      expect(positions.first - positions.last, greaterThan(4));
      await tester.pumpAndSettle();
      if (undo) {
        await tester.tap(find.text(l10n.actionUndo));
      } else {
        await tester.tap(find.byTooltip('Close'));
      }
      await tester.pump(const Duration(milliseconds: 60));
      expect(text, findsOneWidget);
      expect(
        tester.widget<Opacity>(opacity).opacity,
        allOf(greaterThan(0), lessThan(1)),
      );
      if (undo) {
        for (var i = 0; i < 60 && text.evaluate().isNotEmpty; i++) {
          await tester.pump(const Duration(milliseconds: 16));
        }
      } else {
        await tester.pumpAndSettle();
      }
      expect(text, findsNothing);
      operationFrames[message] = samples.length;
      debugPrint(
        'ORBIT_OPERATION_MESSAGE_PASSED: $message, entryFrames=${samples.length}',
      );
    }

    container.read(appNavIndexProvider.notifier).state = 3;
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('settings-category-2')));
    await container.read(reminderSettingsProvider.notifier).setEnabled(true);
    await tester.pumpAndSettle();
    final sync = find.widgetWithText(ListTile, l10n.resyncReminders);
    await tester.scrollUntilVisible(
      sync,
      300,
      scrollable: find.descendant(
        of: find.byKey(const Key('settings-category-content-2')),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(sync);
    for (
      var i = 0;
      i < 1200 &&
          find.byWidgetPredicate((w) => w is SnackBar).evaluate().isEmpty;
      i++
    ) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    final syncBar = tester.widget<SnackBar>(
      find.byWidgetPredicate((w) => w is SnackBar),
    );
    final syncMessage = (syncBar.content as Text).data!;
    expect(syncMessage, contains(l10n.resyncDone));
    await verifyOperationMessage(syncMessage);

    container.read(appNavIndexProvider.notifier).state = 1;
    await tester.pumpAndSettle();
    final firstCourse = (await container.read(sessionsProvider.future)).first;
    await tester.ensureVisible(find.text(firstCourse.courseName));
    await tester.pumpAndSettle();
    await tester.tap(find.text(firstCourse.courseName));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.delete_outline));
    for (
      var i = 0;
      i < 300 && find.byType(AlertDialog).evaluate().isEmpty;
      i++
    ) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, l10n.actionDelete));
    await verifyOperationMessage(l10n.sessionDeleted, undo: true);
    await verifyOperationMessage(l10n.trashRestoreResult(1, 0));
    expect(
      (await container.read(
        sessionsProvider.future,
      )).any((s) => s.id == firstCourse.id),
      true,
    );
    await container.read(reminderSettingsProvider.notifier).setEnabled(false);
    binding.reportData = {
      'platform': 'Android 35 x86_64',
      'courses': 100,
      'permissionRecovery': allowed,
      'interruptedPaging': true,
      'variableListAndMessageExit': true,
      'realOperationMessageFrames': operationFrames,
    };
    expect(tester.takeException(), isNull);
  });
}
