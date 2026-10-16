import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:orbit/models/background_settings.dart';

class BackgroundRegionRegistration {
  BackgroundRegionRegistration(this.page, this.region, this.context);
  final BackgroundPage page;
  final BackgroundRegionId region;
  final BuildContext context;
  Rect? get bounds {
    if (!context.mounted) return null;
    final render = context.findRenderObject();
    if (render is! RenderBox || !render.attached || !render.hasSize) {
      return null;
    }
    var rect = MatrixUtils.transformRect(
      render.getTransformTo(null),
      Offset.zero & render.size,
    );
    RenderObject? parent = render.parent;
    while (parent != null) {
      if (parent is RenderBox &&
          parent.hasSize &&
          (parent is RenderAbstractViewport ||
              parent is RenderClipRect ||
              parent is RenderClipRRect)) {
        rect = rect.intersect(
          MatrixUtils.transformRect(
            parent.getTransformTo(null),
            Offset.zero & parent.size,
          ),
        );
      }
      parent = parent.parent;
    }
    return rect;
  }
}

class BackgroundRegionRegistry extends ChangeNotifier {
  bool _pending = false;
  bool _disposed = false;
  void changed() {
    if (_pending || _disposed) return;
    _pending = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _pending = false;
      if (!_disposed) notifyListeners();
    });
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  final registrations = <Object, BackgroundRegionRegistration>{};
  BackgroundRegionRegistration? at(Offset global) {
    final matches = registrations.values
        .where((r) => r.bounds?.contains(global) == true)
        .toList();
    matches.sort(
      (a, b) => (a.bounds!.width * a.bounds!.height).compareTo(
        b.bounds!.width * b.bounds!.height,
      ),
    );
    return matches.firstOrNull;
  }
}

class BackgroundPageScope extends InheritedWidget {
  const BackgroundPageScope({
    required this.settings,
    required this.owner,
    required super.child,
    this.registry,
    super.key,
  });
  final BackgroundSettings settings;
  final BackgroundPage owner;
  final BackgroundRegionRegistry? registry;
  static BackgroundPageScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<BackgroundPageScope>();
  bool visible(BackgroundRegionId region) =>
      settings.asset(owner) != null &&
      settings.resolved(owner).regions.contains(region);
  static bool enabled(BuildContext context, BackgroundRegionId region) =>
      maybeOf(context)?.visible(region) ?? false;
  static Color color(
    BuildContext context,
    BackgroundRegionId region,
    Color original,
  ) => enabled(context, region) ? Colors.transparent : original;
  static Color surface(BuildContext context, Color original) {
    final scope = maybeOf(context);
    return scope?.visible(BackgroundRegionId.content) == true
        ? original.withValues(
            alpha:
                original.a * scope!.settings.page(scope.owner).surfaceOpacity,
          )
        : original;
  }

  @override
  bool updateShouldNotify(BackgroundPageScope old) =>
      old.settings != settings ||
      old.owner != owner ||
      old.registry != registry;
}

class BackgroundPageTheme extends StatelessWidget {
  const BackgroundPageTheme({
    required this.settings,
    required this.owner,
    required this.child,
    this.registry,
    super.key,
  });
  final BackgroundSettings settings;
  final BackgroundPage owner;
  final Widget child;
  final BackgroundRegionRegistry? registry;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final configured = settings.asset(owner) != null;
    final regions = settings.resolved(owner).regions;
    final header = configured && regions.contains(BackgroundRegionId.header);
    final body = configured && regions.contains(BackgroundRegionId.content);
    final themed = configured
        ? theme.copyWith(
            scaffoldBackgroundColor: Colors.transparent,
            appBarTheme: theme.appBarTheme.copyWith(
              backgroundColor: header
                  ? Colors.transparent
                  : theme.colorScheme.surface,
              surfaceTintColor: header
                  ? Colors.transparent
                  : theme.appBarTheme.surfaceTintColor,
            ),
            cardTheme: body
                ? theme.cardTheme.copyWith(
                    color:
                        (theme.cardTheme.color ??
                                theme.colorScheme.surfaceContainerLow)
                            .withValues(
                              alpha: settings.page(owner).surfaceOpacity,
                            ),
                    surfaceTintColor: Colors.transparent,
                  )
                : theme.cardTheme,
          )
        : theme;
    return BackgroundPageScope(
      settings: settings,
      owner: owner,
      registry: registry,
      child: Theme(data: themed, child: child),
    );
  }
}

class BackgroundRegion extends StatefulWidget {
  const BackgroundRegion({
    required this.region,
    required this.child,
    super.key,
  });
  final BackgroundRegionId region;
  final Widget child;
  @override
  State<BackgroundRegion> createState() => _BackgroundRegionState();
}

