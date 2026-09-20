import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbit/core/desktop/desktop_shell.dart';
import 'package:orbit/core/routing/app_shell.dart';
import 'package:orbit/core/routing/notification_listener.dart';
import 'package:orbit/core/theme/app_theme.dart';
import 'package:orbit/l10n/app_localizations.dart';
import 'package:orbit/providers/app_providers.dart';
import 'package:orbit/providers/account_sync_providers.dart';
import 'package:orbit/models/auto_sync_settings.dart';
import 'package:orbit/core/widgets/notification_permission_banner.dart';
import 'package:orbit/core/widgets/app_snack_bar.dart';

final _navigatorKey = GlobalKey<NavigatorState>();
final _messageRouteObserver = AppMessageRouteObserver();

class OrbitApp extends ConsumerWidget {
  const OrbitApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    final seed = ref.watch(themeColorProvider);

    final themeMode = ref.watch(themeModeProvider);
    final themeStyle = ref.watch(themeStyleProvider);
    final multicolor = ref.watch(multicolorSettingsProvider);
    final useWindowsCjkFont =
        defaultTargetPlatform == TargetPlatform.windows &&
        locale.languageCode == 'zh';

    return MaterialApp(
      navigatorKey: _navigatorKey,
      navigatorObservers: [_messageRouteObserver],
      builder: (context, child) => AppScaffoldMessenger(
        routeObserver: _messageRouteObserver,
        child: _AccountSyncLifecycleHost(
          child: NotificationPermissionHost(
            navigatorKey: _navigatorKey,
            child: child!,
          ),
        ),
      ),
      title: 'Orbit',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(
        seed: seed,
        style: themeStyle,
        multicolor: multicolor,
        useWindowsCjkFont: useWindowsCjkFont,
      ),
      darkTheme: AppTheme.dark(
        seed: seed,
        style: themeStyle,
        multicolor: multicolor,
        useWindowsCjkFont: useWindowsCjkFont,
      ),
      themeMode: themeMode,
      locale: locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: const OrbitNotificationListener(
        child: DesktopShell(child: AppShell()),
      ),
    );
  }
}

class _AccountSyncLifecycleHost extends ConsumerStatefulWidget {
  const _AccountSyncLifecycleHost({required this.child});

  final Widget child;

  @override
  ConsumerState<_AccountSyncLifecycleHost> createState() =>
      _AccountSyncLifecycleHostState();
}

class _AccountSyncLifecycleHostState
    extends ConsumerState<_AccountSyncLifecycleHost>
    with WidgetsBindingObserver {
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  bool? _networkAllowed;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeConnectivity();
  }

  Future<void> _initializeConnectivity() async {
    try {
      final connectivity = Connectivity();
      final initial = await connectivity.checkConnectivity();
      if (!mounted) return;
      _networkAllowed = await _isAllowedNetwork(initial);
      _connectivitySubscription = connectivity.onConnectivityChanged.listen(
        _onConnectivityChanged,
        onError: (Object error, StackTrace stack) {
          debugPrint('Connectivity monitor failed: $error');
        },
      );
    } catch (error) {
      debugPrint('Connectivity monitor unavailable: $error');
    }
  }

  Future<bool> _isAllowedNetwork(List<ConnectivityResult> results) async {
    if (results.isEmpty || results.every((r) => r == ConnectivityResult.none)) {
      return false;
    }
    final settings = await ref
        .read(settingsServiceProvider)
        .loadAutoSyncSettings();
    if (settings.networkPolicy == SyncNetworkPolicy.any) return true;
    return results.any(
      (result) =>
          result == ConnectivityResult.wifi ||
          result == ConnectivityResult.ethernet,
    );
  }

  Future<void> _onConnectivityChanged(List<ConnectivityResult> results) async {
    final allowed = await _isAllowedNetwork(results);
    final wasAllowed = _networkAllowed;
    _networkAllowed = allowed;
    if (wasAllowed == false && allowed && mounted) {
      await ref
          .read(accountSyncProvider.notifier)
          .triggerSync(SyncTrigger.networkRestored);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_connectivitySubscription?.cancel());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_refreshAndSyncOnResume());
    }
  }

  Future<void> _refreshAndSyncOnResume() async {
    final account = ref.read(accountSyncProvider.notifier);
    await account.refreshProfile();
    await account.triggerSync(SyncTrigger.appResume);
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(accountSyncProvider);
    return widget.child;
  }
}
