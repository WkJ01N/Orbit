import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbit/models/typography_settings.dart';
import 'package:orbit/services/font_service.dart';

final fontServiceProvider = Provider<FontService>((ref) => FontService.shared);
final typographySnapshotProvider = Provider<TypographySettings?>((ref) => null);
final typographySettingsProvider =
    NotifierProvider<TypographyNotifier, TypographySettings>(
      TypographyNotifier.new,
    );

class TypographyNotifier extends Notifier<TypographySettings> {
  int _generation = 0;
  Future<void> _tail = Future.value();
  @override
  TypographySettings build() {
    final generation = ++_generation;
    ref.onDispose(() => _generation++);
    final initial = ref.read(typographySnapshotProvider);
    if (initial != null) return initial;
    ref.read(fontServiceProvider).initialize().then((value) {
      if (_generation == generation) state = value;
    });
    return const TypographySettings();
  }

  Future<void> update(TypographySettings Function(TypographySettings) change) {
    _generation++;
    final service = ref.read(fontServiceProvider);
    final work = _tail.catchError((Object _) {}).then((_) async {
      final next = change(state).copyWith(loadWarning: false);
      final prepared = await service.prepare(
        next,
        recover:
            next.appFontId == state.appFontId &&
            next.launchFontId == state.launchFontId,
      );
      await service.save(next);
      state = prepared;
    });
    _tail = work.catchError((Object _) {});
    return work;
  }

  Future<void> remove(String id) async {
    final old = state.imports[id];
    if (old == null) return;
    await update(
      (value) => value.copyWith(
        appFontId: value.appFontId == id ? 'system' : null,
        launchFontId: value.launchFontId == id ? 'nunito' : null,
        imports: {...value.imports}..remove(id),
      ),
    );
    await ref.read(fontServiceProvider).deleteFile(old);
  }

  void restoreLoaded(TypographySettings value) {
    _generation++;
    state = value;
  }
}
