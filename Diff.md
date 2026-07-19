# EB / IB 双线业务流程对比（新人快速上手版）
# EB vs IB Business Process Comparison — Onboarding Guide

> 阅读对象：业务新人。目标：30 分钟建立系统业务框架，分清 EB / IB 两条线在每个环节的差异。

---

## 0. 一句话理解本系统 / The System in One Sentence

**医院（Provider Portal）替患者向保险公司（CRM/AHS）申请担保函 GL (Guarantee Letter)，保险公司审核后担保付款，最后医院提交账单、保险公司在后端核心系统完成理赔。**

一切请求在 CRM 中都是一个 **Case（案件）**；一切审核围绕 **GL** 的签发、追加、修正与结清展开。

---

## 1. 先分清两条业务线 / Two Lines of Business

| | **EB (Employee Benefit) 员工福利·团体险** | **IB (Individual Benefit) 个人福利·个人险** |
|---|---|---|
| 投保人 | 公司 Company（雇主投保） | 个人 Contact |
| 被保人 | Member 成员（员工及家属） | Contact 本人 |
| 数据层级 | Company → EB Policy → EB Plan → Policy Profile → Member | IB Policy → IB Policy Plan / Top Up Plan 加购计划 / Health Reward 健康奖励 → Policy Profile → Contact |
| 产品/责任主数据 | Product Group → Product Type；Benefit Group → Benefit Code（经 EB Customer 四层实例化到保单） | IB Plan Code → IB Plan Benefit Code → IB Benefit Code |
| 后端核心系统 | **G400**（理赔环节配合 **MCS**） | **Compass** |
| 记忆点 | 层级深、玩法多（团体定制） | 结构简、带现金价值（个人长期险） |

> **为什么要先分清？** 系统里几乎每个流程图都有一个 "EB/IB?" 判断菱形——走错分支，校验规则、后端系统、字段全都不一样。

---

## 2. 患者搜索对比 / Patient Search: EB vs IB

医院受理患者的第一步。判断"这个人能不能用保险直付（Cashless）"。

| 校验步骤 | EB（Corporate 分支） | IB（Individual 分支） |
|---|---|---|
| 1 | Member active? 成员是否有效 | Policy active? 保单是否有效 |
| 2 | Policy status = IF/PE/PR? 保单状态有效 | Active plan code? 计划代码有效 |
| 3 | Active plan? 计划有效 | Cashless facilities? 是否支持直付 |
| 4 | All underwriting code <> 4/7? 核保代码排除项 | Within PHN? 是否网络内医院 |
| 5 | Policy suspended? 保单是否暂停 | —— |
| 6 | Product Type = GHS/GMT/GSP? 产品类型 | —— |
| 通过后 | ZGLTYP = C/B/S → 显示眼睛图标 → ZPD01ITM = AHS → 显示保单详情，否则提示"联系 MiCare 出 GL" | 显示患者列表 → PHN 内显示保单详情，PHN 外提示消息 |
| 失败提示 | Display "no active member found" | Display "no active member found" |

**差异本质**：EB 校验的是"**这个成员在团体保单里的资格**"（核保码、暂停、产品类型都是团单概念）；IB 校验的是"**这张个人保单本身 + 这家医院是否直付网络内**"。

---

## 3. 请求创建规则对比 / Request Creation Rules

提交 GL 请求前的"闸门"校验（点击 New GL Request 后）。

### EB 住院 (Inpatient Admission) & 门诊 (Outpatient New Visit)

```
Privilege Card 特权卡?
 ├─ 有 → 直接进请求表单（跳过所有额度检查）
 └─ 无 → Utilization Balance 额度充足?
          └─ Waiting Period 等待期内?（仅住院判断）
              ├─ 是 & <30天 → 仅承保意外（trauma caused by accident），医院确认是否继续
              └─ 否 → Within PHN 网络内?
                       ├─ 是 → 进入表单
                       └─ 否 → Emergency 急诊?
                                ├─ 是 → Hospital has OTEM? → 医院确认承担风险 → 进表单
                                └─ 否 → Hospital has OTNM? → 否则提示 Non Panel Eligibility 终止
          → Co-share/Deductible 有共担免赔? → 患者同意 → 进入表单
```

### IB 住院+门诊（合并为一个流程 IB Request Submission）

