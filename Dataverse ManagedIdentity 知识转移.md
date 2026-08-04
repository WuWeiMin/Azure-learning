# Dataverse Plugin Managed Identity — 知识转移文档

> **项目**：Dynamics 365 Online 插件通过 Managed Identity 访问受保护资源
> **环境**：AIA-AICLAIMS-MY-DEV (`aia-aiclaims-my-dev.crm5.dynamics.com`)
> **状态**：✅ 端到端验证成功
> **完成日期**：2026-08-03

---

## 1. 概述 Overview

本文档记录 Dataverse 插件使用 **Managed Identity (MI)** 获取 AAD token 并访问受保护资源的完整实施过程。

### 核心价值
插件无需存储任何 client secret 或证书密码，即可安全地向 Azure AD 保护的资源（如 Dataverse、Microsoft Graph、外部 API）进行认证。基于 **Federated Identity Credential (FIC)** 机制实现。

### 功能状态
Dataverse Plugin Managed Identity 已于 **2025-06-15 正式发布 (GA)**，可用于生产环境。

---

## 2. 信任链架构 Trust Chain

```
Azure App Registration (sp-my01-sea-d-ripple01-claimmodapp)
  ├── Federated Identity Credential (FIC)
  │     ├── Issuer:  https://login.microsoftonline.com/{tenantId}/v2.0
  │     └── Subject: /eid1/c/pub/t/{encodedTenantId}/.../h/{certSHA256}
  └── Application ID: 9F3D07CA-381E-43FC-8BEF-76DD03B460D6
        │
        ↕ 通过 Dataverse Managed Identity 记录连接
        │
Dataverse Environment
  ├── Managed Identity 记录 (0bb91e27-1d0c-4a60-973c-ed810d9695ff)
  ├── Plugin Assembly (cadc6113-ec1d-43ca-a0d7-62e7f3571864)
  │     └── 已用证书签名 + 关联 MI 记录
  └── Application User (App 作为组织成员 + 安全角色)
```

**关键理解**：
- 插件运行时通过 `IManagedIdentityService.AcquireToken(scopes)` 获取 token
- Dataverse 用 FIC 机制向 Azure AD 换取 token
- 证书的 SHA-256 是 FIC Subject 与插件程序集之间的"指纹"绑定

---

## 3. 关键值清单 Key Values

> ⚠️ 以下为本环境的真实值，请妥善保管，勿泄露到公开渠道。

| 项目 | 值 |
|---|---|
| **Application (Client) ID** | `9F3D07CA-381E-43FC-8BEF-76DD03B460D6` |
| **Tenant ID** | `7f2c1900-9fd4-4b89-91d3-79a649996f0a` |
| **Environment ID** | `59b86021-2790-4a26-b386-15823676bbf4` |
| **Organization ID** | `7ec158d7-95bb-4e89-bb85-4b54cf17806c` |
| **encodedTenantId** | `ABksf9SfiUuR03mmSZlvCg` |
| **Managed Identity 记录 ID** | `0bb91e27-1d0c-4a60-973c-ed810d9695ff` |
| **Plugin Assembly ID** | `cadc6113-ec1d-43ca-a0d7-62e7f3571864` |
| **证书 SHA-1 (Thumbprint)** | `EC61C07E93C0F9B97E9001864BE990530237EFCC` |
| **证书 SHA-256** | `226154c9d2662c1c5fbc213c47d61aa2b49f0d8d51dab6470084a09da46eea00` |
| **证书有效期** | 至 2029-06-14 |
| **组织 URL** | `https://aia-aiclaims-my-dev.crm5.dynamics.com` |
| **App 名称** | `sp-my01-sea-d-ripple01-claimmodapp` |

---

## 4. 实施步骤 Implementation Steps

### Step 1 — 生成 X.509 证书

⚠️ **重要**：MI 要求插件程序集用 **X.509 证书 (Authenticode)** 签名，`.snk` 强名称签名不满足要求（`.snk` 没有 Thumbprint）。两种签名可并存。

