# Orbit CloudBase 后端

新客户端仅使用 CloudBase 邮箱认证完成登录、注册、验证码、密码重置与注销时的身份验证。验证成功后，`orbit-api` 签发 Orbit 自有设备会话；资料、头像与课表同步均通过公开 HTTP 路由访问。旧的三个同步函数继续保留，供 v1.5.0 及更早安装包使用。

CloudBase“最大会话数”可以保持默认值 **1**，无需购买更多 Refresh Token 会话额度。Orbit 自有会话最多允许 5 台设备，第 6 台设备登录时由 `orbit-api` 撤销创建时间最早的设备会话。

## 资源准备

1. 开启邮箱密码认证、注册验证码和密码重置邮件。
2. 创建以下六个集合，并应用 `database.rules.json`，禁止客户端直接访问：`orbit_sync_records`、`orbit_sync_changes`、`orbit_sync_state`、`orbit_sync_mutations`、`orbit_auth_sessions`、`orbit_user_profiles`。`orbit-api` 会在冷启动时幂等补建后两个集合，但数据库规则仍必须由管理员部署。
3. 为 `orbit_sync_changes` 创建 `userId`、`cursor` 升序联合索引；为其余按用户查询的同步集合创建 `userId` 升序索引。
4. 运行 `./prepare-functions.ps1`，把共享同步实现复制到四个可独立部署的函数目录。修改 `orbit-sync-common/index.js` 后必须重新运行。
5. 安装并登录 CloudBase CLI，然后在本目录执行配置校验、部署预检和四个函数的部署。`cloudbaserc.json` 已指向当前测试环境；自行部署时从 `cloudbaserc.example.json` 创建配置。
6. 在 HTTP 访问服务中创建公开路由：路径 `/orbit`，目标函数 `orbit-api`，关闭 CloudBase 网关鉴权，每 IP 限流 20 QPS。部署后以 CLI 返回的默认域名为准；腾讯云可能在环境 ID 后附加账号数字后缀。

验收集合时应查询数据库的集合清单；不要用空集合计数作为存在性判断，因为 MongoDB 对尚未创建的集合也可能返回计数 0。

关闭网关鉴权并不代表接口无鉴权。除会话刷新与退出外，每个 HTTP 请求都必须携带 Orbit Bearer Token；云函数还会逐次检查服务端设备会话注册表，因此退出或设备被淘汰会立即生效。

## 会话与数据安全

- Access Token 有效期 1 小时；Refresh Token 为 30 天滑动有效期。
- Refresh Token 每次使用后轮换，旧令牌仅保留 60 秒并发重试窗口。
- 服务端只保存 256 位随机令牌的 SHA-256 哈希，不保存令牌明文。
- `orbit_auth_sessions` 每个用户只有一份设备注册表；稳定设备 ID 也只保存哈希。
- `orbit_user_profiles` 是新客户端昵称、邮箱与头像文件 ID 的权威来源，首次签发会话时从 CloudBase 用户资料迁移。
- 同步记录继续使用原 CloudBase UID，因此升级无需迁移课表。
- 新头像由服务端 SDK 上传和删除；旧客户端兼容期内仍需保留现有云存储规则。

## 构建参数

```text
--dart-define=ORBIT_CLOUDBASE_ENV=<环境 ID>
--dart-define=ORBIT_CLOUDBASE_REGION=ap-shanghai
--dart-define=ORBIT_API_BASE_URL=https://<CLI 返回的默认域名>/orbit
```

当前发布环境使用：

```text
https://orbit-sync-beta-d6fjsl9220203313-1302156756.ap-shanghai.app.tcloudbase.com/orbit
```

## 验证清单

- CloudBase 最大会话数保持 1，Android 与 Windows 同时登录、长期刷新并双向同步。
- 同一安装重复登录不增加设备数；前 5 台有效，第 6 台使最早设备平稳退出。
- 单设备退出不影响其他设备；离线退出在下次联网后补发撤销。
- 密码重置撤销全部 Orbit 会话；普通断网不删除有效凭证或本机课表。
- 跨账号资料、头像与课表不可访问；请求体、分页和头像限制生效。

客户端不包含腾讯云管理密钥。生产环境还应配置邮件模板、额度告警、隐私政策地址与运营者联系方式。

## DDL 同步兼容性

DDL 使用独立的 `deadline` 同步实体，和课程继续共用原 CloudBase UID 及同步集合。支持 DDL 的客户端在 Orbit API 同步请求中声明 `supportsDeadline: true`。未声明此能力的旧安装包不会收到 DDL 实体；增量拉取仍按原始变更推进游标，快照即使过滤出空页也按原始记录数推进 `nextOffset`，避免重复拉取或漏页。

上线顺序：先运行 `prepare-functions.ps1`，再部署旧客户端使用的 `orbit-sync-pull` 兼容代码，最后部署 `orbit-api`。另外两个旧同步函数可与 pull 一并部署以保持共享代码一致。旧函数不要移除，现有公开安装包与 Release 保持不变，直到新安装包另行发布。
