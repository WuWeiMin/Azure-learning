# 系统交互关系梳理 / System Interaction & Integration Map

> 基于 30 个业务流程图中出现的泳道（Swimlane）与集成节点整理；关键词汇 English + 中文 双语。

---

## 1. 系统清单 / System Inventory

| 系统 System | 中文 | 定位 |
|---|---|---|
| Provider Portal | 医疗机构门户 | 医院端操作入口（外部用户） |
| CRM System (Dynamics 365) | 客户关系管理系统 | 核心业务中枢：Case、GL、审核、主数据 |
| USD (Unified Service Desk) | 统一服务桌面 | CRM 的客户端外壳（审核员/主管专用） |
| Business Rule Engine / STP | 业务规则引擎（直通处理） | 自动判定批准/拒绝/转人工 |
| QMS (Queue Assignment) | 队列分配引擎 | 队列编号与审核员派单 |
| G400 | G400 后端核心 | EB 团体险保单/理赔核心 |
| MCS | MCS 理赔系统 | 理赔处理（常与 G400 并列：MCS/G400） |
| Compass | Compass 后端核心 | IB 个人险核心 |
| OneData | 主数据平台 | 医院代码校验、主数据同步 |
| ESB (Enterprise Service Bus) | 企业服务总线 | 集成中间件（医生主数据、成员创建等） |
| E-Referral System (Medi-connect) | 电子转诊系统 | 外部转诊平台 |
| SMS / PN / Email Gateway | 短信/推送/邮件网关 | 通知触达渠道 |

---

## 2. 交互拓扑总图 / Interaction Topology

```
                         ┌───────────────────────────┐
   医院用户                │      Provider Portal       │   患者/家属
   Hospital Users ──────► │      医疗机构门户            │ ◄── 接收通知
                         └────────────┬──────────────┘
                                      │ ① 请求/结果 双向
                                      ▼
┌──────────────┐        ┌───────────────────────────┐        ┌──────────────┐
│ E-Referral    │  ③    │        CRM System          │   ②    │ SMS/PN/Email │
│ 电子转诊系统    │ ◄────► │   （内嵌 STP 规则引擎、QMS、   │ ─────► │ 通知网关       │
└──────────────┘        │    USD 审核桌面）            │        └──────────────┘
                         └───┬────────┬──────────┬───┘
                             │④       │⑤         │⑥
                             ▼        ▼          ▼
                      ┌─────────┐ ┌────────┐ ┌─────────┐
                      │   ESB   │ │OneData │ │ Backend │
                      │企业服务总线│ │主数据平台│ │ 后端核心  │
                      └────┬────┘ └────────┘ │ EB→G400 │
                           │                 │   /MCS  │
                           └───────────────► │ IB→     │
                                             │ Compass │
                                             └─────────┘
```

---

## 3. 逐对交互明细 / Pairwise Interaction Details

### ① Provider Portal ⇄ CRM（最高频交互）

| 方向 | 交互内容 | 触发流程 |
|---|---|---|
| Portal → CRM | Patient Search (患者搜索) 请求 | 门户患者搜索 |
| Portal → CRM | 各类 GL Request / Bill Submission (担保函请求/账单提交) → Create Case (建案) | 住院/门诊/产科/操作/申诉/取消 |
| CRM → Portal | Display Result (显示结果)：Approved GL / Decline Letter / Prompt Message | 所有审核流程收尾 |
| CRM → Portal | Deferment (延期补材料) 下发 → Portal 用户 Reply Deferment (回复) → 回流 CRM | 延期流程（医院对象） |
| CRM → Portal | AUC Query to Provider (发给医院的澄清质询) → 医院 Update AUC Response | AUC 流程 |
| CRM → Portal | Announcement (公告) 推送（有效期内）；用户阅读 → Tracking Record 回写 | 公告流程 |
| Portal → CRM | Report Request (报表申请) → CRM 生成 → Portal 下载 Statement of Account (对账单) | 报表流程 |
| Portal ⇄ CRM | Portal User / Doctor 创建与维护（双向都可发起，管理员可覆盖） | 主数据流程 |

**特点**：请求-响应式在线交互；Portal 永远看"结果"，审核逻辑全在 CRM 内完成。

### ② CRM → 通知网关（单向触达）

```
Case Created / Updated (案件创建或更新)
 → Condition & Matching Setting (条件与通知设置匹配)
 → Retrieve Notification Template (取通知模板)
 → EB: 按 Relationship (Member配偶Child Guardian) / IB: 按 Role (Self/Others)
 → 用 NRIC (身份证号) 检索接收人
 → Trigger SMS API / PN API / Email API (触发短信/推送/邮件接口)
 → Create Notification Activity (通知活动记录落库)
```

**特点**：纯出站；批准/拒绝场景（Approved/Declined scenario）额外触发 Email。

### ③ E-Referral System ⇄ CRM ⇄ Portal（三方闭环）

```
E-Referral 系统侧                      CRM 侧                        Portal 侧
Launch New E-Referral Form ──────► Retrieve Master Data (取主数据)
Input Request Details      ◄────── Load Master Data (回主数据)
Submit E-Referral Request ──────► Create Case → STP → Approve?
Save as Draft (存草稿)                ├─ 否 → Generate Decline Letter
                                     └─ 是 → Create E-Referral GL ────► Display E-Referral GL
                                                                        Activate E-Referral GL
                                                                        → New Visit Process (转门诊新就诊流程)
E-Referral Search (查询)   ◄──────  E-Referral Information / 状态与函件
```

