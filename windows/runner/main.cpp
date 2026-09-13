#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>
#include <algorithm>

#include "flutter_window.h"
#include "single_instance.h"
#include "utils.h"

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);
  std::vector<std::string> command_line_arguments = GetCommandLineArguments();
  const bool maintenance=std::find(command_line_arguments.begin(),command_line_arguments.end(),"--reminder-maintenance")!=command_line_arguments.end();
  const bool notification_action=std::find(command_line_arguments.begin(),command_line_arguments.end(),"--notification-action")!=command_line_arguments.end();

  if (!AcquireSingleInstanceMutex()) {
    if(maintenance) ForwardReminderMaintenance();
    else if(!notification_action) ActivateExistingInstance();
    ::CoUninitialize();
    return EXIT_SUCCESS;
  }

  // Dart worker isolates may move between pool threads. Keep the implicit MTA
  // alive for their notification FFI objects and COM activation callback,
  // without making Windows notification RPC run on the window's STA thread.
  CO_MTA_USAGE_COOKIE notification_mta = nullptr;
  if (FAILED(::CoIncrementMTAUsage(&notification_mta))) {
    ::CoUninitialize();
    return EXIT_FAILURE;
  }

  flutter::DartProject project(L"data");

  const bool start_hidden =
      maintenance || notification_action || std::find(command_line_arguments.begin(), command_line_arguments.end(),
                "--startup") != command_line_arguments.end();

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project, start_hidden,maintenance || notification_action);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(960, 720);
  if (!window.Create(L"Orbit", origin, size)) {
    ::CoDecrementMTAUsage(notification_mta);
    ::CoUninitialize();
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoDecrementMTAUsage(notification_mta);
  ::CoUninitialize();
  return EXIT_SUCCESS;
}
