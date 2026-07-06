<!-- 目标路径: notes/azure/adf/adf-sync-a-to-b-dual-db.md -->

# ADF 双库数据同步完整指导(A 库 → B 库)

> 任务:从 A 库抽取数据到 B 库,与目标表 `aia_batchcycleconfig` 比对,有差异则更新,并将每条变更推送到 Azure Service Bus。
>
> Pipeline 结构:
> `CP_AtoStaging(Copy) → SP_MergeSync(MERGE比对更新) → LK_GetChanges(读变更) → FE_Changes [ WEB_SendToSB(发消息) → SP_MarkSent(标记已发) ]`
>
> 当前状态说明:Service Bus 资源未到位时,`WEB_SendToSB` 与 `SP_MarkSent` 保持 **Deactivated(停用)**,不影响同步主链路的发布与调试。

---

## 0. 占位符与字段映射

**全文占位符(开始前替换):**

| 占位符 | 含义 | 示例 |
|---|---|---|
| `{{A库源表}}` | A 库中的源表 | dbo.onedata_batchcycle |
| `{{LS_A}}` | 指向 A 库的 Linked Service 名称 | ls_sqldb_a |
| `{{LS_B}}` | 指向 B 库的 Linked Service 名称 | ls_sqldb_b |
| `{{命名空间}}` | Service Bus 命名空间 | mysb001 |
| `{{队列名}}` | Service Bus 队列 | sync-changes |

**字段映射:**

| A 库源表 | B 库 aia_batchcycleconfig | 角色 |
|---|---|---|
| application_name | aia_name | 关联键(JOIN 条件) |
| previous_cycle_date | aia_lastcycledate | 比对 + 更新 |
| current_cycle_date | aia_currentcycledate | 比对 + 更新 |
| next_cycle_date | aia_nextcycledate | 比对 + 更新 |
| before_previous_cycle_date | (不同步) | — |
| — | aia_excutecycledate | 不映射,保持原值 |
| — | aia_id | 目标主键,INSERT 时生成 |

---

## 第 1 步:B 库建 staging 表(SSMS)

staging 表是 A 库数据在 B 库的"落脚点",每次运行先清空再全量灌入:

```sql
-- Staging table: snapshot of source data copied from DB A.
-- Truncated and reloaded on every pipeline run (idempotent by design).
CREATE TABLE dbo.staging_batchcycle (
    application_name    NVARCHAR(200) NOT NULL,
    previous_cycle_date DATETIME2     NULL,
    current_cycle_date  DATETIME2     NULL,
    next_cycle_date     DATETIME2     NULL
);
```

---

## 第 2 步:B 库建变更日志表(SSMS,已建过可跳过)

```sql
-- Change log table: records every INSERT/UPDATE produced by the MERGE.
-- IsSent flag enables idempotent message delivery (safe re-runs).
CREATE TABLE dbo.SyncChangeLog (
    LogId               INT IDENTITY(1,1) PRIMARY KEY,
    ChangeType          NVARCHAR(10)  NOT NULL,          -- INSERT / UPDATE
    AiaName             NVARCHAR(200) NOT NULL,          -- business key of the changed row
    NewLastCycleDate    DATETIME2     NULL,
    NewCurrentCycleDate DATETIME2     NULL,
    NewNextCycleDate    DATETIME2     NULL,
    ChangedOn           DATETIME2     NOT NULL DEFAULT SYSUTCDATETIME(),
    IsSent              BIT           NOT NULL DEFAULT 0
);
```

---

## 第 3 步:创建/更新存储过程(SSMS)

### 3.1 同步存储过程(USING 改为 staging 表)

