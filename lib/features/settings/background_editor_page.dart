import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbit/core/background/background_media.dart';
import 'package:orbit/core/background/background_scope.dart';
import 'package:orbit/core/widgets/app_snack_bar.dart';
import 'package:orbit/features/grid/grid_page.dart';
import 'package:orbit/features/import/import_page.dart';
import 'package:orbit/features/settings/settings_page.dart';
import 'package:orbit/features/upcoming/upcoming_page.dart';
import 'package:orbit/models/background_settings.dart';
import 'package:orbit/models/background_text.dart';
import 'package:orbit/providers/background_providers.dart';
import 'package:orbit/providers/reminder_providers.dart';
import 'package:orbit/services/background_asset_service.dart';

class BackgroundSettingsPage extends ConsumerWidget {
  const BackgroundSettingsPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = BackgroundText(context);
    final value = ref.watch(backgroundSettingsProvider);
    Future<void> edit(
      BackgroundSettings settings, [
      BackgroundPage page = BackgroundPage.grid,
    ]) => Navigator.of(context).push<void>(
      MaterialPageRoute(
        settings: const RouteSettings(name: 'orbit-background-editor'),
        builder: (_) =>
            BackgroundEditorPage(initial: settings, initialPage: page),
      ),
    );
    Future<void> save(BackgroundSettings settings) async {
      try {
        await ref.read(backgroundSettingsProvider.notifier).save(settings);
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showAppSnackBar(
            SnackBar(
              content: Text(
                text.t('Could not save backgrounds', '背景保存失败', '背景儲存失敗'),
              ),
            ),
          );
        }
      }
    }

    return BackgroundScaffold(
      appBar: AppBar(title: Text(text.title)),
      body: value.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (settings) => ListView(
          children: [
            SwitchListTile(
              title: Text(
                text.t('Enable page backgrounds', '启用页面背景', '啟用頁面背景'),
              ),
              value: settings.enabled,
              onChanged: (v) => save(settings.copyWith(enabled: v)),
            ),
            SwitchListTile(
              title: Text(
                text.t('Play animated backgrounds', '播放动态背景', '播放動態背景'),
              ),
              subtitle: Text(
                text.t(
                  'Muted; paused when hidden or reduced motion is enabled',
                  '静音；后台或系统减少动态效果时暂停',
                  '靜音；背景或系統減少動態效果時暫停',
                ),
              ),
              value: settings.animate,
              onChanged: (v) => save(settings.copyWith(animate: v)),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: FilledButton.icon(
                key: const Key('background-configure'),
                icon: const Icon(Icons.wallpaper),
                label: Text(
                  text.t('Choose a page and edit', '选择页面并编辑', '選擇頁面並編輯'),
                ),
                onPressed: () => edit(settings),
              ),
            ),
            for (final page in BackgroundPage.values)
              ListTile(
                title: Text(text.page(page)),
                subtitle: Text(
                  settings.assets[settings.resolved(page).assetId]?.name ??
                      text.t('No background', '未设置背景', '未設定背景'),
                ),
                leading: const Icon(Icons.image_outlined),
                onTap: () => edit(settings, page),
                trailing: IconButton(
                  tooltip: text.t('Clear this page', '清除此页背景', '清除此頁背景'),
                  icon: const Icon(Icons.clear),
                  onPressed: () async {
                    var next = settings;
                    if (page == BackgroundPage.grid) {
                      for (final other in BackgroundPage.values.where(
                        (p) => p != page && next.page(p).followGrid,
                      )) {
                        next = next.detach(other);
                      }
                    }
                    next = next.updatePage(
                      page,
                      const PageBackgroundSettings(),
                    );
                    await save(next);
                  },
                ),
              ),
            ListTile(
              title: Text(
                text.t('Restore default backgrounds', '恢复默认背景', '恢復預設背景'),
              ),
              leading: const Icon(Icons.restore),
              onTap: () async {
                final yes = await showDialog<bool>(
                  context: context,
                  builder: (c) => AlertDialog(
                    title: Text(
                      text.t(
                        'Remove background configuration?',
                        '清除所有页面背景设置？',
                        '清除所有頁面背景設定？',
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(c, false),
                        child: Text(text.t('Cancel', '取消')),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(c, true),
                        child: Text(text.t('Restore', '恢复', '恢復')),
                      ),
                    ],
                  ),
                );
                if (yes == true) await save(const BackgroundSettings());
              },
            ),
          ],
        ),
      ),
    );
  }
}

