# ConfigurableLookup 自定义 Lookup 控件 — 实施指南 (v1.1)

一个 PCF 虚拟控件,绑定在**文本字段**上,提供与原生 Lookup 一致的用户体验(药丸选中值、搜索浮层、键盘导航),数据源通过 **Web API 查询** 配置(环境变量集中管理或表单内联),无需重新编译即可增删改数据源。

## v1.1 变更(相对 v1.0)

| # | 改进 | 说明 |
|---|---|---|
| 1 | 回显校验与显示值刷新 | 打开记录时按 `resolveQuery` 或客户端缓存反查源头,显示名已变化则自动更新持久化的显示值 |
| 2 | 引用悬空检测 | 反查 404 / 缓存未命中时,控件下方显示黄色警告"引用的记录不存在或已被删除" |
| 3 | 错误可观测 | 区分"未找到记录"与"查询出错(HTTP 状态)";配置错误(JSON 非法、环境变量不存在、过滤后为空)直接红字呈现具体原因 |
| 4 | `allowedSources` 属性 | 共享一份配置,各表单用逗号分隔的 key 挑选可用子集 |
| 5 | 环境变量请求去重 | window 级 Promise 缓存,同表单多个控件实例只发一次请求;失败自动移出缓存可重试 |
| 6 | 属性自明化 | `sourcesConfig` 拆为 `sourcesJson` / `sourcesVariableName` 二选一;`defaultSource` → `defaultSourceKey`;`boundSource` → `boundSourceKey`;所有属性配中文显示名和说明 |
| 7 | key 稳定性契约 | 见「配置契约」一节 |

## 方案架构

```
┌─ 表单上的文本字段 ──────────────────────────────┐
│  ConfigurableLookup 控件 (PCF virtual, Fluent UI) │
│  sourcesVariableName = "lucy_LookupSources"       │  ← 表单只存"指针"
│  allowedSources = "account,contact"(可选筛选)    │
└──────────────────┬───────────────────────────────┘
                   │ 运行时读取(window 级缓存去重)
┌──────────────────▼───────────────────────────────┐
│  环境变量 lucy_LookupSources (JSON 类型)          │  ← 配置"内容",改完即生效
│  [ {客户}, {联系人}, {实体元数据}, ... ]           │
└──────────────────┬───────────────────────────────┘
                   │ 按配置发起查询 / 反查校验
┌──────────────────▼───────────────────────────────┐
│  Dataverse Web API                                │
│  /accounts /contacts /EntityDefinitions           │
│  /lucy_SearchExternal(...) ← Custom API 代理外部系统│
└───────────────────────────────────────────────────┘
```

核心设计:

- **虚拟控件 + 平台库**:manifest 引用平台内置 React 16 / Fluent UI 8(原生 UCI 同款),`TagPicker` 复刻原生 Lookup 交互与主题
- **三元组存储**:返回值 + 显示值 + 来源 key,对应原生多态 lookup 数据库里的 GUID + 目标表逻辑名 + name 缓存
- **双搜索模式**:大表用 `server`(`{search}` 占位实时查询 + 300ms 防抖);元数据端点不支持对 Label 做 `contains`,用 `client`(全量缓存本地过滤)
- **外部数据**:通过 Dataverse Custom API 做服务端代理,控件零改动(同域无 CORS、凭据在服务端)

---

## 第 1 步:环境准备(一次性)

| 工具 | 说明 |
|---|---|
| Node.js LTS | https://nodejs.org |
| Power Platform CLI | `dotnet tool install --global Microsoft.PowerApps.CLI.Tool` |
| VS 2022 或 Build Tools | `pac pcf push` 打包时需要 MSBuild |

验证:`pac --version` 和 `node --version` 都能输出版本号。

## 第 2 步:初始化 PCF 项目

```bash
mkdir ConfigurableLookup && cd ConfigurableLookup
pac pcf init --namespace Lucy --name ConfigurableLookup --template field --framework react
npm install
```

> `--framework react` 不能省略,它决定生成的是虚拟控件模板(使用平台提供的 React/Fluent)。

## 第 3 步:放入控件代码

用交付的三个文件替换/新增(注意是 **ConfigurableLookup 子目录**,不是项目根目录):