```sql
CREATE OR ALTER PROCEDURE dbo.usp_Sync_BatchCycleConfig
AS
BEGIN
    SET NOCOUNT ON;

    MERGE dbo.aia_batchcycleconfig AS t
    USING dbo.staging_batchcycle AS s
        ON t.aia_name = s.application_name

    -- Update only when at least one mapped column actually differs.
    -- ISNULL guards make NULL-vs-NULL compare as "equal".
    WHEN MATCHED AND (
           ISNULL(t.aia_lastcycledate,    '1900-01-01') <> ISNULL(s.previous_cycle_date, '1900-01-01')
        OR ISNULL(t.aia_currentcycledate, '1900-01-01') <> ISNULL(s.current_cycle_date,  '1900-01-01')
        OR ISNULL(t.aia_nextcycledate,    '1900-01-01') <> ISNULL(s.next_cycle_date,     '1900-01-01')
    ) THEN
        UPDATE SET
            t.aia_lastcycledate    = s.previous_cycle_date,
            t.aia_currentcycledate = s.current_cycle_date,
            t.aia_nextcycledate    = s.next_cycle_date

    -- Insert rows that exist in source but not in target.
    -- If aia_id is an IDENTITY column, remove aia_id and NEWID() below.
    WHEN NOT MATCHED BY TARGET THEN
        INSERT (aia_id, aia_name, aia_lastcycledate, aia_currentcycledate, aia_nextcycledate)
        VALUES (NEWID(), s.application_name, s.previous_cycle_date, s.current_cycle_date, s.next_cycle_date)

    -- Capture actual changes into the change log for downstream messaging.
    OUTPUT
        $action,
        inserted.aia_name,
        inserted.aia_lastcycledate,
        inserted.aia_currentcycledate,
        inserted.aia_nextcycledate
    INTO dbo.SyncChangeLog
        (ChangeType, AiaName, NewLastCycleDate, NewCurrentCycleDate, NewNextCycleDate);
END
GO
```

### 3.2 标记已发送存储过程(已建过可跳过)

```sql
CREATE OR ALTER PROCEDURE dbo.usp_MarkChangeSent
    @LogId INT
AS
BEGIN
    SET NOCOUNT ON;
    -- Called per message after a successful send to Service Bus.
    UPDATE dbo.SyncChangeLog SET IsSent = 1 WHERE LogId = @LogId;
END
GO
```

---

## 第 4 步:创建 Dataset(ADF Studio)

共需三个 Dataset(`ds_sqldb_b` 已有则只建前两个):

| Dataset 名 | Linked Service | Table | Import schema | 用途 |
|---|---|---|---|---|
| `ds_source_a` | {{LS_A}} | {{A库源表}} | From connection(可选) | Copy 的 Source |
| `ds_staging_b` | {{LS_B}} | dbo.staging_batchcycle | From connection | Copy 的 Sink |
| `ds_sqldb_b` | {{LS_B}} | None(留空) | None | Lookup 用 |

操作:**Author → Datasets → + → New dataset → Azure SQL Database**(若 Linked Service 指向 Managed Instance,则选 Azure SQL Managed Instance 类型)→ 按上表配置。

> 若 schema 导入报 interactive authoring 错误,把 Import schema 选 None 即可,不影响运行。

---

## 第 5 步:Pipeline 加入 Copy Activity(ADF Studio)

打开 `pl_sync_batchcycle` 主画布:

1. Activities 搜索 `copy`,把 **Copy data** 拖到 `SP_MergeSync` 左侧,命名 `CP_AtoStaging`
2. 从 CP_AtoStaging 拉**绿色箭头**连到 SP_MergeSync
3. **Source** 标签:
   - Source dataset:`ds_source_a`
   - Use query:选 **Query**,只抽需要的列:

```sql
-- Pull only the columns required by the sync.
SELECT application_name, previous_cycle_date, current_cycle_date, next_cycle_date
FROM {{A库源表}};
```

4. **Sink** 标签:
   - Sink dataset:`ds_staging_b`
   - Write behavior:Insert
   - **Pre-copy script**(关键,保证 staging 每次都是全新快照):

```sql
TRUNCATE TABLE dbo.staging_batchcycle;
```

5. **Mapping** 标签:点 **Import schemas**,确认四列一一对应(同名会自动对齐)

最终主画布链路:

```
CP_AtoStaging → SP_MergeSync → LK_GetChanges → FE_Changes
```

