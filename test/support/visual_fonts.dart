import 'dart:io';

/// SimHei is the font the pixel baselines under `test/goldens/` were rendered
/// with. A Windows machine without it (GitHub's `windows-latest` image, for
/// one) would compare against glyph shapes it cannot draw, so the visual tests
/// skip there instead of reporting a meaningless diff.
const String _simHeiPath = r'C:/Windows/Fonts/simhei.ttf';

/// Path to the font the baselines were rendered with, or null when this
/// machine does not have it.
String? visualBaselineFontPath() {
  if (!Platform.isWindows) return null;
  return File(_simHeiPath).existsSync() ? _simHeiPath : null;
}

/// Whether the golden and visual tests can produce comparable pixels here.
bool get visualBaselinesAvailable => visualBaselineFontPath() != null;
