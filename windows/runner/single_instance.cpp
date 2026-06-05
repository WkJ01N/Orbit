#include "single_instance.h"

#include <windows.h>

namespace {

constexpr wchar_t kMutexName[] = L"Local\\Orbit.SingleInstance";
constexpr wchar_t kWindowTitle[] = L"Orbit";
constexpr wchar_t kShowExistingMessageName[] = L"Orbit.ShowExistingInstance";

constexpr int kFindWindowRetryCount = 30;
constexpr DWORD kFindWindowRetryDelayMs = 100;

HANDLE g_single_instance_mutex = nullptr;

unsigned int RegisteredShowExistingMessage() {
  static const unsigned int message =
      ::RegisterWindowMessageW(kShowExistingMessageName);
  return message;
}

}  // namespace

unsigned int GetShowExistingInstanceMessage() {
  return RegisteredShowExistingMessage();
}

bool AcquireSingleInstanceMutex() {
  g_single_instance_mutex =
      ::CreateMutexW(nullptr, TRUE, kMutexName);
  if (g_single_instance_mutex == nullptr) {
    return false;
  }
  return ::GetLastError() != ERROR_ALREADY_EXISTS;
}

bool ActivateExistingInstance() {
  const unsigned int show_message = RegisteredShowExistingMessage();
  if (show_message == 0) {
    return false;
  }

  HWND hwnd = nullptr;
  for (int attempt = 0; attempt < kFindWindowRetryCount; ++attempt) {
    hwnd = ::FindWindowW(nullptr, kWindowTitle);
    if (hwnd != nullptr) {
      break;
    }
    ::Sleep(kFindWindowRetryDelayMs);
  }

  if (hwnd == nullptr) {
    return false;
  }

  return ::PostMessageW(hwnd, show_message, 0, 0) != FALSE;
}