```
Within Waiting Period 等待期内?
 ├─ 是 → 仅承保意外相关（accident-related conditions）→ 医院同意?
 └─ 否 ↓
Premium Paid Date 保费缴纳 > 30 天?
 ├─ 是 → Has Cash Value 有现金价值?
 │        └─ Cash Value 足以覆盖欠缴保费? 否则提示保费不足终止
 └─ ≤30天 ↓
Sufficient Utilization Balance 额度充足?
 └─ Co-share/Deductible? → 患者同意 → 进入表单（门诊走 OP 提交）
```

### 核心差异

| 维度 | EB | IB |
|---|---|---|
| 特权卡 Privilege Card | ✅ 有（可全跳过） | ❌ 无 |
| 网络判断 PHN / OTEM / OTNM | ✅ 核心校验链 | ❌ 无此链（患者搜索阶段已查 PHN） |
| 急诊例外 Emergency | ✅ 有专门分支 | ❌ 无 |
| 保费/现金价值校验 | ❌ 无 | ✅ 特有（个人险可能欠费，用现金价值抵扣） |
| 住院/门诊流程 | 分开两套规则（1.3.1 / 1.3.2） | 合并一套（1.3.3） |

**记忆点**：**EB 关心"医院资格"，IB 关心"保单缴费状态"。** 因为团单保费由公司缴（不会欠费），风险在医院是否网络内；个人险医院已在搜索时过滤，风险在客户是否断缴。

---

## 4. 请求类型清单对比 / Request Type Menu

| 请求类型 | EB | IB | 备注 |
|---|---|---|---|
| Admission Request 入院申请 | ✅ | ✅ | 住院流程起点，后续请求须挂接它 |
| Additional GL 追加担保 | ✅ | ✅ | 住院中新增诊断/操作 |
| Top-Up Request 额度追加 | ✅ | ✅ | 批准额度不足时 |
| Discharge Request 出院申请 | ✅ | ✅ | 可触发 AUC |
| Amended Bill / Final Bill 修正/终版账单 | ✅ | ✅ | Final Bill 金额必须 = AIA 批准额 |
| Follow-Up GL / Follow-Up Bill 复诊担保/账单 | ✅ | ✅ | 出院后复诊 |
| Outpatient 门诊五类（New Visit / Follow-up / Procedural / Medication / Check-up） | ✅ | ✅（无 Procedural） | 每类新 Case 新 LOG# |
| **Maternity Request 产科申请** | ✅ **仅 EB** | ❌ | 文档明示 "Maternity is only for EB" |
| **Procedural Request 操作申请** | ✅ **仅 EB** | ❌ | 文档明示 "Procedural is only for EB" |
| **Open GL 开放担保函** | ✅ **仅 EB** | ❌ | 白名单保单+医院绕过额度检查 |
| Pre-Employment Screening 入职前体检 | ✅（团体入职场景） | ❌ | 批准后生成 GL 模板 |
| E-Referral 电子转诊 | 共用 | 共用 | 外部 Medi-connect 集成 |
| Appeal / Cancellation / Reopen 申诉/取消/重开 | 共用 | 共用 | 后端处理路径不同（见 §6） |

**记忆点**：**EB 比 IB 多四样：产科、操作、Open GL、入职体检**——全是团体保障场景的产物。

---

## 5. 案件处理骨架（两线通用）/ Universal Case Skeleton

所有请求进 CRM 后走同一套骨架，这是整个系统最值得背下来的主线：

```
1. Submit（Portal 提交）
2. Create Case（CRM 建案）
3. STP 规则引擎自动判 或 QMS 排队派单给 Assessor
4. Manual Assessment 人工审核
   ├─ Deferment? 需补材料 → 向医院(Portal)/第三方(Doctor/MOH)发起 → 回流 QMS
   ├─ Update Diagnosis & Procedures → System matched ICD / LOS / Value 系统匹配建议
   └─ Approve?
       ├─ 批 → Generate Approved GL → Generate Log Number → 后端建/更新 Claim Record
       │        └─ Success/Failed? 失败进 Filter Failed List 人工补录
       └─ 拒 → Update Decline Reason → Generate Decline Letter → Portal 显示
                └─ Appeal? 申诉（仅一次）→ 重建 Case 再走 QMS
```

**四个关键数字**：
- **< 30 天**等待期 → 仅承保意外
- **30 天** GL 批准后未动作 → 系统取消请求（Cancel the Request）
- **7 天** 出院批准后未提终版账单 → 系统自动创建 Final Bill 案件
- **30 秒** QMS 找不到可用审核员 → 等待重试

---

