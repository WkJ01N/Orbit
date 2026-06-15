# Orbit

跨平台课表提醒应用，支持 **Windows** 与 **Android**。导入学生课表 xlsx 后自动识别课程，提供网格课表与「接下来的课程」视图，并在课前通过系统通知提醒。

**版本 1.1.0** · [GitHub 仓库](https://github.com/WkJ01N/Orbit)

## 功能概览

| 模块 | 说明 |
|------|------|
| 导入 | 多文件并行解析、自动合并去重；重复周导入策略选择；导入成功可跳转课表；格式说明与本地化错误提示 |
| 导出与备份 | 课表导出为 JSON / xlsx；JSON 备份恢复；导出 / 还原进行中状态 |
| 课表网格 | 左右滑动 / 按钮切换周次（无动画，即时切换）；宽屏表头列对齐、固定行高、当前时间红线；标准 AppBar；横滚性能优化与单元格重绘隔离；骨架屏加载；窄屏 AppBar 防重叠；默认周次可设（智能 / 本周 / 最早）；周选择器、批量删除；手动添加 / 编辑课程；冲突覆盖保存；课程搜索（简繁互搜）；无课周引导切换（非全局空态不重复显示导入按钮） |
| 接下来 | 未来课程按今天 / 明天 / 本周 / 更晚分组；扁平化懒加载列表；「即将开始」与倒计时两行显示；骨架屏加载；FAB 快速添加课程 |
| 提醒 | 课前通知、次日摘要、打卡提醒；排程 pending 校验与失败提示；精确闹钟降级回退；通知点击跳转课程详情；重排失败全局 Banner / SnackBar；Android 可选系统闹钟（含 OriginOS 回退） |
| 课程管理 | 编辑、备注、单节删除；详情页响应式快捷操作（窄屏自适应）；宽屏居中对话框、窄屏底部 Sheet |
| Windows | 系统托盘、最小化到托盘、锁屏唤醒托盘自检、通知点击唤窗、单实例启动、快速退出、可选开机自启 |
| Android | AlarmManager 后台维护；电池优化双向开关；权限分项引导（含精确闹钟）；重启后自动维护闹钟 |
| 多语言 | 繁体中文、简体中文、English |
| 隐私 | 数据仅存本机 SQLite，不上传云端 |

## 快速开始（用户）

从源码自行构建，或下载本地 `release/v1.1.0/` 中的预编译包：

| 平台 | 文件 | 说明 |
|------|------|------|
| Windows | `orbit-v1.1.0-windows-x64.zip` | 解压后运行 `orbit.exe`，**勿删除**同目录 `data/` 与 DLL |
| Android | `orbit-v1.1.0-release.apk` | 直接安装（当前为 debug 签名，适合自用） |

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
flutter test          # 64 项测试
flutter run -d windows
flutter run -d android
```

## 构建 Release

```bash
flutter test
flutter build windows --release
flutter build apk --release
```

| 平台 | 构建输出 |
|------|----------|
| Windows | `build/windows/x64/runner/Release/orbit.exe` |
| Android | `build/app/outputs/flutter-apk/app-release.apk` |

可将 `Release` 目录整份复制为分发包；Windows 必须保留 `data/` 子目录（含 `app.so`、`flutter_assets/` 等）。

打包示例（可选）：

```bash
# Windows zip
Compress-Archive -Path build/windows/x64/runner/Release/* -DestinationPath release/v1.1.0/orbit-v1.1.0-windows-x64.zip

# Android APK
Copy-Item build/app/outputs/flutter-apk/app-release.apk release/v1.1.0/orbit-v1.1.0-release.apk
```

## 更新日志

完整 Release Note 见 [CHANGELOG.md](CHANGELOG.md)。

### v1.1.0

**课表**
- 宽屏表头与课程列对齐；时间线固定行高；当前时间红线仅在课表时段内显示
- 无课周移除「立即导入」，引导切换周次；窄屏 AppBar 换周与搜索不再重叠
- 标准 AppBar；横滚不再触发整表 rebuild；Chip 高亮与红线共用分钟级时间源
- 骨架屏加载；单元格重绘隔离

**接下来**
- 「即将开始」与倒计时分两行；「上课中」徽章垂直居中
- 扁平化懒加载列表；骨架屏加载

**界面与导航**
- Tab 切换淡入过渡；宽屏课程详情 / 编辑 / 备注居中对话框
- FAB 仅在数据加载完成后显示

**提醒**
- 冷启动使用已保存设置排程；pending 数量校验与精确闹钟降级
- 保存后显示排定条数；「重新同步提醒」不再绑定课前提醒开关
- 手动添加默认下一整点 / 半点

**修复与其他**
- 课前 / 打卡提醒、详情页删除 / 编辑 / 备注、Android 系统闹钟、宽屏列对齐、设置页版本号显示
- 版本号 1.1.0（build `+5`）；测试 64 项

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

## 课表 xlsx 格式

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

解析器以列位置为主、列名为辅，对导出格式轻微调整有一定容错。

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
