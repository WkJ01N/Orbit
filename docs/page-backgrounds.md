# 页面背景

入口为「设置 → 外观 → 页面背景」，适用于 Android 和 Windows。

## 使用

选择 JPEG、PNG、WebP、GIF 或 MP4、M4V、MOV、WebM 文件；实际能否使用以设备解码结果为准。素材会复制到应用目录，删除相册或原文件不影响已保存背景。

点击编辑后先单选课表、接下来、导入或设置；页面快捷入口仅预选对应页面。第一步编辑区域与构图，第二步调整效果；两步均能直接点击预览区域和缩放拖动。手机双指操作，Windows 可拖动、滚轮缩放或使用按钮。切换「浏览预览」可滚动内容，页面中的业务按钮不可执行。手机控制面板可展开，Windows 宽窗口显示侧栏。上一步保留草稿，切换编辑目标若有更改则询问是否放弃，关闭时可保存或放弃。

保存直接提交当前编辑，成功后退出并提示；失败保留草稿供重试。配置写入后回读验证，退出后的素材清理重新读取持久化引用。编辑器只有解除返回拦截并完成一帧更新后才退出，避免保存与返回状态竞争。

其他页面可选择持续跟随课表：素材、构图、播放进度、模糊、暗化、边缘填补，以及标题栏和主导航开关均同步；这些选项在跟随页只读。其他区域、底板透明度和文字保护独立设置。关闭跟随复制当前有效配置；更换课表素材会影响跟随页，清除课表则让跟随页保留现有背景并转为独立。即使主导航隐藏了接下来或导入，仍可在编辑器配置。

默认只显示课程网格／页面内容区，底板不透明度80%，暗化20%，整图模糊0，图片居中铺满且不露边。暗化可调至90%，整图模糊0–100映射到0–20逻辑像素模糊半径；允许露边后可选择主题底色或同素材模糊填补。模糊复用已有媒体纹理，不增加播放器。暗化低于30%时自动添加柔和文字阴影，可按页面关闭；仅应用于开启背景的区域，不带入弹窗。文字、图标、网格线及课程配色不随底板降低透明度。

GIF、视频默认循环，视频禁用音轨、字幕且音量为零。可关闭动态播放；系统减少动态效果时使用封面。应用进入后台、Windows 隐藏或最小化时暂停。视频保持原文件，没有裁剪或转码功能。

## 备份

完整备份升级为 v10。默认导出 JSON，包含背景描述和构图，不包含素材文件或设备绝对路径。勾选「包含背景素材」导出 `.orbit` ZIP，保存去重后的原始媒体及封面。大视频按流散列、打包、导出和恢复，Android 使用系统文档目标输出流。

恢复时先校验 ZIP 项目、长度、CRC 和素材 SHA-256，再安装文件和提交配置；失败会回滚新文件和设置。仅恢复课程不改变背景。旧版 v1–v9 备份不含背景字段时保留本机背景；只有描述的备份可匹配本机同散列素材，否则停用缺失背景并提示补选。背景未加入云同步白名单。

## 实现位置

- `lib/models/background_settings.dart`：独立设置、素材描述、共用归属和视口构图约束。
- `lib/core/background/`：分区实际边界、主题透出、连续切页、来源路由快照、图片及动态媒体。
- `lib/features/settings/background_editor_page.dart`：草稿编辑、真实页面预览、手势隔离、单页分步流程。
- `lib/services/background_asset_service.dart`：复制、解码验证、散列去重、封面、取消清理和本机素材匹配。
- `lib/services/background_package_service.dart`：素材包的流式处理、校验和回滚。
- `android/.../MainActivity.kt`：系统文档选择后的流式文件导出。

完整二级页面通过 `BackgroundScaffold` 使用来源标题／内容区域，路由链捕获来源及当时的背景配置。弹层保留现有底板。相同素材的共用构图复用动画层外的媒体实例；独立配置使用与内容一致的过渡，旧过渡实例在结束或被替换时释放。

二级页面的背景主题在路由内部应用，导航器外层结构保持固定。路由退出时，来源配置和背景保持到反向动画结束、覆盖层移除后再释放，避免退出页面更换布局树而重建滚动列表。Android 保留系统预测返回与取消手势；有背景参与时取消默认过渡底色。Windows 保留默认缩放曲线和淡出时序，但显式跳过背景遮罩绘制（Flutter 默认缩放绘制器会重新设置颜色透明度，仅传入透明色仍会产生黑色遮罩）。无背景过渡保留主题遮罩。

