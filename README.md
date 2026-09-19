# Orbit

跨平台课表提醒应用，支持 **Windows** 与 **Android**。导入 XLSX / CSV 课表后识别课程，支持课程列表、周网格和自定义识别模板，提供网格课表与「接下来的课程」视图，并在课前通过系统通知提醒。

**源码版本 1.5.0** · [GitHub 仓库](https://github.com/WkJ01N/Orbit)

## 功能概览

| 模块 | 说明 |
|------|------|
| 导入 | XLSX 多工作表与 CSV（UTF-8 / GBK / GB18030）；按表头识别课程列表、周网格合并格与一格多课；可视化模板、正则捕获组与测试预览；学期与作息方案、周次展开；导入前预览去重、定位错误与明确跳过；重复周导入策略选择 |
| 导出与备份 | JSON v5 完整备份课程、批量系列、主题、提醒规则、引用音频、显示设置及识别模板、学期、作息方案，并兼容 v1–4；支持无课程时备份设置、课程和设置分项恢复、合并覆盖或替换课表；支持 xlsx 导出与识别模板 JSON 分享 |
| 账号与同步 | 可选 CloudBase 邮箱账号；支持显示名称、私有头像、验证码重发与 8–20 位字母数字密码；本地优先同步课程、自定义导入模板、学期与作息方案；可按设备配置启动、回前台、本地变化、网络恢复四种自动同步事件及网络条件；首次登录预览合并、离线修改队列、删除标记和并发冲突选择；退出账号默认保留本机课表 |
| 课表网格 | 按真实时间定位的整周时间轴；窄屏默认一屏显示完整七天，可切换经典单日/多日自适应布局，宽屏一屏展示整周；冲突课程自动分栏；当前时间线仅显示在今天列；支持隐藏无课日期、周选择、显示密度、50%–150% 纵向缩放及 08:00–22:00 页面自适应；支持批量删除 |
| 接下来 | 未来课程按今天 / 明天 / 本周 / 更晚分组；扁平化懒加载列表；「即将开始」与倒计时两行显示；骨架屏加载；标题栏快速添加课程；实时滚动进度回顶按钮，到底后在课程下方居中显示 |
| 提醒 | 独立自定义规则支持开始／结束偏移、日期固定时刻、课程筛选、秒级间隔、文案占位符、1–100 次发送及确认后停止；强提醒可按提醒类型、独立规则、课程系列或课次配置，明确指定普通／强提醒的规则优先；最近 24 小时只补发最后一条未处理消息。课前通知、次日摘要、打卡提醒均可自定义文案模板（占位符如 `{course}`、`{room}`、`{time}`、`{minutes}`、`{count}`、`{date}`）；Android 原生 `AlarmManager` 接收器在不启动 Flutter 的情况下直接通知；IANA 时区排程；精确 / 非精确降级；开机与更新时间恢复；通知点击跳转课程详情 |
| 课程管理 | 按学期周次与多个每周安排批量加课；冲突预览、跳过或覆盖；按每周安排编辑；7 天回收站、即时撤销和冲突安全恢复；课程备注及按科目自定义颜色 |
| 外观 | 单色／多色独立保存；多色支持九种生成方案、主／辅／第三色独立编辑及不限数量调色板；课程配色独立选择统一颜色／自动分色，手动颜色优先；跟随系统／浅色／深色 |
| Windows | 系统托盘、最小化到托盘、锁屏唤醒托盘自检、通知点击唤窗、单实例启动、快速退出、可选开机自启；系统循环强提醒、15 分钟隐藏维护和通知动作后台处理 |
| Android | 原生 AlarmManager 后台提醒（课前 / 打卡 / 次日摘要）；持久化阶段诊断与强制停止识别；可选低打扰增强提醒服务；电池优化双向开关；权限分项引导（含精确闹钟）；OriginOS 自启动、高耗电与任务锁定说明；重启后自动恢复提醒 |
| 多语言 | 繁体中文、简体中文、English |
| 通知权限 | Android 和 Windows 全页面权限警告、通知设置直达、二次确认后永久忽略；忽略仅保存在本设备，可在设置恢复提示；权限恢复自动重新排程 |
| 隐私 | 未登录时数据仅存本机；用户主动登录并确认首次合并后，课表及课表方案才会上传到隔离的个人云空间；通知权限、提醒运行状态和登录令牌不进入课表备份 |

## 快速开始（用户）

可从 [GitHub Releases](https://github.com/WkJ01N/Orbit/releases/latest) 下载 v1.5.0：

| 平台 | 文件 | 说明 |
|------|------|------|
| Windows | `orbit-v1.5.0-windows-x64.zip` | 解压后运行 `orbit.exe`，**勿删除**同目录 `data/` 与 DLL |
| Android | `orbit-v1.5.0-android.apk` | 可从现有版本直接覆盖安装并保留本机数据 |

## 从源码运行

### 环境要求

- Flutter SDK（stable，推荐 3.44+）
- **Android**：Android SDK，`flutter doctor --android-licenses`
- **Windows**：Visual Studio 2022「使用 C++ 的桌面开发」；系统需开启「开发人员模式」（符号链接）

### 命令

```bash
git clone https://github.com/WkJ01N/Orbit.git
cd Orbit
flutter pub get
flutter test          # 完整自动化测试
flutter run -d windows
flutter run -d android
```

官方 Release 已连接 Orbit 的 CloudBase 环境。自行构建时可按
[CloudBase 部署说明](cloudbase/README.md) 使用自己的环境，并加入：

```bash
flutter run -d windows \
  --dart-define=ORBIT_CLOUDBASE_ENV=<测试环境 ID> \
  --dart-define=ORBIT_CLOUDBASE_REGION=ap-shanghai
```

## 构建 Release

```bash
flutter test
flutter build windows --release --dart-define=ORBIT_CLOUDBASE_ENV=orbit-sync-beta-d6fjsl9220203313 --dart-define=ORBIT_CLOUDBASE_REGION=ap-shanghai
flutter build apk --release --dart-define=ORBIT_CLOUDBASE_ENV=orbit-sync-beta-d6fjsl9220203313 --dart-define=ORBIT_CLOUDBASE_REGION=ap-shanghai
```

| 平台 | 构建输出 |
|------|----------|
| Windows | `build/windows/x64/runner/Release/orbit.exe` |
| Android | `build/app/outputs/flutter-apk/app-release.apk` |

可将 `Release` 目录整份复制为分发包；Windows 必须保留 `data/` 子目录（含 `app.so`、`flutter_assets/` 等）。

打包示例（可选）：

```bash
# Windows zip
Compress-Archive -Path build/windows/x64/runner/Release/* -DestinationPath release/v1.5.0/orbit-v1.5.0-windows-x64.zip -Force

# Android APK
Copy-Item build/app/outputs/flutter-apk/app-release.apk release/v1.5.0/orbit-v1.5.0-android.apk -Force
```

## 更新日志

完整 Release Note 见 [CHANGELOG.md](CHANGELOG.md)。

### v1.3.3

- 新增按学期周次、单双周和多个每周安排批量添加课程
- 批量保存支持冲突预览、跳过或覆盖，并可按每周安排安全编辑
- 窄屏默认使用“紧凑整周”：固定时间轴，一屏显示七天，左右滑动切换周；课程名换行、教室靠底，时间与教师按空间显示
- 设置中可切换“经典自适应”，保留单日/多日、窄屏显示天数及隐藏无课日期；紧凑整周始终显示七天
- 修复批量安排标题间距和课表时钟格底线对齐，适配窄屏当前时间红线
- 数据库升级至 v4，JSON 备份升级至 v3 并兼容旧版本
- 版本号 1.3.3（build `+14`）

### v1.3.2

- Android 课程提醒改由原生后台定时提醒接收器直接发布，不依赖后台启动 Flutter
- 修复 iQOO / OriginOS 回到桌面、锁屏、进程冻结或最近任务上划后不提醒
- 通知诊断工具移至“数据管理 → 调试”，课表新增入口移至标题栏左侧
- 系统设置中的真正强行停止仍会取消应用闹钟，需重新打开应用恢复后台排程
- 版本号 1.3.2（build `+13`）

### v1.2.1

- 课表升级为按真实起止时间定位的自适应时间轴，支持单日、多日与整周模式
- 课程冲突自动分栏，课程卡片新增教师并按可用高度自适应显示信息
- 新增彩色主题、课程默认颜色恢复和仅当天显示的当前时间提示线
- 「接下来」增加周日期与可配置课程日期；修复语言切换提示和 Windows 中文字体粗细不一致
- 版本号 1.2.1（build `+9`）；测试 109 项

### v1.2.0

**设置与外观**
- 深浅色模式手动切换（跟随系统 / 浅色 / 深色）
- 课表周起始日可选（周一 / 周日）
- 课表显示密度可选（紧凑 / 标准 / 宽松）
- 课程按科目自定义颜色（课程详情页设置，课表与「接下来」同步显示）

**提醒**
- 课前提醒、打卡提醒支持自定义标题 / 正文模板（`{course}`、`{room}`、`{time}`、`{minutes}` 等）；留空使用默认文案

**优化**
- 提醒重排复用已缓存课表数据；日程摘要按日分组一次扫描
- 导入合并冲突检测按日期分组；`replaceSessions` 批量删除
- 提取重复的 Android 通知详情构造

**其他**
- 版本号 1.2.0（build `+8`）；测试 97 项；预编译包见 `release/v1.2.0/`

### v1.1.2

**提醒**
- 次日摘要可自定义标题 / 正文（`{count}`、`{time}`、`{date}`）；「无课时也提醒」开关
- 全局重同步横幅区分 verify / partial / 失败

**Android**
- 次日摘要纳入 AlarmManager；FLN `alarmClock` + 最高优先级
- 课前 / 打卡以 AlarmManager 为主通道，避免三重投递
- 清空数据同步取消闹钟；registry 先 OS 成功再写入

**课表**
- pinned 表头 delegate 优化；分钟 tick 局部重建；换周清理选中态

**修复与其他**
- 修复 Android 次日提醒后台 / 杀进程后不触发
- reschedule 链错误恢复、SnackBar / handler / async context 修补
- 版本号 1.1.2（build `+7`）；测试 86 项；预编译包见 `release/v1.1.2/`

### v1.1.1

**Android**
- 课前 / 打卡提醒 `AlarmManager.oneShotAt` 注册；6 小时维护闹钟；重启后自动恢复
- 设置页「后台提醒」：电池优化、OriginOS 自启动提示、1 分钟测试按钮

**课表**
- 宽屏 pinned 表头与表体共享垂直 viewport，纵向滚动条不再导致列错位

**修复与其他**
- 修复宽屏导入多时段课表后表头与课程列水平错位
- 版本号 1.1.1（build `+6`）；测试 76 项；预编译包见 `release/v1.1.1/`

### v1.1.0

**课表**
- 宽屏表头与课程列对齐；时间线固定行高；当前时间红线仅在课表时段内、**且仅在今天列**显示
- 无课周移除「立即导入」，引导切换周次；窄屏 AppBar 换周与搜索不再重叠
- 标准 AppBar；横滚不再触发整表 rebuild；Chip 高亮与红线共用分钟级时间源
- 骨架屏加载；单元格重绘隔离

**接下来**
- 「即将开始」与倒计时分两行；「上课中」徽章垂直居中
- 扁平化懒加载列表；骨架屏加载

**界面与导航**
- Tab 切换淡入过渡；宽屏课程详情 / 编辑 / 备注居中对话框
- FAB 仅在数据加载完成后显示

**课程**
- 手动添加 / 编辑可填学院；未填编号时使用唯一内部编号

**提醒**
- IANA 时区排程；Android `alarmClock` 优先与精确 / 非精确降级
- 2 小时内课前 / 打卡提醒进程内 Timer 兜底
- 冷启动使用已保存设置排程；pending 数量校验
- 保存后显示排定条数；OriginOS / iQOO 自启动与权限提示
- 手动添加默认下一整点 / 半点

**修复与其他**
- 详情弹窗删除 ref 已释放、红线跨天显示、手动课学院与提醒不触发等
- 课前 / 打卡提醒、详情编辑 / 备注、Android 后台定时提醒、宽屏列对齐、设置页版本号
- 版本号 1.1.0（build `+5`）；测试 70 项；预编译包见 `release/v1.1.0/`

### v1.0.3

**导入与课表**
- 重复周导入策略（整周替换 / 合并并覆盖冲突）；手动编辑冲突覆盖保存
- 默认周次设置（智能 / 本周 / 最早）；简繁互搜；搜索 loading / 错误 / 截断提示
- 当周无课「立即导入」入口

**提醒**
- 增删改后重排部分失败 SnackBar；全局 MaterialBanner 提示重新同步
- Android 精确闹钟权限直达授权页

**Windows**
- 锁屏 / 合盖后托盘图标自检恢复；通知点击唤窗；关闭前托盘提示；托盘随语言更新

**稳定性与其他**
- 提醒部分失败全局可感知；导出 / 还原 loading；保存防双击；语义化错误文案
- 修复搜索详情跳转、Android 导出取消误报成功、精确闹钟跳转
- 版本号 1.0.3（build `+4`）；测试 54 项

### v1.0.2

**导入与导出**
- 课表导出 JSON / xlsx；JSON 备份恢复
- 导入格式说明；xlsx 解析错误本地化提示

**课表**
- 手动添加 / 编辑单节课程（网格与「接下来」FAB）
- 课程搜索（科目、课室、教师等）

**提醒**
- 通知点击跳转课程详情
- Android 电池优化双向开关，同步系统真实状态
- Android 权限分项展示与跳转设置；重启后自动维护闹钟

**稳定性**
- 提醒重排串行化；后台维护容错；冷启动通知延后处理
- 前台 6 小时 debounce 重新同步；时区统一 `timezone_utils`
- 设置页提醒失败 SnackBar / MaterialBanner 反馈

**其他**
- 版本号升至 1.0.2（`pubspec.yaml` build `+3`）
- 测试增至 51 项

### v1.0.1

**课表与界面**
- 课表页支持左右滑动切换周次（无过渡动画）
- 修复周切换时整页闪烁（`weekGridProvider` 改为同步派生，避免 loading 占位）
- 修复设置中「清除所有课表」后仍显示「本周无课程」而非全局空态的问题
- 课程详情底部按钮窄屏自适应（编辑 / 备注 / 删除；极窄屏仅显示图标）
- 窄屏星期 Chip 垂直居中；「接下来」列表左侧状态竖条对齐优化

**Windows**
- 单实例启动：重复打开应用时激活已有窗口，不新增任务栏图标
- 托盘「退出」加速：清理托盘图标与 SQLite 后 `exit(0)`，退出时间由约 5 秒降至 1 秒内
- 应用显示名称统一为 **Orbit**

**其他**
- 版本号升至 1.0.1（`pubspec.yaml` build `+2`）
- 测试增至 48 项（含空态与翻页回归用例）

## 课表导入格式

支持按表头识别的 XLSX / CSV 课程列表，以及星期为列、节次为行的周网格。XLSX 可选择多个工作表；CSV 自动尝试 UTF-8 与 GB18030，也可手动选择 GBK 和分隔符。导入页及「设置 → 数据管理」可管理识别模板、学期与作息方案。详细步骤、网格多课与正则示例见 [课表导入指南](docs/importing-schedules.md)。

原有 Orbit 13 列 XLSX 格式继续兼容：

导出的课表为逐行列表，每行一节课：

| 列 | 字段 | 示例 |
|----|------|------|
| A | 课堂类型 | 一般课堂 |
| B | 课室 | A001 |
| C | 人数 | 67 |
| D | 学院名称 | 示例学院 |
| E | 日期 | 2026-07-27 |
| F | 星期 | 1（周一）~ 7（周日）|
| G | 科目名称 | 物理 |
| H | 科目编号 | P0721 |
| I | 班别名称 | EX1 |
| J | 开始时间 | 12:30 |
| K | 结束时间 | 15:20 |
| L | 教师 | Miku,null（解析时过滤 null）|
| M | 学期 | 2606 |

原有格式按固定列位置读取；通用课程列表按简繁中文或英文表头识别，列可重排。自定义模板可指定列、课程区域、固定值及正则提取规则。

## 技术栈

Flutter · Riverpod · sqflite · excel · flutter_local_notifications · android_alarm_manager_plus · timezone

## 项目结构

```
lib/
  features/          grid · upcoming · import · settings
  providers/         Riverpod（database / reminder / schedule / navigation）
  services/          解析、网格、提醒调度
  data/              SQLite 与 Repository
  core/              路由、组件、主题、格式化
test/                单元测试与 Widget 测试（含程序化 xlsx 夹具）
```

## 构建注意事项

**sqlite3 原生库**：项目已在 `pubspec.yaml` 配置 `hooks.user_defines.sqlite3.source: system`，使用各平台系统自带的 SQLite（Windows 为 `winsqlite3.dll`），避免 `flutter test` / `flutter build` 时从 GitHub Releases 下载预编译库——在国内网络或未配置代理时，该下载步骤可能长时间无输出、看似卡住。若需固定 SQLite 版本或启用加密扩展，可改回默认 `source: sqlite3` 并确保能访问 GitHub，或参考 [sqlite3 hook 文档](https://pub.dev/documentation/sqlite3/latest/topics/hook-topic.html) 自定义构建。

**Windows**：可先执行 `flutter precache --windows` 预拉引擎。

**Android**（`android/` 已配置）：

- `compileSdk = 36`，core library desugaring（通知插件需要）
- `kotlin.incremental=false`：规避 E: 项目盘与 C: Pub 缓存跨盘时 Kotlin 增量编译崩溃
- Gradle 可指向本机已下载发行版，避免重复下载损坏

## 开源许可

本项目采用 [GNU General Public License v3.0](https://www.gnu.org/licenses/gpl-3.0.html)（GPL-3.0）开源。完整许可文本见仓库根目录 [LICENSE.md](LICENSE.md)。
