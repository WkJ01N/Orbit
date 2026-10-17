# Startup and timetable entrance

Android and Windows share `OrbitLaunchHost` and `LaunchMotion`. The host lives
inside the home route, so notifications and other routes can take priority.
Hidden startup and reminder maintenance bypass the animation. Resuming the app
does not replay it; pointer input, window resizing and urgent reminders finish
an active entrance immediately.

The brand layer exits after 450 ms. Shell elements start at 350–480 ms, with
35 ms between navigation buttons. The first ready timetable starts its card
clock at 500 ms, or immediately if data arrives later. Card starts span 180 ms
and movement takes 420 ms, keeping the normal sequence near 1.1 seconds.
Reduced-motion preferences render final positions directly.

Cards are prepared after initial scroll callbacks. Only cards and the current
time marker intersecting the initial viewport receive entrance specifications.
Directions balance per date column and globally; direction and start-order
shuffles are independent. The same specification moves each card, its strong
reminder bell and its enlarged hit target. An explicit clip below the dates is
required even when the content fits without scrolling.

Appearance → Startup & entrance provides image selection, circular cropping,
reset, edge/nearby movement and a preview with isolated navigation and sample
courses. Images are normalized to at most 512 px and copied into private
`launch_icons` storage. Settings use `launch_presentation_v1` and are local to
the device; they are excluded from portable settings and cloud sync.

The Flutter brand screen uses the saved theme color and selected image. The
Android system splash uses the default brand color/icon before Flutter is ready.
The startup wordmark has its own typography selection, defaulting to Nunito.
It does not inherit the interface font. See `typography.md` for import and backup
behavior. Android 12+ uses a dedicated circular splash resource with transparent
safe padding; the launcher icon itself is unchanged. Startup images are decoded
while initialization runs. The first Flutter brand frame retains the visible icon
at screen center, independent of wordmark metrics, to avoid an empty flash.
The Android launcher's own launch motion remains controlled by the system.

Validation:

```powershell
flutter test test/launch_motion_test.dart
flutter drive --profile -d windows --target integration_test/launch_motion_test.dart --driver test_driver/launch_motion_driver.dart
```

The profile test runs 49 sample classes in both entrance modes, with in-memory
preferences and no user database. It writes `build/launch-motion-profile.json`.
Replace `windows` with an attached Android device ID to measure phone rendering.
