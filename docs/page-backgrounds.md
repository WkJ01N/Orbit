# 页面背景

入口为「设置 → 外观 → 页面背景」，适用于 Android 和 Windows。

## 使用

选择 JPEG、PNG、WebP、GIF 或 MP4、M4V、MOV、WebM 文件；实际能否使用以设备解码结果为准。素材会复制到应用目录，删除相册或原文件不影响已保存背景。

先编辑课表，再选择是否应用到接下来、导入和设置。预览使用实际页面组件，可点击区域，也可用下方区域开关；手机双指缩放、拖动，Windows 可拖动、滚轮缩放或使用按钮。切换「浏览预览」可滚动内容，页面中的业务按钮不可执行。上一步保留草稿，关闭时可保存或放弃，正式页面只在保存后改变。

其他页面默认共用课表素材、构图和播放进度；修改共用构图会影响所有共用页面。关闭共用可独立调整或换图。更换课表素材后，未选择应用的旧共用页面保留原素材和构图，改为独立配置。即使主导航隐藏了接下来或导入，仍可在编辑器配置。

默认只显示课程网格／页面内容区，底板不透明度 80%，暗化 20%，图片居中铺满且不露边。允许露边后可缩小，并选择主题底色或同素材模糊填补。区域开关只控制背景透出，文字、图标、网格线及课程配色继续保留。

GIF、视频默认循环，视频禁用音轨、字幕且音量为零。可关闭动态播放；系统减少动态效果时使用封面。应用进入后台、Windows 隐藏或最小化时暂停。视频保持原文件，没有裁剪或转码功能。

## 备份

完整备份升级为 v10。默认导出 JSON，包含背景描述和构图，不包含素材文件或设备绝对路径。勾选「包含背景素材」导出 `.orbit` ZIP，保存去重后的原始媒体及封面。大视频按流散列、打包、导出和恢复，Android 使用系统文档目标输出流。

恢复时先校验 ZIP 项目、长度、CRC 和素材 SHA-256，再安装文件和提交配置；失败会回滚新文件和设置。仅恢复课程不改变背景。旧版 v1–v9 备份不含背景字段时保留本机背景；只有描述的备份可匹配本机同散列素材，否则停用缺失背景并提示补选。背景未加入云同步白名单。

## 实现位置

- `lib/models/background_settings.dart`：独立设置、素材描述、共用归属和视口构图约束。
- `lib/core/background/`：分区实际边界、主题透出、连续切页、来源路由快照、图片及动态媒体。
- `lib/features/settings/background_editor_page.dart`：草稿编辑、真实页面预览、手势隔离、分步流程和总览。
- `lib/services/background_asset_service.dart`：复制、解码验证、散列去重、封面、取消清理和本机素材匹配。
- `lib/services/background_package_service.dart`：素材包的流式处理、校验和回滚。
- `android/.../MainActivity.kt`：系统文档选择后的流式文件导出。

完整二级页面通过 `BackgroundScaffold` 使用来源标题／内容区域，路由链捕获来源及当时的背景配置。弹层保留现有底板。相同素材的共用构图复用动画层外的媒体实例；独立配置使用与内容一致的过渡，旧过渡实例在结束或被替换时释放。

## 验证

执行 `flutter analyze --no-pub` 和 `flutter test --no-pub`。新增测试覆盖构图比例及约束、共用／脱离、去重和取消清理、真实图片解码、有限 GIF 循环策略、分区点击与双指缩放互不误触、四页流程及保存／放弃、320px 双倍字体、共用媒体状态与独立过渡、路由快照、v1–v9 兼容、v10 素材包及损坏／缺失素材、恢复回滚和云同步排除。现有课表视觉基线保持通过。

Windows 原生无窗口媒体检查：

```powershell
ffmpeg -f lavfi -i testsrc=size=320x180:rate=15 -f lavfi -i sine=frequency=440:sample_rate=44100 -t 2 -c:v libx264 -pix_fmt yuv420p -c:a aac build/background-audio-fixture.mp4
dart run tool/background_media_smoke.dart E:/Multiplatform/Orbit/build/windows/x64/runner/Debug/libmpv-2.dll E:/Multiplatform/Orbit/build/background-audio-fixture.mp4
```

该检查实测 Windows 解码、无音轨、音量零、暂停／恢复和循环。Android／Windows debug 构建均已通过。当前未连接 Android 设备，尚需真机验证锁屏、后台恢复、系统文档导出取消及普通／强提醒同时发声；Windows 托盘隐藏、纹理模糊填补及硬件解码失败恢复也需交互实测。自动化结果不替代这些设备验收。

正式构建验证：Android 与 Windows release 均使用现有正式 CloudBase 编译配置构建成功（1.5.5+27）；Android APK 签名通过验证，与既有 v1.5.5 正式包证书一致。Windows release 原生媒体库也通过静音、循环和暂停／恢复测试。产物归档在本机 `release/background-customization-20261016/`，附 SHA256SUMS.txt；该构建未创建 GitHub Release 或更新线上更新清单。