`SP_MergeSync` 的 Settings 无需改动(存储过程名不变,内部逻辑已在第 3 步更新)。

---

## 第 6 步:Lookup / ForEach 配置核对(已配好则跳过)

**LK_GetChanges**(Lookup):

- Source dataset:`ds_sqldb_b`
- Use query = Query,**First row only 不勾选**:

```sql
-- Fetch unsent changes; dates converted to ISO 8601 strings for JSON payload.
SELECT LogId, ChangeType, AiaName,
       CONVERT(VARCHAR(33), NewLastCycleDate,    126) AS LastCycleDate,
       CONVERT(VARCHAR(33), NewCurrentCycleDate, 126) AS CurrentCycleDate,
       CONVERT(VARCHAR(33), NewNextCycleDate,    126) AS NextCycleDate,
       CONVERT(VARCHAR(33), ChangedOn,           126) AS ChangedOn
FROM dbo.SyncChangeLog
WHERE IsSent = 0
ORDER BY LogId;
```

**FE_Changes**(ForEach):

- Items:`@activity('LK_GetChanges').output.value`
- Sequential:勾选(调试期)

---

## 第 7 步:Service Bus 环节(资源到位后再做)

当前 `WEB_SendToSB` 和 `SP_MarkSent` 处于停用状态。资源到位后:

### 7.1 生成 SAS Token(本机 PowerShell)

需要:命名空间、队列名、具有 Send 权限的 Policy 名称和 Key。

```powershell
# Generate a long-lived SAS token for Service Bus REST API.
# Do NOT commit the real Key to GitHub. Get it from the environment owner
# or Azure Portal > Service Bus > Shared access policies.
Add-Type -AssemblyName System.Web
$URI     = "{{命名空间}}.servicebus.windows.net/{{队列名}}"
$KeyName = "<POLICY_NAME>"    # e.g. RootManageSharedAccessKey
$Key     = "<POLICY_KEY>"     # placeholder - never hardcode the real key
$Expires = ([DateTimeOffset]::Now.ToUnixTimeSeconds()) + 31536000   # 1 year
$SigStr  = [System.Web.HttpUtility]::UrlEncode($URI) + "`n" + $Expires
$HMAC    = New-Object System.Security.Cryptography.HMACSHA256
$HMAC.Key = [Text.Encoding]::UTF8.GetBytes($Key)
$Sig     = [Convert]::ToBase64String($HMAC.ComputeHash([Text.Encoding]::UTF8.GetBytes($SigStr)))
"SharedAccessSignature sr=" + [System.Web.HttpUtility]::UrlEncode($URI) + "&sig=" + [System.Web.HttpUtility]::UrlEncode($Sig) + "&se=" + $Expires + "&skn=" + $KeyName
```

### 7.2 激活并配置两个 Activity

右键 `WEB_SendToSB` → **Activate**,配置:

| 项 | 值 |
|---|---|
| URL | `https://{{命名空间}}.servicebus.windows.net/{{队列名}}/messages` |
| Method | POST |
| Header: Authorization | 7.1 生成的完整 SAS Token 整串 |
| Header: Content-Type | `application/json` |
| Body | `@string(item())` |

右键 `SP_MarkSent` → **Activate**,核对:

| 项 | 值 |
|---|---|
| Linked service | {{LS_B}} |
| Stored procedure name | `dbo.usp_MarkChangeSent` |
| 参数 LogId (Int32) | `@item().LogId` |

激活后 **Publish all**。

---

## 第 8 步:端到端测试

### 8.1 准备差异数据(在 A 库执行)

```sql
-- Scenario 1 (UPDATE): shift a date on an existing application.
UPDATE {{A库源表}}
SET next_cycle_date = DATEADD(DAY, 7, next_cycle_date)
WHERE application_name = '<PICK_AN_EXISTING_NAME>';

-- Scenario 2 (INSERT): a record that does not exist in target DB B.
INSERT INTO {{A库源表}} (application_name, previous_cycle_date, current_cycle_date, next_cycle_date)
VALUES ('TEST_APP_001', '2026-06-01', '2026-07-01', '2026-08-01');

-- Scenario 3 (SKIP): all untouched rows should produce no change log entries.
```

