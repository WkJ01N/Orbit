import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbit/core/routing/app_tab.dart';

final appNavIndexProvider = StateProvider<int>((ref) => AppTab.grid.index);

void navigateToAppTab(WidgetRef ref, AppTab tab) {
  ref.read(appNavIndexProvider.notifier).state = tab.index;
}
