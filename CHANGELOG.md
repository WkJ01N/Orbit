# Orbit v1.0.1 Update Note

**版本：** 1.0.1 (build +2)  
**日期：** 2026-06-05  
**平台：** Windows · Android

---

## 概览

本次更新聚焦课表交互体验、Windows 桌面行为，以及若干 UI 与稳定性修复。共 **48** 项自动化测试全部通过，Release 构建产物已生成。

---

## 新功能与体验改进

### 课表网格

- **左右滑动切换周次**：课表页支持手势左右滑动翻周，切换过程无过渡动画，操作更直接。
- **周翻页不闪烁**：`weekGridProvider` 由 `FutureProvider` 改为基于 `sessionsProvider` 的同步 `Provider`，周切换时不再短暂显示 `CircularProgressIndicator`。
- **空周仍可翻页**：有课表但当前周无课程时，仍保留 `AdjacentPagePager` 与「本周无课程」提示，可继续左右翻页浏览其他周。

### 课程详情与列表 UI

- **详情页底部按钮响应式布局**：编辑 / 备注 / 删除按钮在窄屏下自动收窄；极窄屏仅显示图标。
- **星期 Chip 垂直居中**：窄屏下课表顶栏的星期选择 Chip 对齐优化。
- **「接下来」列表对齐**：左侧课程状态竖条与内容垂直居中对齐。

### Windows 桌面

- **单实例启动**：重复启动 Orbit 时激活已有窗口并置前，不再产生多个任务栏图标（`single_instance.cpp` + 自定义窗口消息）。
- **托盘快速退出**：托盘「退出」由约 5 秒降至 **1 秒内**。
  - `TrayService.dispose()` 增加 `trayManager.destroy()`，立即移除托盘图标
  - 退出前显式关闭 SQLite（`registerAppDatabase` / `closeAppDatabase`）
  - 移除慢速 `windowManager.destroy()`，改为资源清理后 `exit(0)`
- **品牌名统一**：应用显示名称由 `orbit` 更正为 **Orbit**（`AndroidManifest.xml`、`main.cpp`、`Runner.rc`）。

---

## Bug 修复

### 清除课表后空态不显示

**问题：** 在设置中「清除所有课表」后，课表页仍显示「本周无课程」的周视图，而非「尚未导入课表」全局空态。

**根因：** `selectedWeekStartProvider` 在清除后仍保留旧周次，`weekGridProvider` 继续为该周构建空网格。

**修复：**
- `weekGridProvider`：`sessions.isEmpty` 时返回 `null`
- 清除全部数据时重置 `selectedWeekStartProvider`
- AppBar 周次来源改为 `grid?.weekStart`，无课表时显示「课表」标题

### 课表翻页闪烁

**问题：** 滑动或按钮切换周次时，页面短暂闪烁。

**根因：** `weekGridProvider` 为异步 `FutureProvider`，周切换触发 loading 态。

**修复：** 改为同步派生 Provider，loading/error 由 `sessionsProvider` 统一承担。

---

## 技术变更摘要

| 区域 | 主要文件 |
|------|----------|
| 课表翻页 | `lib/features/grid/grid_week_view.dart`、`grid_page.dart` |
| 翻页组件 | `lib/core/widgets/adjacent_page_pager.dart`（新增） |
| 翻页缓存 | `lib/features/grid/grid_pager_cache.dart`（新增） |
| 数据派生 | `lib/providers/schedule_providers.dart` |
| 托盘退出 | `lib/services/tray_service.dart`、`lib/providers/database_providers.dart`、`lib/main.dart` |
| 单实例 | `windows/runner/single_instance.{h,cpp}`、`main.cpp`、`win32_window.cpp` |
| 清除空态 | `lib/features/settings/settings_page.dart`、`lib/providers/schedule_providers.dart` |
| 详情页 UI | `lib/features/session/session_detail_sheet.dart` |
| 接下来列表 | `lib/features/upcoming/upcoming_page.dart` |
| 国际化 | `editSessionShort`、`addSessionNoteShort`、`deleteSessionShort` 等短标签 |
| 版本 | `pubspec.yaml` → `1.0.1+2`，`lib/core/app_info.dart` → `1.0.1` |

---

## 测试

- 测试总数：**48** 项（`flutter test` 全部通过）
- 新增/更新用例：
  - `test/grid_empty_week_swipe_test.dart`：清除后全局空态、空周仍可翻页
  - `test/widget_test.dart`：空态「立即导入」跳转
  - 翻页相关 Provider override 调整

---

## Release 构建产物

| 平台 | 路径 |
|------|------|
| Windows 可执行文件 | `build/windows/x64/runner/Release/orbit.exe` |
| Windows 分发包 | `release/v1.0.1/orbit-v1.0.1-windows-x64.zip` |
| Android APK（原始） | `build/app/outputs/flutter-apk/app-release.apk` |
| Android 分发包 | `release/v1.0.1/orbit-v1.0.1-release.apk` |

**使用提示：**
- Windows：解压 zip 后运行 `orbit.exe`，**勿删除**同目录 `data/` 与 DLL。
- Android：直接安装 APK（当前为 debug 签名，适合自用）。

---

## 建议手动验证

1. 课表左右滑动 / 按钮翻周 — 无闪烁，切换流畅
2. 设置 → 清除所有课表 — 课表页显示「尚未导入课表」+「立即导入」
3. 有课表时翻到无课周 — 仍显示「本周无课程」且可翻页
4. Windows 重复启动 — 仅一个任务栏图标，二次启动激活已有窗口
5. Windows 托盘 → 退出 — 1 秒内结束，托盘图标同步消失，重启后数据正常
6. 窗口关闭按钮 — 仍最小化到托盘（行为不变）
7. 窄屏下课程详情按钮 — 布局自适应正常

---

## 已知提示

- Android 构建时可能出现 Kotlin Gradle Plugin 兼容性警告（`android_alarm_manager_plus`），不影响当前 Release 构建。
- Windows 单实例通过窗口标题 `Orbit` 查找已有实例；若未来修改窗口标题需同步更新 `single_instance.cpp`。
