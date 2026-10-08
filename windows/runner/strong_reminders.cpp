#include "strong_reminders.h"
#include <windows.h>
#include <shlobj.h>
#include <taskschd.h>
#include <comdef.h>
#include <wrl/client.h>
#include <winrt/Windows.Data.Json.h>
#include <winrt/Windows.Data.Xml.Dom.h>
#include <winrt/Windows.UI.Notifications.h>
#include <winrt/Windows.Foundation.h>
#include <winrt/Windows.Foundation.Collections.h>
#include <fstream>
#include <filesystem>
#include <chrono>
#include <random>
#include <thread>
#include <algorithm>
#include <functional>
#include <map>
#include <set>
using namespace winrt::Windows::Data::Json;
using namespace winrt::Windows::UI::Notifications;
using Microsoft::WRL::ComPtr;
namespace {
constexpr wchar_t appId[]=L"com.must.orbit";
thread_local long long testClock=-1;
long long Now(){if(testClock>=0)return testClock;return std::chrono::duration_cast<std::chrono::milliseconds>(std::chrono::system_clock::now().time_since_epoch()).count();}
JsonValue Num(long long n){return JsonValue::CreateNumberValue(static_cast<double>(n));}
void Put(JsonObject s,const wchar_t* k,const wchar_t* v){s.SetNamedValue(k,JsonValue::CreateStringValue(v));}
long long N(JsonObject s,const wchar_t* k,long long fallback=0){return static_cast<long long>(s.GetNamedNumber(k,static_cast<double>(fallback)));}
std::wstring StatePath(){PWSTR path=nullptr; if(FAILED(SHGetKnownFolderPath(FOLDERID_LocalAppData,0,nullptr,&path)))throw std::runtime_error("Application data unavailable"); std::wstring dir=std::wstring(path)+L"\\Orbit\\reminders";CoTaskMemFree(path);std::filesystem::create_directories(dir);return dir+L"\\strong.json";}
JsonObject Read(){std::ifstream f(StatePath(),std::ios::binary);std::string text((std::istreambuf_iterator<char>(f)),{});JsonObject o; if(!text.empty() && JsonObject::TryParse(winrt::to_hstring(text),o))return o; o=JsonObject();o.SetNamedValue(L"pending",JsonArray());return o;}
void Write(JsonObject s){auto path=StatePath();auto text=winrt::to_string(s.Stringify());std::ofstream f(path+L".tmp",std::ios::binary|std::ios::trunc);f.write(text.data(),static_cast<std::streamsize>(text.size()));f.close();if(!MoveFileExW((path+L".tmp").c_str(),path.c_str(),MOVEFILE_REPLACE_EXISTING|MOVEFILE_WRITE_THROUGH))throw std::runtime_error("Cannot save strong reminder");}
struct Lock {HANDLE mutex;Lock(){mutex=CreateMutexW(nullptr,FALSE,L"Local\\OrbitStrongState");if(!mutex)throw std::runtime_error("Strong state mutex failed");DWORD r=WaitForSingleObject(mutex,10000);if(r!=WAIT_OBJECT_0&&r!=WAIT_ABANDONED){CloseHandle(mutex);throw std::runtime_error("Strong state busy");}}~Lock(){ReleaseMutex(mutex);CloseHandle(mutex);}};
bool Active(JsonObject s){auto p=s.GetNamedString(L"phase",L"");return !p.empty()&&p!=L"completed"&&p!=L"emergency"&&p!=L"unconfirmed"&&Now()<N(s,L"expiresAt");}
JsonArray Numbers(){std::vector<int> v{1,2,3,4,5,6};std::mt19937 rng(std::random_device{}());std::shuffle(v.begin(),v.end(),rng);JsonArray a;for(int n:v)a.Append(Num(n));return a;}
JsonObject NewSession(JsonObject r){auto settings=r.GetNamedObject(L"strong");auto at=N(r,L"fireAtMillis");auto duration=std::clamp(N(settings,L"durationSeconds",30),5LL,300LL)*1000;JsonObject s;Put(s,L"id",r.GetNamedString(L"key").c_str());Put(s,L"phase",L"ringing");s.SetNamedValue(L"startedAt",Num(at));s.SetNamedValue(L"expiresAt",Num(at+duration*3+30000));s.SetNamedValue(L"duration",Num(duration));s.SetNamedValue(L"round",Num(1));s.SetNamedValue(L"roundEnd",Num(at+duration));s.SetNamedValue(L"nextRoundAt",Num(0));s.SetNamedValue(L"settings",settings);s.SetNamedValue(L"opened",JsonValue::CreateBooleanValue(false));s.SetNamedValue(L"progress",Num(0));s.SetNamedValue(L"numbers",Numbers());JsonArray records;records.Append(r);s.SetNamedValue(L"records",records);JsonArray q;std::mt19937 rng(std::random_device{}());for(int i=0;i<2;i++){JsonObject v;v.SetNamedValue(L"a",Num(10+rng()%80));v.SetNamedValue(L"b",Num(1+rng()%9));v.SetNamedValue(L"subtract",JsonValue::CreateBooleanValue(rng()%2==0));q.Append(v);}s.SetNamedValue(L"questions",q);return s;}
void Advance(JsonObject s){if(!Active(s)){if(s.GetNamedString(L"phase",L"")!=L"completed"&&s.GetNamedString(L"phase",L"")!=L"emergency")Put(s,L"phase",L"unconfirmed");return;}auto now=Now();if(now>=N(s,L"roundEnd")&&N(s,L"nextRoundAt")==0){if(N(s,L"round")>=3){Put(s,L"phase",L"unconfirmed");return;}s.SetNamedValue(L"nextRoundAt",Num(N(s,L"roundEnd")+15000));}auto phase=s.GetNamedString(L"phase");auto deadline=phase==L"task"?N(s,L"answerDeadline"):phase==L"ready"?N(s,L"prepareDeadline"):0;bool timeout=deadline>0&&now>=deadline;if(timeout)Put(s,L"phase",L"timeout");if(N(s,L"nextRoundAt")>0&&(now>=N(s,L"nextRoundAt")||timeout)){s.SetNamedValue(L"round",Num(N(s,L"round")+1));s.SetNamedValue(L"roundEnd",Num(std::min(now+N(s,L"duration"),N(s,L"expiresAt"))));s.SetNamedValue(L"nextRoundAt",Num(0));}}
void OpenSession(JsonObject s){
  if(Active(s)&&!s.GetNamedBoolean(L"opened",false)){s.SetNamedValue(L"opened",JsonValue::CreateBooleanValue(true));Put(s,L"phase",L"ready");s.SetNamedValue(L"prepareDeadline",Num(std::min(Now()+std::clamp(N(s.GetNamedObject(L"settings"),L"prepareSeconds",15),5LL,60LL)*1000,N(s,L"expiresAt"))));}
}
void BeginSession(JsonObject s){
  if(Active(s)&&s.GetNamedString(L"phase")!=L"task"){Put(s,L"phase",L"task");s.SetNamedValue(L"answerDeadline",Num(std::min(Now()+std::clamp(N(s.GetNamedObject(L"settings"),L"answerSeconds",30),10LL,120LL)*1000,N(s,L"expiresAt"))));}
}
void ClearSound(){try{for(auto t:ToastNotificationManager::History().GetHistory(appId)){auto xml=winrt::to_string(t.Content().GetXml());if(xml.find("scenario=\"alarm\"")!=std::string::npos)ToastNotificationManager::History().Remove(t.Tag(),t.Group(),appId);}}catch(...) {}}
HRESULT ScheduleWorker(long long at){
  wchar_t exe[MAX_PATH];GetModuleFileNameW(nullptr,exe,MAX_PATH);wchar_t user[256];DWORD size=256;if(!GetUserNameW(user,&size))return E_FAIL;
  ComPtr<ITaskService> service;HRESULT hr=CoCreateInstance(CLSID_TaskScheduler,nullptr,CLSCTX_INPROC_SERVER,IID_PPV_ARGS(&service));if(FAILED(hr))return hr;hr=service->Connect(_variant_t(),_variant_t(),_variant_t(),_variant_t());if(FAILED(hr))return hr;ComPtr<ITaskFolder> folder;hr=service->GetFolder(_bstr_t(L"\\"),&folder);if(FAILED(hr))return hr;
  std::wstring name=L"Orbit Strong Reminder "+std::wstring(user);
  if(at==0){folder->DeleteTask(_bstr_t(name.c_str()),0);return S_OK;}
  ComPtr<ITaskDefinition> task;hr=service->NewTask(0,&task);if(FAILED(hr))return hr;ComPtr<ITaskSettings> settings;hr=task->get_Settings(&settings);if(FAILED(hr))return hr;settings->put_Enabled(VARIANT_TRUE);settings->put_StartWhenAvailable(VARIANT_TRUE);settings->put_DisallowStartIfOnBatteries(VARIANT_FALSE);settings->put_StopIfGoingOnBatteries(VARIANT_FALSE);settings->put_ExecutionTimeLimit(_bstr_t(L"PT1H"));settings->put_MultipleInstances(TASK_INSTANCES_IGNORE_NEW);
  ComPtr<IPrincipal> principal;hr=task->get_Principal(&principal);if(FAILED(hr))return hr;principal->put_UserId(_bstr_t(user));principal->put_LogonType(TASK_LOGON_INTERACTIVE_TOKEN);principal->put_RunLevel(TASK_RUNLEVEL_LUA);
  ComPtr<ITriggerCollection> triggers;hr=task->get_Triggers(&triggers);if(FAILED(hr))return hr;ComPtr<ITrigger> trigger;hr=triggers->Create(TASK_TRIGGER_TIME,&trigger);if(FAILED(hr))return hr;ComPtr<ITimeTrigger> timer;hr=trigger.As(&timer);if(FAILED(hr))return hr;
  FILETIME ft;ULARGE_INTEGER u;u.QuadPart=static_cast<ULONGLONG>(std::max(at,Now()+1000))*10000ULL+116444736000000000ULL;ft.dwLowDateTime=u.LowPart;ft.dwHighDateTime=u.HighPart;SYSTEMTIME time;FileTimeToSystemTime(&ft,&time);wchar_t boundary[40];swprintf_s(boundary,L"%04u-%02u-%02uT%02u:%02u:%02uZ",time.wYear,time.wMonth,time.wDay,time.wHour,time.wMinute,time.wSecond);timer->put_StartBoundary(_bstr_t(boundary));
  ComPtr<IActionCollection> actions;hr=task->get_Actions(&actions);if(FAILED(hr))return hr;ComPtr<IAction> action;hr=actions->Create(TASK_ACTION_EXEC,&action);if(FAILED(hr))return hr;ComPtr<IExecAction> exec;hr=action.As(&exec);if(FAILED(hr))return hr;exec->put_Path(_bstr_t(exe));exec->put_Arguments(_bstr_t(L"--strong-worker"));std::wstring path(exe);exec->put_WorkingDirectory(_bstr_t(path.substr(0,path.find_last_of(L"\\")).c_str()));ComPtr<IRegisteredTask> registered;
  return folder->RegisterTaskDefinition(_bstr_t(name.c_str()),task.Get(),TASK_CREATE_OR_UPDATE,_variant_t(user),_variant_t(),TASK_LOGON_INTERACTIVE_TOKEN,_variant_t(L""),&registered);
}
void StartWorker(){wchar_t exe[MAX_PATH];GetModuleFileNameW(nullptr,exe,MAX_PATH);std::wstring command=L"\""+std::wstring(exe)+L"\" --strong-worker";STARTUPINFOW si{};si.cb=sizeof(si);PROCESS_INFORMATION pi{};if(CreateProcessW(exe,command.data(),nullptr,nullptr,FALSE,CREATE_NO_WINDOW,nullptr,nullptr,&si,&pi)){CloseHandle(pi.hProcess);CloseHandle(pi.hThread);}}
long long Earliest(JsonArray jobs){long long at=0;for(auto j:jobs){auto n=N(j.GetObject(),L"fireAtMillis");if(at==0||n<at)at=n;}return at;}
}
std::string StrongCommand(const std::string& command,const std::string& argument){
  bool start=false;std::string output;
  {Lock lock;auto root=Read();auto before=root.Stringify();auto s=root.GetNamedObject(L"session",JsonObject());if(s.HasKey(L"phase"))Advance(s);auto pending=root.GetNamedArray(L"pending",JsonArray());
  if(command=="scheduleStrong"||command=="scheduleStrongBatch"){
    JsonArray incoming;
    if(command=="scheduleStrongBatch")incoming=JsonArray::Parse(winrt::to_hstring(argument));else incoming.Append(JsonObject::Parse(winrt::to_hstring(argument)));
    std::set<std::wstring> keys;for(auto v:pending)keys.insert(v.GetObject().GetNamedString(L"key").c_str());
    if(s.HasKey(L"records"))for(auto v:s.GetNamedArray(L"records"))keys.insert(v.GetObject().GetNamedString(L"key").c_str());
    auto previous=Earliest(pending);
    for(auto v:incoming){auto r=v.GetObject();auto key=std::wstring(r.GetNamedString(L"key").c_str());if(keys.insert(key).second){pending.Append(r);if(N(r,L"fireAtMillis")<=Now()+1000)start=true;}}
    root.SetNamedValue(L"pending",pending);if(previous!=Earliest(pending)){auto hr=ScheduleWorker(Earliest(pending));if(FAILED(hr))throw std::runtime_error("Windows reminder task registration failed");}
  }else if(command=="strongPendingIds") {JsonArray ids;for(auto r:pending)ids.Append(Num(N(r.GetObject(),L"notificationId")));return winrt::to_string(ids.Stringify());}
  else if(command=="strongCancel") {JsonArray retained;auto id=std::stoi(argument);for(auto r:pending)if(N(r.GetObject(),L"notificationId")!=id)retained.Append(r);if(Earliest(pending)!=Earliest(retained))ScheduleWorker(Earliest(retained));root.SetNamedValue(L"pending",retained);
  }else if(command=="cancelStrongScheduled"){root.SetNamedValue(L"pending",JsonArray());ScheduleWorker(0);}
  else if(command=="stopStrongTests"){
    JsonArray retained;for(auto r:pending)if(r.GetObject().GetNamedString(L"payload")!=L"test_strong_reminder")retained.Append(r);root.SetNamedValue(L"pending",retained);ScheduleWorker(Earliest(retained));
    if(Active(s)){JsonArray formal;for(auto r:s.GetNamedArray(L"records"))if(r.GetObject().GetNamedString(L"payload")!=L"test_strong_reminder")formal.Append(r);s.SetNamedValue(L"records",formal);if(formal.Size()==0)Put(s,L"phase",L"emergency");}
  }else if(Active(s)){
    if(command=="strongOpen"){
      OpenSession(s);
      if(s.GetNamedString(L"phase")==L"timeout"){
        auto reposts=root.GetNamedArray(L"reposts",JsonArray());
        for(auto raw:s.GetNamedArray(L"records",JsonArray()))reposts.Append(raw.GetObject().GetNamedValue(L"notificationId"));
        root.SetNamedValue(L"reposts",reposts);
      }
    }
    if(command=="strongBegin")BeginSession(s);
    if(command=="strongLeave"&&(s.GetNamedString(L"phase")==L"ready"||s.GetNamedString(L"phase")==L"task")){
      Put(s,L"phase",L"timeout");if(N(s,L"nextRoundAt")>0){s.SetNamedValue(L"round",Num(N(s,L"round")+1));s.SetNamedValue(L"roundEnd",Num(std::min(Now()+N(s,L"duration"),N(s,L"expiresAt"))));s.SetNamedValue(L"nextRoundAt",Num(0));}
    }
    if(command=="strongEmergency")Put(s,L"phase",L"emergency");
    if(command=="strongAnswer"&&s.GetNamedString(L"phase")==L"task"){int input=std::stoi(argument);auto progress=N(s,L"progress");bool seq=s.GetNamedObject(L"settings").GetNamedString(L"dismissTask",L"arithmetic")==L"sequence";long long expected=progress%6+1;if(!seq){auto q=s.GetNamedArray(L"questions").GetObjectAt(static_cast<uint32_t>(progress));expected=N(q,L"a")+(q.GetNamedBoolean(L"subtract")?-N(q,L"b"):N(q,L"b"));}s.SetNamedValue(L"wrong",JsonValue::CreateBooleanValue(input!=expected));if(input==expected){s.SetNamedValue(L"progress",Num(progress+1));if(seq&&progress==5)s.SetNamedValue(L"numbers",Numbers());if(progress+1>=(seq?12:2))Put(s,L"phase",L"completed");}}
  }
  if((command=="strongAnswer"||command=="strongEmergency")&&s.HasKey(L"phase")&&(s.GetNamedString(L"phase")==L"completed"||s.GetNamedString(L"phase")==L"emergency")){
    JsonArray retained;auto jobs=root.GetNamedArray(L"pending",JsonArray());
    for(auto job:jobs){auto r=job.GetObject();bool same=false;
      for(auto raw:s.GetNamedArray(L"records",JsonArray())){auto record=raw.GetObject();
        auto rule=record.GetNamedValue(L"ruleId",JsonValue::CreateNullValue());auto session=record.GetNamedValue(L"sessionId",JsonValue::CreateNullValue());
        if(rule.ValueType()==JsonValueType::String && session.ValueType()==JsonValueType::String &&
          r.GetNamedValue(L"ruleId",JsonValue::CreateNullValue()).Stringify()==rule.Stringify() &&
          r.GetNamedValue(L"sessionId",JsonValue::CreateNullValue()).Stringify()==session.Stringify())same=true;
      }if(!same)retained.Append(r);
    }
    if(Earliest(jobs)!=Earliest(retained))ScheduleWorker(Earliest(retained));root.SetNamedValue(L"pending",retained);
  }
  if(s.HasKey(L"phase")){root.SetNamedValue(L"session",s);output=winrt::to_string(s.Stringify());}if(before!=root.Stringify())Write(root);}
  if(command=="strongOpen" && !output.empty()){auto state=JsonObject::Parse(winrt::to_hstring(output));auto phase=state.GetNamedString(L"phase");if(Active(state))ClearSound();}
  if(!output.empty()&&(command=="strongEmergency"||command=="strongAnswer")){
    auto state=JsonObject::Parse(winrt::to_hstring(output));if(!Active(state))ClearSound();
  }
  if(start)StartWorker();return output;
}
void OpenStrongReminder(){try{StrongCommand("strongOpen");}catch(...) {}}
int RunStrongReminderWorker(){
  CoInitializeEx(nullptr,COINIT_MULTITHREADED);HANDLE worker=CreateMutexW(nullptr,TRUE,L"Local\\OrbitStrongWorker");if(GetLastError()==ERROR_ALREADY_EXISTS){CloseHandle(worker);CoUninitialize();return 0;}
  std::map<int,ToastNotification> shown;std::wstring lastPhase;long long lastRound=0;bool lastPlay=false;
  try{
    auto notifier=ToastNotificationManager::CreateToastNotifier(appId);
    for(;;){JsonObject s;bool active=false;
      {Lock lock;auto root=Read();auto before=root.Stringify();s=root.GetNamedObject(L"session",JsonObject());if(s.HasKey(L"phase"))Advance(s);auto pending=root.GetNamedArray(L"pending",JsonArray());JsonArray retained;
        for(auto v:pending){auto r=v.GetObject();auto at=N(r,L"fireAtMillis");if(at>Now()){retained.Append(r);continue;}auto length=std::clamp(N(r.GetNamedObject(L"strong"),L"durationSeconds",30),5LL,300LL)*1000;if(Now()>=at+length*3+30000)continue;
          if(!Active(s))s=NewSession(r);else s.GetNamedArray(L"records").Append(r);
        }
        root.SetNamedValue(L"pending",retained);if(s.HasKey(L"phase")){Advance(s);root.SetNamedValue(L"session",s);}if(before!=root.Stringify())Write(root);active=Active(s);
        if(!active){ScheduleWorker(Earliest(retained));}
      }
      auto phase=s.GetNamedString(L"phase",L"");bool play=active&&phase!=L"ready"&&phase!=L"task"&&Now()<N(s,L"roundEnd");
      if(play!=lastPlay||std::wstring(phase.c_str())!=lastPhase||N(s,L"round")!=lastRound){for(auto& item:shown)notifier.Hide(item.second);shown.clear();}
      if(active){
        for(auto it=shown.begin();it!=shown.end();){bool present=false;for(auto record:s.GetNamedArray(L"records"))if(N(record.GetObject(),L"notificationId")==it->first)present=true;
          if(!present){notifier.Hide(it->second);it=shown.erase(it);}else ++it;}
      }
      if(active){for(auto v:s.GetNamedArray(L"records")){auto r=v.GetObject();auto id=static_cast<int>(N(r,L"notificationId"));if(shown.count(id))continue;auto xml=winrt::to_string(r.GetNamedString(L"xml"));if(!play){auto from=xml.find("<audio ");auto end=xml.find("/>",from);if(from!=std::string::npos&&end!=std::string::npos)xml.replace(from,end+2-from,"<audio silent=\"true\"/>");}
        winrt::Windows::Data::Xml::Dom::XmlDocument document;document.LoadXml(winrt::to_hstring(xml));ToastNotification toast(document);toast.Tag(winrt::to_hstring(std::to_string(id)));toast.Group(L"orbit_strong");toast.Dismissed([id](const auto&,const ToastDismissedEventArgs& args){if(args.Reason()!=ToastDismissalReason::UserCanceled)return;std::thread([id](){std::this_thread::sleep_for(std::chrono::seconds(2));try{Lock lock;auto root=Read();auto value=root.GetNamedObject(L"session",JsonObject());if(Active(value)){auto reposts=value.GetNamedArray(L"reposts",JsonArray());bool exists=false;for(auto entry:reposts)if(static_cast<int>(entry.GetNumber())==id)exists=true;if(!exists)reposts.Append(Num(id));value.SetNamedValue(L"reposts",reposts);root.SetNamedValue(L"session",value);Write(root);}}catch(...) {}}).detach();});notifier.Show(toast);shown.emplace(id,toast);
      }}
      {Lock lock;auto root=Read();auto value=root.GetNamedObject(L"session",JsonObject());auto reposts=value.GetNamedArray(L"reposts",JsonArray());if(reposts.Size()>0){for(auto entry:reposts)shown.erase(static_cast<int>(entry.GetNumber()));value.Remove(L"reposts");root.SetNamedValue(L"session",value);Write(root);}}
      lastPlay=play;lastPhase=phase.c_str();lastRound=N(s,L"round");if(!active)break;std::this_thread::sleep_for(std::chrono::milliseconds(200));
    }
    for(auto& item:shown)notifier.Hide(item.second);
    { Lock lock; auto root=Read();auto s=root.GetNamedObject(L"session",JsonObject());
      if(s.GetNamedString(L"phase",L"")==L"unconfirmed") {
        for(auto raw:s.GetNamedArray(L"records",JsonArray())) {
          auto r=raw.GetObject();winrt::Windows::Data::Xml::Dom::XmlDocument doc;
          doc.LoadXml(L"<toast><visual><binding template=\"ToastGeneric\"><text>Orbit</text><text>未确认 / Not confirmed</text></binding></visual><audio silent=\"true\"/></toast>");
          ToastNotification toast(doc);toast.Tag(winrt::to_hstring(std::to_string(N(r,L"notificationId"))));toast.Group(L"orbit_strong");notifier.Show(toast);
        }
      }
    }
  }catch(...) {for(auto& item:shown){try{ToastNotificationManager::CreateToastNotifier(appId).Hide(item.second);}catch(...) {}}}
  ReleaseMutex(worker);CloseHandle(worker);CoUninitialize();return 0;
}

