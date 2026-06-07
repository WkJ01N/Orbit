import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbit/core/formatters/date_time_formatters.dart';
import 'package:orbit/core/routing/app_tab.dart';
import 'package:orbit/features/grid/week_calendar_utils.dart';
import 'package:orbit/features/session/session_detail_sheet.dart';
import 'package:orbit/l10n/app_localizations.dart';
import 'package:orbit/models/course_session.dart';
import 'package:orbit/providers/app_providers.dart';

class SessionSearchPage extends ConsumerStatefulWidget {
  const SessionSearchPage({super.key});

  static Future<void> show(BuildContext context) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => const SessionSearchPage(),
      ),
    );
  }

  @override
  ConsumerState<SessionSearchPage> createState() => _SessionSearchPageState();
}

class _SessionSearchPageState extends ConsumerState<SessionSearchPage> {
  final _controller = TextEditingController();
  List<CourseSession> _results = [];
  bool _searched = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final query = _controller.text.trim();
    if (query.isEmpty) {
      setState(() {
        _results = [];
        _searched = false;
      });
      return;
    }

    final results =
        await ref.read(scheduleRepositoryProvider).searchSessions(query);
    if (mounted) {
      setState(() {
        _results = results;
        _searched = true;
      });
    }
  }

  Future<void> _openSession(CourseSession session) async {
    ref.read(selectedWeekStartProvider.notifier).state =
        weekStartFor(session.date);
    navigateToAppTab(ref, AppTab.grid);
    if (!mounted) {
      return;
    }
    Navigator.pop(context);
    await SessionDetailSheet.show(context, session);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.searchSessions),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _controller,
              autofocus: true,
              decoration: InputDecoration(
                hintText: l10n.searchHint,
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: _search,
                ),
              ),
              onSubmitted: (_) => _search(),
            ),
          ),
          Expanded(
            child: _results.isEmpty
                ? Center(
                    child: Text(
                      _searched ? l10n.searchNoResults : l10n.searchHint,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  )
                : ListView.separated(
                    itemCount: _results.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final session = _results[index];
                      return ListTile(
                        title: Text(session.courseName),
                        subtitle: Text(
                          '${formatIsoDate(session.date)} · '
                          '${formatTimeHm(session.startAt)} · ${session.room}',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _openSession(session),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
