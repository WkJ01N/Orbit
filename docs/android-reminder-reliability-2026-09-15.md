# Android 后台提醒修复与验证

日期：2026-09-15。版本保持 1.4.0+15；未安装、未发布。

## 已确认的代码问题

对照 1.3.2（`be32e96`）与 1.4.0（`873d3c1`），原生 AlarmManager、独立 `:reminders` 进程及延迟退出机制仍然存在，提醒没有退回依赖后台 Flutter 启动。

1. 1.4.0 将恢复和维护改成异步工作，但旧退出回调只检查强提醒布尔状态。另一条广播完成后，250 毫秒的退出回调可能杀掉仍在恢复排程的进程。多条强提醒启动请求也会被一个布尔值合并，首条服务命令能过早清除后续请求的保护。
2. 新增的数据库路径、通知文案和运行状态通过 SharedPreferences 在两个进程间共享。`MODE_MULTI_PROCESS` 无法可靠同步缓存和并发写入；主界面与后台可能读取不同配置。
3. 原接收器在通知发布前提交规则的 processed_index，并在 finally 中无条件删除原生记录。发布异常、通知权限关闭或去重数据库不可用时，提醒可能丢失，后续恢复又将其视为已处理。

后续已连接 iQOO V2408A／OriginOS 真机。`dumpsys activity exit-info` 记录到最近任务清理器以 `USER REQUESTED / FORCE STOP` 停止 Orbit，描述包含 `single-cleaner`，同时系统闹钟记录显示 Orbit 的精确闹钟被取消。Android 不会向处于强制停止状态的应用发送闹钟或广播，因此应用内代码无法绕过这一系统状态。

当前版本会持久化计划、接收、发布和失败阶段，在下次打开时读取系统退出原因并明确显示强制停止；设置页提供 OriginOS 自启动、后台高耗电、电池限制和最近任务锁定指引。用户还可开启增强提醒模式，在存在未来提醒时由独立 `:guard` 进程显示低打扰常驻通知，以降低普通进程清理造成的失效。增强模式仍不能绕过真正的强制停止。

## 修复行为

- 统一跟踪广播、异步恢复任务、服务启动请求和服务实例。新任务取消待执行的退出；全部任务结束后才保留原来的 250 毫秒退出策略，并核对当前进程确为 `:reminders`。停止服务时清理被取消的启动请求。
- 后台配置和错误状态存入现有原生 SQLite metadata 表。旧配置事务迁移一次，保留旧偏好数据供历史版本使用；之后读写不依赖跨进程偏好缓存。Flutter 的 `configureDatabase` 和 `runtimeStatus` 接口保持原样。
- 通知发布成功才提交发送序号；数据库事务串行化规则投递、去重与已知晓动作。失败保留原生记录和未处理序号，重试从 1 分钟开始，退避至最长 16 分钟；超过 24 小时停止重试。权限关闭时等待后台维护或前台恢复，不持续唤醒重试。
- 失败记录不会被普通过期清理删掉，恢复时使用新的重试时间，避免被原计划时间覆盖。非持久化的一分钟诊断提醒继续不跨恢复保留。
- 强提醒服务启动／进入前台失败时降级普通通知。异步降级失败时保留普通通知重试，允许替换已提交的强提醒通知，仍然尊重已知晓状态。重复强提醒不延长原有超时。
- 原生日志标签为 `OrbitReminders`，记录排程、广播、通知、去重、补排、重试、服务和退出阶段。只包含进程号、闹钟 ID、固定阶段／原因及异常类型，不记录课程名称、正文、payload 或异常消息。失败状态保存在 SQLite，读取状态不会清除错误。

## 自动验证

- 提醒相关 Flutter 测试：35 项通过。
- Android 原生 Robolectric 测试（API 32）：25 项通过，包含 17 项新增场景。
- `flutter analyze`：通过，无问题。
- Android 调试构建与 Flutter 标准入口正式签名构建：通过。
- 最终 APK 签名验证：通过，与 `release/v1.4.0/orbit-v1.4.0-android.apk` 的证书 SHA-256 一致；包内版本为 1.4.0、versionCode 15，原生接收器与强提醒服务仍位于 `:reminders` 进程。
- 原生测试覆盖配置迁移及旧记录兼容、独立数据库连接读取最新配置、异步任务／连续广播／启动取消与退出竞争、发布失败后的事务回滚和恢复、权限恢复、过期重试清理、两种服务启动失败、降级重试、已知晓及强提醒超时。

主验证命令：

```powershell
flutter test test/reminder_scheduler_test.dart test/custom_reminder_test.dart test/reminder_resync_status_test.dart test/notification_template_test.dart
flutter analyze
flutter build apk --debug
cd android
./gradlew.bat :app:testDebugUnitTest --console=plain
cd ..
flutter build apk --release
```

构建日志：`build/orbit-reminder-flutter-release.log`。正式 APK：`build/app/outputs/flutter-apk/app-release.apk`。直接调用 Gradle 同时组装 debug 和 release 时，曾因旧的生成插件注册文件包含 integration_test 引用而失败；通过 Flutter 标准入口重新生成注册文件，未修改导入功能或依赖配置。

## 真机验收步骤（待执行）

1. 在同一台 iQOO／OriginOS 设备记录型号、Android／系统版本、自启动、电池策略、通知权限和精确闹钟权限。分别用 1.3.2、原 1.4.0、本次修复包测试相同课表和权限；跨版本数据对照应使用独立测试数据，不能把包含 v5 数据的数据库直接交给旧版本使用。
2. 先保持后台验证提醒，再上划最近任务。上划前、上划后、到点前后分别保存系统闹钟、应用停止状态、进程状态和原生日志。不要用 `am force-stop` 模拟上划。
3. 分别验证一分钟诊断、课前、打卡、次日摘要、自定义连续提醒与强提醒；覆盖上划后锁屏、至少三次连续投递、已知晓取消当前规则后续发送、停止强提醒不取消后续课程，以及重复投递不延长铃声时间。
4. 验证重启和同签名覆盖升级后的恢复。测试系统真正强行停止时，单独记录系统取消应用闹钟的行为，再打开应用确认重新排程。
5. 若 `schedule_exact` 后系统闹钟在上划时消失且没有 `receive`，继续定位系统清理／停止状态；若闹钟保留但没有 `receive`，检查系统投递和进程冻结；若有 `receive` 无 `post`，根据错误阶段检查存储、去重或通知权限。

可使用以下只读诊断命令（将 adb 替换为本机 SDK 中的实际路径）：

```powershell
adb devices -l
adb shell getprop ro.product.model
adb shell getprop ro.build.version.release
adb shell getprop ro.build.version.sdk
adb shell dumpsys package com.must.orbit.orbit
adb shell dumpsys alarm
adb shell ps -A
adb logcat -d -v threadtime -s OrbitReminders ActivityManager AlarmManager
```

验收条件：正常权限与同样系统策略下，上划后无需打开应用也能收到提醒；连续提醒不漏发、不重复，通知动作正常。调试包使用调试签名；覆盖正式安装应使用本机现有正式签名构建的 APK，并核对设备安装证书一致。本次 APK 来自当前工作区，包含此前尚未提交的导入等改动，未将这些改动回退或拆出。
