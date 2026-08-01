

---

## 一、预计需要改动的范围

### Doctor端表单
- Admission Section 诊断字段（涵盖 Admission Request / Add Doctor Request 两种GL申请类型）
- Discharge Section 诊断字段
- Outpatient Specialist Assessment Letter 的 Final Diagnosis 字段
- 备注：Add Procedure / Add Doctor 页面本身不需要改动（现有ePAF已支持5个）

### 生成的PDF/文档模板
- 上述三处对应的ePAF PDF模板，诊断展示区域需从3行扩展为5行

### Hospital端展示
- GL Request pages：IGL、AGL（含Additional Procedure / Additional Doctor两种）、FGL、OP Bill Submission
- 需确认这几个页面是否共享同一诊断展示逻辑，还是各自独立实现

### CRM / Dataverse 数据层
- All ePAF data 评估视图（AIA Assessor查看的Diagnosis表）能否完整承载并展示5个诊断
- 尤其是跨多个GL请求（如IGL + Add Procedure）合并后的诊断数据是否能正确聚合展示

### 下游系统联动
- One Data等下游系统是否需要同步扩容（该事项已在需求文档中标注为待Tech评估）

---

## 二、需要在系统里排查的内容

1. **诊断字段的数据模型**
   确认诊断是Dataverse实体上的固定字段（如Diagnosis1/2/3各自独立列），还是通过子表/一对多关系挂载的明细记录。这直接决定改动是"扩数据模型"还是"改前端上限校验"，两者工作量差异很大。

2. **承载诊断输入的PCF控件**
   定位具体控件源码，确认"最多3个"的限制是硬编码常量，还是可配置项（如Environment Variable或Config实体）。

3. **该PCF控件的复用范围**
   Admission、Discharge、Outpatient、GL Request pages 是否共用同一个诊断输入/展示组件——若共用，改一处即可覆盖多处场景。

4. **PDF生成机制**
   确认是通过Word模板 + Power Automate导出，还是Custom API / Azure Function拼装；模板里诊断区域是固定行数表格，还是动态生成的结构。

5. **相关Plugin / Business Rule**
   排查是否存在针对诊断数量做校验或触发逻辑的Plugin（如限制不超过3条、诊断变更时触发的自动化流程）。

6. **CRM评估视图的聚合逻辑**
   确认当前"All ePAF data"视图是单一来源展示，还是已经做了跨GL类型的诊断聚合/去重处理，这关系到Discharge超量场景（见下方风险点）是否需要额外开发。

7. **下游集成接口**
   排查是否存在把诊断数据推送/同步到One Data或其他外部系统的接口，接口数据结构是否也存在3个诊断的字段限制。

---

## 三、需要问用户/业务方的问题

1. **Discharge Section超量场景**（原需求文档已标红提出的问题）
   如果同一医生的诊断分批次审批（例如IGL批准4个诊断 + Add Procedure又批准2个），Final Diagnosis字段应如何处理超过5个的情况？是合并展示全部，还是只保留最近/最多5个？这将决定是否需要额外的去重/合并逻辑，而不只是简单把上限调整为5。

2. **One Data等下游系统是否需要同步扩容**
   业务方是否已与下游团队确认过对方系统能否接收超过3个诊断的数据？这部分是否包含在本次需求范围内，还是单独立项处理。

3. **历史数据兼容性**
   已有的历史ePAF记录（诊断数为3个及以下）是否需要做任何数据迁移或兼容处理，还是保持原样、仅对新数据生效。

4. **PDF模板的排版预期**
   当实际诊断数少于5个时（例如只有2个），PDF上是否要求隐藏空行，还是保留固定5行空白位置？这会影响模板改造的复杂度。

5. **优先级/交付范围确认**
   Admission、Discharge、Outpatient三处是否要求同一优先级同步上线，还是可以分批次交付（例如先做Admission，Discharge的超量逻辑单独排期）。
