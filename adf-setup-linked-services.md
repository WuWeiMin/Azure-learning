<!-- Target path: notes/azure/adf-setup-linked-services.md -->

# ADF 学习笔记：搭建 Linked Services + Datasets（A库 → B库同步项目）

## 背景

目标：用 Azure Data Factory 实现 A库 → B库 的数据同步，比对差异后更新B库，并向 Service Bus 发送变更通知。

本篇笔记记录第一步：搭建两个数据库的 Linked Service 和 Dataset，使用 **System-assigned Managed Identity** 认证（不用密码/连接串）。

数据库类型：A库、B库均为 Azure SQL Database（云端）。

---

## 前置条件

- [ ] ADF 实例已创建（Portal 建 Data Factory 资源，选 V2）
- [ ] A库、B库的 Server 名称、数据库名已知
- [ ] 有权限访问两个 SQL Server 设置 Azure AD 管理员

---

## 第一步：在两个 SQL Server 上开启 Azure AD 管理员

1. Azure Portal → 找到 A库所在的 **SQL Server**（注意是 Server 资源，不是 Database）
2. 左侧菜单 → Settings → **Microsoft Entra ID**
3. 点击 "Set admin"，设置一个 Entra ID 账号作为管理员（可以用你自己的账号）
4. 保存

对 B库所在的 Server 重复同样操作。

> 这一步的目的：只有 Entra ID 管理员账号才能在数据库里创建"外部提供程序用户"（也就是给 ADF 的托管身份开权限）。

---

## 第二步：给 ADF 的托管身份开数据库权限

用 SSMS 或 Azure Portal 里的 Query Editor，以 **Entra ID 管理员身份**连接数据库，执行以下 SQL。

### 在 A库执行（只需要读权限）

```sql
-- Target path: notes/azure/adf-setup-sql.sql
-- Run this against Database A, connected as the Entra ID admin
CREATE USER [your-adf-name] FROM EXTERNAL PROVIDER;
ALTER ROLE db_datareader ADD MEMBER [your-adf-name];
```

### 在 B库执行（需要读写权限，因为要 Upsert）

```sql
-- Target path: notes/azure/adf-setup-sql.sql
-- Run this against Database B, connected as the Entra ID admin
CREATE USER [your-adf-name] FROM EXTERNAL PROVIDER;
ALTER ROLE db_datareader ADD MEMBER [your-adf-name];
ALTER ROLE db_datawriter ADD MEMBER [your-adf-name];
```

> `[your-adf-name]` 替换成你的 ADF 资源名称。ADF 的系统托管身份在 Azure AD 里显示的名字就是 ADF 实例名本身，不需要额外创建。

**踩坑提示**：如果执行 `CREATE USER ... FROM EXTERNAL PROVIDER` 报错找不到该主体，通常是因为：
- ADF 实例还没有启用 System-assigned Managed Identity（默认是启用的，可以在 ADF 资源 → Identity 里确认）
- 或者名称拼写和 ADF 实例名不完全一致（区分大小写敏感度视情况而定，建议直接复制 ADF 资源名）

---

## 第三步：在 ADF Studio 里创建 Linked Service

1. 打开 ADF Studio（Author 界面，🖊️ 图标）
2. 左侧 → **Manage**（🧰 图标）→ Linked services → **New**
3. 搜索并选择 **Azure SQL Database**
4. 填写：
   - Name: `LS_SqlDB_A`
   - Server name: A库的 Server 全名（如 `xxx.database.windows.net`）
   - Database name: A库的数据库名
   - Authentication type: **System Assigned Managed Identity**
5. 点击 **Test connection**，确认成功
6. Create 保存

重复以上步骤，创建：
   - Name: `LS_SqlDB_B`
   - 指向 B库

---

## 第四步：创建 Datasets

1. Author 界面 → Datasets → **New dataset**
2. 选择 **Azure SQL Database**
3. 关联 Linked Service 选 `LS_SqlDB_A`
4. Dataset 命名建议：`DS_SqlDB_A_<表名>`（例如同步订单表就叫 `DS_SqlDB_A_Orders`）
5. Table name 选择/填入对应的实际表名
6. Create 保存

重复操作，创建关联 `LS_SqlDB_B` 的 Dataset，命名 `DS_SqlDB_B_<表名>`。

---

## 完成检查清单

- [ ] A库、B库 Server 都设置了 Entra ID 管理员
- [ ] A库执行了 db_datareader 权限授予 SQL
- [ ] B库执行了 db_datareader + db_datawriter 权限授予 SQL
- [ ] `LS_SqlDB_A` Linked Service 创建成功，Test connection 通过
- [ ] `LS_SqlDB_B` Linked Service 创建成功，Test connection 通过
- [ ] `DS_SqlDB_A_<表名>` Dataset 创建成功
- [ ] `DS_SqlDB_B_<表名>` Dataset 创建成功

---

## 下一步预告

基础打好之后，下一篇笔记会讲：
1. 水位线（Watermark）增量读取设计
2. Data Flow 里用 Join + Alter Row 做比对更新（Upsert）
3. 用 Azure Function Activity + Managed Identity 向 Service Bus 发送变更通知
