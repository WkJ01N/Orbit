# Orbit CloudBase 同步后端

使用独立的测试环境部署 `orbit-sync-push`、`orbit-sync-pull` 和
`orbit-sync-delete-data`。运行时必须启用身份认证，数据库集合应用
`database.rules.json`，禁止客户端绕过云函数直接读写。

## 部署准备

1. 在 CloudBase 控制台创建环境并开启邮箱密码认证、注册验证码和重置密码邮件。
2. 创建 `orbit_sync_records`、`orbit_sync_changes`、`orbit_sync_state`、
   `orbit_sync_mutations` 四个文档集合。逐个将安全规则设为 `read: false`、
   `write: false`；云函数仍可通过服务端 SDK 访问。
3. 为 `orbit_sync_changes` 创建 `userId` 升序、`cursor` 升序的联合索引；为
   `orbit_sync_records`、`orbit_sync_state`、`orbit_sync_mutations` 创建
   `userId` 升序单字段索引。
4. 运行 `./prepare-functions.ps1`。它将共享实现复制到三个函数目录，使每个目录都可
   独立上传。每次修改 `orbit-sync-common/index.js` 后都要重新运行。
5. 复制 `cloudbaserc.example.json` 为 `cloudbaserc.json`，填入测试环境 ID，然后运行
   `tcb validate`、`tcb deploy --dry-run`，确认计划后执行 `tcb fn deploy --all`。
6. 在“云存储 → 权限设置（安全规则）”中选择自定义安全规则，将
   `storage.rules.json` 的内容完整粘贴并发布。该规则只允许已登录的非匿名用户读写
   自己上传的头像，其他用户无法读取原文件。

CloudBase 官方要求每个函数目录包含入口文件和自己的 `package.json`。这里的三个生成
目录都符合该结构，可以通过 CLI 或控制台分别部署。

Flutter 构建时传入环境：

```text
--dart-define=ORBIT_CLOUDBASE_ENV=<测试环境 ID>
--dart-define=ORBIT_CLOUDBASE_REGION=ap-shanghai
```

客户端不包含腾讯云管理密钥。部署完成后先以两个邀请测试账号验证跨账号隔离、离线冲突、
删除标记和账号注销，再为正式发布创建单独环境。生产环境需要配置邮箱认证模板、调用额度、
异常告警、隐私政策地址和运营者联系信息。

一次常规同步由 `orbit-sync-push` 同时完成上传和增量下载，上传按每 15 项共用一次数据库
事务，以减少移动网络往返与数据库调用。初期无需为此购买套餐；只有实际测试确认首次同步
仍长期受云函数冷启动影响时，再考虑为 push/pull 函数配置预置并发。

参考：[云函数目录与部署](https://docs.cloudbase.net/cli-v1/functions/deploy)、
[数据库安全规则](https://docs.cloudbase.net/database/security-rules)。