class BackgroundEditorPage extends ConsumerStatefulWidget {
  const BackgroundEditorPage({
    required this.initial,
    this.initialPage = BackgroundPage.grid,
    super.key,
  });
  final BackgroundSettings initial;
  final BackgroundPage initialPage;
  @override
  ConsumerState<BackgroundEditorPage> createState() =>
      _BackgroundEditorPageState();
}

class _BackgroundEditorPageState extends ConsumerState<BackgroundEditorPage> {
  late BackgroundSettings _draft = widget.initial;
  late BackgroundPage _page = widget.initialPage;
  final _registry = BackgroundRegionRegistry();
  final _previewKey = GlobalKey();
  final _sceneKey = GlobalKey();
  final _captureKey = GlobalKey();

  final _imported = <BackgroundAsset>[];
  bool _busy = false, _browse = false, _saved = false, _mouse = false;
  int _step = 0;
  bool _allowExit = false;
  bool _confirmingExit = false;
  bool _expandedControls = false;
  bool get _following =>
      _page != BackgroundPage.grid && _draft.page(_page).followGrid;
  double _startZoom = 1;
  ScrollPosition? _scroll;
  String? _error;
  late final BackgroundAssetService _service = ref.read(
    backgroundAssetServiceProvider,
  );
  late final _preferences = ref.read(settingsServiceProvider);
  bool get _dirty =>
      jsonEncode(_draft.toJson()) != jsonEncode(widget.initial.toJson());
  @override
  void initState() {
    super.initState();
    _service;
    _preferences;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ScaffoldMessenger.of(context).hideCurrentSnackBar();
    });
  }

  @override
  void dispose() {
    final service = _service;
    final preferences = _preferences;
    unawaited(() async {
      try {
        final saved = await preferences.loadBackgroundSettings();
        await service.removeUnreferenced(_imported, saved);
      } catch (_) {
        /* Keep media if committed references cannot be checked. */
      }
    }());
    _registry.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    if (_following || _busy) return;
    setState(() {
      _error = null;
      _busy = true;
    });
    try {
      final selected = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: BackgroundAssetService.extensions,
        withData: false,
      );
      if (selected == null || selected.files.single.path == null || !mounted) {
        return;
      }
      setState(() => _busy = true);
      final asset = await _service.importFile(
        File(selected.files.single.path!),
        name: selected.files.single.name,
      );
      _imported.add(asset);
      if (!mounted) return;
      var next = _draft;
      next = next.copyWith(
        enabled: true,
        assets: {...next.assets, asset.id: asset},
      );
      next = next.updatePage(
        _page,
        next
            .page(_page)
            .copyWith(
              assetId: asset.id,
              followGrid: false,
              framing: const BackgroundFraming(),
            ),
      );
      setState(() {
        _draft = next;
      });
    } catch (e) {
      if (mounted) {
        setState(
          () => _error =
              '${BackgroundText(context).t('Could not decode this media', '无法解码此素材', '無法解碼此素材')}：$e',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _close() async {
    if (!mounted) return;
    setState(() {
      _allowExit = true;
      _busy = false;
    });
    // PopScope must rebuild before Navigator sees the updated disposition.
    await WidgetsBinding.instance.endOfFrame;
    if (mounted) Navigator.of(context).pop();
  }

  Future<bool> _save() async {
    if (_busy) return false;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final used = {
        for (final p in BackgroundPage.values) _draft.resolved(p).assetId,
      };
      final next = _draft.copyWith(
        assets: Map.fromEntries(
          _draft.assets.entries.where((e) => used.contains(e.key)),
        ),
      );
      await ref.read(backgroundSettingsProvider.notifier).save(next);
      if (!mounted) return true;
      _saved = true;
      ScaffoldMessenger.of(context).showAppSnackBar(
        SnackBar(
          content: Text(
            BackgroundText(context).t('Background saved', '背景已保存', '背景已儲存'),
          ),
        ),
      );
      await _close();
      return true;
    } catch (e) {
      if (mounted) {
        setState(
          () => _error =
              '${BackgroundText(context).t('Could not save. Please retry.', '保存失败，请重试。', '儲存失敗，請重試。')} $e',
        );
      }
      return false;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _exit() async {
    if (_busy || _confirmingExit) return;
    if (_saved || !_dirty) {
      await _close();
      return;
    }
    _confirmingExit = true;
    final t = BackgroundText(context);
    final choice = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(t.t('Save background changes?', '保存背景更改？', '儲存背景變更？')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, 'cancel'),
            child: Text(t.t('Continue editing', '继续编辑', '繼續編輯')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, 'discard'),
            child: Text(t.t('Discard', '放弃', '放棄')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, 'save'),
            child: Text(t.t('Save', '保存', '儲存')),
          ),
        ],
      ),
    );
    _confirmingExit = false;
    if (!mounted) return;
    if (choice == 'save') await _save();
    if (choice == 'discard') await _close();
  }

  Future<void> _next() async {
    setState(() {
      _step++;
      _browse = false;
      _expandedControls = false;
    });
    if (_step == 1 &&
        _draft.resolved(_page).assetId == null &&
        !_following &&
        (_page == BackgroundPage.grid ||
            _draft.page(BackgroundPage.grid).assetId == null)) {
      await _pick();
    }
  }

  void _previous() => setState(() {
    _step = math.max(0, _step - 1);
    _expandedControls = false;
  });

  void _updateFrame(BackgroundFraming frame) {
    if (_following || _busy) return;
    final asset = _draft.assets[_draft.resolved(_page).assetId];
    final render = _sceneKey.currentContext?.findRenderObject();
    if (asset != null && render is RenderBox && render.hasSize) {
      final rect = backgroundRect(
        render.size,
        Size(asset.width.toDouble(), asset.height.toDouble()),
        frame,
      );
      frame = frame.copyWith(
        zoom: frame.zoom.clamp(frame.allowEdges ? .1 : 1.0, 8.0),
        x: (rect.center.dx - render.size.width / 2) / render.size.width,
        y: (rect.center.dy - render.size.height / 2) / render.size.height,
      );
    }
    setState(() => _draft = _draft.setFraming(_page, frame));
  }

  void _toggle(BackgroundRegionId region) {
    if (_busy ||
        (_following &&
            (region == BackgroundRegionId.header ||
                region == BackgroundRegionId.navigation))) {
      return;
    }
    final value = _draft.page(_page);
    final regions = {...value.regions};
    if (!regions.remove(region)) regions.add(region);
    setState(
      () => _draft = _draft.updatePage(_page, value.copyWith(regions: regions)),
    );
  }

  Rect? get _sceneRect {
    final box = _sceneKey.currentContext?.findRenderObject();
    return box is RenderBox && box.hasSize
        ? MatrixUtils.transformRect(
            box.getTransformTo(null),
            Offset.zero & box.size,
          )
        : null;
  }

  ScrollPosition? _findScroll(Offset global) {
    ScrollPosition? result;
    void visit(Element element) {
      if (element is StatefulElement && element.state is ScrollableState) {
        final box = element.renderObject;
        if (box is RenderBox &&
            box.hasSize &&
            MatrixUtils.transformRect(
              box.getTransformTo(null),
              Offset.zero & box.size,
            ).contains(global)) {
          final position = (element.state as ScrollableState).position;
          if (position.hasContentDimensions &&
              position.maxScrollExtent > 0 &&
              position.axis == Axis.vertical) {
            result = position;
          }
        }
      }
      element.visitChildren(visit);
    }

    _sceneKey.currentContext?.visitChildElements(visit);
    return result;
  }

  void _scrollBy(double pixels) {
    final p = _scroll;
    if (p != null && p.hasPixels && p.hasContentDimensions) {
      p.jumpTo((p.pixels + pixels).clamp(p.minScrollExtent, p.maxScrollExtent));
      _registry.changed();
    }
  }

  void _zoom(double zoom, [Offset? focal, Offset delta = Offset.zero]) {
    final frame = _draft.resolved(_page).framing;
    final rect = _sceneRect;
    if (rect == null) return;
    final next = zoom.clamp(frame.allowEdges ? .1 : 1.0, 8.0);
    final ratio = next / frame.zoom;
    final point = focal ?? rect.center;
    final fx = (point.dx - rect.center.dx) / rect.width;
    final fy = (point.dy - rect.center.dy) / rect.height;
    _updateFrame(
      frame.copyWith(
        zoom: next,
        x: fx + (frame.x - fx) * ratio + delta.dx / rect.width,
        y: fy + (frame.y - fy) * ratio + delta.dy / rect.height,
      ),
    );
  }

  Widget _preview(Size viewport, BackgroundText t) {
    final settings = _draft.copyWith(enabled: true);
    final asset = settings.asset(_page);
    final page = switch (_page) {
      BackgroundPage.grid => const GridPage(),
      BackgroundPage.upcoming => const UpcomingPage(),
      BackgroundPage.import => const ImportPage(),
      BackgroundPage.settings => const SettingsPage(),
    };
    return Stack(
      fit: StackFit.expand,
      children: [
        ExcludeFocus(
          child: IgnorePointer(
            child: FittedBox(
              fit: BoxFit.contain,
              child: RepaintBoundary(
                key: _captureKey,
                child: SizedBox(
                  key: _sceneKey,
                  width: viewport.width,
                  height: viewport.height,
                  child: MediaQuery(
                    data: MediaQuery.of(context).copyWith(size: viewport),
                    child: BackgroundPageTheme(
                      settings: settings,
                      owner: _page,
                      registry: _registry,
                      child: Builder(
                        builder: (context) => Stack(
                          fit: StackFit.expand,
                          children: [
                            ColoredBox(
                              color: Theme.of(context).colorScheme.surface,
                            ),
                            if (asset != null)
                              BackgroundMedia(
                                key: ValueKey(
                                  'editor-${settings.continuityKey(_page)}',
                                ),
                                asset: asset,
                                framing: settings.resolved(_page).framing,
                                service: _service,
                                animate: settings.animate,
                              ),
                            Scaffold(
                              backgroundColor: Colors.transparent,
                              body: Row(
                                children: [
                                  if (viewport.width >= 720)
                                    BackgroundRegion(
                                      region: BackgroundRegionId.navigation,
                                      child: NavigationRail(
                                        backgroundColor:
                                            BackgroundPageScope.color(
                                              context,
                                              BackgroundRegionId.navigation,
                                              Theme.of(
                                                context,
                                              ).colorScheme.surface,
                                            ),
                                        selectedIndex: _page.index,
                                        onDestinationSelected: (_) {},
                                        labelType:
                                            NavigationRailLabelType.selected,
                                        leading: Padding(
                                          padding: const EdgeInsets.only(
                                            top: 12,
                                            bottom: 8,
                                          ),
                                          child: CircleAvatar(
                                            radius: 20,
                                            backgroundColor: Theme.of(
                                              context,
                                            ).colorScheme.primaryContainer,
                                            child: Icon(
                                              Icons.calendar_month,
                                              color: Theme.of(
                                                context,
                                              ).colorScheme.onPrimaryContainer,
                                              size: 22,
                                            ),
                                          ),
                                        ),
                                        destinations: [
                                          for (final p in BackgroundPage.values)
                                            NavigationRailDestination(
                                              icon: Icon(_icon(p)),
                                              label: Text(t.page(p)),
                                            ),
                                        ],
                                      ),
                                    ),
                                  if (viewport.width >= 720)
                                    VerticalDivider(
                                      width: 1,
                                      thickness: 1,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.outlineVariant,
                                    ),
                                  Expanded(child: page),
                                ],
                              ),
                              bottomNavigationBar: viewport.width < 720
                                  ? BackgroundRegion(
                                      region: BackgroundRegionId.navigation,
                                      child: NavigationBar(
                                        backgroundColor:
                                            BackgroundPageScope.color(
                                              context,
                                              BackgroundRegionId.navigation,
                                              Theme.of(
                                                context,
                                              ).colorScheme.surface,
                                            ),
                                        surfaceTintColor: Colors.transparent,
                                        selectedIndex: _page.index,
                                        onDestinationSelected: (_) {},
                                        destinations: [
                                          for (final p in BackgroundPage.values)
                                            NavigationDestination(
                                              icon: Icon(_icon(p)),
                                              label: t.page(p),
                                            ),
                                        ],
                                      ),
                                    )
                                  : null,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: Listener(
            onPointerDown: (e) {
              _mouse = e.kind == PointerDeviceKind.mouse;
            },
            onPointerSignal: (e) {
              if (e is PointerScrollEvent) {
                if (_browse) {
                  _scroll = _findScroll(e.position);
                  _scrollBy(e.scrollDelta.dy);
                } else {
                  _zoom(
                    _draft.resolved(_page).framing.zoom *
                        math.exp(-e.scrollDelta.dy * .001),
                    e.position,
                  );
                }
              }
            },
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapUp: _browse
                  ? null
                  : (d) {
                      final region = _registry.at(d.globalPosition);
                      if (region != null && region.page == _page) {
                        _toggle(region.region);
                      }
                    },
              onScaleStart: (d) {
                _startZoom = _draft.resolved(_page).framing.zoom;
                _scroll = _browse ? _findScroll(d.focalPoint) : null;
              },
              onScaleUpdate: (d) {
                if (_browse) {
                  final rect = _sceneRect;
                  _scrollBy(
                    -d.focalPointDelta.dy *
                        (rect == null ? 1 : viewport.height / rect.height),
                  );
                } else if (d.pointerCount >= 2 || _mouse) {
                  _zoom(_startZoom * d.scale, d.focalPoint, d.focalPointDelta);
                }
              },
              child: CustomPaint(
                key: _previewKey,
                painter: _browse
                    ? null
                    : _RegionPainter(_registry, _page, _draft, t, _previewKey),
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = BackgroundText(context);
    final viewport = MediaQuery.sizeOf(context);
    final wide = viewport.width >= 900;
    return PopScope(
      canPop: _allowExit,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_exit());
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: _busy ? null : _exit,
          ),
          title: Text(
            _step == 0
                ? t.t('Choose a page', '选择编辑页面', '選擇編輯頁面')
                : '${t.page(_page)} · ${_step == 1 ? t.t('Layout', '区域与构图', '區域與構圖') : t.t('Effects', '效果调整', '效果調整')}',
          ),
        ),
        body: Column(
          children: [
            if (_busy) const LinearProgressIndicator(),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            Expanded(
              child: _step == 0
                  ? _pageChooser(t)
                  : wide
                  ? Row(
                      children: [
                        Expanded(child: _preview(viewport, t)),
                        SizedBox(width: 340, child: _controls(t)),
                      ],
                    )
                  : Column(
                      children: [
                        Expanded(child: _preview(viewport, t)),
                        TextButton.icon(
                          onPressed: () => setState(
                            () => _expandedControls = !_expandedControls,
                          ),
                          icon: Icon(
                            _expandedControls
                                ? Icons.expand_more
                                : Icons.expand_less,
                          ),
                          label: Text(t.t('Adjustments', '调整选项', '調整選項')),
                        ),
                        SizedBox(
                          height: math.min(
                            _expandedControls ? 300 : 150,
                            viewport.height * (_expandedControls ? .42 : .23),
                          ),
                          child: _controls(t),
                        ),
                      ],
                    ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    if (_step > 0)
                      TextButton(
                        onPressed: _busy ? null : _previous,
                        child: Text(t.t('Back', '上一步', '上一步')),
                      ),
                    const Spacer(),
                    FilledButton(
                      key: const Key('background-next-save'),
                      onPressed: _busy
                          ? null
                          : _step == 2
                          ? () => _save()
                          : _next,
                      child: Text(
                        _step == 2
                            ? t.t('Save', '保存', '儲存')
                            : t.t('Next', '下一步', '下一步'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectPage(BackgroundPage page) async {
    if (page == _page) return;
    if (_dirty) {
      final t = BackgroundText(context);
      final discard = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: Text(
            t.t(
              'Discard changes before switching pages?',
              '放弃当前更改并切换编辑页面？',
              '放棄目前變更並切換編輯頁面？',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: Text(t.t('Continue editing', '继续编辑', '繼續編輯')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: Text(t.t('Discard', '放弃', '放棄')),
            ),
          ],
        ),
      );
      if (discard != true || !mounted) return;
    }
    setState(() {
      _draft = widget.initial;
      _page = page;
      _error = null;
      _browse = false;
    });
  }

  Widget _pageChooser(BackgroundText t) => ListView(
    children: [
      for (final page in BackgroundPage.values)
        ListTile(
          key: ValueKey('background-page-${page.name}'),
          leading: Icon(
            _page == page ? Icons.radio_button_checked : Icons.radio_button_off,
          ),
          title: Text(t.page(page)),
          subtitle: Text(
            _draft.assets[_draft.resolved(page).assetId]?.name ??
                t.t('No background', '未设置背景', '未設定背景'),
          ),
          selected: _page == page,
          onTap: _busy ? null : () => _selectPage(page),
        ),
    ],
  );

  Widget _controls(BackgroundText t) {
    final value = _draft.page(_page);
    final effective = _draft.resolved(_page);
    final frame = effective.framing;
    final canFrame = !_busy && !_following;
    final desktop = defaultTargetPlatform == TargetPlatform.windows;
    final zoomControls = [
      IconButton(
        tooltip: t.t('Zoom out', '缩小', '縮小'),
        onPressed: canFrame ? () => _zoom(frame.zoom / 1.1) : null,
        icon: const Icon(Icons.remove),
      ),
      Text('${frame.zoom.toStringAsFixed(2)}×'),
      IconButton(
        tooltip: t.t('Zoom in', '放大'),
        onPressed: canFrame ? () => _zoom(frame.zoom * 1.1) : null,
        icon: const Icon(Icons.add),
      ),
    ];
    return SingleChildScrollView(
      key: ValueKey('controls-${_page.name}-$_step'),
      padding: EdgeInsets.symmetric(horizontal: desktop ? 16 : 12, vertical: 6),
      child: Column(
        children: [
          if (_step == 2) ...[
            _slider(
              t.t('Background blur', '背景模糊', '背景模糊'),
              frame.blur,
              1,
              canFrame ? (v) => _updateFrame(frame.copyWith(blur: v)) : null,
            ),
            _slider(
              t.t('Background dimming', '背景暗化', '背景暗化'),
              frame.dim,
              .9,
              canFrame ? (v) => _updateFrame(frame.copyWith(dim: v)) : null,
            ),
            _slider(
              t.t('Card opacity', '底板不透明度', '底板不透明度'),
              value.surfaceOpacity,
              1,
              (v) => setState(
                () => _draft = _draft.updatePage(
                  _page,
                  value.copyWith(surfaceOpacity: v),
                ),
              ),
            ),
          ],
          Text(
            t.t(
              'Tap regions; pinch to compose. Desktop: drag / wheel.',
              '点击区块；双指缩放拖动。桌面：拖动／滚轮。',
              '點擊區塊；雙指縮放拖曳。桌面：拖曳／滾輪。',
            ),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (desktop) const SizedBox(height: 12),
          TextButton(
            onPressed: _busy ? null : () => setState(() => _browse = !_browse),
            child: Text(
              _browse
                  ? t.t('Edit regions', '区域编辑', '區域編輯')
                  : t.t('Browse preview', '浏览预览', '瀏覽預覽'),
            ),
          ),
          if (desktop) const SizedBox(height: 12),
          if (_page != BackgroundPage.grid)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                t.t('Follow schedule background', '跟随课表背景', '跟隨課表背景'),
              ),
              subtitle: Text(
                _draft.page(BackgroundPage.grid).assetId == null
                    ? t.t(
                        'Set a schedule background first',
                        '请先设置课表背景',
                        '請先設定課表背景',
                      )
                    : t.t(
                        'Media, framing, effects, header and navigation follow the schedule. Turn off to edit independently.',
                        '素材、构图、效果、标题栏和主导航跟随课表；关闭后可独立编辑。',
                        '素材、構圖、效果、標題列和主導覽跟隨課表；關閉後可獨立編輯。',
                      ),
              ),
              value: value.followGrid,
              onChanged:
                  _busy || _draft.page(BackgroundPage.grid).assetId == null
                  ? null
                  : (v) => setState(
                      () => _draft = v
                          ? _draft
                                .copyWith(enabled: true)
                                .updatePage(
                                  _page,
                                  value.copyWith(followGrid: true),
                                )
                          : _draft.detach(_page),
                    ),
            ),
          if (_page == BackgroundPage.grid &&
              BackgroundPage.values.any(
                (p) => p != _page && _draft.page(p).followGrid,
              ))
            Text(
              t.t(
                'Changes also affect pages following the schedule.',
                '修改会同时影响跟随课表的页面。',
                '修改會同時影響跟隨課表的頁面。',
              ),
              style: TextStyle(color: Theme.of(context).colorScheme.primary),
            ),
          if (_step == 1) ...[
            Wrap(
              key: const Key('background-region-controls'),
              spacing: desktop ? 8 : 4,
              runSpacing: desktop ? 8 : 0,
              children: [
                for (final region in backgroundRegions(_page))
                  FilterChip(
                    label: Text(t.region(region)),
                    selected: effective.regions.contains(region),
                    onSelected:
                        _busy ||
                            (_following &&
                                (region == BackgroundRegionId.header ||
                                    region == BackgroundRegionId.navigation))
                        ? null
                        : (_) => _toggle(region),
                  ),
              ],
            ),
            if (desktop) const SizedBox(height: 12),
            TextButton.icon(
              onPressed: canFrame ? _pick : null,
              icon: const Icon(Icons.image_outlined),
              label: Text(t.t('Change media', '更换素材', '更換素材')),
            ),
            if (desktop) const SizedBox(height: 12),
          ],
          Wrap(
            key: const Key('background-framing-controls'),
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: desktop ? 8 : 0,
            runSpacing: desktop ? 8 : 0,
            children: [
              if (desktop)
                Row(mainAxisSize: MainAxisSize.min, children: zoomControls)
              else
                ...zoomControls,
              TextButton(
                onPressed: canFrame
                    ? () => _updateFrame(frame.copyWith(x: 0, y: 0))
                    : null,
                child: Text(t.t('Center', '居中')),
              ),
              TextButton(
                onPressed: canFrame
                    ? () => _updateFrame(frame.copyWith(zoom: 1, x: 0, y: 0))
                    : null,
                child: Text(t.t('Reset framing', '重置构图', '重設構圖')),
              ),
            ],
          ),
          if (desktop) const SizedBox(height: 12),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(t.t('Allow image edges', '允许露出图片边缘', '允許露出圖片邊緣')),
            value: frame.allowEdges,
            onChanged: canFrame
                ? (v) => _updateFrame(frame.copyWith(allowEdges: v))
                : null,
          ),
          if (_step == 2) ...[
            if (frame.allowEdges)
              DropdownButtonFormField<BackgroundEdgeFill>(
                initialValue: frame.fill,
                key: ValueKey('${_page.name}-${frame.fill.name}'),
                decoration: InputDecoration(
                  labelText: t.t('Outside image', '图片外部填补', '圖片外部填補'),
                ),
                items: [
                  DropdownMenuItem(
                    value: BackgroundEdgeFill.theme,
                    child: Text(t.t('Theme color', '主题底色', '主題底色')),
                  ),
                  DropdownMenuItem(
                    value: BackgroundEdgeFill.blur,
                    child: Text(t.t('Blurred media', '模糊背景')),
                  ),
                ],
                onChanged: canFrame
                    ? (v) {
                        if (v != null) _updateFrame(frame.copyWith(fill: v));
                      }
                    : null,
              ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(t.t('Automatic text protection', '自动文字保护', '自動文字保護')),
              subtitle: Text(
                t.t(
                  'Soft text shadows below 30% dimming',
                  '暗化低于30%时添加柔和文字阴影',
                  '暗化低於30%時加入柔和文字陰影',
                ),
              ),
              value: value.autoTextProtection,
              onChanged: _busy
                  ? null
                  : (v) => setState(
                      () => _draft = _draft.updatePage(
                        _page,
                        value.copyWith(autoTextProtection: v),
                      ),
                    ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _slider(
    String title,
    double value,
    double max,
    ValueChanged<double>? changed,
  ) => Row(
    children: [
      SizedBox(width: 130, child: Text('$title ${(value * 100).round()}%')),
      Expanded(
        child: Slider(
          value: value,
          max: max,
          onChanged: _busy ? null : changed,
        ),
      ),
    ],
  );
}

IconData _icon(BackgroundPage page) => switch (page) {
  BackgroundPage.grid => Icons.grid_view,
  BackgroundPage.upcoming => Icons.schedule,
  BackgroundPage.import => Icons.upload_file,
  BackgroundPage.settings => Icons.settings,
};

class _RegionPainter extends CustomPainter {
  _RegionPainter(this.registry, this.page, this.settings, this.text, this.host)
    : super(repaint: registry);
  final BackgroundRegionRegistry registry;
  final BackgroundPage page;
  final BackgroundSettings settings;
  final BackgroundText text;
  final GlobalKey host;
  @override
  void paint(Canvas canvas, Size size) {
    final render = host.currentContext?.findRenderObject();
    if (render is! RenderBox || !render.hasSize) return;
    final origin = render.localToGlobal(Offset.zero);
    final visible = Offset.zero & size;
    for (final item in registry.registrations.values.where(
      (r) => r.page == page,
    )) {
      final bounds = item.bounds;
      if (bounds == null) continue;
      final rect = bounds.shift(-origin).intersect(visible);
      if (rect.isEmpty) continue;
      final selected = settings.resolved(page).regions.contains(item.region);
      final color = selected ? Colors.tealAccent : Colors.orangeAccent;
      canvas.drawRect(
        rect.deflate(1),
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
      final label = TextPainter(
        text: TextSpan(
          text: '${selected ? "✓" : "○"} ${text.region(item.region)}',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            backgroundColor: Colors.black87,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: rect.width);
      label.paint(canvas, rect.topLeft + const Offset(3, 3));
    }
  }

  @override
  bool shouldRepaint(_RegionPainter old) =>
      old.page != page || old.settings != settings;
}
