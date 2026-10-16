import 'package:flutter/material.dart';
import 'package:orbit/providers/schedule_providers.dart';
import 'package:orbit/features/upcoming/upcoming_page.dart';
import 'package:orbit/features/import/import_page.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbit/core/routing/app_tab.dart';
import 'package:orbit/models/background_settings.dart';

final appNavIndexProvider = StateProvider<int>((ref) => AppTab.grid.index);

void navigateToAppTab(WidgetRef ref, AppTab tab, {BuildContext? context}) {
  final display = ref.read(scheduleDisplaySettingsProvider);
  final hidden =
      tab == AppTab.upcoming && display.hideUpcomingPage ||
      tab == AppTab.import && display.hideImportPage;
  if (hidden && context != null && context.mounted) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        settings: RouteSettings(
          name: 'orbit-standalone-tab',
          arguments: BackgroundPage.values[tab.index],
        ),
        builder: (_) => tab == AppTab.upcoming
            ? const UpcomingPage(showBackButton: true)
            : const ImportPage(showBackButton: true),
      ),
    );
    return;
  }
  if (context != null &&
      context.mounted &&
      tab == AppTab.grid &&
      ModalRoute.of(context)?.settings.name == 'orbit-standalone-tab') {
    Navigator.of(context).pop();
  }
  ref.read(appNavIndexProvider.notifier).state = tab.index;
}
