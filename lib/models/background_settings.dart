import 'dart:math' as math;
import 'dart:ui';

enum BackgroundPage { grid, upcoming, import, settings }

enum BackgroundRegionId {
  header,
  week,
  dates,
  timeRail,
  content,
  categories,
  navigation,
}

enum BackgroundMediaKind { image, gif, video }

enum BackgroundEdgeFill { theme, blur }

List<BackgroundRegionId> backgroundRegions(BackgroundPage page) =>
    switch (page) {
      BackgroundPage.grid => const [
        BackgroundRegionId.header,
        BackgroundRegionId.week,
        BackgroundRegionId.dates,
        BackgroundRegionId.timeRail,
        BackgroundRegionId.content,
        BackgroundRegionId.navigation,
      ],
      BackgroundPage.settings => const [
        BackgroundRegionId.header,
        BackgroundRegionId.categories,
        BackgroundRegionId.content,
        BackgroundRegionId.navigation,
      ],
      _ => const [
        BackgroundRegionId.header,
        BackgroundRegionId.content,
        BackgroundRegionId.navigation,
      ],
    };

double _number(Object? value, double fallback, double min, double max) =>
    value is num && value.isFinite
    ? value.toDouble().clamp(min, max)
    : fallback;

class BackgroundAsset {
  const BackgroundAsset({
    required this.id,
    required this.name,
    required this.kind,
    required this.width,
    required this.height,
    this.durationMs,
    this.extension = 'png',
  });
  final String id, name, extension;
  final BackgroundMediaKind kind;
  final int width, height;
  final int? durationMs;
  String get relativePath => 'backgrounds/$id.$extension';
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'kind': kind.name,
    'width': width,
    'height': height,
    'durationMs': durationMs,
    'extension': extension,
  };
  factory BackgroundAsset.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final extension = json['extension'];
    if (id is! String ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(id) ||
        extension is! String ||
        !const [
          'jpg',
          'jpeg',
          'png',
          'webp',
          'gif',
          'mp4',
          'm4v',
          'mov',
          'webm',
        ].contains(extension) ||
        json['width'] is! int ||
        json['height'] is! int ||
        json['width'] <= 0 ||
        json['height'] <= 0) {
      throw const FormatException('Invalid background asset');
    }
    return BackgroundAsset(
      id: id,
      name: json['name'] as String? ?? '',
      extension: extension,
      kind: BackgroundMediaKind.values.byName(json['kind'] as String),
      width: json['width'],
      height: json['height'],
      durationMs: json['durationMs'] as int?,
    );
  }
}

class BackgroundFraming {
  const BackgroundFraming({
    this.zoom = 1,
    this.x = 0,
    this.y = 0,
    this.allowEdges = false,
    this.fill = BackgroundEdgeFill.theme,
    this.dim = .2,
  });
  final double zoom, x, y, dim;
  final bool allowEdges;
  final BackgroundEdgeFill fill;
  BackgroundFraming copyWith({
    double? zoom,
    double? x,
    double? y,
    bool? allowEdges,
    BackgroundEdgeFill? fill,
    double? dim,
  }) => BackgroundFraming(
    zoom: zoom ?? this.zoom,
    x: x ?? this.x,
    y: y ?? this.y,
    allowEdges: allowEdges ?? this.allowEdges,
    fill: fill ?? this.fill,
    dim: dim ?? this.dim,
  );
  Map<String, dynamic> toJson() => {
    'zoom': zoom,
    'x': x,
    'y': y,
    'allowEdges': allowEdges,
    'fill': fill.name,
    'dim': dim,
  };
  factory BackgroundFraming.fromJson(Map<String, dynamic> j) =>
      BackgroundFraming(
        zoom: _number(j['zoom'], 1, .1, 8),
        x: _number(j['x'], 0, -100, 100),
        y: _number(j['y'], 0, -100, 100),
        allowEdges: j['allowEdges'] == true,
        fill: j['fill'] == 'blur'
            ? BackgroundEdgeFill.blur
            : BackgroundEdgeFill.theme,
        dim: _number(j['dim'], .2, 0, .8),
      );
}

/// All geometry is relative to the complete viewport, not to each revealed region.
Rect backgroundRect(Size viewport, Size media, BackgroundFraming frame) {
  if (viewport.isEmpty || media.isEmpty) return Rect.zero;
  final cover = math.max(
    viewport.width / media.width,
    viewport.height / media.height,
  );
  final zoom = frame.zoom.clamp(frame.allowEdges ? .1 : 1.0, 8.0);
  final size = media * (cover * zoom);
  double limit(double desired, double rendered, double available) {
    final bound = frame.allowEdges
        ? math.max(
            0.0,
            (rendered + available) / 2 -
                math.min(24.0, math.min(rendered, available) / 2),
          )
        : math.max(0.0, (rendered - available) / 2);
    return desired.clamp(-bound, bound);
  }

  final dx = limit(frame.x * viewport.width, size.width, viewport.width);
  final dy = limit(frame.y * viewport.height, size.height, viewport.height);
  return Rect.fromLTWH(
    (viewport.width - size.width) / 2 + dx,
    (viewport.height - size.height) / 2 + dy,
    size.width,
    size.height,
  );
}