```bash
# Git Bash — 一步生成私钥 + 自签名证书
# 注意 MSYS_NO_PATHCONV=1 避免 Git Bash 路径转换问题
MSYS_NO_PATHCONV=1 openssl req -x509 -newkey rsa:2048 \
  -keyout private.key \
  -out certificate.crt \
  -days 1095 \
  -nodes \
  -subj "/CN=MyPlugin-Test/O=MyOrg-AIA/C=CN"

# 转换为 PFX（Windows/.NET 使用），密码从环境变量读取
openssl pkcs12 -export \
  -out plugin.pfx \
  -inkey private.key \
  -in certificate.crt \
  -passout env:PfxPassword
```

**获取证书哈希**：

```bash
# SHA-256（FIC Subject 用，注意是 SHA-256 不是 SHA-1）
openssl x509 -in certificate.crt -fingerprint -sha256 -noout

# 或转成 DER 格式的 .cer 后用 CertUtil（结果应一致）
openssl x509 -in certificate.crt -outform DER -out certificate.cer
certutil -hashfile certificate.cer SHA256
```

> ⚠️ **PEM vs DER**：`openssl x509 -fingerprint` 对 PEM/DER 都算 DER 内容的哈希（正确）；`certutil -hashfile` 对 PEM 文件算的是文件字节（可能不对），务必对 DER 格式的 .cer 使用。

---

### Step 2 — 程序集签名 Assembly Signing

在 Visual Studio 项目属性 → **生成事件 → 生成后事件命令行** 配置自动签名：

```
signtool sign /f "$(ProjectDir)plugin.pfx" /p "%PfxPassword%" /fd SHA256 /tr http://timestamp.sectigo.com /td SHA256 "$(TargetPath)"
```

**要点**：
- 密码用 `%PfxPassword%` 环境变量，不要明文
- signtool 找不到（错误 9009）时，把 Windows SDK 的 x64 目录加入 PATH：
  `C:\Program Files (x86)\Windows Kits\10\bin\10.0.26100.0\x64`
- 加时间戳 (`/tr`) 保证签名长期有效（但对 MI 场景仍需证书轮换）

**验证签名**：

```bash
# signtool 验证（自签名会有 "not trusted" 警告，属正常，Dataverse 只比对 Thumbprint）
signtool verify /pa /v "...\Company.CRM.Plugins.dll"

# 或用 certutil 确认已签名（看到 CMSG_SIGNED 即已签名）
certutil -dump "...\Company.CRM.Plugins.dll"
```

---

### Step 3 — 配置 FIC (Federated Identity Credential)

在 Azure Portal → App Registration → **Certificates & secrets → Federated credentials → Add credential**，选择 **Other issuer** 场景。

> ⚠️ **格式来自 Microsoft Learn 官方文档**（很多社区博客的旧格式已过时，会导致 `AADSTS700213` 错误）。

**Issuer**：
```
https://login.microsoftonline.com/7f2c1900-9fd4-4b89-91d3-79a649996f0a/v2.0
```

**Type**：`Explicit subject identifier`

**Value (Subject)**（本环境实际值）：
```
/eid1/c/pub/t/ABksf9SfiUuR03mmSZlvCg/a/qzXoWDkuqUa3l6zM5mM0Rw/n/plugin/e/59b86021-2790-4a26-b386-15823676bbf4/h/226154c9d2662c1c5fbc213c47d61aa2b49f0d8d51dab6470084a09da46eea00
```

**Audience**：`api://AzureADTokenExchange`（默认）

#### Subject 各段说明

| 段 | 含义 | 是否可变 |
|---|---|---|
| `/eid1` | 版本 | 固定 |
| `/c/pub` | 公有云（Geo=APAC 属公有云）| 固定 |
| `/t/{encodedTenantId}` | 编码后的 Tenant ID | 随租户 |
| `/a/qzXoWDkuqUa3l6zM5mM0Rw` | 内部固定值 | **勿改** |
| `/n/plugin` | 插件组件 | 固定 |
| `/e/{environmentId}` | 环境 ID（带横线完整 GUID）| 随环境 |
| `/h/{sha256}` | 证书 SHA-256 | 随证书 |

#### encodedTenantId 计算方法

```powershell
# GUID → 字节（.NET 小端序）→ Base64URL
$tenantId = '7f2c1900-9fd4-4b89-91d3-79a649996f0a'
$bytes = [System.Guid]::Parse($tenantId).ToByteArray()
$b64 = [System.Convert]::ToBase64String($bytes)
$b64url = $b64.TrimEnd('=').Replace('+','-').Replace('/','_')
Write-Host $b64url
# 结果：ABksf9SfiUuR03mmSZlvCg
```

