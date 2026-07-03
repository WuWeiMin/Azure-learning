# Dynamics 365 Online — 自定义 Action 与自定义 API 演示

两个练习插件，帮你重新熟悉 D365 插件开发。

- **目标项目：** 已有的 `Company.CRM.Plugins`（.NET Framework 4.6.2）
- **目的：** 重新熟悉流程 *消息定义 → 插件读写参数 → 注册/触发*

---

## 文件放置位置

```
Company.CRM.Plugins/
└── Plugins/
    ├── CallExternalApiPlugin.cs        (已有的 MI 插件)
    └── Demo/
        ├── EchoActionPlugin.cs          ← 演示 1（自定义 Action）
        └── GreetingApiPlugin.cs         ← 演示 2（自定义 API）
```

在 `Plugins` 下新建文件夹 **`Demo`**，然后把下面两个文件加进去。

---

## 代码 vs 配置 — 核心认知

两个演示的插件**代码几乎一样**：读 `InputParameters`、写 `OutputParameters`。区别在于**如何定义和注册**。

| | 自定义 Action | 自定义 API |
|---|---|---|
| 插件代码 | 写法相同 | 写法相同 |
| 参数定义 | 在 Process 编辑器 | 在 Custom API 记录 |
| 插件关联 | PRT 注册 Step | `PluginType` 字段 |
| 是否需激活 | 需要 | 不需要 |

---

# 演示 1 — 自定义 Action

## 文件：`Plugins/Demo/EchoActionPlugin.cs`

```csharp
// Plugins/Demo/EchoActionPlugin.cs
using System;
using Microsoft.Xrm.Sdk;

namespace Company.CRM.Plugins.Plugins.Demo
{
    /// <summary>
    /// 绑定到自定义 Action: new_EchoAction
    /// 输入参数 InputText  (String)
    /// 输出参数 OutputText (String)
    /// </summary>
    public class EchoActionPlugin : IPlugin
    {
        public void Execute(IServiceProvider serviceProvider)
        {
            var context = (IPluginExecutionContext)
                serviceProvider.GetService(typeof(IPluginExecutionContext));
            var tracing = (ITracingService)
                serviceProvider.GetService(typeof(ITracingService));

            tracing.Trace($"EchoActionPlugin started. Message: {context.MessageName}");

            // 读取输入参数
            string inputText = context.InputParameters.Contains("InputText")
                ? context.InputParameters["InputText"] as string
                : string.Empty;

            tracing.Trace($"InputText = {inputText}");

            // 业务逻辑：回显 + 时间戳
            string result = $"Echo: {inputText} (processed at {DateTime.UtcNow:o})";

            // 设置输出参数
            context.OutputParameters["OutputText"] = result;

            tracing.Trace($"OutputText = {result}");
        }
    }
}
```

## 配置演示 1

### 第 1 步 — 创建 Action
- 打开解决方案 → **新建 → Process（流程）**
- **名称：** `Echo Action`
- **类别（Category）：** `Action`
- **实体（Entity）：** `None`（全局运行）
- 点击 **确定**

### 第 2 步 — 定义参数
在 Process 编辑器的 **Process Arguments（流程参数）** 区域，添加：

| 方向 | 名称 | 类型 |
|---|---|---|
| Input（输入） | `InputText` | String |
| Output（输出） | `OutputText` | String |

> 记下生成的唯一消息名（例如 `new_EchoAction`）。

### 第 3 步 — 激活
- 点击 Process 上的 **Activate（激活）**。
- 激活后消息（`new_EchoAction`）才能绑定插件。

### 第 4 步 — 注册插件 Step（Plugin Registration Tool）
- 若程序集尚未注册，先注册你签名后的程序集。
- **Register New Step：**
  - **Message：** `new_EchoAction`（Action 的唯一名）
  - **Primary Entity：** `none`
  - **Stage：** `PostOperation`
  - **Execution Mode：** `Synchronous`（同步）
- 保存。

### 第 5 步 — 测试（Web API）

```http
POST https://<orgURL>/api/data/v9.2/new_EchoAction
Content-Type: application/json

{
  "InputText": "hello"
}
```

预期响应：

```json
{
  "OutputText": "Echo: hello (processed at 2026-..-..T..:..:..Z)"
}
```

---

# 演示 2 — 自定义 API

## 文件：`Plugins/Demo/GreetingApiPlugin.cs`

