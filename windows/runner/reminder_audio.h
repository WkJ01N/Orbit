#pragma once
#include <windows.h>
#include <winrt/Windows.Data.Json.h>
#include <memory>
#include <string>
class ReminderAudioPlayer {
 public:
  ReminderAudioPlayer();
  ~ReminderAudioPlayer();
  HRESULT Start(const std::wstring& path, bool loop);
  HRESULT StartWave(const std::wstring& path, bool loop);
  void Tick();
  void Stop();
  bool Playing() const;
  HRESULT Error() const;
 private:
  struct Impl;
  std::unique_ptr<Impl> impl_;
};
std::wstring SystemReminderSound(int number);
HRESULT ValidateReminderAudio(const std::wstring& path);
HRESULT PreviewReminderAudio(winrt::Windows::Data::Json::JsonObject settings);
void StopReminderPreview();
void SetReminderAudioActive(bool active);
int RunReminderAudioSelfTest(const std::wstring& path);
