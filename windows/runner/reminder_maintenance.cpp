#include "reminder_maintenance.h"
#include <flutter/standard_method_codec.h>
#include <taskschd.h>
#include <comdef.h>
#include <wrl/client.h>
#include <string>
#include <ctime>
#include <thread>
#include <functional>
#include <winrt/Windows.UI.Notifications.h>
#include <winrt/Windows.Foundation.h>
#include <winrt/Windows.Foundation.Collections.h>

using Microsoft::WRL::ComPtr;

namespace {
HRESULT RegisterMaintenance() {
  wchar_t executable[MAX_PATH];
  if (!GetModuleFileNameW(nullptr, executable, MAX_PATH)) return HRESULT_FROM_WIN32(GetLastError());
  HKEY key = nullptr;
  const wchar_t* registry = L"Software\\Classes\\CLSID\\{7f8d9c2a-4b1e-4f6a-9c3d-2e1f0a9b8c7d}\\LocalServer32";
  auto status = RegCreateKeyExW(HKEY_CURRENT_USER, registry, 0, nullptr, 0, KEY_SET_VALUE, nullptr, &key, nullptr);
  if (status != ERROR_SUCCESS) return HRESULT_FROM_WIN32(status);
  std::wstring command = L"\"" + std::wstring(executable) + L"\" --notification-action";
  status = RegSetValueExW(key, nullptr, 0, REG_SZ, reinterpret_cast<const BYTE*>(command.c_str()), static_cast<DWORD>((command.size()+1)*sizeof(wchar_t)));
  RegCloseKey(key);
  if (status != ERROR_SUCCESS) return HRESULT_FROM_WIN32(status);
  ComPtr<ITaskService> service;
  HRESULT hr = CoCreateInstance(CLSID_TaskScheduler, nullptr, CLSCTX_INPROC_SERVER, IID_PPV_ARGS(&service));
  if (FAILED(hr)) return hr;
  hr = service->Connect(_variant_t(),_variant_t(),_variant_t(),_variant_t());
  if (FAILED(hr)) return hr;
  ComPtr<ITaskFolder> folder;
  hr = service->GetFolder(_bstr_t(L"\\"), &folder);
  if (FAILED(hr)) return hr;
  ComPtr<ITaskDefinition> task;
  hr = service->NewTask(0,&task);
  if (FAILED(hr)) return hr;
  ComPtr<ITaskSettings> settings;
  if (FAILED(hr = task->get_Settings(&settings))) return hr;
  if (FAILED(hr = settings->put_Hidden(VARIANT_TRUE))) return hr;
  if (FAILED(hr = settings->put_WakeToRun(VARIANT_FALSE))) return hr;
  if (FAILED(hr = settings->put_StartWhenAvailable(VARIANT_TRUE))) return hr;
  if (FAILED(hr = settings->put_DisallowStartIfOnBatteries(VARIANT_FALSE))) return hr;
  if (FAILED(hr = settings->put_StopIfGoingOnBatteries(VARIANT_FALSE))) return hr;
  if (FAILED(hr = settings->put_MultipleInstances(TASK_INSTANCES_IGNORE_NEW))) return hr;
  if (FAILED(hr = settings->put_ExecutionTimeLimit(_bstr_t(L"PT10M")))) return hr;
  ComPtr<IPrincipal> principal;
  if (FAILED(hr = task->get_Principal(&principal))) return hr;
  wchar_t username[256]; DWORD length=256;
  if (!GetUserNameW(username,&length)) return HRESULT_FROM_WIN32(GetLastError());
  if (FAILED(hr = principal->put_UserId(_bstr_t(username)))) return hr;
  if (FAILED(hr = principal->put_LogonType(TASK_LOGON_INTERACTIVE_TOKEN))) return hr;
  if (FAILED(hr = principal->put_RunLevel(TASK_RUNLEVEL_LUA))) return hr;
  ComPtr<ITriggerCollection> triggers;
  if (FAILED(hr = task->get_Triggers(&triggers))) return hr;
  ComPtr<ITrigger> time_trigger;
  if (FAILED(hr = triggers->Create(TASK_TRIGGER_TIME,&time_trigger))) return hr;
  SYSTEMTIME now; GetLocalTime(&now);
  wchar_t boundary[64];
  swprintf_s(boundary,L"%04u-%02u-%02uT%02u:%02u:%02u",now.wYear,now.wMonth,now.wDay,now.wHour,now.wMinute,now.wSecond);
  if (FAILED(hr = time_trigger->put_StartBoundary(_bstr_t(boundary)))) return hr;
  ComPtr<IRepetitionPattern> repetition;
  if (FAILED(hr = time_trigger->get_Repetition(&repetition))) return hr;
  if (FAILED(hr = repetition->put_Interval(_bstr_t(L"PT15M")))) return hr;
  ComPtr<ITrigger> logon_base;
  if (FAILED(hr = triggers->Create(TASK_TRIGGER_LOGON,&logon_base))) return hr;
  ComPtr<ILogonTrigger> logon;
  if (FAILED(hr = logon_base.As(&logon))) return hr;
  if (FAILED(hr = logon->put_UserId(_bstr_t(username)))) return hr;
  ComPtr<IActionCollection> actions;
  if (FAILED(hr = task->get_Actions(&actions))) return hr;
  ComPtr<IAction> action;
  if (FAILED(hr = actions->Create(TASK_ACTION_EXEC,&action))) return hr;
  ComPtr<IExecAction> exec;
  if (FAILED(hr = action.As(&exec))) return hr;
  if (FAILED(hr = exec->put_Path(_bstr_t(executable)))) return hr;
  if (FAILED(hr = exec->put_Arguments(_bstr_t(L"--reminder-maintenance")))) return hr;
  const std::wstring path(executable);
  if (FAILED(hr = exec->put_WorkingDirectory(_bstr_t(path.substr(0,path.find_last_of(L"\\")).c_str())))) return hr;
  ComPtr<IRegisteredTask> registered;
  const std::wstring task_name=L"Orbit Reminder Maintenance "+std::wstring(username);
  return folder->RegisterTaskDefinition(_bstr_t(task_name.c_str()),task.Get(),TASK_CREATE_OR_UPDATE,
    _variant_t(username),_variant_t(),TASK_LOGON_INTERACTIVE_TOKEN,_variant_t(L""),&registered);
}
}