主导航动画复用稳定页面子树，页面及媒体使用绘制隔离；无背景页面之间不启动空媒体过渡。Windows 编辑面板使用 8px 按钮／换行间距、12px 分组间距和 16px 水平留白，缩放按钮作为整体换行，手机布局不变。

## 验证

执行 `flutter analyze --no-pub` 和 `flutter test --no-pub`。新增测试覆盖构图比例及约束、共用／脱离、去重和取消清理、真实图片解码、有限 GIF 循环策略、分区点击与双指缩放互不误触、页面单选、更换素材、保存失败重试、保存／放弃、跟随页区域锁定及效果只读、320px 双倍字体、共用媒体状态与独立过渡、路由快照、v1–v9 兼容、v10 素材包及损坏／缺失素材、恢复回滚和云同步排除。现有课表视觉基线保持通过。

Windows 原生无窗口媒体检查：

```powershell
ffmpeg -f lavfi -i testsrc=size=320x180:rate=15 -f lavfi -i sine=frequency=440:sample_rate=44100 -t 2 -c:v libx264 -pix_fmt yuv420p -c:a aac build/background-audio-fixture.mp4
dart run '-Ddart.vm.product=true' tool/background_media_smoke.dart E:/Multiplatform/Orbit/build/windows/x64/runner/Release/libmpv-2.dll E:/Multiplatform/Orbit/build/background-audio-fixture.mp4
```

该检查实测 Windows 解码、无音轨、音量零、暂停／恢复和循环。Android／Windows debug 构建均已通过。当前未连接 Android 设备，尚需真机验证锁屏、后台恢复、系统文档导出取消及普通／强提醒同时发声；Windows 托盘隐藏、纹理模糊填补及硬件解码失败恢复也需交互实测。自动化结果不替代这些设备验收。

### 背景切换性能复测

`integration_test/background_transition_test.dart` 使用真实主导航、已登录账号页面与原生媒体插件，在内存设置和临时素材目录下记录静态图片、GIF、视频的主导航与二级页面帧耗时。每种素材预热全部页面后，记录 20 次主导航切换及 5 次账号页面进入、滚动和返回。测试不执行真实登录，不使用用户课程数据。素材目录必须位于测试设备可读取的位置，包含 `still.png`、`animated.gif`、1280×720 的 `video.mp4`。视频直接安装为测试素材，测量实际播放与切换，不经过视频导入流程。

```powershell
$env:ORBIT_BACKGROUND_REPORT = 'build/background-transition-profile.json'
flutter drive --no-pub --profile -d windows --driver=test_driver/background_transition_driver.dart --target=integration_test/background_transition_test.dart --dart-define=ORBIT_BACKGROUND_FIXTURES=E:/path/to/fixtures
```

Windows 验收应使用独立测试副本，且测试副本的原生 runner 必须跳过单实例互斥、`OpenStrongReminder` 与 `RegisterStrongReminderWindow`，避免启动测试时激活当前 Orbit 或改写提醒窗口登记。正式源码保留这些功能。修复前后需使用相同 runner 隔离调整、素材、窗口大小与操作流程，并分别保存报告；比较 UI／光栅耗时、超时帧及视觉连续性。Android 使用 `-d <device-id>` 和设备端素材目录另行验收，桌面数据不能替代手机真机结果。

2026-10-17 本次源码验收：静态检查通过，全量 Flutter 测试 674 项通过、1 项跳过；补充的测试验证动画各阶段背景像素、来源路由配置释放、账号页按钮／系统返回及预测返回取消／提交时的滚动位置，以及 Windows 宽窄窗口、中文和双倍字体布局。

Windows profile 使用 1920×1080 PNG、640×360／12fps GIF、1280×720／24fps 视频，在同一隔离 runner、相同流程下分别采集修复前 4,414 帧、修复后 6,008 帧。账号页静态背景的 UI 构建 P99 从 8.521ms 降至 1.624ms，GIF 从 8.302ms 降至 2.376ms；主导航静态背景为 1.655→1.298ms，视频为 1.520→1.390ms，GIF 为 1.443→1.514ms，存在小幅波动。六场景修复前后均未超过 Flutter 默认帧预算，因此这些数据用于说明本机 UI 构建负担改善，不作为所有设备零掉帧的保证。视频场景额外验证实际解码为 1280×720、音量为零且无音轨。原始报告为本机 `build/background-transition-baseline.json`、`build/background-transition-fixed.json`，精简对比为 `build/background-transition-comparison.json`。当前未连接 Android 真机，手机帧耗时验收仍待设备连接后执行。