### 8.2 运行

Pipeline 画布 → **Debug**,预期所有 Activity 绿色。

### 8.3 验证(在 B 库执行)

```sql
-- Check 1: staging holds the latest snapshot from DB A.
SELECT COUNT(*) AS staging_rows FROM dbo.staging_batchcycle;

-- Check 2: target table updated / inserted as expected.
SELECT * FROM dbo.aia_batchcycleconfig
WHERE aia_name IN ('<PICK_AN_EXISTING_NAME>', 'TEST_APP_001');

-- Check 3: exactly the changed rows are logged (1 UPDATE + 1 INSERT).
SELECT * FROM dbo.SyncChangeLog ORDER BY LogId DESC;
```

### 8.4 幂等性验证(必做)

不改任何数据,**再 Debug 一次**:

```sql
-- Expected: no new unsent rows after the second run.
SELECT COUNT(*) AS unsent_rows FROM dbo.SyncChangeLog WHERE IsSent = 0;
```

第二次运行零新增 = 比对逻辑正确。

### 8.5 消息验证(Service Bus 激活后)

- Debug 后日志应全部 `IsSent = 1`
- 有权限的话用 Service Bus Explorer 查看队列消息,消息体形如:

```json
{"LogId":12,"ChangeType":"UPDATE","AiaName":"AppA","LastCycleDate":"2026-06-01T00:00:00","CurrentCycleDate":"2026-07-01T00:00:00","NextCycleDate":"2026-08-01T00:00:00","ChangedOn":"2026-07-06T02:11:05"}
```

---

## 第 9 步:定时触发器

1. 画布顶部 **Add trigger → New/Edit → + New**
2. Type:Schedule;Recurrence:按需(如每 15 分钟)
3. OK → **Publish all**(发布后才生效)

---

## 常见错误速查

| 现象 | 原因 | 处理 |
|---|---|---|
| Copy 报 Cannot bulk load / TRUNCATE 权限 | ADF 身份缺 staging 表权限 | 授予 db_datawriter + ALTER 或 db_ddladmin |
| Copy 的 Mapping 对不上 | 列名大小写/多余列 | Source 用 Query 精确取四列,重新 Import schemas |
| MERGE 报重复键 | A 库 application_name 有重复 | MERGE 要求源侧关联键唯一,Source Query 先去重 |
| MERGE 报 aia_id 不能为 NULL | aia_id 类型与 INSERT 写法不符 | IDENTITY 则删掉 aia_id/NEWID();GUID 则保留 |
| Web 401 | SAS Token 过期/拼错/无 Send 权限 | 重新生成,整串完整粘贴 |
| Web 超时/DNS 失败 | 命名空间或队列名错;或公司网络拦截 | 核对 URL;公司网络优先排查代理/防火墙 |
| Lookup 报 interactive authoring | Managed VNet IR 交互功能未开 | Dataset Table 设 None;或 IR 开 Interactive authoring |
| 日志表膨胀 | 正常积累 | 定期清理:`DELETE FROM dbo.SyncChangeLog WHERE IsSent = 1 AND ChangedOn < DATEADD(DAY, -30, SYSUTCDATETIME());` |

---

## 附:架构说明(将来接入 D365 时的位置)

```
DB A (source)
   │  Copy Activity (snapshot)
   ▼
DB B staging_batchcycle
   │  MERGE (compare & upsert) ──► SyncChangeLog (audit + IsSent)
   ▼                                      │ Lookup + ForEach
aia_batchcycleconfig                      ▼
                                   Azure Service Bus Queue
                                          │ (future) subscriber
                                          ▼
                                   D365 Plugin / Azure Function
```

将来 D365 侧消费消息时,只需在 Service Bus 后面挂订阅方,ADF 侧零改动。

---

*版本:双库版 v2,2026-07-06。替换占位符后按序执行。*