std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> CreateReminderMaintenanceChannel(flutter::BinaryMessenger* messenger,HWND window,std::function<void()> finish_headless) {
  auto channel=std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(messenger,
    "com.must.orbit.orbit/windows_reminders",&flutter::StandardMethodCodec::GetInstance());
  channel->SetMethodCallHandler([window,finish_headless](const auto& call, auto result) {
    if(call.method_name()=="finishHeadless") {finish_headless();result->Success();return;}
    if (call.method_name()=="registerMaintenance" || call.method_name()=="deliveredIds" || call.method_name()=="notificationsEnabled") {
      const auto operation=call.method_name();
      std::thread([operation,window,result=std::move(result)]() mutable {
        CoInitializeEx(nullptr,COINIT_MULTITHREADED);
        HRESULT hr=S_OK;
        flutter::EncodableList delivered;
        bool notifications_enabled = false;
        try {
          if(operation=="registerMaintenance") hr=RegisterMaintenance();
          else if(operation=="notificationsEnabled") {
            notifications_enabled = winrt::Windows::UI::Notifications::ToastNotificationManager::CreateToastNotifier(L"com.must.orbit").Setting() ==
              winrt::Windows::UI::Notifications::NotificationSetting::Enabled;
          }
          else {
            const auto history=winrt::Windows::UI::Notifications::ToastNotificationManager::History().GetHistory(L"com.must.orbit");
            for(const auto& toast:history) {
              try {delivered.emplace_back(std::stoi(winrt::to_string(toast.Tag())));} catch(...) {}
            }
          }
        } catch(const winrt::hresult_error& error) {hr=error.code();}
        CoUninitialize();
        auto completion=new std::function<void()>([result=std::shared_ptr<flutter::MethodResult<flutter::EncodableValue>>(std::move(result)),hr,operation,notifications_enabled,delivered=std::move(delivered)]() {
          if(FAILED(hr)) result->Error("reminder_native",std::to_string(static_cast<long>(hr)));
          else if(operation=="deliveredIds") result->Success(flutter::EncodableValue(delivered));
          else if(operation=="notificationsEnabled") result->Success(flutter::EncodableValue(notifications_enabled));
          else result->Success();
        });
        if(!PostMessageW(window,WM_APP+51,0,reinterpret_cast<LPARAM>(completion))) delete completion;
      }).detach();
    } else result->NotImplemented();
  });
  return channel;
}
void CompleteReminderOperation(LPARAM operation) {
  std::unique_ptr<std::function<void()>> completion(reinterpret_cast<std::function<void()>*>(operation));
  (*completion)();
}
bool ForwardReminderMaintenance() {
  const HWND window=FindWindowW(nullptr,L"Orbit");
  if(!window) return false;
  const char command[]="maintenance";
  COPYDATASTRUCT data{0x4F524249,sizeof(command),const_cast<char*>(command)};
  DWORD_PTR result=0;
  return SendMessageTimeoutW(window,WM_COPYDATA,0,reinterpret_cast<LPARAM>(&data),SMTO_ABORTIFHUNG,2000,&result)!=0;
}
