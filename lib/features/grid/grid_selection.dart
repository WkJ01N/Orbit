import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbit/models/grid_action_text.dart';

class GridSelection {
  const GridSelection({
    this.active = false,
    this.ids = const {},
    this.busy = false,
  });
  final bool active;
  final Set<String> ids;
  final bool busy;
}

final gridSelectionProvider =
    NotifierProvider<GridSelectionNotifier, GridSelection>(
      GridSelectionNotifier.new,
    );

class GridSelectionNotifier extends Notifier<GridSelection> {
  @override
  GridSelection build() => const GridSelection();
  void enter() => state = const GridSelection(active: true);
  void exit() => state = const GridSelection();
  void toggle(String id) {
    if (!state.active || state.busy) return;
    final ids = {...state.ids};
    if (!ids.remove(id)) ids.add(id);
    replace(ids);
  }

  void replace(Set<String> ids) => state = GridSelection(
    active: state.active,
    ids: Set.unmodifiable(ids),
    busy: state.busy,
  );
  void setBusy(bool busy) =>
      state = GridSelection(active: state.active, ids: state.ids, busy: busy);
}

Future<bool> cancelGridSelection(BuildContext context, WidgetRef ref) async {
  final state = ref.read(gridSelectionProvider);
  if (!state.active) return true;
  if (state.busy) return false;
  if (state.ids.isNotEmpty) {
    final text = GridActionText.of(context);
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(text.cancelSelection),
        content: Text(text.cancelHint(state.ids.length)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(text.keepSelecting),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(text.cancelSelection),
          ),
        ],
      ),
    );
    if (discard != true || !context.mounted) return false;
  }
  ref.read(gridSelectionProvider.notifier).exit();
  return true;
}
