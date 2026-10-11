#include "strong_reminders.h"
#include "reminder_audio.h"
#include <sddl.h>
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
#include <climits>
#include <set>
using namespace winrt::Windows::Data::Json;
using namespace winrt::Windows::UI::Notifications;
using Microsoft::WRL::ComPtr;
namespace {
constexpr wchar_t appId[]=L"com.must.orbit";
thread_local long long testClock=-1;
std::wstring testStatePath;
bool testSchedule=false;
long long Now(){if(testClock>=0)return testClock;return std::chrono::duration_cast<std::chrono::milliseconds>(std::chrono::system_clock::now().time_since_epoch()).count();}
JsonValue Num(long long n){return JsonValue::CreateNumberValue(static_cast<double>(n));}
void Put(JsonObject s,const wchar_t* k,const wchar_t* v){s.SetNamedValue(k,JsonValue::CreateStringValue(v));}
long long N(JsonObject s,const wchar_t* k,long long fallback=0){return static_cast<long long>(s.GetNamedNumber(k,static_cast<double>(fallback)));}
std::wstring StatePath(){if(!testStatePath.empty())return testStatePath;PWSTR path=nullptr; if(FAILED(SHGetKnownFolderPath(FOLDERID_LocalAppData,0,nullptr,&path)))throw std::runtime_error("Application data unavailable"); std::wstring dir=std::wstring(path)+L"\\Orbit\\reminders";CoTaskMemFree(path);std::filesystem::create_directories(dir);return dir+L"\\strong.json";}
JsonObject Read(){std::ifstream f(StatePath(),std::ios::binary);std::string text((std::istreambuf_iterator<char>(f)),{});JsonObject o; if(!text.empty() && JsonObject::TryParse(winrt::to_hstring(text),o))return o; o=JsonObject();o.SetNamedValue(L"pending",JsonArray());return o;}
void Write(JsonObject s){auto path=StatePath();auto text=winrt::to_string(s.Stringify());std::ofstream f(path+L".tmp",std::ios::binary|std::ios::trunc);f.write(text.data(),static_cast<std::streamsize>(text.size()));f.close();if(!MoveFileExW((path+L".tmp").c_str(),path.c_str(),MOVEFILE_REPLACE_EXISTING|MOVEFILE_WRITE_THROUGH))throw std::runtime_error("Cannot save strong reminder");}
struct Lock {HANDLE mutex;Lock(){mutex=CreateMutexW(nullptr,FALSE,testStatePath.empty()?L"Local\\OrbitStrongState":L"Local\\OrbitStrongStateSelfTest");if(!mutex)throw std::runtime_error("Strong state mutex failed");DWORD r=WaitForSingleObject(mutex,10000);if(r!=WAIT_OBJECT_0&&r!=WAIT_ABANDONED){CloseHandle(mutex);throw std::runtime_error("Strong state busy");}}~Lock(){ReleaseMutex(mutex);CloseHandle(mutex);}};
bool Active(JsonObject s){auto p=s.GetNamedString(L"phase",L"");return !p.empty()&&p!=L"completed"&&p!=L"emergency"&&p!=L"unconfirmed"&&p!=L"cancelled"&&Now()<N(s,L"expiresAt");}
JsonArray Numbers(int count=6){std::vector<int> v;for(int i=1;i<=count;++i)v.push_back(i);std::mt19937 rng(std::random_device{}());std::shuffle(v.begin(),v.end(),rng);JsonArray a;for(int n:v)a.Append(Num(n));return a;}
long long ArithmeticAnswer(JsonObject q) {
  auto op=q.GetNamedString(L"operator",q.GetNamedBoolean(L"subtract",false)?L"subtract":L"add");
  if(op==L"multiply")return N(q,L"a")*N(q,L"b");
  return N(q,L"a")+(op==L"subtract"?-N(q,L"b"):N(q,L"b"));
}
JsonArray CreateTasks(JsonObject settings) {
  std::mt19937 rng(std::random_device{}());
  auto draw=[&](int low,int high){return std::uniform_int_distribution<int>(low,high)(rng);};
  auto mode=settings.GetNamedString(L"dismissTask",L"arithmetic");
  auto rounds=std::clamp(N(settings,mode==L"mixed"?L"mixedRounds":mode==L"sequence"?L"sequenceRounds":L"arithmeticRounds",2),1LL,10LL);
  auto count=static_cast<int>(std::clamp(N(settings,L"sequenceNumberCount",6),4LL,25LL));
  JsonArray tasks;
  for(int i=0;i<rounds;++i) {
    JsonObject q;
    if(mode==L"sequence"||(mode==L"mixed"&&draw(0,1)==1)) {
      Put(q,L"type",L"sequence");q.SetNamedValue(L"numberCount",Num(count));q.SetNamedValue(L"numbers",Numbers(count));
    } else {
      Put(q,L"type",L"arithmetic");auto difficulty=settings.GetNamedString(L"arithmeticDifficulty",L"medium");
      int op=draw(0,difficulty==L"simple"?1:2);
      int a=difficulty==L"hard"&&op!=2?draw(100,999):draw(10,difficulty==L"simple"?89:99);
      int b=difficulty==L"simple"?draw(1,9):difficulty==L"hard"?(op==2?draw(10,99):draw(100,999)):op==2?draw(2,9):draw(10,99);
      if(op==1&&a<b)std::swap(a,b);
      q.SetNamedValue(L"a",Num(a));q.SetNamedValue(L"b",Num(b));q.SetNamedValue(L"subtract",JsonValue::CreateBooleanValue(op==1));
      Put(q,L"operator",op==2?L"multiply":op==1?L"subtract":L"add");
      auto answerMode=settings.GetNamedString(L"arithmeticAnswerMode",L"input");int choicesCount=answerMode==L"choice3"?3:answerMode==L"choice6"?6:0;
      std::vector<int> values;
      if(choicesCount>0) {
        int answer=static_cast<int>(ArithmeticAnswer(q));values.push_back(answer);int spread=std::max(6,answer/8);
        for(int trial=0;trial<50&&static_cast<int>(values.size())<choicesCount;++trial) {
          int candidate=answer+(draw(0,1)?1:-1)*draw(1,spread);
          if(candidate>=0&&std::find(values.begin(),values.end(),candidate)==values.end())values.push_back(candidate);
        }
        for(int delta=1;static_cast<int>(values.size())<choicesCount;++delta) {
          int candidate=answer+delta;
          if(std::find(values.begin(),values.end(),candidate)==values.end())values.push_back(candidate);
        }
        std::shuffle(values.begin(),values.end(),rng);
      }
      JsonArray choices;for(int v:values)choices.Append(Num(v));q.SetNamedValue(L"choices",choices);
    }
    tasks.Append(q);
  }
  return tasks;
}
JsonObject NewSession(JsonObject r){auto settings=r.GetNamedObject(L"strong");auto at=N(r,L"fireAtMillis");auto duration=std::clamp(N(settings,L"durationSeconds",30),5LL,300LL)*1000;JsonObject s;Put(s,L"id",r.GetNamedString(L"key").c_str());Put(s,L"phase",L"ringing");s.SetNamedValue(L"startedAt",Num(at));s.SetNamedValue(L"expiresAt",Num(at+duration*3+30000));s.SetNamedValue(L"duration",Num(duration));s.SetNamedValue(L"round",Num(1));s.SetNamedValue(L"roundEnd",Num(at+duration));s.SetNamedValue(L"nextRoundAt",Num(0));s.SetNamedValue(L"settings",settings);s.SetNamedValue(L"opened",JsonValue::CreateBooleanValue(false));s.SetNamedValue(L"progress",Num(0));s.SetNamedValue(L"openRequest",Num(0));JsonArray records;records.Append(r);s.SetNamedValue(L"records",records);
  auto tasks=CreateTasks(settings);s.SetNamedValue(L"tasks",tasks);s.SetNamedValue(L"taskIndex",Num(0));s.SetNamedValue(L"taskProgress",Num(0));
  JsonArray questions;for(auto raw:tasks){auto task=raw.GetObject();if(task.GetNamedString(L"type")==L"arithmetic")questions.Append(task);}
  s.SetNamedValue(L"questions",questions);s.SetNamedValue(L"numbers",tasks.GetObjectAt(0).GetNamedArray(L"numbers",JsonArray()));return s;
}
void AnswerSession(JsonObject s,int input){
  if(s.HasKey(L"tasks")) {
    auto tasks=s.GetNamedArray(L"tasks");auto index=static_cast<uint32_t>(N(s,L"taskIndex"));if(index>=tasks.Size())return;
    auto q=tasks.GetObjectAt(index);bool sequence=q.GetNamedString(L"type")==L"sequence";auto step=N(s,L"taskProgress");
    auto expected=sequence?step+1:ArithmeticAnswer(q);bool offered=true;auto choices=q.GetNamedArray(L"choices",JsonArray());
    if(!sequence&&choices.Size()>0){offered=false;for(auto v:choices)if(v.GetNumber()==input)offered=true;}
    bool correct=input==expected&&offered;s.SetNamedValue(L"wrong",JsonValue::CreateBooleanValue(!correct));if(!correct)return;
    s.SetNamedValue(L"progress",Num(N(s,L"progress")+1));
    if(sequence&&step+1<N(q,L"numberCount"))s.SetNamedValue(L"taskProgress",Num(step+1));
    else {s.SetNamedValue(L"taskIndex",Num(index+1));s.SetNamedValue(L"taskProgress",Num(0));
      if(index+1==tasks.Size())Put(s,L"phase",L"completed");
      else s.SetNamedValue(L"numbers",tasks.GetObjectAt(index+1).GetNamedArray(L"numbers",JsonArray()));}
    return;
  }
  // Persisted sessions from earlier versions keep their original task rules.
  auto progress=N(s,L"progress");bool seq=s.GetNamedObject(L"settings").GetNamedString(L"dismissTask",L"arithmetic")==L"sequence";long long expected=progress%6+1;
  if(!seq)expected=ArithmeticAnswer(s.GetNamedArray(L"questions").GetObjectAt(static_cast<uint32_t>(progress)));
  s.SetNamedValue(L"wrong",JsonValue::CreateBooleanValue(input!=expected));if(input==expected){s.SetNamedValue(L"progress",Num(progress+1));if(seq&&(progress+1)%6==0)s.SetNamedValue(L"numbers",Numbers());if(progress+1>=(seq?std::clamp(N(s.GetNamedObject(L"settings"),L"sequenceRounds",2),1LL,10LL)*6:static_cast<long long>(s.GetNamedArray(L"questions").Size())))Put(s,L"phase",L"completed");}
}

void Advance(JsonObject s){if(!Active(s)){if(s.GetNamedString(L"phase",L"")!=L"completed"&&s.GetNamedString(L"phase",L"")!=L"emergency")Put(s,L"phase",L"unconfirmed");return;}auto now=Now();if(now>=N(s,L"roundEnd")&&N(s,L"nextRoundAt")==0){if(N(s,L"round")>=3){Put(s,L"phase",L"unconfirmed");return;}s.SetNamedValue(L"nextRoundAt",Num(N(s,L"roundEnd")+15000));}auto phase=s.GetNamedString(L"phase");auto deadline=phase==L"task"?N(s,L"answerDeadline"):phase==L"ready"?N(s,L"prepareDeadline"):0;bool timeout=deadline>0&&now>=deadline;if(timeout)Put(s,L"phase",L"timeout");if(N(s,L"nextRoundAt")>0&&(now>=N(s,L"nextRoundAt")||timeout)){s.SetNamedValue(L"round",Num(N(s,L"round")+1));s.SetNamedValue(L"roundEnd",Num(std::min(now+N(s,L"duration"),N(s,L"expiresAt"))));s.SetNamedValue(L"nextRoundAt",Num(0));}}
void OpenSession(JsonObject s){
  if(Active(s))s.SetNamedValue(L"openRequest",Num(N(s,L"openRequest")+1));
  if(Active(s)&&!s.GetNamedBoolean(L"opened",false)){s.SetNamedValue(L"opened",JsonValue::CreateBooleanValue(true));Put(s,L"phase",L"ready");s.SetNamedValue(L"prepareDeadline",Num(std::min(Now()+std::clamp(N(s.GetNamedObject(L"settings"),L"prepareSeconds",15),5LL,60LL)*1000,N(s,L"expiresAt"))));}
}
void BeginSession(JsonObject s){
  if(Active(s)&&s.GetNamedString(L"phase")!=L"task"){Put(s,L"phase",L"task");s.SetNamedValue(L"answerDeadline",Num(std::min(Now()+std::clamp(N(s.GetNamedObject(L"settings"),L"answerSeconds",30),10LL,120LL)*1000,N(s,L"expiresAt"))));}
}
bool DeadlineRecord(JsonObject r){return r.GetNamedString(L"acknowledgementMode",L"")==L"openApp";}
std::wstring DeadlineIdentity(JsonObject r){return std::wstring(r.GetNamedString(L"deadlineId").c_str())+L":"+std::to_wstring(N(r,L"leadMinutes"))+L":"+std::to_wstring(N(r,L"fireAtMillis"));}
JsonObject NewDeadlineSession(JsonObject r){auto s=NewSession(r);s.Remove(L"questions");s.Remove(L"numbers");s.Remove(L"tasks");s.Remove(L"taskIndex");s.Remove(L"taskProgress");return s;}
void AdvanceDeadline(JsonObject s){
  auto phase=s.GetNamedString(L"phase",L"");if(phase==L"completed"||phase==L"cancelled"||phase==L"unconfirmed")return;
  if(Now()>=N(s,L"expiresAt")){Put(s,L"phase",L"unconfirmed");return;}
  auto duration=N(s,L"duration");auto round=std::clamp((Now()-N(s,L"startedAt"))/(duration+15000)+1,1LL,3LL);
  s.SetNamedValue(L"round",Num(round));s.SetNamedValue(L"roundEnd",Num(N(s,L"startedAt")+(round-1)*(duration+15000)+duration));
}
bool Ringing(JsonObject s){auto phase=s.GetNamedString(L"phase",L"");return Active(s)&&phase!=L"ready"&&phase!=L"task"&&Now()<N(s,L"roundEnd");}
bool OrbitVisible(JsonObject root,bool focused){
  auto window=reinterpret_cast<HWND>(static_cast<intptr_t>(N(root,L"appWindow")));DWORD pid=0;
  if(!window||!IsWindow(window)||!IsWindowVisible(window)||IsIconic(window))return false;
  GetWindowThreadProcessId(window,&pid);return pid==static_cast<DWORD>(N(root,L"appPid"))&&(!focused||GetForegroundWindow()==window);
}
void HideRecord(JsonObject record){try{ToastNotificationManager::History().Remove(winrt::to_hstring(std::to_string(N(record,L"notificationId"))),L"orbit_strong",appId);}catch(...) {}}
void HideRecords(JsonObject session){for(auto record:session.GetNamedArray(L"records",JsonArray()))HideRecord(record.GetObject());}
void ConfirmDeadlines(JsonObject root,bool hide=true){
  auto events=root.GetNamedArray(L"deadlineEvents",JsonArray());
  for(auto raw:root.GetNamedArray(L"deadlineSessions",JsonArray())){
    auto s=raw.GetObject();AdvanceDeadline(s);if(!Active(s))continue;
    Put(s,L"phase",L"completed");auto r=s.GetNamedArray(L"records").GetObjectAt(0);if(hide)HideRecord(r);
    JsonObject event;event.SetNamedValue(L"id",s.GetNamedValue(L"id"));event.SetNamedValue(L"deadlineId",r.GetNamedValue(L"deadlineId"));
    event.SetNamedValue(L"leadMinutes",r.GetNamedValue(L"leadMinutes"));event.SetNamedValue(L"fireAtMillis",r.GetNamedValue(L"fireAtMillis"));events.Append(event);
  }
  root.SetNamedValue(L"deadlineEvents",events);
}
JsonObject DeadlineEvents(JsonObject root){JsonObject output;output.SetNamedValue(L"events",root.GetNamedArray(L"deadlineEvents",JsonArray()));return output;}
JsonArray DeadlineSessions(JsonObject root){JsonArray kept;for(auto raw:root.GetNamedArray(L"deadlineSessions",JsonArray())){auto s=raw.GetObject();AdvanceDeadline(s);if(Now()<N(s,L"expiresAt")+7*86400000LL)kept.Append(s);}root.SetNamedValue(L"deadlineSessions",kept);return kept;}
std::wstring ExecutablePath(){std::wstring path(32768,L'\0');auto size=GetModuleFileNameW(nullptr,path.data(),static_cast<DWORD>(path.size()));if(size==0||size>=path.size())throw std::runtime_error("Executable path unavailable");path.resize(size);return path;}
void Diagnostic(JsonObject root,const wchar_t* stage,HRESULT hr,const std::wstring& key=L"") {
  auto data=root.GetNamedObject(L"diagnostics",JsonObject());auto instances=data.GetNamedObject(L"instances",JsonObject());auto instance=key.empty()?JsonObject():instances.GetNamedObject(key,JsonObject());auto old=key.empty()?data.GetNamedObject(stage,JsonObject()):instance.GetNamedObject(stage,JsonObject());
  if(old.HasKey(L"hr")&&N(old,L"hr")==hr&&old.GetNamedString(L"key",L"")==key)return;
  JsonObject entry;entry.SetNamedValue(L"hr",Num(hr));entry.SetNamedValue(L"ok",JsonValue::CreateBooleanValue(SUCCEEDED(hr)));entry.SetNamedValue(L"at",Num(Now()));Put(entry,L"key",key.c_str());data.SetNamedValue(stage,entry);
  if(!key.empty()){instance.SetNamedValue(stage,entry);instance.SetNamedValue(L"at",Num(Now()));instances.SetNamedValue(key,instance);
    while(instances.Size()>64){winrt::hstring oldest;long long at=LLONG_MAX;for(auto item:instances){auto time=N(item.Value().GetObject(),L"at");if(time<at){at=time;oldest=item.Key();}}instances.Remove(oldest);}
    data.SetNamedValue(L"instances",instances);
  }
  auto previous=data.GetNamedArray(L"events",JsonArray());JsonArray events;for(uint32_t i=previous.Size()>19?previous.Size()-19:0;i<previous.Size();++i)events.Append(previous.GetAt(i));
  auto event=JsonObject::Parse(entry.Stringify());Put(event,L"stage",stage);events.Append(event);data.SetNamedValue(L"events",events);root.SetNamedValue(L"diagnostics",data);
}
void Report(const wchar_t* stage,HRESULT hr,const std::wstring& key=L""){try{Lock lock;auto root=Read();auto before=root.Stringify();Diagnostic(root,stage,hr,key);if(root.Stringify()!=before)Write(root);}catch(...) {}}
HRESULT EnsureNotificationRegistration(){
  try{auto exe=ExecutablePath();HKEY key=nullptr;auto set=[&](const std::wstring& path,const wchar_t* name,const std::wstring& value){auto result=RegCreateKeyExW(HKEY_CURRENT_USER,path.c_str(),0,nullptr,0,KEY_WRITE,nullptr,&key,nullptr);if(result!=ERROR_SUCCESS)throw winrt::hresult_error(HRESULT_FROM_WIN32(result));result=RegSetValueExW(key,name,0,REG_SZ,reinterpret_cast<const BYTE*>(value.c_str()),static_cast<DWORD>((value.size()+1)*sizeof(wchar_t)));RegCloseKey(key);key=nullptr;if(result!=ERROR_SUCCESS)throw winrt::hresult_error(HRESULT_FROM_WIN32(result));};
    const std::wstring app=L"Software\\Classes\\AppUserModelId\\com.must.orbit";
    set(app,L"DisplayName",L"Orbit");set(app,L"CustomActivator",L"{7f8d9c2a-4b1e-4f6a-9c3d-2e1f0a9b8c7d}");
    set(L"Software\\Classes\\CLSID\\{7f8d9c2a-4b1e-4f6a-9c3d-2e1f0a9b8c7d}\\LocalServer32",nullptr,L"\""+exe+L"\" --notification-action");return S_OK;
  }catch(const winrt::hresult_error& error){return error.code();}catch(...){return E_FAIL;}
}
HRESULT ScheduleWorker(long long at){
  if(!testStatePath.empty()&&!testSchedule)return S_OK;
  auto exe=ExecutablePath();wchar_t user[256];DWORD size=256;if(!GetUserNameW(user,&size))return E_FAIL;
  ComPtr<ITaskService> service;HRESULT hr=CoCreateInstance(CLSID_TaskScheduler,nullptr,CLSCTX_INPROC_SERVER,IID_PPV_ARGS(&service));if(FAILED(hr))return hr;hr=service->Connect(_variant_t(),_variant_t(),_variant_t(),_variant_t());if(FAILED(hr))return hr;ComPtr<ITaskFolder> folder;hr=service->GetFolder(_bstr_t(L"\\"),&folder);if(FAILED(hr))return hr;
  std::wstring name=(testStatePath.empty()?L"Orbit Strong Reminder ":L"Orbit Strong Reminder Self Test ")+std::wstring(user);
  if(at==0){folder->DeleteTask(_bstr_t(name.c_str()),0);return S_OK;}
  ComPtr<ITaskDefinition> task;hr=service->NewTask(0,&task);if(FAILED(hr))return hr;ComPtr<ITaskSettings> settings;hr=task->get_Settings(&settings);if(FAILED(hr))return hr;settings->put_Enabled(VARIANT_TRUE);settings->put_StartWhenAvailable(VARIANT_TRUE);settings->put_DisallowStartIfOnBatteries(VARIANT_FALSE);settings->put_StopIfGoingOnBatteries(VARIANT_FALSE);settings->put_ExecutionTimeLimit(_bstr_t(L"PT1H"));settings->put_MultipleInstances(TASK_INSTANCES_IGNORE_NEW);
  HANDLE token=nullptr;if(!OpenProcessToken(GetCurrentProcess(),TOKEN_QUERY,&token))return HRESULT_FROM_WIN32(GetLastError());DWORD needed=0;GetTokenInformation(token,TokenUser,nullptr,0,&needed);std::vector<BYTE> tokenData(needed);if(!GetTokenInformation(token,TokenUser,tokenData.data(),needed,&needed)){auto error=GetLastError();CloseHandle(token);return HRESULT_FROM_WIN32(error);}CloseHandle(token);LPWSTR sid=nullptr;if(!ConvertSidToStringSidW(reinterpret_cast<TOKEN_USER*>(tokenData.data())->User.Sid,&sid))return HRESULT_FROM_WIN32(GetLastError());std::wstring userId(sid);LocalFree(sid);
  settings->put_RestartInterval(_bstr_t(L"PT1M"));settings->put_RestartCount(1);
  ComPtr<IPrincipal> principal;hr=task->get_Principal(&principal);if(FAILED(hr))return hr;principal->put_UserId(_bstr_t(userId.c_str()));principal->put_LogonType(TASK_LOGON_INTERACTIVE_TOKEN);principal->put_RunLevel(TASK_RUNLEVEL_LUA);
  ComPtr<ITriggerCollection> triggers;hr=task->get_Triggers(&triggers);if(FAILED(hr))return hr;ComPtr<ITrigger> trigger;hr=triggers->Create(TASK_TRIGGER_TIME,&trigger);if(FAILED(hr))return hr;ComPtr<ITimeTrigger> timer;hr=trigger.As(&timer);if(FAILED(hr))return hr;
  FILETIME ft;ULARGE_INTEGER u;u.QuadPart=static_cast<ULONGLONG>(std::max(at,Now()+1000))*10000ULL+116444736000000000ULL;ft.dwLowDateTime=u.LowPart;ft.dwHighDateTime=u.HighPart;SYSTEMTIME time;FileTimeToSystemTime(&ft,&time);wchar_t boundary[40];swprintf_s(boundary,L"%04u-%02u-%02uT%02u:%02u:%02uZ",time.wYear,time.wMonth,time.wDay,time.wHour,time.wMinute,time.wSecond);timer->put_StartBoundary(_bstr_t(boundary));
  ComPtr<IActionCollection> actions;hr=task->get_Actions(&actions);if(FAILED(hr))return hr;ComPtr<IAction> action;hr=actions->Create(TASK_ACTION_EXEC,&action);if(FAILED(hr))return hr;ComPtr<IExecAction> exec;hr=action.As(&exec);if(FAILED(hr))return hr;exec->put_Path(_bstr_t(exe.c_str()));std::wstring workerArgs=testStatePath.empty()?L"--strong-worker":L"--strong-worker-test \""+testStatePath+L"\"";exec->put_Arguments(_bstr_t(workerArgs.c_str()));std::wstring path(exe);exec->put_WorkingDirectory(_bstr_t(path.substr(0,path.find_last_of(L"\\")).c_str()));ComPtr<IRegisteredTask> registered;
  return folder->RegisterTaskDefinition(_bstr_t(name.c_str()),task.Get(),TASK_CREATE_OR_UPDATE,_variant_t(userId.c_str()),_variant_t(),TASK_LOGON_INTERACTIVE_TOKEN,_variant_t(L""),&registered);
}
HRESULT StartWorker(){auto exe=ExecutablePath();std::wstring command=L"\""+exe+L"\" --strong-worker";if(!testStatePath.empty())command=L"\""+exe+L"\" --strong-worker-test \""+testStatePath+L"\"";STARTUPINFOW si{};si.cb=sizeof(si);PROCESS_INFORMATION pi{};if(!CreateProcessW(exe.c_str(),command.data(),nullptr,nullptr,FALSE,CREATE_NO_WINDOW,nullptr,nullptr,&si,&pi))return HRESULT_FROM_WIN32(GetLastError());{Lock lock;auto root=Read();auto diagnostics=root.GetNamedObject(L"diagnostics",JsonObject());diagnostics.SetNamedValue(L"workerPid",Num(pi.dwProcessId));root.SetNamedValue(L"diagnostics",diagnostics);Diagnostic(root,L"workerStart",S_OK);Write(root);}CloseHandle(pi.hProcess);CloseHandle(pi.hThread);return S_OK;}
long long Earliest(JsonArray jobs){long long at=0;for(auto j:jobs){auto n=N(j.GetObject(),L"fireAtMillis");if(at==0||n<at)at=n;}return at;}
}
std::string StrongCommand(const std::string& command,const std::string& argument){
  bool start=false;std::string output;
  {Lock lock;auto root=Read();auto before=root.Stringify();auto s=root.GetNamedObject(L"session",JsonObject());if(s.HasKey(L"phase"))Advance(s);auto pending=root.GetNamedArray(L"pending",JsonArray());auto deadlines=DeadlineSessions(root);
  if(command=="strongDiagnostics") {auto diagnostics=root.GetNamedObject(L"diagnostics",JsonObject());diagnostics.SetNamedValue(L"pendingCount",Num(pending.Size()));bool alive=false;auto pid=static_cast<DWORD>(N(diagnostics,L"workerPid"));if(pid){auto process=OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION,FALSE,pid);if(process){DWORD exitCode=0;alive=GetExitCodeProcess(process,&exitCode)&&exitCode==STILL_ACTIVE;CloseHandle(process);}}diagnostics.SetNamedValue(L"workerAlive",JsonValue::CreateBooleanValue(alive));return winrt::to_string(diagnostics.Stringify());}
  if(command=="scheduleStrong"||command=="scheduleStrongBatch"){
    JsonArray incoming;
    if(command=="scheduleStrongBatch")incoming=JsonArray::Parse(winrt::to_hstring(argument));else incoming.Append(JsonObject::Parse(winrt::to_hstring(argument)));
    std::set<std::wstring> keys;for(auto v:pending)keys.insert(v.GetObject().GetNamedString(L"key").c_str());
    if(s.HasKey(L"records"))for(auto v:s.GetNamedArray(L"records"))keys.insert(v.GetObject().GetNamedString(L"key").c_str());
    for(auto raw:deadlines) for(auto v:raw.GetObject().GetNamedArray(L"records")) keys.insert(v.GetObject().GetNamedString(L"key").c_str());
    auto previous=Earliest(pending);
    for(auto v:incoming){auto r=v.GetObject();auto key=std::wstring(r.GetNamedString(L"key").c_str());if(keys.insert(key).second){pending.Append(r);if(N(r,L"fireAtMillis")<=Now()+1000)start=true;}}
    root.SetNamedValue(L"pending",pending);if(previous!=Earliest(pending)||!root.GetNamedObject(L"diagnostics",JsonObject()).GetNamedObject(L"task",JsonObject()).GetNamedBoolean(L"ok",false)){auto hr=ScheduleWorker(Earliest(pending));Diagnostic(root,L"task",hr);if(FAILED(hr)){Write(root);throw std::runtime_error("Windows reminder task registration failed: "+std::to_string(hr));}}
  }else if(command=="strongPendingIds") {JsonArray ids;for(auto r:pending)ids.Append(Num(N(r.GetObject(),L"notificationId")));return winrt::to_string(ids.Stringify());}
  else if(command=="strongCancel") {JsonArray retained;auto id=std::stoi(argument);for(auto r:pending)if(N(r.GetObject(),L"notificationId")!=id)retained.Append(r);if(Earliest(pending)!=Earliest(retained))ScheduleWorker(Earliest(retained));root.SetNamedValue(L"pending",retained);
  }else if(command=="cancelStrongScheduled"){root.SetNamedValue(L"pending",JsonArray());ScheduleWorker(0);}
  else if(command=="deadlineStrongOpen") {if(OrbitVisible(root,true))ConfirmDeadlines(root);output=winrt::to_string(DeadlineEvents(root).Stringify());}
  else if(command=="deadlineStrongEventsHandled") {
    auto ids=JsonArray::Parse(winrt::to_hstring(argument));std::set<std::wstring> handled;for(auto id:ids)handled.insert(id.GetString().c_str());
    JsonArray retained;for(auto raw:root.GetNamedArray(L"deadlineEvents",JsonArray()))if(!handled.count(raw.GetObject().GetNamedString(L"id").c_str()))retained.Append(raw);
    root.SetNamedValue(L"deadlineEvents",retained);output=winrt::to_string(DeadlineEvents(root).Stringify());
  }
  else if(command=="deadlineStrongReconcile") {
    auto ids=JsonArray::Parse(winrt::to_hstring(argument));std::set<std::wstring> valid;for(auto id:ids)valid.insert(id.GetString().c_str());
    for(auto raw:deadlines){auto value=raw.GetObject();if(Active(value)&&!valid.count(DeadlineIdentity(value.GetNamedArray(L"records").GetObjectAt(0)))){Put(value,L"phase",L"cancelled");HideRecords(value);}}
  }
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
    if(command=="strongAnswer"&&s.GetNamedString(L"phase")==L"task")AnswerSession(s,std::stoi(argument));
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
  if(s.HasKey(L"phase")){root.SetNamedValue(L"session",s);if(command.rfind("deadline",0)!=0)output=winrt::to_string(s.Stringify());}if(before!=root.Stringify())Write(root);}
  if(command=="strongOpen" && !output.empty()){auto state=JsonObject::Parse(winrt::to_hstring(output));auto phase=state.GetNamedString(L"phase");if(Active(state))HideRecords(state);}
  if(!output.empty()&&(command=="strongEmergency"||command=="strongAnswer")){
    auto state=JsonObject::Parse(winrt::to_hstring(output));if(!Active(state))HideRecords(state);
  }
  if(start){auto hr=StartWorker();if(FAILED(hr)){Report(L"workerStart",hr);throw std::runtime_error("Windows reminder worker could not start: "+std::to_string(hr));}}return output;
}
void RegisterStrongReminderWindow(void* window){try{Lock lock;auto root=Read();root.SetNamedValue(L"appWindow",Num(reinterpret_cast<intptr_t>(window)));root.SetNamedValue(L"appPid",Num(GetCurrentProcessId()));Write(root);}catch(...) {}}
void OpenStrongReminder(){try{StrongCommand("deadlineStrongOpen");StrongCommand("strongOpen");}catch(...) {}}
int RunStrongReminderWorker(){
  auto com=CoInitializeEx(nullptr,COINIT_MULTITHREADED);if(FAILED(com))return 1;
  HANDLE worker=CreateMutexW(nullptr,FALSE,testStatePath.empty()?L"Local\\OrbitStrongWorker":L"Local\\OrbitStrongWorkerSelfTest");if(!worker){CoUninitialize();return 1;}
  auto acquired=WaitForSingleObject(worker,0);if(acquired!=WAIT_OBJECT_0&&acquired!=WAIT_ABANDONED){CloseHandle(worker);CoUninitialize();return 0;}
  int exitCode=0;
  {ReminderAudioPlayer player;
  std::map<int,ToastNotification> shown;std::map<int,long long> retries;std::set<std::wstring> finalReported;
  std::wstring previousSound;bool fallback=false,waveFallback=false,reportedPlaying=false;ToastNotifier notifier{nullptr};
  auto registration=EnsureNotificationRegistration();Report(L"registration",registration);
  try{notifier=ToastNotificationManager::CreateToastNotifier(appId);Report(L"notifications",notifier.Setting()==NotificationSetting::Enabled?S_OK:E_ACCESSDENIED);}catch(const winrt::hresult_error& error){Report(L"notifications",error.code());}
  try{
    for(;;){std::vector<JsonObject> sessions;std::vector<JsonObject> finals;bool active=false,failToast=false,failAudio=false;
      {Lock lock;auto root=Read();auto before=root.Stringify();failToast=!testStatePath.empty()&&root.GetNamedBoolean(L"failToast",false);failAudio=!testStatePath.empty()&&root.GetNamedBoolean(L"failAudio",false);auto diagnostics=root.GetNamedObject(L"diagnostics",JsonObject());diagnostics.SetNamedValue(L"workerPid",Num(GetCurrentProcessId()));root.SetNamedValue(L"diagnostics",diagnostics);Diagnostic(root,L"workerStart",S_OK);
        auto course=root.GetNamedObject(L"session",JsonObject());if(course.HasKey(L"phase"))Advance(course);auto deadlines=DeadlineSessions(root);auto pending=root.GetNamedArray(L"pending",JsonArray());JsonArray retained;
        for(auto v:pending){auto r=v.GetObject();auto at=N(r,L"fireAtMillis");if(at>Now()){retained.Append(r);continue;}
          auto length=std::clamp(N(r.GetNamedObject(L"strong"),L"durationSeconds",30),5LL,300LL)*1000;if(Now()>=at+length*3+30000)continue;
          if(DeadlineRecord(r)){bool exists=false;for(auto raw:deadlines)if(raw.GetObject().GetNamedString(L"id")==r.GetNamedString(L"key"))exists=true;if(!exists){auto ddl=NewDeadlineSession(r);AdvanceDeadline(ddl);deadlines.Append(ddl);}}
          else if(!Active(course))course=NewSession(r);else {bool exists=false;for(auto raw:course.GetNamedArray(L"records"))if(raw.GetObject().GetNamedString(L"key")==r.GetNamedString(L"key"))exists=true;if(!exists)course.GetNamedArray(L"records").Append(r);}
          Diagnostic(root,L"trigger",S_OK,r.GetNamedString(L"key").c_str());
        }
        root.SetNamedValue(L"deadlineSessions",deadlines);root.SetNamedValue(L"pending",retained);if(OrbitVisible(root,true))ConfirmDeadlines(root);
        if(course.HasKey(L"phase")){Advance(course);root.SetNamedValue(L"session",course);sessions.push_back(course);}for(auto raw:deadlines)sessions.push_back(raw.GetObject());
        for(auto session:sessions){if(Active(session))active=true;else if(session.GetNamedString(L"phase",L"")==L"unconfirmed"&&finalReported.insert(session.GetNamedString(L"id").c_str()).second)for(auto raw:session.GetNamedArray(L"records"))finals.push_back(raw.GetObject());}
        auto earliest=Earliest(retained);if(!active&&earliest>0&&earliest<=Now()+1500)active=true;
        if(!active){auto hr=ScheduleWorker(earliest);Diagnostic(root,L"task",hr);if(FAILED(hr)){Write(root);throw winrt::hresult_error(hr);}}
        for(auto entry:root.GetNamedArray(L"reposts",JsonArray())){auto id=static_cast<int>(entry.GetNumber());shown.erase(id);retries.erase(id);}if(root.HasKey(L"reposts"))root.Remove(L"reposts");if(before!=root.Stringify())Write(root);
      }
      JsonObject sound;for(auto session:sessions)if(Ringing(session)&&session.GetNamedObject(L"settings").GetNamedBoolean(L"soundEnabled",true)){sound=session;break;}
      std::wstring soundKey;std::wstring recordKey;
      if(sound.HasKey(L"records")){recordKey=sound.GetNamedArray(L"records").GetObjectAt(0).GetNamedString(L"key").c_str();soundKey=std::wstring(sound.GetNamedString(L"id").c_str())+L":"+std::to_wstring(N(sound,L"round"));}
      if(testStatePath.empty())SetReminderAudioActive(std::any_of(sessions.begin(),sessions.end(),[](JsonObject session){return Ringing(session);}));
      if(soundKey!=previousSound){player.Stop();fallback=false;waveFallback=false;reportedPlaying=false;
        if(!soundKey.empty()){auto settings=sound.GetNamedObject(L"settings");auto configured=settings.GetNamedObject(L"sound",JsonObject());auto path=configured.GetNamedString(L"kind",L"system")==L"file"?std::wstring(configured.GetNamedString(L"value").c_str()):SystemReminderSound(static_cast<int>(N(settings,L"windowsSound",1)));
          auto hr=failAudio?E_FAIL:player.Start(path,true);if(FAILED(hr)){Report(L"audioFallback",hr,recordKey);fallback=true;hr=failAudio?E_FAIL:player.Start(SystemReminderSound(static_cast<int>(N(settings,L"windowsSound",1))),true);}if(FAILED(hr))Report(L"audio",hr,recordKey);
        }previousSound=soundKey;
      }
      player.Tick();if(!soundKey.empty()&&FAILED(player.Error())&&!fallback){Report(L"audioFallback",player.Error(),recordKey);fallback=true;auto hr=player.Start(SystemReminderSound(static_cast<int>(N(sound.GetNamedObject(L"settings"),L"windowsSound",1))),true);if(FAILED(hr))Report(L"audio",hr,recordKey);}
      if(!soundKey.empty()&&fallback&&FAILED(player.Error())&&!waveFallback&&!failAudio){waveFallback=true;Report(L"audioFallback",player.Error(),recordKey);player.StartWave(SystemReminderSound(static_cast<int>(N(sound.GetNamedObject(L"settings"),L"windowsSound",1))),true);}
      if(!soundKey.empty()&&FAILED(player.Error()))Report(L"audio",player.Error(),recordKey);
      if(!soundKey.empty()&&player.Playing()&&!reportedPlaying){Report(L"audio",S_OK,recordKey);reportedPlaying=true;}
      std::map<int,JsonObject> records;for(auto session:sessions)if(Active(session))for(auto raw:session.GetNamedArray(L"records")){auto r=raw.GetObject();records.emplace(static_cast<int>(N(r,L"notificationId")),r);}
      for(auto it=shown.begin();it!=shown.end();){if(!records.count(it->first)){try{if(notifier)notifier.Hide(it->second);}catch(...) {}retries.erase(it->first);it=shown.erase(it);}else ++it;}
      for(auto& item:records){auto id=item.first;if(shown.count(id)||retries[id]>Now())continue;auto r=item.second;auto key=std::wstring(r.GetNamedString(L"key").c_str());
        try{if(failToast)throw winrt::hresult_error(E_FAIL);if(!notifier)notifier=ToastNotificationManager::CreateToastNotifier(appId);if(notifier.Setting()!=NotificationSetting::Enabled)throw winrt::hresult_error(E_ACCESSDENIED);
          auto xml=winrt::to_string(r.GetNamedString(L"xml"));auto from=xml.find("<audio ");auto end=xml.find("/>",from);if(from!=std::string::npos&&end!=std::string::npos)xml.replace(from,end+2-from,"<audio silent=\"true\"/>");
          winrt::Windows::Data::Xml::Dom::XmlDocument document;document.LoadXml(winrt::to_hstring(xml));ToastNotification toast(document);toast.Tag(winrt::to_hstring(std::to_string(id)));toast.Group(L"orbit_strong");
          toast.Failed([key](const auto&,const ToastFailedEventArgs& args){Report(L"toast",args.ErrorCode(),key);});
          toast.Dismissed([id](const auto&,const ToastDismissedEventArgs& args){if(args.Reason()!=ToastDismissalReason::UserCanceled)return;std::thread([id](){std::this_thread::sleep_for(std::chrono::seconds(2));try{Lock lock;auto root=Read();std::vector<JsonObject> states{root.GetNamedObject(L"session",JsonObject())};for(auto raw:DeadlineSessions(root))states.push_back(raw.GetObject());bool exists=false;for(auto state:states)if(Active(state))for(auto raw:state.GetNamedArray(L"records",JsonArray()))if(N(raw.GetObject(),L"notificationId")==id)exists=true;if(exists){auto reposts=root.GetNamedArray(L"reposts",JsonArray());reposts.Append(Num(id));root.SetNamedValue(L"reposts",reposts);Write(root);}}catch(...) {}}).detach();});
          notifier.Show(toast);shown.emplace(id,toast);Report(L"toastSubmitted",S_OK,key);
        }catch(const winrt::hresult_error& error){Report(L"toast",error.code(),key);retries[id]=Now()+2000;}catch(...){Report(L"toast",E_FAIL,key);retries[id]=Now()+2000;}
      }
      // A successful Show only accepts the request. Confirm delivery through Windows history.
      try{if(notifier)for(auto delivered:ToastNotificationManager::History().GetHistory(appId))if(delivered.Group()==L"orbit_strong"){
        auto id=std::stoi(winrt::to_string(delivered.Tag()));if(shown.count(id)&&records.count(id))Report(L"toast",S_OK,records.at(id).GetNamedString(L"key").c_str());
      }}catch(...) {}
      for(auto r:finals){try{if(!notifier)continue;auto xml=winrt::to_string(r.GetNamedString(L"xml"));auto from=xml.find("<audio ");auto end=xml.find("/>",from);if(from!=std::string::npos&&end!=std::string::npos)xml.replace(from,end+2-from,"<audio silent=\"true\"/>");auto guide=xml.find("</binding>");if(guide!=std::string::npos)xml.insert(guide,"<text>未确认 / Not confirmed</text>");winrt::Windows::Data::Xml::Dom::XmlDocument doc;doc.LoadXml(winrt::to_hstring(xml));ToastNotification toast(doc);toast.Tag(winrt::to_hstring(std::to_string(N(r,L"notificationId"))));toast.Group(L"orbit_strong");notifier.Show(toast);}catch(...) {}}
      if(!active)break;std::this_thread::sleep_for(std::chrono::milliseconds(100));
    }
  }catch(const winrt::hresult_error& error){Report(L"workerExit",error.code());exitCode=1;}catch(...){Report(L"workerExit",E_FAIL);exitCode=1;}
  player.Stop();if(testStatePath.empty())SetReminderAudioActive(false);for(auto& item:shown){try{if(notifier)notifier.Hide(item.second);}catch(...) {}}
  }ReleaseMutex(worker);CloseHandle(worker);CoUninitialize();return exitCode;
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
    for(auto count:{1LL,2LL,10LL})for(bool sequence:{false,true}){
      testClock=100000;JsonObject r,settings;settings.SetNamedValue(L"arithmeticRounds",Num(count));settings.SetNamedValue(L"sequenceRounds",Num(count));Put(settings,L"dismissTask",sequence?L"sequence":L"arithmetic");r.SetNamedValue(L"strong",settings);r.SetNamedValue(L"fireAtMillis",Num(testClock));Put(r,L"key",L"round-test");auto task=NewSession(r);check(task.GetNamedArray(L"tasks").Size()==count);OpenSession(task);BeginSession(task);
      auto total=sequence?count*6:count;
      for(long long step=0;step<total;step++){
        int expected=static_cast<int>(step%6+1);if(!sequence){auto q=task.GetNamedArray(L"questions").GetObjectAt(static_cast<uint32_t>(step));expected=static_cast<int>(ArithmeticAnswer(q));}
        AnswerSession(task,expected+100);check(N(task,L"progress")==step);check(task.GetNamedString(L"phase")==L"task");AnswerSession(task,expected);check(N(task,L"progress")==step+1);check(task.GetNamedString(L"phase")==((step+1==total)?L"completed":L"task"));
      }
    }
    for(auto mode:{L"arithmetic",L"sequence",L"mixed"})for(auto difficulty:{L"simple",L"medium",L"hard"})for(auto answerMode:{L"input",L"choice3",L"choice6"})for(int count:{4,25}) {
      testClock=100000;JsonObject record,config;Put(config,L"dismissTask",mode);Put(config,L"arithmeticDifficulty",difficulty);Put(config,L"arithmeticAnswerMode",answerMode);
      config.SetNamedValue(L"mixedRounds",Num(10));config.SetNamedValue(L"sequenceRounds",Num(10));config.SetNamedValue(L"arithmeticRounds",Num(10));config.SetNamedValue(L"sequenceNumberCount",Num(count));
      record.SetNamedValue(L"strong",config);record.SetNamedValue(L"fireAtMillis",Num(testClock));Put(record,L"key",L"mixed-test");auto task=NewSession(record);OpenSession(task);BeginSession(task);
      auto taskList=task.GetNamedArray(L"tasks");check(taskList.Size()==10);auto stableTasks=taskList.Stringify();auto deadline=N(task,L"answerDeadline");
      for(uint32_t index=0;index<taskList.Size();++index) {
        auto q=taskList.GetObjectAt(index);bool sequence=q.GetNamedString(L"type")==L"sequence";
        if(sequence) {std::set<int> numbers;for(auto raw:q.GetNamedArray(L"numbers"))numbers.insert(static_cast<int>(raw.GetNumber()));check(numbers.size()==static_cast<size_t>(count));check(*numbers.begin()==1&&*numbers.rbegin()==count);}
        else {auto op=q.GetNamedString(L"operator");auto a=N(q,L"a"),b=N(q,L"b");
          if(std::wstring(difficulty)==L"simple")check(op!=L"multiply"&&a>=10&&a<=89&&b>=1&&b<=9);
          else if(std::wstring(difficulty)==L"hard"&&op!=L"multiply")check(a>=100&&a<=999&&b>=100&&b<=999);
          else check(a>=10&&a<=99&&b>= (op==L"multiply"&&std::wstring(difficulty)==L"medium"?2:10)&&b<= (op==L"multiply"&&std::wstring(difficulty)==L"medium"?9:99));
          auto choices=q.GetNamedArray(L"choices");check(choices.Size()==(std::wstring(answerMode)==L"choice3"?3u:std::wstring(answerMode)==L"choice6"?6u:0u));std::set<long long> distinct;for(auto raw:choices)distinct.insert(static_cast<long long>(raw.GetNumber()));check(distinct.size()==choices.Size());if(choices.Size())check(distinct.count(ArithmeticAnswer(q))==1);
        }
        for(int step=1;step<=(sequence?count:1);++step) {
          AnswerSession(task,-1);check(N(task,L"taskIndex")==index);check(task.GetNamedArray(L"tasks").Stringify()==stableTasks);
          AnswerSession(task,sequence?step:static_cast<int>(ArithmeticAnswer(q)));check(N(task,L"answerDeadline")==deadline);
          check(task.GetNamedString(L"phase")==((index+1==taskList.Size()&&step==(sequence?count:1))?L"completed":L"task"));
        }
      }
    }
    testClock=100000;
    JsonObject root,r,settings;settings.SetNamedValue(L"durationSeconds",Num(30));r.SetNamedValue(L"strong",settings);r.SetNamedValue(L"fireAtMillis",Num(testClock));r.SetNamedValue(L"leadMinutes",Num(60));Put(r,L"key",L"ddl-key");Put(r,L"deadlineId",L"ddl");Put(r,L"acknowledgementMode",L"openApp");
    auto ddl=NewDeadlineSession(r);check(!ddl.HasKey(L"questions")&&!ddl.HasKey(L"tasks"));check(DeadlineRecord(r));check(Ringing(ddl));
    auto course=fresh();OpenSession(course);BeginSession(course);root.SetNamedValue(L"session",course);JsonArray sessions;sessions.Append(ddl);root.SetNamedValue(L"deadlineSessions",sessions);
    auto courseBefore=course.Stringify();auto expiry=N(ddl,L"expiresAt");
    testClock=130000;AdvanceDeadline(ddl);check(!Ringing(ddl));check(N(ddl,L"round")==1);
    testClock=145000;AdvanceDeadline(ddl);check(Ringing(ddl));check(N(ddl,L"round")==2);check(N(ddl,L"expiresAt")==expiry);
    ConfirmDeadlines(root,false);check(!Active(ddl));check(root.GetNamedArray(L"deadlineEvents").Size()==1);check(course.Stringify()==courseBefore);
    ConfirmDeadlines(root,false);check(root.GetNamedArray(L"deadlineEvents").Size()==1);
    testClock=190000;auto another=NewDeadlineSession(r);AdvanceDeadline(another);check(N(another,L"round")==3);check(N(another,L"expiresAt")==expiry);
    testClock=220000;AdvanceDeadline(another);check(!Active(another));check(another.GetNamedString(L"phase")==L"unconfirmed");Put(another,L"phase",L"cancelled");testClock=110000;check(!Active(another));
    testClock=100000;s=fresh();Put(s,L"phase",L"completed");testClock=500000;Advance(s);check(s.GetNamedString(L"phase")==L"completed");OpenSession(s);check(!s.GetNamedBoolean(L"opened",false));
  }catch(...){result=1;}
  testClock=-1;CoUninitialize();return result;
}