---

### Step 4 — 部署签名程序集

用 **Plugin Registration Tool** 注册签名后的 DLL：
- Isolation Mode: **Sandbox**（Online 必须）
- Location: **Database**（Online 必须）
- 记录生成的 **Plugin Assembly ID**：`cadc6113-ec1d-43ca-a0d7-62e7f3571864`

---

### Step 5 — 创建并关联 Managed Identity 记录

用 **Dataverse REST Builder (DRB)** 或 REST 客户端。DRB 里 POST 对应 **Create**，PATCH 对应 **Update**。

**请求 1 — 创建 MI 记录 (Create)**：

```http
POST https://aia-aiclaims-my-dev.crm5.dynamics.com/api/data/v9.0/managedidentities

{
  "applicationid":     "9F3D07CA-381E-43FC-8BEF-76DD03B460D6",
  "managedidentityid": "0bb91e27-1d0c-4a60-973c-ed810d9695ff",
  "credentialsource":  2,
  "subjectscope":      1,
  "tenantid":          "7f2c1900-9fd4-4b89-91d3-79a649996f0a",
  "version":           2
}
```

字段说明：
- `applicationid`：App Registration 的 Client ID
- `credentialsource: 2`：Managed client
- `subjectscope: 1`：Environment Scope（同租户，多环境场景适用）
- `version: 2`：新版 MI 记录格式

**请求 2 — 关联到程序集 (Update)**：

```http
PATCH https://aia-aiclaims-my-dev.crm5.dynamics.com/api/data/v9.0/pluginassemblies(cadc6113-ec1d-43ca-a0d7-62e7f3571864)

{
  "managedidentityid@odata.bind": "/managedidentities(0bb91e27-1d0c-4a60-973c-ed810d9695ff)"
}
```

> 必须先 Create 再 Update（PATCH 要引用 MI 记录 GUID）。

---

### Step 6 — 注册插件 Step

在 Plugin Registration Tool 里给 `CallExternalApiPlugin` 注册 Step：
- Message: `Create`
- Primary Entity: `demo_equipmenttype`
- Stage: `PostOperation`
- Mode: `Synchronous`

---

### Step 7 — 配置应用用户 Application User

⚠️ **访问 Dataverse 资源必须配置此步**（否则报 403 "not a member of the organization"）。

路径：**Power Platform Admin Center → Environments → AIA-AICLAIMS-MY-DEV → Settings → Users + permissions → Application users → + New app user**

1. Add an app → 搜索 `9F3D07CA-381E-43FC-8BEF-76DD03B460D6`
2. Business unit：选根业务部门 (AHS CRM)
3. Security roles：选 **System Administrator**（测试用）

> ⚠️ **坑**：不要选 "Support User" 角色——它是系统内部角色，无法分配给用户（会报 "The Support User role cannot be assigned"）。选 System Administrator 或其他可分配的角色。

---

### Step 8 — 验证 Validation

创建一条 `demo_equipmenttype` 记录触发插件，查看结果。

**成功标志**：
```
Access token acquired via Managed Identity.        ← MI 取到 token
Calling external API: /api/data/v9.2/WhoAmI
External API call succeeded.                        ← 真实 Dataverse 调用成功
```

---

## 5. 代码要点 Code Notes

### 获取 token 与调用

```csharp
// 插件入口获取 IManagedIdentityService
var managedIdentityService = (IManagedIdentityService)
    serviceProvider.GetService(typeof(IManagedIdentityService));

// 取 token
var scopes = new List<string> { "https://aia-aiclaims-my-dev.crm5.dynamics.com/.default" };
string accessToken = managedIdentityService.AcquireToken(scopes);
```

### 关键代码要点

| 要点 | 说明 |
|---|---|
| **TLS 1.2** | .NET Framework 4.6.2 必须显式启用：`ServicePointManager.SecurityProtocol = SecurityProtocolType.Tls12;` |
| **GET vs POST** | WhoAmI 等 Function 端点必须用 `GetAsync`，用 POST 会报 405/404 |
| **异步调用** | 插件是同步上下文，用 `.GetAwaiter().GetResult()` |
| **scope 格式** | `<资源根地址>/.default`，如 Dataverse 用 `https://<org>.crm5.dynamics.com/.default` |
| **Profiler 局限** | Plugin Profiler 本地调试时 `IManagedIdentityService` 返回 null（模拟环境不支持），只能靠真实环境 + tracing 验证 |
| **Sandbox 限制** | 单程序集部署最简；多程序集需 ILRepack 合并 |

