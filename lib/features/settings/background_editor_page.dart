import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'dart:math' as math;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/gestures.dart';
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
                  text.t('Choose media and configure', '选择素材并设置', '選擇素材並設定'),
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
  final _shots = <BackgroundPage, ui.Image>{};
  final _imported = <BackgroundAsset>[];
  bool _busy = false,
      _browse = false,
      _overview = false,
      _saved = false,
      _mouse = false;
  bool _needsScope = false;
  List<BackgroundPage>? _steps;
  int _step = 0;
  double _startZoom = 1;
  ScrollPosition? _scroll;
  String? _error;
  late final BackgroundAssetService _service = ref.read(
    backgroundAssetServiceProvider,
  );
  late BackgroundSettings _persisted = widget.initial;
  bool get _dirty =>
      jsonEncode(_draft.toJson()) != jsonEncode(widget.initial.toJson());
  @override
  void initState() {
    super.initState();
    _service;
    _persisted;
    if (widget.initial.resolved(_page).assetId == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_pick());
      });
    }
  }

  @override
  void dispose() {
    final service = _service;
    final saved = _persisted;
    unawaited(service.removeUnreferenced(_imported, saved));
    for (final image in _shots.values) {
      image.dispose();
    }
    _registry.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
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
      if (_page == BackgroundPage.grid) {
        for (final p in BackgroundPage.values.where(
          (p) => p != _page && next.page(p).followGrid,
        )) {
          next = next.detach(p);
        }
      }
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
        if (_page == BackgroundPage.grid) {
          _needsScope = true;
          _steps = null;
          _step = 0;
        }
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

  Future<void> _save() async {
    if (_needsScope) {
      setState(() {
        _page = BackgroundPage.grid;
        _overview = false;
      });
      await _next();
      return;
    }
    setState(() => _busy = true);
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
      _persisted = next;
      if (mounted) {
        setState(() => _saved = true);
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> _exit() async {
    if (_saved || !_dirty) return true;
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
    if (choice == 'save') {
      await _save();
      return false;
    }
    return choice == 'discard';
  }

  Future<void> _next() async {
    await _capture();
    if (!mounted) return;
    final t = BackgroundText(context);
    if (_steps == null && _page == BackgroundPage.grid) {
      final selected = <BackgroundPage>{};
      final proceed = await showDialog<bool>(
        context: context,
        builder: (c) => StatefulBuilder(
          builder: (c, update) => AlertDialog(
            title: Text(t.t('Apply to other pages?', '应用到其他页面？', '套用到其他頁面？')),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  t.t(
                    'Selected pages share the schedule image and framing. Unselected pages keep their backgrounds.',
                    '选定页面共用课表素材与构图。未选页面保留自己的背景。',
                    '選定頁面共用課表素材與構圖。未選頁面保留自己的背景。',
                  ),
                ),
                for (final p in BackgroundPage.values.where(
                  (p) => p != BackgroundPage.grid,
                ))
                  CheckboxListTile(
                    title: Text(t.page(p)),
                    value: selected.contains(p),
                    onChanged: (v) => update(
                      () => v == true ? selected.add(p) : selected.remove(p),
                    ),
                  ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: Text(t.t('Schedule only', '只应用课表', '只套用課表')),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(c, true),
                child: Text(t.t('Continue', '继续', '繼續')),
              ),
            ],
          ),
        ),
      );
      if (proceed == null || !mounted) return;
      var next = _draft;
      final steps = proceed ? selected.toList() : <BackgroundPage>[];
      for (final p in steps) {
        next = next.updatePage(
          p,
          next
              .page(p)
              .copyWith(
                assetId: next.page(BackgroundPage.grid).assetId,
                followGrid: true,
              ),
        );
      }
      setState(() {
        _draft = next;
        _needsScope = false;
        _steps = steps;
        _step = 0;
        if (steps.isEmpty) {
          _overview = true;
        } else {
          _page = steps.first;
        }
      });
    } else if (_steps != null && _step + 1 < _steps!.length) {
      setState(() => _page = _steps![++_step]);
    } else {
      setState(() => _overview = true);
    }
  }

  Future<void> _capture() async {
    final object = _captureKey.currentContext?.findRenderObject();
    if (object is! RenderRepaintBoundary || object.debugNeedsPaint) return;
    final owner = _page;
    try {
      final image = await object.toImage(pixelRatio: .35);
      if (!mounted) {
        image.dispose();
        return;
      }
      _shots.remove(owner)?.dispose();
      _shots[owner] = image;
    } catch (_) {
      /* A platform texture may not support snapshots. */
    }
  }

  void _previous() {
    setState(() {
      if (_overview) {
        _overview = false;
        return;
      }
      _overview = false;
      if (_steps != null && _step > 0) {
        _page = _steps![--_step];
      } else {
        _page = BackgroundPage.grid;
        _step = -1;
      }
    });
  }

  void _updateFrame(BackgroundFraming frame) {
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
    final value = _draft.page(_page);
    final frame = _draft.resolved(_page).framing;
    final viewport = MediaQuery.sizeOf(context);
    return PopScope(
      canPop: !_busy && (_saved || !_dirty),
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop && !_busy && await _exit() && context.mounted) {
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        appBar: AppBar(
          backgroundColor: Theme.of(context).colorScheme.surface,
          surfaceTintColor: Colors.transparent,
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: _busy
                ? null
                : () async {
                    if (await _exit() && context.mounted) {
                      Navigator.pop(context);
                    }
                  },
          ),
          title: Text(t.title),
          actions: [
            IconButton(
              tooltip: t.t('Previous step', '上一步'),
              onPressed: _busy ? null : _previous,
              icon: const Icon(Icons.arrow_back),
            ),
            TextButton(
              onPressed: _busy ? null : _save,
              child: Text(t.t('Save', '保存', '儲存')),
            ),
          ],
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
              child: _overview
                  ? ListView(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            t.t(
                              'Review each page, then save all changes together.',
                              '检查各页效果后统一保存。',
                              '檢查各頁效果後統一儲存。',
                            ),
                          ),
                        ),
                        for (final p in BackgroundPage.values)
                          ListTile(
                            title: Text(t.page(p)),
                            subtitle: Text(
                              _draft.assets[_draft.resolved(p).assetId]?.name ??
                                  t.t('No background', '未设置背景', '未設定背景'),
                            ),
                            leading: _shots[p] == null
                                ? null
                                : SizedBox(
                                    width: 80,
                                    height: 100,
                                    child: RawImage(
                                      image: _shots[p],
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                            minTileHeight: _shots[p] == null ? null : 124,
                            trailing: const Icon(Icons.edit_outlined),
                            onTap: () => setState(() {
                              _page = p;
                              _overview = false;
                            }),
                          ),
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: FilledButton(
                            onPressed: _busy ? null : _save,
                            child: Text(
                              t.t('Save all pages', '保存全部页面', '儲存全部頁面'),
                            ),
                          ),
                        ),
                      ],
                    )
                  : _preview(viewport, t),
            ),
            if (!_overview)
              SizedBox(
                height: math.min(228, viewport.height * .42),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  child: Column(
                    children: [
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        children: [
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 260),
                            child: DropdownButton<BackgroundPage>(
                              isExpanded: true,
                              value: _page,
                              items: [
                                for (final p in BackgroundPage.values)
                                  DropdownMenuItem(
                                    value: p,
                                    child: Text(t.page(p)),
                                  ),
                              ],
                              onChanged: _busy
                                  ? null
                                  : (p) {
                                      if (p != null) setState(() => _page = p);
                                    },
                            ),
                          ),
                          const SizedBox(width: 8),
                          TextButton(
                            onPressed: _busy
                                ? null
                                : () => setState(() => _browse = !_browse),
                            child: Text(
                              _browse
                                  ? t.t('Edit regions', '区域编辑', '區域編輯')
                                  : t.t('Browse preview', '浏览预览', '瀏覽預覽'),
                            ),
                          ),
                          FilledButton(
                            onPressed: _busy ? null : _next,
                            child: Text(t.t('Next', '下一步')),
                          ),
                        ],
                      ),
                      Text(
                        t.t(
                          'Tap a region; pinch with two fingers to zoom and drag. Desktop: drag / mouse wheel.',
                          '点击区域开关；双指缩放拖动。桌面：拖动／滚轮。',
                          '點擊區域開關；雙指縮放拖曳。桌面：拖曳／滾輪。',
                        ),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      if ((_page == BackgroundPage.grid || value.followGrid) &&
                          BackgroundPage.values.any(
                            (p) =>
                                p != BackgroundPage.grid &&
                                _draft.page(p).followGrid,
                          ))
                        Text(
                          t.t(
                            'Framing changes affect every page sharing the schedule.',
                            '调整构图会同时影响所有与课表共用的页面。',
                            '調整構圖會同時影響所有與課表共用的頁面。',
                          ),
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      Wrap(
                        spacing: 5,
                        children: [
                          for (final region in backgroundRegions(_page))
                            FilterChip(
                              label: Text(t.region(region)),
                              selected: value.regions.contains(region),
                              onSelected: _busy ? null : (_) => _toggle(region),
                            ),
                        ],
                      ),
                      if (_page != BackgroundPage.grid)
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            t.t('Share schedule framing', '与课表共用构图', '與課表共用構圖'),
                          ),
                          subtitle: Text(
                            t.t(
                              'Zoom, position, edge fill and dimming change together.',
                              '缩放、位置、边缘填补和暗化同步变更。',
                              '縮放、位置、邊緣填補和暗化同步變更。',
                            ),
                          ),
                          value: value.followGrid,
                          onChanged:
                              _busy ||
                                  _draft.page(BackgroundPage.grid).assetId ==
                                      null
                              ? null
                              : (v) => setState(
                                  () => _draft = v
                                      ? _draft.updatePage(
                                          _page,
                                          value.copyWith(followGrid: true),
                                        )
                                      : _draft.detach(_page),
                                ),
                        ),
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          TextButton.icon(
                            onPressed: _busy ? null : _pick,
                            icon: const Icon(Icons.image_outlined),
                            label: Text(t.t('Change media', '更换素材', '更換素材')),
                          ),
                          IconButton(
                            tooltip: t.t('Zoom out', '缩小', '縮小'),
                            onPressed: () => _zoom(frame.zoom / 1.1),
                            icon: const Icon(Icons.remove),
                          ),
                          Text('${frame.zoom.toStringAsFixed(2)}×'),
                          IconButton(
                            tooltip: t.t('Zoom in', '放大'),
                            onPressed: () => _zoom(frame.zoom * 1.1),
                            icon: const Icon(Icons.add),
                          ),
                          TextButton(
                            onPressed: _busy
                                ? null
                                : () =>
                                      _updateFrame(frame.copyWith(x: 0, y: 0)),
                            child: Text(t.t('Center', '居中')),
                          ),
                          TextButton(
                            onPressed: _busy
                                ? null
                                : () => _updateFrame(
                                    frame.copyWith(zoom: 1, x: 0, y: 0),
                                  ),
                            child: Text(t.t('Reset framing', '重置构图', '重設構圖')),
                          ),
                        ],
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          t.t(
                            'Allow image edges in view',
                            '允许图片边缘进入可视范围',
                            '允許圖片邊緣進入可視範圍',
                          ),
                        ),
                        value: frame.allowEdges,
                        onChanged: (v) =>
                            _updateFrame(frame.copyWith(allowEdges: v)),
                      ),
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
                              child: Text(t.t('Blurred media', '模糊背景', '模糊背景')),
                            ),
                          ],
                          onChanged: (v) {
                            if (v != null) {
                              _updateFrame(frame.copyWith(fill: v));
                            }
                          },
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
                      _slider(
                        t.t('Background dimming', '背景暗化', '背景暗化'),
                        frame.dim,
                        .8,
                        (v) => _updateFrame(frame.copyWith(dim: v)),
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

  Widget _slider(
    String title,
    double value,
    double max,
    ValueChanged<double> changed,
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
      final selected = settings.page(page).regions.contains(item.region);
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
