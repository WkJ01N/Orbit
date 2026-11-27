import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbit/providers/course_color_providers.dart';
import 'package:orbit/providers/database_providers.dart';
import 'package:orbit/providers/reminder_providers.dart';
import 'package:orbit/providers/schedule_providers.dart';
import 'package:orbit/models/android_widget_settings.dart';
import 'package:orbit/services/android_widget_service.dart';

final androidWidgetServiceProvider = Provider<AndroidWidgetService>(
  (ref) => AndroidWidgetService.instance,
);

final androidWidgetSettingsProvider =
    NotifierProvider<AndroidWidgetSettingsNotifier, AndroidWidgetSettings>(
      AndroidWidgetSettingsNotifier.new,
    );

class AndroidWidgetSettingsNotifier extends Notifier<AndroidWidgetSettings> {
  int _generation = 0;
  Future<void> _saves = Future.value();

  @override
  AndroidWidgetSettings build() {
    final generation = ++_generation;
    ref.onDispose(() => _generation++);
    ref.read(settingsServiceProvider).loadAndroidWidgetSettings().then((
      loaded,
    ) {
      if (generation == _generation) state = loaded;
    });
    return const AndroidWidgetSettings();
  }

  Future<void> setShowDeadlines(bool value) =>
      _save(state.copyWith(showDeadlines: value));

  Future<void> setDeadlineLookaheadDays(int days) =>
      _save(state.copyWith(deadlineLookaheadDays: days));

  Future<void> setBackgroundOpacity(int opacity) =>
      _save(state.copyWith(backgroundOpacity: opacity));

  Future<void> _save(AndroidWidgetSettings next) {
    _generation++;
    state = next;
    final service = ref.read(settingsServiceProvider);
    final save = _saves
        .catchError((Object _) {})
        .then((_) => service.saveAndroidWidgetSettings(next));
    _saves = save.catchError((Object _) {});
    return save;
  }
}

class AndroidWidgetLifecycleHost extends ConsumerStatefulWidget {
  const AndroidWidgetLifecycleHost({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<AndroidWidgetLifecycleHost> createState() =>
      _AndroidWidgetLifecycleHostState();
}

class _AndroidWidgetLifecycleHostState
    extends ConsumerState<AndroidWidgetLifecycleHost>
    with WidgetsBindingObserver {
  Timer? _debounce;
  StreamSubscription<void>? _syncSubscription;

  bool get _enabled => Platform.isAndroid;

  @override
  void initState() {
    super.initState();
    if (!_enabled) return;
    WidgetsBinding.instance.addObserver(this);
    _syncSubscription = ref.read(appDatabaseProvider).syncChanges.listen((_) {
      _scheduleSync();
    });
    _scheduleSync();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    unawaited(_syncSubscription?.cancel());
    if (_enabled) {
      WidgetsBinding.instance.removeObserver(this);
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_enabled && state == AppLifecycleState.resumed) {
      _scheduleSync();
    }
  }

  void _scheduleSync() {
    if (!_enabled || !mounted) return;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      _debounce = null;
      unawaited(_pushConfig());
    });
  }

  Future<void> _pushConfig() async {
    if (!mounted || !_enabled) return;
    final sessions = ref.read(sessionsProvider).valueOrNull ?? const [];
    final payload = buildAndroidWidgetSyncPayload(
      databasePath: ref.read(appDatabaseProvider).path,
      locale: ref.read(localeProvider),
      themeMode: ref.read(themeModeProvider),
      themeStyle: ref.read(themeStyleProvider),
      seedColor: ref.read(themeColorProvider),
      colorScheme: ref.read(colorSchemeProvider),
      multicolor: ref.read(multicolorSettingsProvider),
      widgetSettings: ref.read(androidWidgetSettingsProvider),
      sessions: sessions,
      courseColorOverrides: ref.read(courseColorOverridesProvider),
      automaticColorIds: ref.read(resolvedAutomaticCourseColorIdsProvider),
    );
    await ref.read(androidWidgetServiceProvider).syncConfig(payload);
  }

  @override
  Widget build(BuildContext context) {
    if (!_enabled) return widget.child;
    ref.listen(scheduleRefreshProvider, (_, _) => _scheduleSync());
    ref.listen(deadlinesRefreshProvider, (_, _) => _scheduleSync());
    ref.listen(sessionsProvider, (_, _) => _scheduleSync());
    ref.listen(localeProvider, (_, _) => _scheduleSync());
    ref.listen(themeColorProvider, (_, _) => _scheduleSync());
    ref.listen(themeModeProvider, (_, _) => _scheduleSync());
    ref.listen(themeStyleProvider, (_, _) => _scheduleSync());
    ref.listen(colorSchemeProvider, (_, _) => _scheduleSync());
    ref.listen(multicolorSettingsProvider, (_, _) => _scheduleSync());
    ref.listen(courseColorOverridesProvider, (_, _) => _scheduleSync());
    ref.listen(
      resolvedAutomaticCourseColorIdsProvider,
      (_, _) => _scheduleSync(),
    );
    ref.listen(androidWidgetSettingsProvider, (_, _) => _scheduleSync());
    return widget.child;
  }
}