| 文件 | 操作 |
|---|---|
| `ConfigurableLookup/ControlManifest.Input.xml` | 覆盖 |
| `ConfigurableLookup/index.ts` | 覆盖 |
| `ConfigurableLookup/LookupControl.tsx` | 新增(放在 index.ts 旁边) |
| 模板生成的 `HelloWorld.tsx` | 删除 |

## 第 4 步:构建

```bash
npm run build
```

构建依据 manifest 自动生成 `generated/ManifestTypes.ts`。如报 TS 类型错误,先确认本步骤成功执行过一次。

可选本地预览:`npm start watch`。测试沙箱内没有 Xrm 和组织 Web API,查询会失败,只能验证布局;真实数据必须部署后验证。

## 第 5 步:部署到环境

```bash
pac auth create --url https://你的org.crm.dynamics.com
pac pcf push --publisher-prefix lucy
```

`pcf push` 创建临时解决方案 `PowerAppsTools_lucy`,适合开发迭代。**正式交付时**把控件组件加入自己的解决方案随包迁移。

## 第 6 步:准备实体字段

| 字段(示例名) | 类型 | 长度建议 | 必要性 |
|---|---|---|---|
| lucy_refvalue | 单行文本 | 100 | **必须**(控件挂载的字段,存返回值) |
| lucy_refname | 单行文本 | 200 | 推荐(显示值,视图/报表可读) |
| lucy_refsource | 单行文本 | 50 | 多数据源时强烈推荐(来源 key,消费方据此分支) |

建完**先发布**,再做第 8 步的绑定,否则属性面板下拉里找不到新字段。
单数据源场景 lucy_refsource 可省(来源是已知常量)。

## 第 7 步:创建环境变量

1. maker portal → 解决方案 → 新建 → 更多 → **环境变量**
2. 显示名 `Lookup Sources`,记下 schema name,例如 `lucy_LookupSources`
3. 数据类型:**JSON**
4. 当前值:粘贴 `sources-sample.json` 内容
5. 保存

### 数据源 JSON 字段参考

| 字段 | 必填 | 说明 |
|---|---|---|
| `key` | ✓ | 数据源唯一标识,写入 boundSourceKey。**契约字段,见下节** |
| `label` | ✓ | 切换器显示名,可随时改 |
| `query` | ✓ | 搜索查询相对 URL;server 模式用 `{search}` 占位用户输入 |
| `resolveQuery` |  | 按返回值反查单条记录的 URL,`{value}` 占位。配置后启用回显校验:刷新过期显示值 + 悬空检测。示例:`/api/data/v9.2/contacts({value})?$select=fullname` |
| `valueField` | ✓ | 返回值属性,支持点路径 |
| `displayField` | ✓ | 显示值属性,支持点路径,如 `DisplayName.UserLocalizedLabel.Label` |
| `secondaryField` |  | 建议项第二行小字,如邮箱、ObjectTypeCode |
| `searchMode` |  | `server`(默认)/ `client`(全量缓存本地过滤;元数据端点必须用它,client 模式自带回显校验,无需 resolveQuery) |

### 配置契约(重要)

- **`key` 一旦有存量数据,禁止改名**。存量记录的 boundSourceKey 里存的是旧 key,改名会导致回显校验失联、后端分支逻辑失效。把 key 当 LogicalName 对待:label 随便改,key 不动
- **返回值跨环境迁移用 LogicalName,不用 ObjectTypeCode**。自定义实体的 type code 在环境间不保证一致
- **query 中的字符串拼接**只发生在 `{search}` / `{value}` 占位符,控件已做单引号翻倍转义 + URL 编码

## 第 8 步:表单配置

1. 表单编辑器选中目标**文本字段**(lucy_refvalue)→ 组件 → 添加组件 → `ConfigurableLookup`
2. 属性配置:

| 属性 | 类别 | 填写 |
|---|---|---|
| boundValue | 字段绑定 | 自动绑定当前字段(存返回值) |
| boundDisplay | 字段绑定 | 可选,选 lucy_refname(存显示值) |
| boundSourceKey | 字段绑定 | 可选,选 lucy_refsource(存来源 key) |
| sourcesJson | 静态值 | 二选一 A:直接粘贴 JSON(单表单独立配置) |
| sourcesVariableName | 静态值 | 二选一 B:`lucy_LookupSources`(集中配置,**推荐**)。两者都填时 JSON 优先 |
| defaultSourceKey | 静态值 | 默认选中的数据源 key,如 `account`(仅初始态,不限制切换) |
| allowedSources | 静态值 | 可选,本表单允许的 key 子集,如 `account,contact`;留空 = 全部 |

