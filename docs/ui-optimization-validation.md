# 界面、配色与课表自适应验证记录

验证日期：2026-09-12。保留已有课程管理、提醒、备份及 Windows 后台修改；本次未新增依赖或数据库迁移，备份保持版本 4。

## 自动检查

- 完整 Flutter 测试：252 项通过。默认跳过的 Windows 原生队列测试已另行启用，1 项通过。
- Android 原生测试：8 项通过（自定义提醒 6 项、接收器 2 项），无失败或错误。
- Dart 静态检查与改动空白检查：通过。
- Windows release 构建：成功，产物 `build/windows/x64/runner/Release/orbit.exe`，运行时需保留 Release 目录内的 DLL 与 data 文件。
- Android debug 构建：成功，产物 `build/app/outputs/flutter-apk/app-debug.apk`。本次没有生成 Android release APK。

覆盖提醒表单单行标题、动态正文、固定钟点边界与独立相对时长、星期文案、日期定位和跨日期选择、取消不提交、红色放弃按钮、光标变量插入及替换选区。

覆盖六种自动方案的浅色文字对比、旧深色课表视觉基线、150 与 3,000 个课程身份的双主题颜色唯一性、重复标识修复、增加和移除课程后稳定性、旧备份默认值与新字段往返，以及配色异步初始加载保护。

覆盖窄屏与宽屏、单日/多日/紧凑整周/宽屏整周、三档密度、08:00–22:00 完整显示与相等留白、额外时段滚动、跨午夜课程、窗口缩放保持顶部时刻、切周及相邻周预览 08:00 定位、短课程重叠点击选择、保留手动缩放值和恢复默认。

覆盖拖动尚未停止时的进度环更新、回顶打断、浮动与底部按钮转场、普通及操作消息超时、消息队列与旧计时器取消、导入格式展开快速反向及减少动画模式。Windows 原生检查使用独立测试身份，仅排定未来任务后查询并取消，没有实际发送测试通知。

## 截图复核

新增截图检查全部通过，并人工查看以下截图的课程位置、配色、文字可读性及表单留白：

- `test/goldens/adaptive_320_light.png`
- `test/goldens/adaptive_1100_light.png`
- `test/goldens/adaptive_320_dark.png`
- `test/goldens/theme_schemes.png`
- `test/goldens/reminder_templates.png`

这些是 Flutter 组件渲染截图，使用本机字体；不等同于 Android 实机或 Windows 主窗口操作验证。

## 实机预览

- Android：没有连接设备，尚未实机验证软键盘、声音、震动、锁屏和后台行为。
- Windows：现有 v1.3.3 实例正在运行，共享单实例机制限制了新主窗口预览；未关闭现有实例，以保留用户会话。系统通知队列原生检查已通过，但新界面鼠标/键盘操作、动画观感及长期后台恢复仍需退出旧实例后实测。

## 日志

- `build/ui-optimization-analyze.log`
- `build/ui-optimization-full-flutter.log`
- `build/ui-optimization-android-build.log`
- `build/ui-optimization-windows-build.log`
- `build/ui-optimization-native-windows.log`