class _BackgroundRegionState extends State<BackgroundRegion> {
  BackgroundRegionRegistry? _registry;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _registry?.registrations.remove(this);
    final scope = BackgroundPageScope.maybeOf(context);
    _registry = scope?.registry;
    if (scope != null) {
      _registry?.registrations[this] = BackgroundRegionRegistration(
        scope.owner,
        widget.region,
        context,
      );
    }
    _registry?.changed();
  }

  @override
  void deactivate() {
    _registry?.registrations.remove(this);
    _registry?.changed();
    super.deactivate();
  }

  @override
  void dispose() {
    _registry?.registrations.remove(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scope = BackgroundPageScope.maybeOf(context);
    if (scope == null || scope.settings.asset(scope.owner) == null) {
      return widget.child;
    }
    return Material(
      color: BackgroundPageScope.color(
        context,
        widget.region,
        Theme.of(context).colorScheme.surface,
      ),
      surfaceTintColor: Colors.transparent,
      child: BackgroundTextProtection(
        enabled:
            scope.visible(widget.region) &&
            scope.settings.page(scope.owner).autoTextProtection,
        dim: scope.settings.resolved(scope.owner).framing.dim,
        child: widget.child,
      ),
    );
  }
}

/// Region-local styles; captured themes restore normal typography on dialogs.
class BackgroundTextProtection extends StatelessWidget {
  const BackgroundTextProtection({
    required this.enabled,
    required this.dim,
    required this.child,
    super.key,
  });
  final bool enabled;
  final double dim;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    if (!enabled || dim >= .3) return child;
    final theme = Theme.of(context);
    final amount = (1 - dim / .3).clamp(0.0, 1.0);
    TextStyle? protect(TextStyle? style) {
      if (style == null) return null;
      final foreground = style.color ?? theme.colorScheme.onSurface;
      final contrast = foreground.computeLuminance() > .4
          ? Colors.black
          : Colors.white;
      return style.copyWith(
        shadows: [
          ...?style.shadows,
          Shadow(color: contrast.withValues(alpha: .8 * amount), blurRadius: 3),
          Shadow(color: contrast.withValues(alpha: .5 * amount), blurRadius: 1),
        ],
      );
    }

    TextTheme protectTheme(TextTheme t) => TextTheme(
      displayLarge: protect(t.displayLarge),
      displayMedium: protect(t.displayMedium),
      displaySmall: protect(t.displaySmall),
      headlineLarge: protect(t.headlineLarge),
      headlineMedium: protect(t.headlineMedium),
      headlineSmall: protect(t.headlineSmall),
      titleLarge: protect(t.titleLarge),
      titleMedium: protect(t.titleMedium),
      titleSmall: protect(t.titleSmall),
      bodyLarge: protect(t.bodyLarge),
      bodyMedium: protect(t.bodyMedium),
      bodySmall: protect(t.bodySmall),
      labelLarge: protect(t.labelLarge),
      labelMedium: protect(t.labelMedium),
      labelSmall: protect(t.labelSmall),
    );
    return Theme(
      data: theme.copyWith(
        textTheme: protectTheme(theme.textTheme),
        primaryTextTheme: protectTheme(theme.primaryTextTheme),
        appBarTheme: theme.appBarTheme.copyWith(
          titleTextStyle: protect(
            theme.appBarTheme.titleTextStyle ?? theme.textTheme.titleLarge,
          ),
        ),
        navigationBarTheme: theme.navigationBarTheme.copyWith(
          labelTextStyle: WidgetStateProperty.resolveWith(
            (states) => protect(
              theme.navigationBarTheme.labelTextStyle?.resolve(states) ??
                  theme.textTheme.labelMedium,
            ),
          ),
        ),
        navigationRailTheme: theme.navigationRailTheme.copyWith(
          selectedLabelTextStyle: protect(
            theme.navigationRailTheme.selectedLabelTextStyle ??
                theme.textTheme.labelMedium,
          ),
          unselectedLabelTextStyle: protect(
            theme.navigationRailTheme.unselectedLabelTextStyle ??
                theme.textTheme.labelMedium,
          ),
        ),
      ),
      child: _RestoreBackgroundPopupTheme(
        original: theme,
        child: DefaultTextStyle.merge(
          style: protect(DefaultTextStyle.of(context).style),
          child: child,
        ),
      ),
    );
  }
}

class _RestoreBackgroundPopupTheme extends InheritedTheme {
  const _RestoreBackgroundPopupTheme({
    required this.original,
    required super.child,
  });
  final ThemeData original;
  @override
  bool updateShouldNotify(_RestoreBackgroundPopupTheme oldWidget) =>
      original != oldWidget.original;
  @override
  Widget wrap(BuildContext context, Widget child) =>
      Theme(data: original, child: child);
}

class BackgroundAppBar extends StatelessWidget implements PreferredSizeWidget {
  const BackgroundAppBar({required this.child, super.key});
  final PreferredSizeWidget child;
  @override
  Size get preferredSize => child.preferredSize;
  @override
  Widget build(BuildContext context) =>
      BackgroundRegion(region: BackgroundRegionId.header, child: child);
}

/// Full routes use the same real app-bar/body boundaries as the main pages.
/// Popups deliberately keep their existing Material surfaces.
class BackgroundScaffold extends StatelessWidget {
  const BackgroundScaffold({super.key, this.appBar, this.body});
  final PreferredSizeWidget? appBar;
  final Widget? body;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: appBar == null ? null : BackgroundAppBar(child: appBar!),
    body: body == null
        ? null
        : BackgroundRegion(region: BackgroundRegionId.content, child: body!),
  );
}
