# Startup and timetable entrance

Android and Windows share `OrbitLaunchHost` and `LaunchMotion`. The host lives
inside the home route, so notifications and other routes can take priority.
Hidden startup and reminder maintenance bypass the animation. Resuming the app
does not replay it by default; pointer input, window resizing and urgent reminders finish
an active entrance immediately.

The brand layer exits after 450 ms. Shell elements start at 350–480 ms, with
35 ms between navigation buttons. The first ready timetable starts its card
clock at 500 ms, or immediately if data arrives later. Card starts span 140 ms
and movement takes 480 ms with a monotonic ease-out quint curve, keeping the normal sequence near 1.1 seconds.
Reduced-motion preferences render final positions directly.

Cards are prepared after initial scroll callbacks. Only cards and the current
time marker intersecting the initial viewport receive entrance specifications.
Directions balance per date column and globally; visible starts follow screen
order from top to bottom and left to right. The same specification moves each card, its strong
reminder bell and its enlarged hit target. An explicit clip below the dates is
required even when the content fits without scrolling.

Appearance → Startup & entrance provides image selection, circular cropping,
reset, edge/nearby movement and a preview with isolated navigation and sample
courses. Images are normalized to at most 512 px and copied into private
`launch_icons` storage. Settings use `launch_presentation_v1` and are local to
the device; they are excluded from ordinary portable settings and cloud sync. The v12
downgrade protection backup additionally carries their private resource data.

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


## v1.6.2 trigger controls

Appearance → Startup & page animations separates the cold-start brand switch
from the four main-page entrance switches. Page switches default on; triggering
on startup defaults on, while foreground resume and page navigation default off.
Returning from a subpage counts as navigation, but dialogs and temporary loss of
focus do not. Entrances wait for existing navigation transitions and preserve
page state. Timetable replay resets its visible-card plan; the other main pages
use a 360 ms fade and a 10 px movement. See `v1.6.2.md` for validation scope.

## v1.6.3 page and mutation motion

The original trigger preferences remain intact. Main and secondary destinations
prepare their hidden state before their first visible frame, then begin at the
actual navigation midpoint. Visible modules share a paint clock: 420 ms travel
with at most 180 ms total staggering. Late initial content can join the entrance;
user interaction seals that wave so scrolling retains lazy, immediate rows.
Popup contents keep their existing container transitions. Paint, hit testing and
semantics use matching coordinates, and cancelled generations cannot restart.

Timetable refreshes commit courses and deadlines together while retaining the
last successful snapshot. Added cards use the selected edge/nearby movement;
removed snapshots fade out, while edits crossfade using old-to-new identity
maps. These changes do not replay a page entrance. Phone quick actions have an
independent gesture/overlay lifecycle; see `v1.6.3.md` for geometry and timing.

Reveal and card wrappers retain the same element path while pending, playing,
disabled and finished. Completed reveals disable clipping without remounting
their children. Timetable date indexes and one-time initial scrolling survive
page replays, so replay cannot discard cached layout or reset a user's scroll.
