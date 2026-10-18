import 'package:orbit/core/motion/page_module.dart';
import 'package:orbit/core/background/background_scope.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbit/models/account_sync.dart';
import 'package:orbit/models/sync_content.dart';
import 'package:orbit/models/sync_update_text.dart';
import 'package:orbit/providers/account_sync_providers.dart';
import 'package:orbit/providers/database_providers.dart';

class SyncContentPage extends ConsumerStatefulWidget {
  const SyncContentPage({super.key});
  @override
  ConsumerState<SyncContentPage> createState() => _SyncContentPageState();
}

class _SyncContentPageState extends ConsumerState<SyncContentPage> {
  SyncSelection? _selection;
  SyncScopeMode _mode = SyncScopeMode.perDevice;
  bool _busy = false;
  Set<SyncCategory> _pending = {};
  String? _error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final service = ref.read(syncScopeServiceProvider);
      service.accountUid = ref.read(accountSyncProvider).value?.account?.uid;
      try {
        await service.refresh();
      } catch (_) {
        /* Cached choices stay editable offline. */
      }
      final selection = await service.selection();
      final pending = await service.pendingCategories();
      final policy = await service.cachedPolicy();
      if (mounted) {
        setState(() {
          _selection = selection;
          _pending = pending;
          _mode = policy.mode;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  Future<void> _change(SyncCategory category, bool enabled) async {
    final target = _selection!.toggle(category, enabled);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final coordinator = ref.read(scheduleSyncCoordinatorProvider);
      InitialSyncPreview? preview;
      Map<String, bool> choices = {};
      if (enabled) {
        preview = await coordinator.previewCategories(
          SyncSelection({category}),
        );
        if (!mounted) return;
        final chosen = await _review(preview);
        if (chosen == null) return;
        choices = chosen;
      }
      await ref.read(syncScopeServiceProvider).saveSelection(target);
      if (preview != null) {
        final account = await ref.read(appDatabaseProvider).activeSyncAccount();
        await coordinator.confirmInitialMerge(
          account: account!,
          preview: preview,
          useLocalForConflict: choices,
          resetState: false,
          synchronizeAfter: false,
        );
      }
      final service = ref.read(syncScopeServiceProvider);
      await service.markApplied(
        (await service.appliedSelection()).toggle(category, enabled),
      );
      if (mounted) {
        setState(() {
          _selection = target;
          _pending.remove(category);
        });
      }
      await ref.read(accountSyncProvider.notifier).syncNow();
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<Map<String, bool>?> _review(InitialSyncPreview preview) {
    final t = SyncUpdateText.of(context);
    final choices = <String, bool>{};
    return showDialog<Map<String, bool>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialog) => AlertDialog(
          title: PageModule(child: Text(t.preview)),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  PageModule(
                    child: Text(
                      t.mergeCounts(
                        preview.localOnly.length,
                        preview.remoteOnly.length,
                      ),
                    ),
                  ),
                  for (final c in preview.conflicts)
                    PageModule(
                      child: ListTile(
                        title: Text(
                          '${c.remote.payload['title'] ?? c.remote.payload['courseName'] ?? c.remote.id}${c.remote.deleted ? ' 🗑' : ''}',
                        ),
                        subtitle: Wrap(
                          children: [
                            for (final local in [true, false])
                              ChoiceChip(
                                label: Text(local ? t.local : t.cloud),
                                selected: choices[c.id] == local,
                                onSelected: (_) =>
                                    setDialog(() => choices[c.id] = local),
                              ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            PageModule(
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(t.cancel),
              ),
            ),
            PageModule(
              child: FilledButton(
                onPressed: choices.length == preview.conflicts.length
                    ? () => Navigator.pop(context, choices)
                    : null,
                child: Text(t.confirm),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _switchMode(SyncScopeMode value) async {
    final t = SyncUpdateText.of(context);
    if (value == SyncScopeMode.shared &&
        await showDialog<bool>(
              context: context,
              builder: (c) => AlertDialog(
                title: PageModule(child: Text(t.shared)),
                content: PageModule(
                  child: Text(
                    '${t.sharedConfirm}\n\n${_selection!.enabled.map(t.category).join('、')}',
                  ),
                ),
                actions: [
                  PageModule(
                    child: TextButton(
                      onPressed: () => Navigator.pop(c, false),
                      child: Text(t.cancel),
                    ),
                  ),
                  PageModule(
                    child: FilledButton(
                      onPressed: () => Navigator.pop(c, true),
                      child: Text(t.confirm),
                    ),
                  ),
                ],
              ),
            ) !=
            true) {
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(syncScopeServiceProvider).setMode(value);
      await _load();
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = SyncUpdateText.of(context);
    return BackgroundScaffold(
      appBar: AppBar(title: PageModule(child: Text(t.content))),
      body: _selection == null
          ? Center(
              child: _error == null
                  ? const CircularProgressIndicator()
                  : PageModule(child: Text(_error!)),
            )
          : ListView(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: PageModule(child: Text(t.scopeHint)),
                ),
                if (_busy) const LinearProgressIndicator(),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: PageModule(child: Text(_error!)),
                  ),
                RadioGroup<SyncScopeMode>(
                  groupValue: _mode,
                  onChanged: (v) {
                    if (!_busy && v != null) _switchMode(v);
                  },
                  child: Column(
                    children: [
                      RadioListTile(
                        value: SyncScopeMode.perDevice,
                        title: PageModule(child: Text(t.device)),
                      ),
                      RadioListTile(
                        value: SyncScopeMode.shared,
                        title: PageModule(child: Text(t.shared)),
                      ),
                    ],
                  ),
                ),
                for (final c in _pending)
                  PageModule(
                    child: ListTile(
                      leading: const Icon(Icons.merge),
                      title: Text('${t.preview}: ${t.category(c)}'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: _busy ? null : () => _change(c, true),
                    ),
                  ),
                for (final c in SyncCategory.values)
                  PageModule(
                    child: SwitchListTile(
                      title: Text(t.category(c)),
                      value: _selection!.enabled.contains(c),
                      onChanged: _busy ? null : (v) => _change(c, v),
                    ),
                  ),
              ],
            ),
    );
  }
}