void SetStrongReminderTestState(const std::wstring& path){testStatePath=path;}
int RunStrongReminderOSSelfTest(const std::wstring& path){
  CoInitializeEx(nullptr,COINIT_MULTITHREADED);testStatePath=path;testSchedule=path.find(L"scheduled")!=std::wstring::npos;int result=1;
  bool failToast=path.find(L"notify-failure")!=std::wstring::npos;bool failAudio=path.find(L"audio-failure")!=std::wstring::npos;bool missingAudio=path.find(L"missing-audio")!=std::wstring::npos;
  try{
    JsonObject root;root.SetNamedValue(L"pending",JsonArray());root.SetNamedValue(L"failToast",JsonValue::CreateBooleanValue(failToast));root.SetNamedValue(L"failAudio",JsonValue::CreateBooleanValue(failAudio));Write(root);
    JsonObject record,settings,sound;settings.SetNamedValue(L"durationSeconds",Num(5));settings.SetNamedValue(L"soundEnabled",JsonValue::CreateBooleanValue(true));
    if(missingAudio){Put(sound,L"kind",L"file");Put(sound,L"value",(path+L".missing.wav").c_str());settings.SetNamedValue(L"sound",sound);}
    record.SetNamedValue(L"strong",settings);record.SetNamedValue(L"fireAtMillis",Num(Now()+(testSchedule?3000:500)));record.SetNamedValue(L"notificationId",Num(1999991));record.SetNamedValue(L"alarmId",Num(1999991));
    Put(record,L"key",path.c_str());Put(record,L"payload",L"test_strong_reminder");
    Put(record,L"xml",L"<toast><visual><binding template=\"ToastGeneric\"><text>Orbit</text><text>Windows strong reminder self-test</text></binding></visual><audio silent=\"true\"/></toast>");
    StrongCommand("scheduleStrong",winrt::to_string(record.Stringify()));auto until=Now()+12000;
    while(Now()<until){auto diagnostics=JsonObject::Parse(winrt::to_hstring(StrongCommand("strongDiagnostics")));auto audio=diagnostics.GetNamedObject(L"audio",JsonObject());auto toast=diagnostics.GetNamedObject(L"toast",JsonObject());bool delivered=false;
      if(!failToast)try{for(auto notification:ToastNotificationManager::History().GetHistory(appId))if(notification.Tag()==L"1999991"&&notification.Group()==L"orbit_strong")delivered=true;}catch(...) {}
      if((failAudio?audio.HasKey(L"hr")&&!audio.GetNamedBoolean(L"ok",true):audio.GetNamedBoolean(L"ok",false))&&(failToast?toast.HasKey(L"hr")&&!toast.GetNamedBoolean(L"ok",true):toast.GetNamedBoolean(L"ok",false)&&delivered)&&(!missingAudio||diagnostics.HasKey(L"audioFallback"))){result=0;break;}
      std::this_thread::sleep_for(std::chrono::milliseconds(100));
    }
    StrongCommand("stopStrongTests");for(int i=0;i<30;++i){auto diagnostics=JsonObject::Parse(winrt::to_hstring(StrongCommand("strongDiagnostics")));if(!diagnostics.GetNamedBoolean(L"workerAlive",false))break;std::this_thread::sleep_for(std::chrono::milliseconds(100));}
    auto finished=Read();auto output=winrt::to_string(finished.Stringify());std::ofstream file(path+L".result.json",std::ios::binary|std::ios::trunc);file<<output;
  }catch(...){try{StrongCommand("stopStrongTests");}catch(...) {}}
  if(testSchedule)ScheduleWorker(0);testSchedule=false;testStatePath.clear();CoUninitialize();return result;
}
