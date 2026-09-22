import 'package:crop_your_image/crop_your_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:orbit/services/avatar_image_service.dart';

Future<Uint8List?> showAvatarCropDialog(
  BuildContext context,
  Uint8List image,
) => showDialog<Uint8List>(
  context: context,
  barrierDismissible: false,
  builder: (_) => _AvatarCropDialog(image: image),
);

class _AvatarCropDialog extends StatefulWidget {
  const _AvatarCropDialog({required this.image});

  final Uint8List image;

  @override
  State<_AvatarCropDialog> createState() => _AvatarCropDialogState();
}

class _AvatarCropDialogState extends State<_AvatarCropDialog> {
  final CropController _controller = CropController();
  bool _square = true;
  bool _stretch = false;
  bool _fill = false;
  bool _ready = false;
  Size? _cropViewport;
  Size? _readyViewport;
  bool _busy = false;
  String? _error;

  bool get _canCrop => _ready && _readyViewport == _cropViewport;

  void _setSquare(bool value) {
    setState(() {
      _square = value;
      if (value) {
        _stretch = false;
        _fill = false;
      }
    });
    _controller.aspectRatio = value ? 1 : null;
  }

  void _setStretch(bool value) => setState(() {
    _stretch = value;
    if (value) _fill = false;
  });

  void _setFill(bool value) => setState(() {
    _fill = value;
    if (value) _stretch = false;
  });

  AvatarImageTransform get _transform {
    if (_square) return AvatarImageTransform.preserve;
    if (_stretch) return AvatarImageTransform.stretch;
    if (_fill) return AvatarImageTransform.fill;
    return AvatarImageTransform.preserve;
  }

  void _crop() {
    if (!_canCrop || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    _controller.crop();
  }

  Future<void> _onCropped(CropResult result) async {
    switch (result) {
      case CropSuccess(:final croppedImage):
        try {
          final processed = await compute(_processAvatar, (
            croppedImage,
            _transform.index,
          ));
          if (mounted) Navigator.pop(context, processed);
        } catch (_) {
          if (mounted) {
            setState(() {
              _busy = false;
              _error = _CropText.of(context).processingFailed;
            });
          }
        }
      case CropFailure():
        if (mounted) {
          setState(() {
            _busy = false;
            _error = _CropText.of(context).processingFailed;
          });
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = _CropText.of(context);
    final colors = Theme.of(context).colorScheme;
    final screen = MediaQuery.sizeOf(context);
    final controlsMaxHeight = (screen.height * 0.3).clamp(120.0, 240.0);
    final content = Column(
      children: [
        AppBar(
          automaticallyImplyLeading: false,
          title: Text(text.title),
          actions: [
            IconButton(
              tooltip: text.cancel,
              onPressed: _busy ? null : () => Navigator.pop(context),
              icon: const Icon(Icons.close),
            ),
          ],
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final viewport = constraints.biggest;
                if (_cropViewport != viewport) {
                  _cropViewport = viewport;
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) setState(() {});
                  });
                }
                return ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    width: constraints.maxWidth,
                    height: constraints.maxHeight,
                    child: ColoredBox(
                      color: colors.surfaceContainerHighest,
                      child: Padding(
                        // The crop handles extend 16 px past the image bounds.
                        // Keep that space visible while the image stays fixed.
                        padding: const EdgeInsets.all(16),
                        child: Crop(
                          // Recreate its internal geometry when the available
                          // viewport changes (for example, a resized window).
                          key: ValueKey(viewport),
                          image: widget.image,
                          controller: _controller,
                          aspectRatio: _square ? 1 : null,
                          initialRectBuilder:
                              InitialRectBuilder.withSizeAndRatio(
                                size: 0.8,
                                aspectRatio: 1,
                              ),
                          clipBehavior: Clip.none,
                          interactive: false,
                          baseColor: colors.surfaceContainerHighest,
                          maskColor: Colors.black.withValues(alpha: 0.55),
                          progressIndicator: const Center(
                            child: CircularProgressIndicator(),
                          ),
                          onStatusChanged: (status) {
                            if (mounted && _cropViewport == viewport) {
                              final ready = status == CropStatus.ready;
                              if (_ready != ready ||
                                  _readyViewport != viewport) {
                                setState(() {
                                  _ready = ready;
                                  _readyViewport = ready ? viewport : null;
                                });
                              }
                            }
                          },
                          onCropped: _onCropped,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        SizedBox(
          height: controlsMaxHeight,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Column(
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(text.squareCrop),
                  subtitle: Text(text.squareCropHint),
                  value: _square,
                  onChanged: _busy || !_canCrop ? null : _setSquare,
                ),
                if (!_square) ...[
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(text.stretch),
                    subtitle: Text(text.stretchHint),
                    value: _stretch,
                    onChanged: _busy || !_canCrop ? null : _setStretch,
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(text.fill),
                    subtitle: Text(text.fillHint),
                    value: _fill,
                    onChanged: _busy || !_canCrop ? null : _setFill,
                  ),
                ],
                if (_error != null)
                  Text(_error!, style: TextStyle(color: colors.error)),
              ],
            ),
          ),
        ),
        SafeArea(
          top: false,
          minimum: const EdgeInsets.fromLTRB(16, 4, 16, 16),
          child: OverflowBar(
            alignment: MainAxisAlignment.end,
            spacing: 8,
            overflowSpacing: 8,
            children: [
              TextButton(
                onPressed: _busy ? null : () => Navigator.pop(context),
                child: Text(text.cancel),
              ),
              FilledButton.icon(
                onPressed: !_canCrop || _busy ? null : _crop,
                icon: _busy
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.crop),
                label: Text(text.useImage),
              ),
            ],
          ),
        ),
      ],
    );