```csharp
// Plugins/Demo/GreetingApiPlugin.cs
using System;
using Microsoft.Xrm.Sdk;

namespace Company.CRM.Plugins.Plugins.Demo
{
    /// <summary>
    /// 绑定到自定义 API: new_GreetingApi
    /// 请求参数 Name    (String)
    /// 响应属性 Message (String)
    /// </summary>
    public class GreetingApiPlugin : IPlugin
    {
        public void Execute(IServiceProvider serviceProvider)
        {
            var context = (IPluginExecutionContext)
                serviceProvider.GetService(typeof(IPluginExecutionContext));
            var tracing = (ITracingService)
                serviceProvider.GetService(typeof(ITracingService));

            tracing.Trace($"GreetingApiPlugin started. Message: {context.MessageName}");

            // 读取请求参数
            string name = context.InputParameters.Contains("Name")
                ? context.InputParameters["Name"] as string
                : "World";

            tracing.Trace($"Name = {name}");

            // 业务逻辑
            string message = $"Hello, {name}! Welcome to Dataverse Custom API.";

            // 设置响应属性
            context.OutputParameters["Message"] = message;

            tracing.Trace($"Message = {message}");
        }
    }
}
```

## 配置演示 2

### 第 1 步 — 注册签名程序集（Plugin Registration Tool）
- **Register New Assembly** → 选择你签名后的 DLL。
- 注册后，记下插件类型全名：
  ```
  Company.CRM.Plugins.Plugins.Demo.GreetingApiPlugin
  ```

### 第 2 步 — 创建 Custom API 记录
打开解决方案 → **新建 → 更多 → Custom API**。填写：

| 字段 | 值 |
|---|---|
| Unique Name | `new_GreetingApi` |
| Name | `GreetingApi` |
| Binding Type | `Global` |
| Is Function | `No`（No = POST；Yes = GET）|
| Plugin Type | `Company.CRM.Plugins.Plugins.Demo.GreetingApiPlugin` |

保存。

### 第 3 步 — 添加请求参数
新建 **Custom API Request Parameter**：

| 字段 | 值 |
|---|---|
| Unique Name | `Name` |
| Name | `Name` |
| Type | `String` |
| Is Optional | `No` |
| Custom API | `new_GreetingApi`（查找到第 2 步的记录）|

保存。

### 第 4 步 — 添加响应属性
新建 **Custom API Response Property**：

| 字段 | 值 |
|---|---|
| Unique Name | `Message` |
| Name | `Message` |
| Type | `String` |
| Custom API | `new_GreetingApi`（查找到第 2 步的记录）|

保存。

### 第 5 步 — 测试（Web API）

```http
POST https://<orgURL>/api/data/v9.2/new_GreetingApi
Content-Type: application/json

{
  "Name": "Alice"
}
```

预期响应：

```json
{
  "Message": "Hello, Alice! Welcome to Dataverse Custom API."
}
```

> 自定义 API **不需要**单独注册 Step。关联通过 Custom API 记录上的 **Plugin Type** 字段完成。

---

## 自定义 API — 参数类型选项（参考）

定义请求参数 / 响应属性时，可用的类型：

```
Boolean, DateTime, Decimal, Entity, EntityCollection,
EntityReference, Float, Integer, Money, Picklist, String,
StringArray, Guid
```

这两个演示用 `String` 就够了。

---

## 建议练习顺序

1. **先做自定义 API**（`GreetingApiPlugin`）
   - 关联更简单（只需设 Plugin Type 字段）
   - 无需激活步骤
2. **再做自定义 Action**（`EchoActionPlugin`）
   - 练习在 Process 编辑器定义参数
   - 练习在 PRT 注册 Step

两个跑通后，你就重新熟悉了完整流程：*消息定义 → 插件读写参数 → 注册/触发*。

---

## 编译与签名提醒

- 加入两个文件后 **Build（生成）**。你已有的 Post-Build `signtool` 步骤会自动签名程序集。
- 每次编译后，在 Plugin Registration Tool 里 **Update（更新）** 程序集，确保 Dataverse 拿到最新的签名 DLL。

---

## 常见坑

- **参数名区分大小写。** `"InputText"` ≠ `"inputtext"`。代码里的名称必须和参数定义完全一致。
- **自定义 Action：** 消息名来自 Process 的唯一名。注册 Step 前先确认。
- **自定义 API：** 插件不触发时，检查 **Plugin Type** 字段是否和命名空间 + 类名完全一致。
- **改完插件代码后，** 一定要在 Dataverse **Update（更新）** 程序集（不是只重新编译），否则跑的还是旧版本。
- 用 **Plugin Trace Log**（设置 → 插件跟踪日志）查看 `tracing.Trace` 的输出来调试。
