# Orbit 1.4.0 优化验证记录（2026-09-13）

本次在现有工作区修改上实现配色、通知权限、强提醒范围、设置布局和交互优化，保留原有课程、手动颜色、自动颜色身份、自定义规则与备份版本 4。

## 已完成检查

- Flutter 静态检查：无问题。
- 新增 UI／配色／消息回归：19 项通过；视觉基准 8 项通过，包含全部方案的亮暗三色预览。
- 完整 Flutter 测试：307 项通过，默认跳过的 Windows 原生队列测试此前另行启用，1 项通过。
- Android 35 x86_64 模拟器真实应用集成测试：1 项通过，覆盖 100 门变高课程、二级页面警告、忽略确认、实际应用通知设置、权限恢复、可中断反向翻页、列表回顶与消息退出。
- Android 原生测试：8 项通过（自定义提醒 6 项、接收器 2 项），无失败或错误。
- 相关行为回归：独立主题配置及异步保存、三色亮暗对比、调色板稳定身份和删除、默认课程颜色跨页面及恢复默认、规则强度优先级、类型／规则／课程范围、编辑后身份关联、备份规范化、次日汇总与补发、全页面权限提示及忽略二次确认、权限查询失败后的恢复重新排程、窄屏范围编辑、空状态添加、消息退出队列、变高列表滚动基准和可中断翻页。
- 受影响的课表与配色面板视觉基准已更新；复核浅色／深色、窄屏／宽屏课表和窄屏英文强提醒设置。
- Windows 原生队列检查使用独立应用身份 `com.must.orbit.reminder-test`，只排定未来任务、查询并取消，不实际发送通知。
- Android 和 Windows 正式构建均成功；Android 安装包约 60.5 MB，Windows 压缩包包含可执行文件、依赖库及应用资源。

## 安装包

- Android：`release/v1.4.0/orbit-v1.4.0-android.apk`
- Windows x64：`release/v1.4.0/orbit-v1.4.0-windows-x64.zip`，解压后运行 `orbit.exe`。
- `release/v1.4.0/SHA256SUMS.txt` 保存两份安装包的 SHA256；替换后与构建产物逐一核对。

## 兼容与来源

单色沿用原生成逻辑；多色从旧方案及旧种子初始化独立配置。旧强提醒默认全类型、全部继承规则及全部课程，新安装仍默认关闭。通知警告忽略偏好只保存本设备，不导出到备份。新增直接依赖 material_color_utilities，供 HCT 调色交互使用；Flutter SDK 自带 integration_test 用于设备回归，没有数据库迁移。自定义三色使用保持色相的完整角色生成，预设选项保留原标识，改用 Orbit 独立 HCT 三色生成；中性和灰阶保留低饱和特点。新增可选 presetSeed 字段记录进入自定义编辑前的种子，旧配置缺少该字段时沿用原 primary，备份版本不变。

多色颜色网格、生成方案选择、调色对话框、长按删除和重置交互参考 FlClash（GPL-3.0）：https://github.com/chen08209/FlClash/blob/main/lib/views/theme.dart，代码保留来源说明。预览与实际应用复用同一个颜色生成入口。

## 设备验证限制

已在工作区建立独立 Android 35 Google APIs x86_64 模拟器（1080×2400、420 dpi、WHPX 与 SwiftShader），完成真实应用及交互验证，全部测试通过。记录确认“去开启”进入 `Settings$AppNotificationSettingsActivity`，系统返回恢复原 Activity 后自动刷新权限。

此前设备回归测量后台说明距卡片实际表面的顶部和底部均为 16 像素，并检查消息进入、退出中间帧的透明度与全局文字位置，确认动画实际可见且方向正确。随后按要求移除底部设备验证说明及对应多语言文案，顶部说明保留 16 像素内边距，设备测试不再检查已删除说明的底部位置。

模拟器关闭主机声音，因此音频听感、真实震动、不同厂商锁屏／电池策略和长期后台维护仍需真机复测；模拟器调试运行不代表真机帧率。

设备测试使用独立模拟器并写入测试课程，运行控制脚本为 `tool/verify_android_optimizations.ps1`，禁止用于实体设备。它自动准备未授权状态，并在进入通知设置后授予权限、通过系统返回恢复原窗口。

Windows 原生队列检查和正式构建可以覆盖原生链接与系统排程，但实际通知权限开关、主窗口操作、通知声音及长期后台恢复仍需在运行新版本后实测。

## 本轮界面与动画复核

后台顶部说明内边距为顶部 16，底部设备验证说明已移除；窄屏选择项改为下一行，强提醒组卡片消除重复外边距，长标题按实际文字高度换行。调色板网格按 HEX 文字的实际宽高计算列数和高度，颜色操作面板可滚动。

消息使用独立状态外观直接消费 ScaffoldMessenger 的动画，进入 240 毫秒、退出 180 毫秒、位移 16 像素；同一缓动曲线保持提前反向时的位置和透明度连续。测试直接检查实际 Opacity 与全局文字坐标，覆盖所有关闭路径、队列及操作计时。

布局矩阵覆盖 320／360／1100 像素、中英文与 1.6 倍字体；配色验证四种种子、九种方案、两种亮度、角色色相、文字对比、自定义编辑及 JSON 恢复。

## 检查日志

- `build/optimization-analyze.log`
- `build/full-optimization-tests.log`
- `build/regressions-test.log`
- `build/golden-update.log`
- `build/final-theme-regression.log`
- `build/android-native-test.log`
- `build/android-device-optimization-test.log`
- `build/android-device-permission-target.log`
- `build/windows-native-optimization-test.log`
- `build/android-optimization-release.log`
- `build/windows-optimization-release.log`

- `build/ui-fix-analyze.log`
- `build/ui-fix-full-tests.log`
- `build/ui-fix-matrix.log`
- `build/ui-fix-goldens.log`

## Android 消息动画追加修复

消息只依照 disableAnimations 跳过动画，不把 accessibleNavigation 当作减少动画；独立消息宿主保留 ScaffoldMessenger 队列与计时，辅助导航下先绘制退出帧再移除，保留 closed Future 的原因。首条消息在首次近透明绘制后开始动画；根导航观察器等待已弹出的 PopupRoute.completed，避免确认弹窗的结果先返回、遮罩还未退出时动画已在后方播放。

新增 12 项生命周期测试覆盖弹窗遮罩退出等待、普通／辅助导航下的关闭、超时、操作与队列，以及显式减少动画。完整测试 307 项通过、静态检查无问题。

- `build/message-lifecycle.log`
- `build/message-animation-analyze.log`
- `build/message-animation-full-tests.log`

实际删除流程复现到动画从零直接跳到结束：课程刷新使帧间隔增大，原按墙钟推进的动画在下一帧已经结束。消息宿主改为直接推进同一共享动画控制器，每帧最多补进 32 毫秒，进入／退出均受保护；保持正常帧率下 240／180 毫秒时长，卡顿时延长到足够绘制中间帧。新增 500 毫秒帧延迟的进入／退出测试，确保消息不会直接跳过动画。首次绘制透明度为 0.01，避免 0.001 被渲染器取整为零而完全不绘制。

Android 35 模拟器中运行真实应用流程：同步 100 条提醒、删除课次、点击撤销恢复课程，分别采样到 5／4／5 个进入动画中间帧，并验证关闭与撤销时的退出中间帧，全部通过。Android 与 Windows release 构建成功，安装包替换至 `release/v1.4.0`，校验文件同步更新。