3. boundDisplay / boundSourceKey 对应的字段拖到表单上后设为**隐藏**(不要设"只读+不提交",会拦截绑定写回)
4. 勾选 Web / 手机端启用 → 保存 → **发布**

> **注意**:五个静态值属性不产生实体字段;实体字段只由三个 bound 绑定决定,最少 1 个,完整 3 个。

## 第 9 步:验证清单

- [ ] 多数据源:切换器出现,切换后搜索走对应查询;单数据源:切换器隐藏
- [ ] 选中后显示药丸,× 可清空;三个字段值正确写入(保存后用高级查找验证)
- [ ] 打开已有记录:显示值正常回显;在源头改掉被引用记录的名字 → 重新打开 → 显示值自动刷新
- [ ] 删除被引用记录 → 打开引用它的记录 → 控件下方出现黄色悬空警告
- [ ] 故意把环境变量 JSON 改坏 → 控件显示红色配置错误及原因(改回来记得刷新)

---

## 日常维护

| 场景 | 操作 | 需要发布/编译? |
|---|---|---|
| 修改查询、增删数据源 | 编辑环境变量当前值 | 否,刷新即生效 |
| 某表单限用部分数据源 | 改该表单控件的 allowedSources | 仅一次表单发布 |
| 某表单需要完全独立的配置 | 新建环境变量,改 sourcesVariableName 指向 | 仅一次表单发布 |
| 接入外部系统数据 | 建 Custom API 服务端代理,配置里加一条数据源指向它 | 控件零改动 |
| 修改控件逻辑代码 | 改代码 → **递增 manifest 版本号** → build → push | 是 |

## 常见问题排查

**改了代码 push 后表单没变化** — 版本缓存。递增 manifest `version` 再 push,浏览器 Ctrl+F5。

**控件显示红色"数据源配置错误"** — 按提示文字处理:环境变量不存在(检查 schema name 拼写)、JSON 解析失败(检查格式,推荐先用编辑器校验)、allowedSources 过滤后为空(检查 key 是否匹配)。

**搜索浮层显示"查询出错:HTTP 4xx"** — 该数据源的 query 有问题:400 多为 OData 语法或字段名错误;403 是权限;404 是端点/实体集名拼错。直接把 query 贴到浏览器地址栏(前面拼组织 URL)复现排查。

**元数据数据源必须 `"searchMode": "client"`** — `EntityDefinitions` 端点不支持对 DisplayName Label 做 `contains` 过滤,且 query 中不要放 `{search}`。

**本地 `npm start watch` 查询全失败** — 正常,沙箱无组织上下文,部署后验证。

**环境变量改了没生效** — 用户需刷新页面;确认改的是"当前值"而非"默认值";同页面已有缓存时刷新即清(缓存生命周期为页面会话)。

**悬空警告误报** — 检查该数据源 resolveQuery 是否正确;网络/权限错误不会触发悬空警告,只有确定的 404 或缓存未命中才会。

**用户输入带单引号(O'Brien)** — 控件已转义;自定义 query 若有其他拼接注意同样处理。

## 迁移到其他环境(ALM)

1. **控件组件 + 环境变量定义**加入同一解决方案导出
2. 环境变量"当前值"不随托管解决方案走——导入后在目标环境单独设置(Dev/UAT/Prod 各配各的查询,这正是期望行为)
3. 表单上的控件属性(指针、绑定)存在 FormXML 里随表单迁移,无需重配
4. 返回值持久化遵循「配置契约」:用 LogicalName 不用 ObjectTypeCode

## 已知取舍(接受项)

- **无引用完整性**:字段本质是文本,被引用记录删除只有打开时的悬空警告,无级联行为;需要强引用语义应改用虚拟表/影子表 + 原生 lookup 路线
- **移动离线不可用**:控件直连 Web API,不走离线缓存
- **client 模式缓存会话内不刷新**:元数据变更频率极低,可接受;强制刷新 = 刷新页面
- **与原生剩余 UX 差距**:数据源切换在浮层外、无实体图标、无"新建记录"按钮,按需再加
