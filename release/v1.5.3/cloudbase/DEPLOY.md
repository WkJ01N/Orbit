# CloudBase 控制台部署 Orbit 1.5.3+25

目标环境：orbit-sync-beta-d6fjsl9220203313（控制台名称 orbit-sync-beta）。这是已有服务的代码升级，保留账号和现有数据。

1. 左侧“文档型数据库”：创建 `orbit_sync_policy`、`orbit_update_cache` 两个空集合；如已有则保留。各自安全规则设置 `{ "read": false, "write": false }`。云函数通过服务端 SDK 访问。
2. 左侧“云函数 / 托管”：更新已有 `orbit-sync-pull`、`orbit-sync-push`、`orbit-sync-delete-data`，最后更新 `orbit-api`。每个函数上传本目录同名 ZIP，开启云端安装依赖／点击“保存并安装依赖”。ZIP 根目录已包含 index.js 和 package.json。
3. 保留 Node.js 20.19（或已使用的兼容运行时）、入口 `index.main`、环境变量及其他配置；本次更新函数代码，不执行 delete-data 函数。
4. 左侧“HTTP 网关”：确认已有 `/orbit` 路由指向 `orbit-api`，路径透传开启，网关鉴权关闭（账号业务请求由 Orbit 自有 Bearer Token 校验）。无需新增单独的 sync/policy 路由。
5. 返回 Orbit 重新进入“账号与同步 → 同步内容”，确认错误消失，尝试调整普通提醒同步。强提醒仍默认关闭同步。测试“账号统一设置”及两台设备同步。
6. 更新接口 `/orbit/v1/updates/latest` 返回正式 Release 信息即可。需要发布更新时，把 release/v1.5.3 中的 APK、Windows ZIP 和 update-manifest.json、SHA256SUMS.txt 一起上传到 GitHub 正式 Release。

本目录只提供上传包，没有部署到线上。若部署失败，在该函数的日志中查看具体错误；上传页面与选项名称可能随控制台版本调整。
