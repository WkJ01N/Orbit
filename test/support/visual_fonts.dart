import 'dart:io';

/// SimHei is the font the pixel baselines under `test/goldens/` were rendered
/// with. A Windows machine without it (GitHub's `windows-latest` image, for
/// one) would compare against glyph shapes it cannot draw.
const String _simHeiPath = r'C:/Windows/Fonts/simhei.ttf';

/// Path to the font the baselines were rendered with, or null when this
/// machine does not have it.
String? visualBaselineFontPath() {
  if (!Platform.isWindows) return null;
  return File(_simHeiPath).existsSync() ? _simHeiPath : null;
}

/// Why the pixel baselines cannot be compared here, or null when they can.
///
/// The baselines also bake in the fonts the runner falls back to for text the
/// app draws with a family the test harness never loads, so a builder image
/// renders them differently even with SimHei installed. They are therefore
/// opt-in on CI: set `ORBIT_GOLDEN=1` to compare them there on purpose.
String? visualBaselineSkipReason() {
  if (visualBaselineFontPath() == null) {
    return 'golden baselines need SimHei, which is not installed here';
  }
  final ci = Platform.environment['CI'] == 'true';
  if (ci && Platform.environment['ORBIT_GOLDEN'] != '1') {
    return 'golden baselines are compared on a workstation; '
        'set ORBIT_GOLDEN=1 to compare them on CI';
  }
  return null;
}

/// Whether the golden and visual tests can produce comparable pixels here.
bool get visualBaselinesAvailable => visualBaselineSkipReason() == null;
