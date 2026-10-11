# Windows 强提醒：播放、通知与验收

课程提醒在前台也先播放音频、发送静音通知。点击通知、“打开并答题”入口或重新打开窗口后，原生会话增加 `openRequest`，暂时静音并进入答题。Flutter 轮询只读取会话，不再自动发出打开请求；关闭答题页后，同一个打开请求不会重新弹出页面。DDL 仍在前台自动确认，后台触发后打开应用确认，不改变完成状态。

音频由独立的 Windows 提醒进程使用 Media Foundation 播放，不依赖通知声音。导入 MP3、M4A、WAV 后先复制到应用音频目录，再原生解码校验；单文件上限 5 MiB，失败删除暂存文件并保留原选择。设置保存原有音频字段，继续兼容十种系统音；成功导入会开启声音。试听最多十秒，可主动停止，离开页面停止；正式响铃优先并停止试听。

每个响铃阶段循环播放，阶段结束或确认、取消、紧急停止后停止。缺失文件或播放失败回退系统音；媒体引擎失效时可使用 WinMM 播放系统 WAV。课程声音优先于 DDL，各实例的固定期限不变。通知注册、投递与音频相互独立；通知失败不结束会话或音频。划掉通知后，活动提醒重新投递。

计划任务使用当前用户 SID 和交互式登录令牌，允许后台唤起独立进程。工作进程异常返回失败状态，任务设置一分钟后重试一次。即时提醒直接交接工作进程。注册和启动失败传回客户端；设置查询真实通知状态，禁用通知时保留音频并提供系统设置入口。

调试页面可查看计划任务、通知注册、工作进程、触发、通知投递和音频播放结果。即时调试需等待对应提醒实例的触发、真实播放事件与 Windows 通知历史回执；其他并发提醒的回执不算本次成功。最近回执按实例保存，防止并发提醒替换全局状态造成误判。

## 可重复的原生测试

构建后的 `orbit.exe` 提供以下自测入口，返回 0 表示通过：

```powershell
# 强提醒状态机：轮数、题目、固定期限、三次响铃、独立 DDL 确认
orbit.exe --strong-self-test

# 指定音频的原生解码、实际开始播放和停止
orbit.exe --audio-self-test "C:\path\中文 audio.mp3"

# 使用独立 JSON 状态文件，避免修改实际课程、DDL 和统计
orbit.exe --strong-os-self-test "E:\Multiplatform\Orbit\build\windows-reminder-selftest\normal.json"
orbit.exe --strong-os-self-test "E:\Multiplatform\Orbit\build\windows-reminder-selftest\scheduled.json"
orbit.exe --strong-os-self-test "E:\Multiplatform\Orbit\build\windows-reminder-selftest\notify-failure.json"
orbit.exe --strong-os-self-test "E:\Multiplatform\Orbit\build\windows-reminder-selftest\audio-failure.json"
orbit.exe --strong-os-self-test "E:\Multiplatform\Orbit\build\windows-reminder-selftest\missing-audio.json"
```

先创建输出目录。文件名选择场景：`scheduled` 注册实际独立测试任务，由系统任务调度器启动工作进程；失败场景仅在隔离测试状态中注入。测试通知使用独立编号，结束后停止测试会话、清理测试通知及计划任务，并写出 `.result.json` 供检查。测试会短时播放声音。测试过程中不要并行执行多个原生测试。

已验证实际 Windows 通知历史、播放器开始播放与停止、独立计划任务触发，以及通知失败继续播放、播放器失败仍发送通知、文件缺失回退系统音。MP3、M4A、WAV 均使用包含中文和空格的文件名通过原生播放测试。

## 尚需设备交互验收

自动化已覆盖显式打开答题、关闭后不自动重开、试听停止、导入解码失败清理、4–25 个数字末行居中与位置稳定、三语及大字体课程按钮。仍需 Android 真机检查实际声音、振动和锁屏，以及 Windows 的通知点击、托盘恢复、最小化、退出软件、系统通知被禁用和并发课程／DDL 的完整人工交互流程。原生回执证明操作系统链路成功，不代表已人工确认每个设备场景的听感和交互。

本次 1.5.5+27 发布：Flutter 648 项通过，1 项需显式启用的系统通知测试跳过；Android 原生 45 项、云端 32 项通过。APK 签名与此前发布证书一致；Windows 项目未配置 Authenticode 签名。更新清单、SHA-256 和 Windows ZIP 的 24 个文件均与最终构建匹配。
