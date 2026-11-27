# Orbit

跨平台大学课表与提醒应用，支持 **Windows** 与 **Android**，本地优先并支持可选云端多端同步。

**当前版本：`v1.7.0 (build 36)`** · [GitHub Releases](https://github.com/WkJ01N/Orbit/releases/latest) · [发布说明](docs/releases/v1.7.0.md) · [更新日志](CHANGELOG.md) · [GPL-3.0 协议](LICENSE.md)

---

## 核心功能

| 模块 | 说明 |
|---|---|
| 课表与视图 | 整周真实时间轴、窄屏紧凑七天、经典单日/多日布局与「接下来」日程列表；冲突自动分栏、键盘导航、归档与 7 天回收站 |
| 提醒与强提醒 | 课前、打卡（含 WeMust 课表入口）、次日摘要与独立自定义规则；支持算术/数字强提醒；Android 原生批量后台调度与滚动窗口，Windows 系统托盘与独立音频 |
| 桌面微件（Android） | 原生「下一节课」紧凑卡与「今日课表」可滚动列表；支持展示近期未完成 DDL、主题与课程多彩配色同步、背景不透明度调节及节点自动刷新 |
| 考试、DDL 与统计 | 独立考试日程与默认强提醒；支持按日/周/月批量生成 DDL；按学期与课程累计学时，游客/账号统计隔离与归属保护 |
| 导入、导出与备份 | XLSX / CSV 智能识别与自定义模板；JSON 完整备份与分项恢复；支持包含 `VALARM` 提醒与 DDL 的 `.ics` 日历导出 |
| 账号与云同步（可选） | CloudBase 邮箱账号登录（最多 5 台设备）；本地优先同步课程、模板、学期、DDL 与统计，支持冲突历史回溯 |
| 外观与扩展 | Material 3 单/多色主题与课程自定义配色；自定义字体与图片/GIF/视频背景（按需下载）；支持繁中 / 简中 / English |

## 安装使用

从 [GitHub Releases](https://github.com/WkJ01N/Orbit/releases/latest) 下载对应安装包：

- **Android**：`orbit-v1.7.0-android.apk`（通用版）或 `arm64-v8a` / `armeabi-v7a` / `x86_64` 分架构包，可直接覆盖安装并保留本地数据。
- **Windows**：`orbit-v1.7.0-windows-x64.zip`，解压后直接运行 `orbit.exe`（需保留同目录 `data/` 与 DLL）。

## 从源码运行与构建

**环境要求**：Flutter SDK（stable 3.44+）；Android 需 Android SDK（`compileSdk = 36`）；Windows 需 Visual Studio 2022「使用 C++ 的桌面开发」并开启系统「开发人员模式」。

```bash
git clone https://github.com/WkJ01N/Orbit.git
cd Orbit
flutter pub get
flutter test
flutter run -d android   # 或 windows
```

构建正式发布包（连接自建 CloudBase 环境时，按 [CloudBase 部署说明](cloudbase/README.md) 替换参数）：

```bash
flutter build apk --release \
  --dart-define=ORBIT_CLOUDBASE_ENV=<你的环境 ID> \
  --dart-define=ORBIT_CLOUDBASE_REGION=ap-shanghai \
  --dart-define=ORBIT_API_BASE_URL=https://<CloudBase 默认域名>/orbit

flutter build windows --release \
  --dart-define=ORBIT_CLOUDBASE_ENV=<你的环境 ID> \
  --dart-define=ORBIT_CLOUDBASE_REGION=ap-shanghai \
  --dart-define=ORBIT_API_BASE_URL=https://<CloudBase 默认域名>/orbit
```

> **提示**：项目在 `pubspec.yaml` 中配置了 `hooks.user_defines.sqlite3.source: system`，直接复用系统自带 SQLite（Windows 为 `winsqlite3.dll`），避免测试或构建时卡在外部二进制下载。

## 相关文档

- 版本更新：[CHANGELOG.md](CHANGELOG.md) · [v1.7.0 发布说明](docs/releases/v1.7.0.md)
- 使用与功能：[课表导入指南](docs/importing-schedules.md) · [导航与 WeMust 打卡辅助](docs/navigation-assistance.md) · [DDL 强提醒说明](docs/ddl-strong-reminders.md)
- 外观与动效：[字体设置](docs/typography.md) · [页面背景](docs/page-backgrounds.md) · [启动与入场动画](docs/launch-animation.md)
- 云端服务：[CloudBase 部署说明](cloudbase/README.md)

## 开源许可

本项目基于 [GNU General Public License v3.0](https://www.gnu.org/licenses/gpl-3.0.html)（GPL-3.0）开源，详见 [LICENSE.md](LICENSE.md)。
