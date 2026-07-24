1.2.3
│ │ │
│ │ └── Patch（补丁版本）
│ └──── Minor（次版本）
└────── Major（主版本）

表示：

* 修复 Bug
* 修复安全漏洞
* 优化性能
* 不增加新功能
* 不影响已有功能（向后兼容）

例如：

* 修复登录失败
* 修复 SQL 查询错误
* 修复 UI 显示问题

如果你们团队采用 Conventional Commits，一般对应：

fix(login): prevent null reference exception

表示：

增加新功能，但不会影响以前的代码。

例如：

* 新增导出 Excel
* 新增 API
* 新增一个页面
* 新增一个 Dataverse Entity
* 新增一个 PCF 控件

已有功能仍然可以正常工作。

通常对应：
fix(login): prevent null reference exception
feat(order): support batch import


表示：

有破坏性变更（Breaking Change）。

也就是说：

升级以后，旧代码可能不能用了，需要修改。

例如：

* 删除 API
* 修改 API 参数
* 删除数据库字段
* 修改返回 JSON 结构
* 删除插件
* 删除配置项
* 重构导致旧接口失效


feat!: change authentication model


1.0.0   第一个正式版本

1.0.1   修复一个Bug
1.0.2   再修复一个Bug

1.1.0   新增导出PDF

1.1.1   修复PDF乱码

1.2.0   新增邮件通知

1.2.1   修复邮件发送失败

2.0.0   API全部升级，不兼容旧版本


当前版本

新版本

意味着什么

是否通常可以放心升级

1.2.3

1.2.4

修 Bug

✅ 基本可以

1.2.3

1.3.0

新增功能

✅ 一般可以

1.2.3

2.0.0

有破坏性修改

⚠️ 需要评估