int RunStrongReminderSelfTest(){
  CoInitializeEx(nullptr,COINIT_MULTITHREADED);
  int result=0;
  try {
    auto check=[](bool condition){if(!condition)throw std::runtime_error("Native deadline assertion failed");};
    auto fresh=[](){JsonObject r,settings;settings.SetNamedValue(L"durationSeconds",Num(30));settings.SetNamedValue(L"prepareSeconds",Num(15));settings.SetNamedValue(L"answerSeconds",Num(30));r.SetNamedValue(L"strong",settings);r.SetNamedValue(L"fireAtMillis",Num(100000));Put(r,L"key",L"test");return NewSession(r);};
    testClock=100000;auto s=fresh();check(N(s,L"expiresAt")==220000);OpenSession(s);check(N(s,L"prepareDeadline")==115000);
    testClock=110000;OpenSession(s);check(N(s,L"prepareDeadline")==115000);check(N(s,L"expiresAt")==220000);
    BeginSession(s);check(N(s,L"answerDeadline")==140000);testClock=120000;BeginSession(s);check(N(s,L"answerDeadline")==140000);
    testClock=139999;Advance(s);check(s.GetNamedString(L"phase")==L"task");check(N(s,L"nextRoundAt")==145000);
    testClock=140000;Advance(s);check(s.GetNamedString(L"phase")==L"timeout");check(N(s,L"round")==2);check(N(s,L"roundEnd")==170000);
    testClock=219000;BeginSession(s);check(N(s,L"answerDeadline")==220000);testClock=220000;Advance(s);check(s.GetNamedString(L"phase")==L"unconfirmed");check(!Active(s));
    testClock=100000;s=fresh();for(auto time:{130000LL,145000LL,175000LL,190000LL}){testClock=time;Advance(s);}check(N(s,L"round")==3);testClock=220000;Advance(s);check(!Active(s));
    testClock=100000;s=fresh();Put(s,L"phase",L"completed");testClock=500000;Advance(s);check(s.GetNamedString(L"phase")==L"completed");OpenSession(s);check(!s.GetNamedBoolean(L"opened",false));
  }catch(...){result=1;}
  testClock=-1;CoUninitialize();return result;
}
