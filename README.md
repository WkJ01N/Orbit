# Orbit

跨平台课表提醒应用，支持 **Windows** 与 **Android**。导入学生课表 xlsx 后自动识别课程，提供网格课表与「接下来的课程」视图，并在课前通过系统通知提醒。

**版本 1.0.0** · [GitHub 仓库](https://github.com/WkJ01N/Orbit)

## 功能概览

| 模块 | 说明 |
|------|------|
| 导入 | 多文件并行解析、自动合并去重；导入成功可跳转课表 |
| 课表网格 | 周切换、周选择器、批量删除；支持周一至周日 |
| 接下来 | 未来课程按今天 / 明天 / 本周 / 更晚分组 |
| 提醒 | 课前通知、次日摘要、打卡提醒；Android 可选系统闹钟 |
| 课程管理 | 编辑、备注、单节删除；详情页快捷操作 |
| Windows | 系统托盘、最小化到托盘、可选开机自启 |
| Android | AlarmManager 后台维护；电池优化引导 |
| 多语言 | 繁体中文、简体中文、English |
| 隐私 | 数据仅存本机 SQLite，不上传云端 |

## 快速开始（用户）

从源码自行构建，或下载本地 `release/v1.0.0/` 中的预编译包：

| 平台 | 文件 | 说明 |
|------|------|------|
| Windows | `orbit-v1.0.0-windows-x64.zip` | 解压后运行 `orbit.exe`，**勿删除**同目录 `data/` 与 DLL |
| Android | `orbit-v1.0.0-release.apk` | 直接安装（当前为 debug 签名，适合自用） |

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
flutter test          # 49 项测试
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

**sqlite3 原生库**：首次构建会从 GitHub Releases 下载预编译库，需可访问网络。请勿在 `pubspec.yaml` 中设置 `hooks.user_defines.sqlite3 = test-sqlite3`，否则 Android 构建会失败。

**Windows**：可先执行 `flutter precache --windows` 预拉引擎。

**Android**（`android/` 已配置）：

- `compileSdk = 36`，core library desugaring（通知插件需要）
- `kotlin.incremental=false`：规避 E: 项目盘与 C: Pub 缓存跨盘时 Kotlin 增量编译崩溃
- Gradle 可指向本机已下载发行版，避免重复下载损坏

## 开源许可

本项目采用 [GNU General Public License v3.0](https://www.gnu.org/licenses/gpl-3.0.html)（GPL-3.0）开源。完整许可文本见仓库根目录 [LICENSE.md](LICENSE.md)。