    if (screen.width < 600) {
      return Dialog.fullscreen(
        child: KeyedSubtree(
          key: const Key('avatar-crop-mobile-panel'),
          child: content,
        ),
      );
    }
    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        key: const Key('avatar-crop-desktop-panel'),
        width: 720,
        height: (screen.height - 48).clamp(300, 712).toDouble(),
        child: content,
      ),
    );
  }
}

Uint8List _processAvatar((Uint8List, int) request) => processAvatarImage(
  request.$1,
  transform: AvatarImageTransform.values[request.$2],
);

class _CropText {
  const _CropText(this.zh, this.hant);

  final bool zh;
  final bool hant;

  factory _CropText.of(BuildContext context) {
    final locale = Localizations.localeOf(context);
    return _CropText(
      locale.languageCode == 'zh',
      locale.scriptCode?.toLowerCase() == 'hant' || locale.countryCode == 'TW',
    );
  }

  String pick(String en, String hans, String traditional) =>
      zh ? (hant ? traditional : hans) : en;

  String get title => pick('Crop avatar', '裁切头像', '裁切頭像');
  String get squareCrop => pick('Square crop', '正方形裁切', '正方形裁切');
  String get squareCropHint => pick(
    'Keep the selection at a 1:1 ratio.',
    '将框选区域固定为 1:1。',
    '將框選區域固定為 1:1。',
  );
  String get stretch => pick('Stretch', '拉伸', '拉伸');
  String get stretchHint => pick(
    'Stretch the free-form crop into a square.',
    '将自由裁切结果拉伸为正方形。',
    '將自由裁切結果拉伸為正方形。',
  );
  String get fill => pick('Fill', '填充', '填充');
  String get fillHint => pick(
    'Add transparent padding without removing content.',
    '以透明区域补成正方形，不裁掉内容。',
    '以透明區域補成正方形，不裁掉內容。',
  );
  String get cancel => pick('Cancel', '取消', '取消');
  String get useImage => pick('Use image', '使用此图片', '使用此圖片');
  String get processingFailed => pick(
    'Could not process this image.',
    '无法处理此图片，请选择其他图片。',
    '無法處理此圖片，請選擇其他圖片。',
  );
}