class PageBackgroundSettings {
  const PageBackgroundSettings({
    this.assetId,
    this.followGrid = false,
    this.framing = const BackgroundFraming(),
    this.regions = const {BackgroundRegionId.content},
    this.surfaceOpacity = .8,
  });
  final String? assetId;
  final bool followGrid;
  final BackgroundFraming framing;
  final Set<BackgroundRegionId> regions;
  final double surfaceOpacity;
  PageBackgroundSettings copyWith({
    String? assetId,
    bool clearAsset = false,
    bool? followGrid,
    BackgroundFraming? framing,
    Set<BackgroundRegionId>? regions,
    double? surfaceOpacity,
  }) => PageBackgroundSettings(
    assetId: clearAsset ? null : assetId ?? this.assetId,
    followGrid: followGrid ?? this.followGrid,
    framing: framing ?? this.framing,
    regions: regions ?? this.regions,
    surfaceOpacity: surfaceOpacity ?? this.surfaceOpacity,
  );
  Map<String, dynamic> toJson() => {
    'assetId': assetId,
    'followGrid': followGrid,
    'framing': framing.toJson(),
    'regions': regions.map((r) => r.name).toList()..sort(),
    'surfaceOpacity': surfaceOpacity,
  };
  factory PageBackgroundSettings.fromJson(Map<String, dynamic> j) =>
      PageBackgroundSettings(
        assetId: j['assetId'] as String?,
        followGrid: j['followGrid'] == true,
        framing: BackgroundFraming.fromJson(
          Map<String, dynamic>.from(j['framing'] as Map? ?? {}),
        ),
        regions: (j['regions'] as List? ?? ['content'])
            .whereType<String>()
            .where((s) => BackgroundRegionId.values.any((r) => r.name == s))
            .map(BackgroundRegionId.values.byName)
            .toSet(),
        surfaceOpacity: _number(j['surfaceOpacity'], .8, 0, 1),
      );
}

class BackgroundSettings {
  const BackgroundSettings({
    this.enabled = false,
    this.animate = true,
    this.assets = const {},
    this.pages = const {},
  });
  final bool enabled, animate;
  final Map<String, BackgroundAsset> assets;
  final Map<BackgroundPage, PageBackgroundSettings> pages;
  PageBackgroundSettings page(BackgroundPage page) =>
      pages[page] ?? const PageBackgroundSettings();
  PageBackgroundSettings resolved(BackgroundPage owner) {
    final value = page(owner);
    if (owner != BackgroundPage.grid && value.followGrid) {
      return value.copyWith(
        assetId: page(BackgroundPage.grid).assetId,
        clearAsset: page(BackgroundPage.grid).assetId == null,
        framing: page(BackgroundPage.grid).framing,
      );
    }
    return value;
  }

  BackgroundAsset? asset(BackgroundPage owner) =>
      enabled ? assets[resolved(owner).assetId] : null;
  String continuityKey(BackgroundPage owner) =>
      '${asset(owner)?.id ?? "none"}:${owner == BackgroundPage.grid || page(owner).followGrid ? "shared" : owner.name}';
  BackgroundSettings copyWith({
    bool? enabled,
    bool? animate,
    Map<String, BackgroundAsset>? assets,
    Map<BackgroundPage, PageBackgroundSettings>? pages,
  }) => BackgroundSettings(
    enabled: enabled ?? this.enabled,
    animate: animate ?? this.animate,
    assets: assets ?? this.assets,
    pages: pages ?? this.pages,
  );
  BackgroundSettings updatePage(
    BackgroundPage owner,
    PageBackgroundSettings value,
  ) => copyWith(pages: {...pages, owner: value});
  BackgroundSettings setFraming(BackgroundPage owner, BackgroundFraming frame) {
    final target = owner != BackgroundPage.grid && page(owner).followGrid
        ? BackgroundPage.grid
        : owner;
    return updatePage(target, page(target).copyWith(framing: frame));
  }

  BackgroundSettings detach(BackgroundPage owner) =>
      updatePage(owner, resolved(owner).copyWith(followGrid: false));
  Map<String, dynamic> toJson() => {
    'version': 1,
    'enabled': enabled,
    'animate': animate,
    'assets': assets.map((k, v) => MapEntry(k, v.toJson())),
    'pages': pages.map((k, v) => MapEntry(k.name, v.toJson())),
  };
  factory BackgroundSettings.fromJson(Map<String, dynamic> j) {
    final assets = <String, BackgroundAsset>{};
    for (final e in (j['assets'] as Map? ?? {}).entries) {
      final asset = BackgroundAsset.fromJson(
        Map<String, dynamic>.from(e.value as Map),
      );
      if (e.key != asset.id) {
        throw const FormatException('Background asset identity mismatch');
      }
      assets[asset.id] = asset;
    }
    return BackgroundSettings(
      enabled: j['enabled'] == true,
      animate: j['animate'] != false,
      assets: assets,
      pages: {
        for (final p in BackgroundPage.values)
          if ((j['pages'] as Map? ?? {})[p.name] is Map)
            p: PageBackgroundSettings.fromJson(
              Map<String, dynamic>.from(j['pages'][p.name] as Map),
            ),
      },
    );
  }
}
