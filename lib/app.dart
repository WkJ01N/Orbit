import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbit/core/desktop/desktop_shell.dart';
import 'package:orbit/core/routing/app_shell.dart';
import 'package:orbit/core/routing/notification_listener.dart';
import 'package:orbit/core/theme/app_theme.dart';
import 'package:orbit/l10n/app_localizations.dart';
import 'package:orbit/providers/app_providers.dart';

class OrbitApp extends ConsumerWidget {
  const OrbitApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    final seed = ref.watch(themeColorProvider);

    return MaterialApp(
      title: 'Orbit',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(seed: seed),
      darkTheme: AppTheme.dark(seed: seed),
      themeMode: ThemeMode.system,
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
