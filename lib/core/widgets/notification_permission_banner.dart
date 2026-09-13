import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';
import 'package:orbit/l10n/app_localizations.dart';
import 'package:orbit/core/widgets/app_snack_bar.dart';
import 'package:orbit/providers/permission_providers.dart';
import 'package:orbit/providers/reminder_providers.dart';
import 'package:orbit/services/notification_permission_service.dart';

class NotificationPermissionHost extends ConsumerStatefulWidget {
  const NotificationPermissionHost({
    super.key,
    required this.child,
    required this.navigatorKey,
  });
  final Widget child;
  final GlobalKey<NavigatorState> navigatorKey;
  @override
  ConsumerState<NotificationPermissionHost> createState() =>
      _NotificationPermissionHostState();
}

class _NotificationPermissionHostState
    extends ConsumerState<NotificationPermissionHost>
    with WidgetsBindingObserver, WindowListener {
  bool _confirming = false;
  Timer? _refresh;
  NotificationPermissionState? _lastPermission;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (Platform.isWindows) windowManager.addListener(this);
  }

  void _scheduleRefresh() {
    _refresh?.cancel();
    _refresh = Timer(const Duration(milliseconds: 250), () {
      if (mounted) ref.invalidate(notificationPermissionProvider);
    });
  }

  Future<void> _resyncAfterPermissionRecovery() async {
    try {
      await ref.read(reminderSettingsProvider.future);
      if (mounted) {
        await ref.read(reminderSettingsProvider.notifier).resyncReminders();
      }
    } catch (error) {
      debugPrint('Permission recovery reminder resync failed: $error');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _scheduleRefresh();
  }

  @override
  void onWindowFocus() => _scheduleRefresh();
  @override
  void dispose() {
    _refresh?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    if (Platform.isWindows) windowManager.removeListener(this);
    super.dispose();
  }

  Future<void> _ignore() async {
    if (_confirming) return;
    final dialogContext = widget.navigatorKey.currentState?.overlay?.context;
    if (dialogContext == null) return;
    final l = AppLocalizations.of(context)!;
    setState(() => _confirming = true);
    try {
      final confirmed = await showDialog<bool>(
        context: dialogContext,
        builder: (ctx) => AlertDialog(
          title: Text(l.notificationIgnoreTitle),
          content: Text(l.notificationIgnoreBody),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l.actionCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l.notificationIgnoreConfirm),
            ),
          ],
        ),
      );
      if (confirmed == true && mounted) {
        await ref
            .read(permissionWarningIgnoredProvider.notifier)
            .setIgnored(true);
      }
    } finally {
      if (mounted) setState(() => _confirming = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final permission = ref.watch(notificationPermissionProvider);
    final ignored = ref.watch(permissionWarningIgnoredProvider);
    ref.listen(notificationPermissionProvider, (previous, next) {
      final value = next.value;
      if (value == NotificationPermissionState.failed || value == null) return;
      final wasDenied =
          _lastPermission == NotificationPermissionState.denied ||
          previous?.value == NotificationPermissionState.denied;
      _lastPermission = value;
      if (wasDenied && value == NotificationPermissionState.allowed) {
        unawaited(_resyncAfterPermissionRecovery());
      }
    });
    final show =
        permission.value == NotificationPermissionState.denied &&
        ignored.hasValue &&
        ignored.value != true;
    final colors = Theme.of(context).colorScheme;
    return Column(
      children: [
        AnimatedSize(
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          child: show
              ? SafeArea(
                  bottom: false,
                  child: Card(
                    color: colors.errorContainer,
                    margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.notifications_off_outlined,
                                color: colors.onErrorContainer,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  l.notificationWarning,
                                  style: TextStyle(
                                    color: colors.onErrorContainer,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          Wrap(
                            alignment: WrapAlignment.end,
                            spacing: 8,
                            children: [
                              TextButton(
                                key: const Key('notification-ignore'),
                                onPressed: _confirming ? null : _ignore,
                                child: Text(l.notificationIgnore),
                              ),
                              TextButton(
                                key: const Key('notification-open'),
                                onPressed: _confirming
                                    ? null
                                    : () async {
                                        try {
                                          await ref
                                              .read(
                                                notificationPermissionServiceProvider,
                                              )
                                              .openSettings();
                                        } catch (_) {
                                          if (mounted) {
                                            await showDialog<void>(
                                              context: widget
                                                  .navigatorKey
                                                  .currentState!
                                                  .overlay!
                                                  .context,
                                              builder: (ctx) => AlertDialog(
                                                content: Text(
                                                  l.notificationCheckFailed,
                                                ),
                                                actions: [
                                                  TextButton(
                                                    onPressed: () =>
                                                        Navigator.pop(ctx),
                                                    child: Text(
                                                      l.actionConfirm,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            );
                                          }
                                        }
                                      },
                                child: Text(l.notificationOpen),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              : const SizedBox(width: double.infinity),
        ),
        Expanded(child: widget.child),
      ],
    );
  }
}

class NotificationPermissionSettingsTiles extends ConsumerWidget {
  const NotificationPermissionSettingsTiles({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final status = ref.watch(notificationPermissionProvider);
    final ignored = ref.watch(permissionWarningIgnoredProvider);
    return Column(
      children: [
        ListTile(
          title: Text(l.notificationPermissions),
          subtitle: Text(
            status.isLoading
                ? l.notificationPermissions
                : switch (status.value) {
                    NotificationPermissionState.allowed =>
                      l.notificationAllowed,
                    NotificationPermissionState.denied => l.notificationWarning,
                    _ => l.notificationCheckFailed,
                  },
          ),
          trailing: const Icon(Icons.open_in_new),
          onTap: () async {
            try {
              await ref
                  .read(notificationPermissionServiceProvider)
                  .openSettings();
            } catch (_) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showAppSnackBar(
                  SnackBar(content: Text(l.notificationCheckFailed)),
                );
              }
            }
            ref.invalidate(notificationPermissionProvider);
          },
        ),
        SwitchListTile(
          title: Text(l.notificationRestore),
          subtitle: Text(l.notificationRestoreDescription),
          value: ignored.value != true,
          onChanged: ignored.hasValue && ignored.value == true
              ? (v) async {
                  if (v) {
                    await ref
                        .read(permissionWarningIgnoredProvider.notifier)
                        .setIgnored(false);
                  }
                }
              : null,
        ),
      ],
    );
  }
}