正式构建验证：Android 与 Windows release 均使用现有正式 CloudBase 编译配置构建成功（1.5.5+27）；Android APK 签名通过验证，与既有 v1.5.5 正式包证书一致。Windows release 原生媒体库也通过静音、循环和暂停／恢复测试。产物归档在本机 `release/background-customization-20261016/`，附 SHA256SUMS.txt；该构建未创建 GitHub Release 或更新线上更新清单。

v1.5.6 发布构建：应用与两端安装包版本为 1.5.6+28；APK 签名与既有正式版一致，Windows ZIP 的 35 个文件与 Release 目录逐文件匹配。生产运行模式下的原生媒体复测通过；调试用 PID 热重启缓存不参与正式运行模式。版本一致性与更新相关 6 项测试通过；产物与更新清单位于 `release/v1.5.6/`。

## 分架构 Android 包

发布流程同时提供通用 APK 和 arm64-v8a、armeabi-v7a、x86_64 APK。设备更新按支持的 ABI 优先级选择；未知架构或旧清单回退通用包。清单保留 schemaVersion=1 及 assets.android，增加 androidAbis 字典，每项独立记录名字、大小和 SHA-256。Windows ZIP 不变。所有APK内部版本号一致，以支持通用包与架构包互相升级；构建使用逐目标架构编译，避免Flutter多APK分包默认增加的版本号偏移。

兼容旧客户端：通用包继续命名为 orbit-vX.Y.Z-android.apk，架构包命名为 orbit-vX.Y.Z-arm64-v8a.apk、orbit-vX.Y.Z-armeabi-v7a.apk、orbit-vX.Y.Z-x86_64.apk。GitHub按文件名返回资产，这套命名保证通用包排在三个架构包前；仅先上传通用包不能保证返回顺序。发布前检查GitHub API返回的首个APK确实为通用包。公共更新代理同时兼容新旧架构包名并优先返回通用包（服务源码修改需部署后生效），新版客户端不依赖资产顺序。

本次本地验收构建保持1.5.6+28，不覆盖正式v1.5.6；构建包放在 release/background-editor-revision-20261016/。体积与构建校验结果见该目录 BUILD_REPORT.md。分包减少单设备下载字节数，不减少已安装应用的原生解码库，也不承诺通用包明显缩小。

### 2026-10-16 编辑器修订验收

静态分析无问题；全量Flutter测试664项通过、1项跳过，追加深浅色文字保护及真实视口布局验证通过。Python清单测试2项、Node更新兼容测试4项通过。四个Android包均已验证签名、1.5.6+28版本及ABI集合；Windows ZIP的35个文件与Release目录散列一致，原生静音视频复测通过。

最终ARM64包38.98MB、ARMv7包36.57MB、x86_64包44.00MB，通用包116.83MB。ARM64下载较原通用包减少66.64%。本次仅本地构建，未推送源码、未发布Release、未部署更新代理。设备交互待验收项目仍按上文保留。

### v1.5.7 发布构建

版本升级为1.5.7+29，正式产物位于 release/v1.5.7/。提供三个独立架构APK、通用APK、Windows ZIP及独立散列清单；Android包保持相同内部版本号和正式签名。背景编辑修订在此版本发布，安装包由现有正式CloudBase配置重新编译。更新代理排序的源码随本次提交推送，但不包含云端部署。

2026-10-17 背景过渡修复版本地 release 构建保持 1.5.7+29，使用既有正式 CloudBase 配置和 Android 签名，单独归档至 `release/background-transition-fix-20261017/`。通用、ARM64、ARMv7、x86_64 四个 APK 的版本、ABI 和证书均通过校验；Windows ZIP 的 35 个文件与构建目录逐一匹配。两端 AOT 包均确认包含本次路由修复且使用正式应用入口，更新清单与 SHA-256 与最终产物一致；Windows release 原生视频的静音、循环、暂停和恢复复测通过。
