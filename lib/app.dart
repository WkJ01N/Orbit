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
        child: NotificationPermissionHost(
          navigatorKey: _navigatorKey,
          child: child!,
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