## 6. 同一流程内的 EB/IB 分叉点 / EB-IB Forks Inside Shared Flows

很多流程是共用的，但内部藏着 EB/IB 分支——这是新人最容易踩坑的地方：

| 流程 | 分叉点 | EB 走向 | IB 走向 |
|---|---|---|---|
| Final Bill Submission 终版账单 | 步骤 "7. EB/IB?" | Claim Status update to CA (**G400**) | 直接更新关联记录为 Completed |
| Follow-Up Bill Submission 复诊账单 | 步骤 "3. EB/IB?" | Create claim header in **G400** | 走 QMS → 人工审核链 |
| OP Bill Submission 门诊账单 | 步骤 "5. EB/IB?" | Create claim header in **G400/MCS** | 走 New Visit/Medical 判断 → QMS |
| Claim Cancellation 理赔取消 | 步骤 "8. EB/IB" | 查 Claim Number → Cancel Claim (Status=**CR**) in **G400** → 失败人工 update G400 | 走 QMS → Manual Cancel in **MCS** → Manual Cancel in CRM → SMS 客户 |
| Hospital Master 医院主数据 | 步骤 "9. IB?" | 仅返回成功消息 | OneData 返回 **Vendor Code + Address Code** 写回 CRM |
| Doctor Master 医生主数据 | 集成触发 | 同步到 **G400** | 同步到 **Compass** |
| SMS/PN/Email 通知 | 步骤 "6. EB/IB" | 按 Relationship（Member/Spouse/Child/Guardian）逐一取 NRIC 发送 | 按 Role（Self/Others）分支发送 |

**规律**：**分叉几乎都发生在"要写后端"的那一步**——EB 写 G400/MCS，IB 写 Compass 或转人工。CRM 内的审核逻辑两线高度一致。

---

## 7. 新人价值洞察 / Insights for Newcomers

1. **抓住"一案一号"原则**：住院线所有请求共享同一 GL + LOG#（互为 related case）；门诊线每个请求独立新 LOG#。看到案件先问：主案（Main Request）还是子案（Sub-case）？——Appeal、Cancellation、Reopen 的规则都依赖这个判断。

2. **审批只有三种出口**：Approve（生成 GL）/ Decline（生成拒绝函，可申诉一次）/ Deferment（补材料后回来重审）。任何流程图看不懂时，先找这三个出口。

3. **"额度"贯穿始终**：Utilization Balance 在提交前查、Top-Up 因它而生、AUC 因金额争议而起、Final Bill 必须等于批准额。理解额度流转 = 理解一半业务。

4. **失败兜底都靠人工**：后端集成 Failed → Filter Failed List → Manual create/update in G400/MCS。系统设计默认"集成会挂"，人工补录是正式流程的一部分，不是异常。

5. **Reopen ≠ 修改**：重开是"作废重来"——原案置 Cancelled-Reopen，复制成新案；旧 IGL/FGL/赔付要在后端**手工**取消（无集成）。这是运营风险高发点。

6. **角色权限记三条**：Assessor 只看派给自己的案（USD）；Supervisor 看全量并可派单（USD）；Contact Centre Agent 只读案件 + 只能写 Call Log（CRM 界面，碰不到 AUC Query）。

7. **交付批次即上线顺序**：[Drop 1] 主数据/搜索/结构 → [Drop 2.x] 住院/账单/申诉/QMS → [Drop 3.x] 产科/操作/AUC/Open GL/运营功能。看到 Drop 标签就知道功能的成熟度与依赖关系。

---

## 8. 一图总结 / One-Page Mental Model

```
                         ┌──────────── 共 用 ────────────┐
                         │  患者搜索 → Case → STP/QMS →   │
                         │  审核(批/拒/延) → GL → 账单 →   │
                         │  FGL → 申诉/取消/重开            │
                         └───────┬──────────────┬────────┘
              EB 特有             │              │            IB 特有
  ┌──────────────────────┐       │              │       ┌──────────────────────┐
  │ Privilege Card 特权卡  │       │              │       │ 现金价值抵保费校验      │
  │ PHN/OTEM/OTNM 网络链  │       ▼              ▼       │ Premium>30天检查      │
  │ Maternity 产科        │   写 G400/MCS    写 Compass  │ 住院门诊合并规则        │
  │ Procedural 操作       │   (EB 后端)      (IB 后端)   │ Vendor/Address Code   │
  │ Open GL / 入职体检     │                             │  (医院主数据回写)       │
  └──────────────────────┘                             └──────────────────────┘
```