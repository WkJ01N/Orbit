#include "reminder_audio.h"
#include <mfapi.h>
#include <mferror.h>
#include <mfidl.h>
#include <mfreadwrite.h>
#include <mfmediaengine.h>
#include <mmsystem.h>
#include <wrl.h>
#include <comdef.h>
#include <atomic>
#include <algorithm>
#include <cwctype>
#include <chrono>
#include <filesystem>
#include <future>
#include <mutex>
#include <thread>
using Microsoft::WRL::ComPtr;
using namespace winrt::Windows::Data::Json;
namespace {
using Clock=std::chrono::steady_clock;
struct AudioEvents : Microsoft::WRL::RuntimeClass<Microsoft::WRL::RuntimeClassFlags<Microsoft::WRL::ClassicCom>,IMFMediaEngineNotify> {
  std::atomic<bool> ready{false},playing{false};
  std::atomic<HRESULT> error{S_OK};
  HRESULT STDMETHODCALLTYPE EventNotify(DWORD event,DWORD_PTR first,DWORD second) override {
    if(event==MF_MEDIA_ENGINE_EVENT_CANPLAY)ready=true;
    if(event==MF_MEDIA_ENGINE_EVENT_PLAYING)playing=true;
    if(event==MF_MEDIA_ENGINE_EVENT_PAUSE||event==MF_MEDIA_ENGINE_EVENT_ENDED)playing=false;
    if(event==MF_MEDIA_ENGINE_EVENT_ERROR){error=second?static_cast<HRESULT>(second):E_FAIL;playing=false;}
    (void)first;return S_OK;
  }
};
bool StrongAudioActive(){auto event=OpenEventW(SYNCHRONIZE,FALSE,L"Local\\OrbitStrongAudioActive");if(!event)return false;bool active=WaitForSingleObject(event,0)==WAIT_OBJECT_0;CloseHandle(event);return active;}
struct PreviewState {
  std::mutex mutex;
  std::atomic<unsigned> generation{0};
  std::thread thread;
  ~PreviewState(){++generation;if(thread.joinable())thread.join();}
};
PreviewState preview;
}
struct ReminderAudioPlayer::Impl {
  ComPtr<IMFMediaEngine> engine;
  ComPtr<AudioEvents> events;
  bool started=false,mf=false,wave=false,heard=false;
  HRESULT failure=S_OK;
  Clock::time_point began;
};
ReminderAudioPlayer::ReminderAudioPlayer():impl_(std::make_unique<Impl>()){}
ReminderAudioPlayer::~ReminderAudioPlayer(){Stop();}
void ReminderAudioPlayer::Stop(){
  if(impl_->engine){impl_->engine->Pause();impl_->engine->Shutdown();impl_->engine.Reset();}
  impl_->events.Reset();if(impl_->wave)PlaySoundW(nullptr,nullptr,0);impl_->wave=false;
  if(impl_->mf){MFShutdown();impl_->mf=false;}impl_->started=false;impl_->heard=false;impl_->failure=S_OK;
}
HRESULT ReminderAudioPlayer::Start(const std::wstring& path,bool loop){
  Stop();impl_->began=Clock::now();
  if(!std::filesystem::is_regular_file(path))return impl_->failure=HRESULT_FROM_WIN32(ERROR_FILE_NOT_FOUND);
  HRESULT hr=MFStartup(MF_VERSION);impl_->mf=SUCCEEDED(hr);
  ComPtr<IMFMediaEngineClassFactory> factory;ComPtr<IMFAttributes> attributes;
  if(SUCCEEDED(hr))hr=CoCreateInstance(CLSID_MFMediaEngineClassFactory,nullptr,CLSCTX_INPROC_SERVER,IID_PPV_ARGS(&factory));
  impl_->events=Microsoft::WRL::Make<AudioEvents>();
  if(SUCCEEDED(hr))hr=MFCreateAttributes(&attributes,1);
  if(SUCCEEDED(hr))hr=attributes->SetUnknown(MF_MEDIA_ENGINE_CALLBACK,impl_->events.Get());
  if(SUCCEEDED(hr))hr=factory->CreateInstance(MF_MEDIA_ENGINE_AUDIOONLY,attributes.Get(),&impl_->engine);
  if(SUCCEEDED(hr))hr=impl_->engine->SetLoop(loop?TRUE:FALSE);
  if(SUCCEEDED(hr))hr=impl_->engine->SetSource(_bstr_t(path.c_str()));
  if(SUCCEEDED(hr))hr=impl_->engine->Load();
  if(FAILED(hr)) {
    Stop();auto extension=std::filesystem::path(path).extension().wstring();std::transform(extension.begin(),extension.end(),extension.begin(),[](wchar_t c){return static_cast<wchar_t>(std::towlower(c));});
    if(extension==L".wav" && PlaySoundW(path.c_str(),nullptr,SND_FILENAME|SND_ASYNC|SND_NODEFAULT|(loop?SND_LOOP:0))){impl_->wave=true;return S_OK;}
    impl_->failure=hr;
  }
  return hr;
}
HRESULT ReminderAudioPlayer::StartWave(const std::wstring& path,bool loop){
  Stop();if(!std::filesystem::is_regular_file(path))return impl_->failure=HRESULT_FROM_WIN32(ERROR_FILE_NOT_FOUND);
  if(PlaySoundW(path.c_str(),nullptr,SND_FILENAME|SND_ASYNC|SND_NODEFAULT|(loop?SND_LOOP:0))){impl_->wave=true;return S_OK;}
  return impl_->failure=E_FAIL;
}
void ReminderAudioPlayer::Tick(){
  if(!impl_->engine)return;
  auto error=impl_->events->error.load();if(FAILED(error)){impl_->failure=error;return;}
  if(!impl_->started&&impl_->events->ready){impl_->failure=impl_->engine->Play();impl_->started=SUCCEEDED(impl_->failure);}
  if(Playing())impl_->heard=true;
  if(!impl_->heard&&Clock::now()-impl_->began>std::chrono::seconds(5))impl_->failure=HRESULT_FROM_WIN32(ERROR_TIMEOUT);
}
bool ReminderAudioPlayer::Playing() const{return impl_->wave||(impl_->events&&impl_->events->playing);}
HRESULT ReminderAudioPlayer::Error() const{return impl_->failure;}
std::wstring SystemReminderSound(int number){wchar_t root[MAX_PATH];GetWindowsDirectoryW(root,MAX_PATH);wchar_t file[32];swprintf_s(file,L"\\Media\\Alarm%02d.wav",std::clamp(number,1,10));auto path=std::wstring(root)+file;
  if(!std::filesystem::is_regular_file(path))path=std::wstring(root)+L"\\Media\\Windows Notify System Generic.wav";return path;
}
HRESULT ValidateReminderAudio(const std::wstring& path){
  if(!std::filesystem::is_regular_file(path))return HRESULT_FROM_WIN32(ERROR_FILE_NOT_FOUND);
  auto size=std::filesystem::file_size(path);if(size==0||size>5*1024*1024)return E_INVALIDARG;
  HRESULT hr=MFStartup(MF_VERSION);if(FAILED(hr))return hr;
  ComPtr<IMFSourceReader> reader;ComPtr<IMFMediaType> type;
  hr=MFCreateSourceReaderFromURL(path.c_str(),nullptr,&reader);
  if(SUCCEEDED(hr))hr=reader->SetStreamSelection(static_cast<DWORD>(MF_SOURCE_READER_ALL_STREAMS),FALSE);
  if(SUCCEEDED(hr))hr=reader->SetStreamSelection(static_cast<DWORD>(MF_SOURCE_READER_FIRST_AUDIO_STREAM),TRUE);
  if(SUCCEEDED(hr))hr=MFCreateMediaType(&type);
  if(SUCCEEDED(hr))hr=type->SetGUID(MF_MT_MAJOR_TYPE,MFMediaType_Audio);
  if(SUCCEEDED(hr))hr=type->SetGUID(MF_MT_SUBTYPE,MFAudioFormat_PCM);
  if(SUCCEEDED(hr))hr=reader->SetCurrentMediaType(static_cast<DWORD>(MF_SOURCE_READER_FIRST_AUDIO_STREAM),nullptr,type.Get());
  bool decoded=false;
  for(int attempt=0;SUCCEEDED(hr)&&!decoded&&attempt<64;++attempt){DWORD stream=0,flags=0;LONGLONG at=0;ComPtr<IMFSample> sample;hr=reader->ReadSample(static_cast<DWORD>(MF_SOURCE_READER_FIRST_AUDIO_STREAM),0,&stream,&flags,&at,&sample);decoded=sample!=nullptr;if(flags&MF_SOURCE_READERF_ENDOFSTREAM)break;}
  reader.Reset();type.Reset();MFShutdown();return FAILED(hr)?hr:decoded?S_OK:MF_E_INVALIDMEDIATYPE;
}
void StopReminderPreview(){std::lock_guard<std::mutex> guard(preview.mutex);++preview.generation;if(preview.thread.joinable())preview.thread.join();}
HRESULT PreviewReminderAudio(JsonObject settings){
  StopReminderPreview();if(StrongAudioActive())return HRESULT_FROM_WIN32(ERROR_BUSY);
  auto sound=settings.GetNamedObject(L"sound",settings);auto path=sound.GetNamedString(L"kind",L"system")==L"file"?std::wstring(sound.GetNamedString(L"value").c_str()):SystemReminderSound(static_cast<int>(settings.GetNamedNumber(L"windowsSound",1)));
  auto valid=ValidateReminderAudio(path);if(FAILED(valid))return valid;
  std::lock_guard<std::mutex> guard(preview.mutex);auto generation=++preview.generation;
  auto result=std::make_shared<std::promise<HRESULT>>();auto future=result->get_future();
  preview.thread=std::thread([path,generation,result](){
    CoInitializeEx(nullptr,COINIT_MULTITHREADED);HRESULT hr=S_OK;
    {ReminderAudioPlayer player;hr=player.Start(path,false);bool reported=false;auto until=Clock::now()+std::chrono::seconds(10);
      while(SUCCEEDED(hr)&&Clock::now()<until&&preview.generation==generation&&!StrongAudioActive()){
        player.Tick();hr=player.Error();if(!reported&&player.Playing()){result->set_value(S_OK);reported=true;}
        std::this_thread::sleep_for(std::chrono::milliseconds(20));
      }
      if(!reported)result->set_value(FAILED(hr)?hr:E_ABORT);
    }CoUninitialize();
  });
  if(future.wait_for(std::chrono::seconds(6))!=std::future_status::ready){++preview.generation;return HRESULT_FROM_WIN32(ERROR_TIMEOUT);}return future.get();
}
void SetReminderAudioActive(bool active){static HANDLE event=CreateEventW(nullptr,TRUE,FALSE,L"Local\\OrbitStrongAudioActive");if(event){if(active)SetEvent(event);else ResetEvent(event);}}
int RunReminderAudioSelfTest(const std::wstring& path){CoInitializeEx(nullptr,COINIT_MULTITHREADED);int result=1;auto valid=ValidateReminderAudio(path);if(SUCCEEDED(valid)){ReminderAudioPlayer player;if(SUCCEEDED(player.Start(path,true))){auto until=Clock::now()+std::chrono::seconds(3);while(Clock::now()<until){player.Tick();if(player.Playing()){result=0;break;}if(FAILED(player.Error()))break;std::this_thread::sleep_for(std::chrono::milliseconds(20));}player.Stop();if(player.Playing())result=1;}}CoUninitialize();return result;}
