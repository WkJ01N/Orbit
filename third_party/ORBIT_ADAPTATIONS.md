# Pinned media-kit adaptations

The four subdirectories retain the upstream MIT license and version metadata.
Orbit builds Android and Windows; other platform implementations are outside this application scope.

- media_kit 1.2.6: Android JNI initialization uses the selected private libmpv path.
- media_kit_video 2.0.1: Windows renders in a separately built orbit_video_backend DLL; the default plugin is a dependency-free stub. The runner loads and registers the checked component on demand.
- media_kit_libs_android_video 1.3.8: retain upstream helper JNI only; libmpv comes from a verified optional component. No startup mpv loading.
- media_kit_libs_windows_video 1.0.11: fetch upstream build headers/import libraries, without installing heavy runtime DLLs in the main bundle.

Rebuild Windows components from the backend target and pinned native dependency directories before regenerating assets/components/catalog.json. Do not edit the user's global Pub cache.