### scope 说明

`https://<资源>/.default` 是 OAuth scope，**不是网页 URL**（浏览器打开会 404，属正常）。

---

## 6. 错误码对照 Troubleshooting

验证过程中错误码的演进，正好反映排查进度：

| 错误 | 含义 | 说明 / 解决 |
|---|---|---|
| `AADSTS700213` | 无匹配的 FIC 记录 | FIC 格式错误——检查 Issuer、encodedTenantId、SHA-256（非 SHA-1）|
| **401** Unauthorized | token 无效 | Dataverse/资源不认 token |
| **403** "not a member" | token 有效但非组织成员 | **配置应用用户**（Step 7）|
| **404** No HTTP resource | URL 路径不对 | token 有效且已是成员，检查 URL 拼写 / 用 GET |
| **405** Method Not Allowed | HTTP 方法不对 | Function 端点改用 GET |
| **9009** (build) | 找不到 signtool | 把 Windows SDK x64 目录加入 PATH |

> **关键洞察**：403 vs 401 的区别很重要——**403 说明 token 已被成功验证**（身份被识别，只是无权限），这本身就证明 token 有效。403 → 404 → 200 的演进，说明权限问题已解决，剩下是 URL 技术细节。

---

## 7. 证书轮换 Certificate Rotation

⚠️ **证书过期是长期最大风险**（本证书有效期至 **2029-06-14**）。

### 关键事实
- Thumbprint / SHA-256 绑定整个证书，证书一变（含续期）哈希必变
- 证书过期后 MI 无法取 token（Azure AD 拒绝过期证书）
- 时间戳只保证 Authenticode 签名有效，**救不了 MI**

### 轮换流程
```
1. 生成新证书（有效期设长，如 3 年）
2. 用新证书重新签名程序集
3. 更新 FIC 的 Subject（新的 /h/{sha256}）
   —— 可用"双 FIC 重叠"减小中断窗口（但无法零停机，因程序集必须重新部署）
4. 重新部署程序集
5. 验证
```

### 减少轮换频率
```powershell
# 生成证书时设置长有效期
New-SelfSignedCertificate ... -NotAfter (Get-Date).AddYears(3)
```

> 若追求真正零停机 + 免证书轮换，可考虑改用 **Azure Function 代理 + Managed Identity** 方案（把证书依赖移出插件）。

---

## 8. 安全提醒 Security Notes

- **plugin.pfx / private.key / certificate.crt** 加入 `.gitignore`，勿提交版本库
- 密码（如 PFX 密码）用环境变量，勿明文写入代码或 Post-Build 事件
- **勿在 Plugin Trace Log 输出完整 token**（token 有效期内可被冒用）；如需诊断，输出 JWT payload 的 claims（不含签名，不可被滥用）
- 生产环境应遵循最小权限原则，应用用户角色收紧到实际所需权限
- 本文档含真实 ID 值，作为内部知识转移使用，注意保管

---

## 9. 工具清单 Tools Used

| 工具 | 用途 |
|---|---|
| OpenSSL (Git Bash) | 生成证书、计算哈希 |
| SignTool (Windows SDK) | Authenticode 签名 |
| Visual Studio 2026 | 插件开发、编译 |
| Plugin Registration Tool | 注册程序集、Step |
| Dataverse REST Builder (XrmToolBox) | 创建 MI 记录、测试调用 |
| Power Platform Admin Center | 配置应用用户 |
| Azure Portal | App Registration、FIC 配置 |

---

## 10. 参考 References

- Microsoft Learn: [Set up Power Platform managed identity for Dataverse plug-ins](https://learn.microsoft.com/en-us/power-platform/admin/set-up-managed-identity)（2025-12-11 更新）
- 功能状态：Generally Available since 2025-06-15

---

*文档生成于 2026-08-03，记录 AIA-AICLAIMS-MY-DEV 环境 Managed Identity 端到端实施全过程。*
