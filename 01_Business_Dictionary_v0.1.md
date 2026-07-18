# AIA Business Dictionary（业务术语词典）

> Version: v0.1
> Status: Draft
> 原则：**一个术语只定义一次（Single Source of Truth）**

---

# 成熟度说明

| 标识 | 含义 |
|------|------|
| 🟢 L3 | 已通过资料确认 |
| 🟡 L2 | 多份流程图佐证，基本确认 |
| 🟠 L1 | 根据业务推断，待验证 |
| 🔴 L0 | 未知，需要后续资料补充 |

---

# 01 Insurance（保险基础）

## Policy

| 属性 | 内容 |
|------|------|
| 中文 | 保单 / 保险合同 |
| 成熟度 | 🟢 L3 |
| 分类 | Insurance |
| 相关术语 | Plan、Benefit、Premium |

**定义**

保险公司与客户（个人或企业）签订的保险合同，是所有医疗保障的基础。

---

## Benefit

| 属性 | 内容 |
|------|------|
| 中文 | 保障项目 |
| 成熟度 | 🟢 L3 |
| 分类 | Insurance |

**定义**

保单中可赔付的具体保障，例如住院、门诊、手术等。

---

## Premium

| 属性 | 内容 |
|------|------|
| 中文 | 保费 |
| 成熟度 | 🟢 L3 |

**定义**

客户为获得保险保障而支付的费用。

---

## Coverage

| 属性 | 内容 |
|------|------|
| 中文 | 保障范围 |
| 成熟度 | 🟢 L3 |

**定义**

保险合同允许赔付的医疗项目范围。

---

## Waiting Period

| 属性 | 内容 |
|------|------|
| 中文 | 等待期 |
| 成熟度 | 🟢 L3 |

**定义**

保单生效后的一段限制期，等待期内某些保障不能使用。

---

## Deductible

| 属性 | 内容 |
|------|------|
| 中文 | 免赔额 |
| 成熟度 | 🟢 L3 |

**定义**

理赔前需由客户自行承担的金额。

---

## Co-share (Co-payment)

| 属性 | 内容 |
|------|------|
| 中文 | 共付比例 |
| 成熟度 | 🟢 L3 |

**定义**

保险公司和客户共同承担医疗费用的比例。

---

## Utilization

| 属性 | 内容 |
|------|------|
| 中文 | 已使用保障额度 |
| 成熟度 | 🟢 L2 |

**定义**

用于判断 Benefit 是否还有剩余额度可使用。

---

# 02 Customer & Policy

## Company

企业投保人（EB）。

成熟度：🟢 L3

---

## Member

企业员工或家属，被 EB 保单保障。

成熟度：🟢 L3

---

## Contact

IB 个人客户。

成熟度：🟢 L3

---

## Dependant

被保险员工家属。

成熟度：🟢 L2

---

## Plan

保障计划。

成熟度：🟢 L3

---

# 03 Eligibility

## Patient Search

根据保单、会员等信息定位患者。

成熟度：🟢 L3

---

## Eligibility

资格校验流程。

检查：

- Policy
- Member
- Benefit
- Waiting Period
- Utilization
- Deductible

成熟度：🟢 L3

---

# 04 Medical Request

## Admission

住院申请。

成熟度：🟢 L3

---

## Outpatient

门诊请求。

成熟度：🟢 L3

---

## Procedure

医疗操作/治疗项目。

成熟度：🟢 L2

---

## Discharge

出院流程。

成熟度：🟢 L3

---

# 05 Assessment

## Assessment

保险审核。

成熟度：🟢 L3

---

## STP (Straight Through Processing)

自动审核。

成熟度：🟢 L3

---

## Manual Assessment

人工审核。

成熟度：🟢 L3

---

## Deferment

补件等待。

成熟度：🟢 L3

---

## Appeal

复核申请。

成熟度：🟢 L3

---

## AUC

成熟度：🔴 L0

**当前理解**

出现在 Assessment 相关流程中。

**未知**

官方含义、触发规则、结束条件。

---

# 06 Guarantee Letter

## GL (Guarantee Letter)

医疗费用授权函。

成熟度：🟢 L3

说明：

不是最终理赔，而是医院继续治疗的付款授权。

---

## Initial GL

首次授权。

成熟度：🟢 L3

---

## Additional GL

新增保障授权。

成熟度：🟢 L2

与 Top-Up 区别：

新增保障内容。

---

## Top-Up

追加授权金额。

成熟度：🟢 L2

与 Additional GL 区别：

增加金额，而不是增加保障项目。

---

## Final GL

最终授权。

成熟度：🟢 L2

---

# 07 Billing & Claim

## Bill

医院账单。

🟢 L3

---

## Final Bill

最终账单。

🟢 L3

---

## Claim

理赔。

🟢 L3

---

# 08 CRM

## Case

CRM 中一个业务事件。

🟢 L3

---

## Case Family

父子 Case 结构。

🟢 L2

---

## Queue

工作队列。

🟢 L3

---

# 09 Integration

## Provider Portal

医院提交业务请求的平台。

🟢 L3

---

## G400

EB 外部系统。

🟠 L1（职责待继续确认）

---

## Compass

IB 外部系统。

🟠 L1

---

## OneData

主数据系统。

🟠 L1

---

## ESB

企业服务总线。

🟢 L2

---

# 10 Unknown Terms（待确认）

| 术语 | 当前理解 | 状态 |
|------|----------|------|
| AUC | Assessment 相关 | 🔴 |
| OTEM | 出现在 Eligibility | 🔴 |
| OTNM | 出现在 Eligibility | 🔴 |
| Health Reward | IB 相关 | 🔴 |
| MCS | IB 系统相关 | 🔴 |

---

> 后续原则：
>
> - 新流程图出现的新术语，优先补充到本词典。
> - 已有术语只更新，不重复定义。
> - 未确认的概念保持 🔴，直到有资料佐证。
