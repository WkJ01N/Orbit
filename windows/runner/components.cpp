#include "components.h"
#include <flutter/standard_method_codec.h>
#include <windows.h>
#include <shlobj.h>
#include <filesystem>
#include <string>

std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> CreateComponentChannel(flutter::FlutterEngine* engine) {
  auto channel = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(engine->messenger(),
    "com.must.orbit.orbit/components", &flutter::StandardMethodCodec::GetInstance());
  channel->SetMethodCallHandler([engine](const auto& call, auto result) {
    if (call.method_name() != "loadVideo") { result->NotImplemented(); return; }
    const auto* args = std::get_if<flutter::EncodableMap>(call.arguments());
    if (!args) { result->Error("component_load", "Missing arguments"); return; }
    const auto found = args->find(flutter::EncodableValue("directory"));
    if (found == args->end() || !std::holds_alternative<std::string>(found->second)) {
      result->Error("component_load", "Missing directory"); return;
    }
    const auto path = std::filesystem::u8path(std::get<std::string>(found->second));
    if (!path.is_absolute() || path.parent_path().filename() != L"components" ||
        path.filename().wstring().find(L"video-win-x64-") != 0) {
      result->Error("component_load", "Invalid component directory"); return;
    }
    // Retain the DLL for the engine/process lifetime: live textures and FFI
    // bindings must never point into an unloaded module.
    static HMODULE backend = nullptr;
    if (!backend) {
      const auto file = path / L"orbit_video_backend.dll";
      backend = LoadLibraryExW(file.c_str(), nullptr, LOAD_LIBRARY_SEARCH_DLL_LOAD_DIR | LOAD_LIBRARY_SEARCH_DEFAULT_DIRS);
      if (!backend) { result->Error("component_load", "Unable to load video runtime: " + std::to_string(GetLastError())); return; }
      using Register = void (*)(FlutterDesktopPluginRegistrarRef);
      const auto register_plugin = reinterpret_cast<Register>(GetProcAddress(backend, "MediaKitVideoPluginCApiRegisterWithRegistrar"));
      if (!register_plugin) { FreeLibrary(backend); backend = nullptr; result->Error("component_load", "Video entry point not found"); return; }
      register_plugin(engine->GetRegistrarForPlugin("OrbitVideoBackend"));
    }
    result->Success();
  });
  return channel;
}