**特点**：转诊单在外部系统录入，CRM 负责主数据供给、STP 审核与 GL 生成，Portal 负责激活使用。

### ④ CRM ⇄ ESB（异步集成中间件）

| 场景 | 链路 |
|---|---|
| Doctor Master (医生主数据) | CRM 设 Integration Status = Ready to Sync → ESB Receives Integration Request → Backend Create/Update → Return Client Code (客户代码) → CRM Update Record |
| Offline GL (线下担保函) 成员创建 | CRM Trigger Integration for Member Creation → ESB → Email Notification → Backend Create Member → CRM Check Member Creation Status (轮询) → Profile Created? → 未建则每 X 天邮件提醒 |

**特点**：人工触发 + 异步回执；CRM 侧有状态字段与轮询/提醒机制兜底。

### ⑤ CRM ⇄ OneData（主数据校验）

```
CRM 保存 Hospital (医院) 记录
 → Trigger Integration to OneData (触发校验)
 → OneData 校验 Hospital Code (医院代码，源自 G400/Compass)
      ├─ Invalid → Return Invalid Message to CRM (返回无效)
      ├─ Valid & IB → Retrieve Vendor Code + Address Code → Return to CRM 回写
      └─ Valid & EB → Return Succeed to CRM (仅成功消息)
 → CRM Update Record & Status (更新记录与状态)
```

**特点**：同步校验式集成；IB 有增量数据回写，EB 只做确认。

### ⑥ CRM ⇄ Backend 后端核心（理赔落账主通道）

| 触发场景 | EB → G400 (/MCS) | IB → Compass / 人工 |
|---|---|---|
| GL 批准（Admission/Outpatient/Maternity/Procedural） | Create Claim Record in G400/MCS (创建理赔记录) | 同链路创建理赔记录 |
| Final Bill Submission (终版账单) | Claim Status Update to CA in G400 | 直接更新 CRM 关联记录为 Completed |
| Follow-Up / OP Bill (复诊/门诊账单) | Create Claim Header in G400 (创建理赔头) | 走 QMS 人工审核链 |
| Discharge / Amended Bill (出院/修正账单) | Retrieve Presented & Final Amount (取账单与终值金额)、Assessor Update Final Details in G400/MCS | 同类金额核对链路 |
| Claim Cancellation (理赔取消) | Cancel Claim (Status = CR) in G400；失败 → Manual Update G400 | Manual Cancel in MCS + CRM 人工取消 + SMS 客户 |
| Case Reopen (案件重开) | 旧 IGL/FGL/赔付：Backend 手工取消（**无集成**） | 同左 |
| Portal User Master (门户用户) | Portal 建 → 先进 Backend → 回流 CRM；CRM 建 → 直进 Backend | 同左 |
| Doctor Master (医生主数据) | 同步至 G400 | 同步至 Compass |

**通用失败兜底**：每次写后端都有 `Success / Failed?` 判断 → **Filter Failed List (筛选失败清单)** → **Manual Create / Update in Backend (人工补录)** → 人工 Resolve in CRM。

---

## 4. 集成模式归纳 / Integration Patterns

```
模式 (Pattern)
│
├── 1. 在线请求-响应 (Online Request-Response)
│      Portal ⇄ CRM：搜索、提交、结果展示、Deferment/AUC 往来
│
├── 2. 规则引擎内嵌判定 (Embedded Rule Evaluation)
│      CRM → STP：案件进入即判 Approve / Decline / Manual
│
├── 3. 队列派单 (Queue-based Dispatch)
│      CRM → QMS：前缀编号 + 优先级 + 排班；无人可用等 30 秒重试
│
├── 4. 人工触发异步集成 (Manually-Triggered Async via ESB)
│      Doctor Master (Ready to Sync)、Offline GL 成员创建（含轮询+邮件提醒）
│
├── 5. 保存即校验 (Save-Triggered Validation)
│      Hospital Master → OneData 校验 Hospital Code，IB 回写 Vendor/Address Code
│
├── 6. 事务落账 + 失败清单 (Transactional Write + Failed List)
│      CRM → G400/MCS/Compass：理赔记录/状态；失败进清单人工补录
│
├── 7. 事件触发通知 (Event-Driven Notification)
│      Case 创建/更新 → 匹配设置 → SMS/PN/Email API → 活动记录
│
└── 8. 无集成人工操作 (No-Integration Manual Ops)
       Case Reopen 的旧 GL/赔付后端取消 —— 明确设计为纯手工
```

---

## 5. 关键设计洞察 / Key Design Insights

1. **CRM 是唯一中枢 (Single Hub)**：Portal、转诊系统、通知、后端全部以 CRM 为中心辐射，系统间不直连（唯一例外：Portal 建门户用户先进 Backend 再回流 CRM）。

2. **EB/IB 的集成分叉都在"写后端"那一步**：CRM 内逻辑两线共用；出 CRM 时 EB 走 G400/MCS，IB 走 Compass 或转人工——排查集成问题先确认业务线。

3. **"集成会失败"是默认假设**：几乎每条写后端链路都自带 Failed List + 人工补录出口；这是正式流程，不是异常处理。

4. **人工触发的集成需要状态字段驱动**：如 Doctor Master 的 Integration Status = Ready to Sync——运维排查时优先看状态字段而非日志。

5. **两处纯手工风险点**：Case Reopen 的后端取消、Offline GL 的成员建档提醒——无系统对账，依赖操作纪律，是审计与出错高发区。
