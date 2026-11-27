part of 'grid_week_view.dart';

class GridSessionChip extends ConsumerWidget {
  const GridSessionChip({
    super.key,
    required this.session,
    required this.colorScheme,
    required this.l10n,
    required this.isSelected,
    this.compact = false,
    this.previewOnly = false,
    required this.onTap,
    required this.onMenu,
  });
  final CourseSession session;
  final ColorScheme colorScheme;
  final AppLocalizations l10n;
  final bool isSelected;
  final bool compact;
  final bool previewOnly;
  final VoidCallback onTap;
  final void Function(Offset? position) onMenu;

  Widget _quickActionWrapper(
    CourseSession session,
    bool enabled,
    Widget child,
  ) => previewOnly
      ? child
      : CourseQuickActionGesture(
          session: session,
          enabled: enabled,
          onFallback: () => onMenu(null),
          child: child,
        );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(currentTimeProvider);
    final themeStyle = appThemeStyleOf(context);
    final accent = _gridCourseAccent(context, ref, session);
    final isPast = isSessionPast(now, session.endAt);
    final isOngoing = isSessionOngoing(now, session.startAt, session.endAt);
    final isSoon = isSessionStartingSoon(now, session.startAt) && !isPast;
    final time = '${_time(session.startAt)} - ${_time(session.endAt)}';
    final strong =
        ref.watch(strongCourseIdsProvider).valueOrNull?.contains(session.id) ??
        false;
    final selection = ref.watch(gridSelectionProvider);
    final selected = selection.active
        ? selection.ids.contains(session.id)
        : isSelected;
    final framed = selected || (isOngoing && !selection.active);
    final surface = courseCardSurface(
      accent: accent,
      colorScheme: colorScheme,
      themeStyle: themeStyle,
      highlighted: isOngoing || isSoon,
      isPast: isPast,
    );
    final gradient = ref
        .watch(scheduleDisplaySettingsProvider)
        .strongCardGradient;
    final foreground = isPast
        ? colorScheme.onSurfaceVariant
        : colorScheme.onSurface;
    return Semantics(
      button: true,
      selected: selection.active ? selected : null,
      label:
          '${session.displayName}, $time, ${session.room}, ${session.teachers.join(localeListSeparator(Localizations.localeOf(context)))}'
          '${strong ? ', ${WakeText.of(context).strong}' : ''}'
          '${selection.active && selected ? ', ${GridActionText.of(context).selectedHint}' : ''}',
      child: _quickActionWrapper(
        session,
        !selection.active,
        GestureDetector(
          onSecondaryTapDown: selection.active
              ? null
              : (details) => onMenu(details.globalPosition),
          child: Material(
            color: BackgroundPageScope.surface(context, surface),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(
                color: framed
                    ? colorScheme.primary
                    : colorScheme.outlineVariant,
                width: framed ? 2 : 1,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: Ink(
              decoration: strong
                  ? BoxDecoration(
                      gradient: strongGridBackground(
                        accent: accent,
                        surface: surface,
                        extent: gradient,
                      ),
                    )
                  : null,
              child: InkWell(
                onTap: onTap,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      width: compact ? 2 : 4,
                      color: isPast ? accent.withAlpha(100) : accent,
                    ),
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) => compact
                            ? _CompactSessionChipContent(
                                session: session,
                                time: time,
                                foreground: foreground,
                                availableHeight: constraints.maxHeight,
                                availableWidth: constraints.maxWidth,
                              )
                            : _SessionChipContent(
                                session: session,
                                time: time,
                                foreground: foreground,
                                availableHeight: constraints.maxHeight,
                                availableWidth: constraints.maxWidth - 11,
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

TextStyle _compactCourseNameStyle(Color? color, bool narrow) => TextStyle(
  color: color,
  fontSize: narrow ? 8.5 : 9.5,
  fontWeight: FontWeight.w700,
  height: 1.12,
);

class _CompactSessionChipContent extends StatelessWidget {
  const _CompactSessionChipContent({
    required this.session,
    required this.time,
    required this.foreground,
    required this.availableHeight,
    required this.availableWidth,
  });

  final CourseSession session;
  final String time;
  final Color foreground;
  final double availableHeight;
  final double availableWidth;

  @override
  Widget build(BuildContext context) {
    final narrow = availableWidth < 32;
    final nameStyle = _compactCourseNameStyle(foreground, narrow);
    final detailStyle = TextStyle(
      color: foreground.withAlpha(210),
      fontSize: narrow ? 7.5 : 8,
      height: 1.08,
    );
    final width = math.max(1.0, availableWidth - 4);
    final scaler = MediaQuery.textScalerOf(context);
    double measure(String text, TextStyle style, int lines) => _textHeight(
      text,
      style,
      width,
      scaler,
      Directionality.of(context),
      maxLines: lines,
    );

    if (availableHeight < measure(session.displayName, nameStyle, 1) + 6) {
      return const SizedBox.shrink();
    }
    final roomStyle = detailStyle.copyWith(fontWeight: FontWeight.w600);
    final roomHeight = measure(session.room, roomStyle, 2);
    final nameHeight = measure(session.displayName, nameStyle, 1);
    var remaining = math.max(0.0, availableHeight - 6) - nameHeight;
    final showRoom = session.room.trim().isNotEmpty && remaining >= roomHeight;
    if (showRoom) remaining -= roomHeight;
    final timeHeight = measure(time, detailStyle, 2);
    final showTime = !narrow && remaining >= timeHeight;
    if (showTime) remaining -= timeHeight;
    final showTeacher =
        !narrow &&
        session.teachers.isNotEmpty &&
        remaining >=
            measure(
              session.teachers.join(
                localeListSeparator(Localizations.localeOf(context)),
              ),
              detailStyle,
              1,
            );
    return ClipRect(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 3),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Align(
                alignment: Alignment.topLeft,
                child: Text(
                  session.displayName,
                  maxLines: 3,
                  overflow: TextOverflow.fade,
                  softWrap: true,
                  style: nameStyle,
                ),
              ),
            ),
            if (showTime)
              Text(
                time,
                maxLines: 2,
                overflow: TextOverflow.fade,
                style: detailStyle,
              ),
            if (showTeacher)
              Text(
                session.teachers.join(
                  localeListSeparator(Localizations.localeOf(context)),
                ),
                maxLines: 1,
                overflow: TextOverflow.fade,
                style: detailStyle,
              ),
            if (showRoom)
              Text(
                session.room,
                maxLines: 2,
                overflow: TextOverflow.fade,
                softWrap: true,
                style: roomStyle,
              ),
          ],
        ),
      ),
    );
  }
}

class _SessionChipContent extends StatelessWidget {
  const _SessionChipContent({
    required this.session,
    required this.time,
    required this.foreground,
    required this.availableHeight,
    required this.availableWidth,
  });

  final CourseSession session;
  final String time;
  final Color foreground;
  final double availableHeight;
  final double availableWidth;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final nameStyle = theme.textTheme.labelMedium?.copyWith(
      color: foreground,
      fontWeight: FontWeight.w700,
      height: 1.15,
    );
    final detailStyle = theme.textTheme.labelSmall?.copyWith(
      color: foreground,
      height: 1.1,
    );
    final width = math.max(1.0, availableWidth);
    final nameHeight = _textHeight(
      session.displayName,
      nameStyle,
      width,
      MediaQuery.textScalerOf(context),
      Directionality.of(context),
    );
    final scaler = MediaQuery.textScalerOf(context);
    final direction = Directionality.of(context);
    final oneLineHeight = _textHeight(
      session.displayName,
      nameStyle,
      width,
      scaler,
      direction,
      maxLines: 1,
    );
    if (availableHeight < oneLineHeight + 10) return const SizedBox.shrink();
    final timeHeight = _textHeight(time, detailStyle, width, scaler, direction);
    final roomHeight = _textHeight(
      session.room,
      detailStyle,
      width,
      scaler,
      direction,
    );
    final teacherHeight = _textHeight(
      session.teachers.join(
        localeListSeparator(Localizations.localeOf(context)),
      ),
      detailStyle,
      width,
      scaler,
      direction,
    );
    var showTeacher = session.teachers.isNotEmpty;
    var showTime = true;
    var showRoom = session.room.trim().isNotEmpty;

    double requiredHeight() {
      var height = 10 + nameHeight;
      if (showTime) height += 3 + timeHeight;
      if (showRoom) height += 2 + roomHeight;
      if (showTeacher) height += 2 + teacherHeight;
      return height;
    }

    if (requiredHeight() > availableHeight) showTeacher = false;
    if (requiredHeight() > availableHeight) showTime = false;
    if (requiredHeight() > availableHeight) showRoom = false;

    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 5, 5, 5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            session.displayName,
            style: nameStyle,
            maxLines: nameHeight + 10 <= availableHeight
                ? null
                : math.max(1, ((availableHeight - 10) / oneLineHeight).floor()),
            overflow: nameHeight + 10 <= availableHeight
                ? TextOverflow.clip
                : TextOverflow.ellipsis,
          ),
          if (showTime) ...[
            const SizedBox(height: 3),
            Text(time, style: detailStyle),
          ],
          if (showRoom) ...[
            const SizedBox(height: 2),
            Text(session.room, style: detailStyle),
          ],
          if (showTeacher) ...[
            const SizedBox(height: 2),
            Text(
              session.teachers.join(
                localeListSeparator(Localizations.localeOf(context)),
              ),
              style: detailStyle,
            ),
          ],
        ],
      ),
    );
  }
}

String _time(DateTime value) =>
    '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
