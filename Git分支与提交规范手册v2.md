# Git 分支管理与提交规范手册

**适用范围**：公司内所有软件开发项目（通用规范，各项目组可结合自身技术栈补充 Scope 清单）
**版本**：v1.0
**最后更新**：2026-07-24

---

## 目录

1. [分支策略总览](#1-分支策略总览)
2. [分支命名与环境映射](#2-分支命名与环境映射)
3. [标准开发流程（单需求）](#3-标准开发流程单需求)
4. [标准开发流程（多需求并行）](#4-标准开发流程多需求并行)
5. [Conventional Commits 提交规范](#5-conventional-commits-提交规范)
6. [提交类型详解与示例](#6-提交类型详解与示例)
7. [Pull Request 规范](#7-pull-request-规范)
8. [减少 Commit 噪音的实践](#8-减少-commit-噪音的实践)
9. [常见问题 FAQ](#9-常见问题-faq)
10. [附录：Commit 速查表（可直接复制修改）](#10-附录commit-速查表可直接复制修改)

---

## 1. 分支策略总览

我们采用 **Develop → Feature → Release → Main** 的分支模型，Main 合并后需回merge到 Develop，保持两条主干同步。

```
develop ──┬──────────────────────────────────────────┬── (回merge)
          │                                           │
          ▼                                           │
     feature/cr1 ──► release/cr1 ──► main ────────────┘
```

核心原则：

- **`develop`**：所有需求分支的起点，日常集成分支，**禁止直接部署**。
- **`feature/*` / `bugfix/*`**：单个需求/缺陷的开发分支，从 `develop` 切出。
- **`release/*`**：UAT 测试分支，从对应的 `feature/*` 通过 PR 创建。
- **`main`**：生产分支，只接受来自 `release/*` 的 PR。
- **`hotfix/*`**：紧急生产修复，仅用于 PROD。
- **`drfix/*`**：灾备（DR）环境专用修复分支。

> ⚠️ `main`、`master`、`develop` 均被**禁止直接部署**，任何环境部署都必须通过符合命名规范的分支或 tag 触发。

---

## 2. 分支命名与环境映射

分支命名必须**严格匹配**下表规则，命名错误会导致路由到错误环境或流水线校验失败。

| 分支/Tag 模式 | 目标环境 | 说明 |
|---|---|---|
| `feature/*` | DEV | 新功能开发 |
| `bugfix/*` | DEV | 缺陷修复（非生产紧急） |
| `release/sit*` | SIT | 系统集成测试 |
| `release/uat*` | UAT | 用户验收测试 |
| `hotfix/*` | PROD only | 仅生产环境紧急修复 |
| `drfix/*` | DR only | 仅灾备环境修复（含 PROD 定义下的 `.dr` 目标，待 zh 确认） |
| `refs/tags/*` | PROD + DR | 已批准的正式发布 tag，可同时部署至生产与灾备 |

**重要行为约定：**

- `main`、`master`、`develop` 三个分支**禁止**作为部署来源。
- 生产环境专项修复 → 使用 `hotfix/*`。
- 灾备环境专项修复 → 使用 `drfix/*`。
- 需要**同时**部署到 PROD 和 DR → 使用已批准的 release tag，不要分别用 `hotfix` 和 `drfix`。
- `release/*` 分支与生产 tag，必须从**已经合入 develop 的 commit**上创建，不能跳过 develop 直接从 feature 拉。
- 旧的有效 release 分支/tag 可以在需要**回滚（rollback）**时重新运行，不会因为 develop 已经往前推进而失效。

**命名示例：**

```
feature/CR1024-add-search-filter
bugfix/CR1030-fix-null-reference
release/sit-2026.07
release/uat-2026.07
hotfix/CR1041-prod-workflow-crash
drfix/CR1042-dr-sync-fix
```

---

## 3. 标准开发流程（单需求）

对应「单一增强」流程图（Develop → Feature/cr1 → Release/cr1 → Main → 回merge）：

1. **从 `develop` 切出 feature 分支**，命名如 `feature/cr1-xxx`，开始开发。
2. 开发完成、准备进入 UAT 时，从 `feature/cr1` 发起 PR，**克隆创建** `release/cr1` 分支。
3. UAT 期间如有修复：**只在 `feature/cr1` 上改动**，测试通过后再合并回 `release/cr1`。
4. UAT 全部通过后，从 `release/cr1` 发起 PR 合并到 `main`。
5. 合并到 `main` 后，**次日**将 `main` 合并回 `develop`，保持两条主干同步。

```bash
# 1. 创建 feature 分支
git checkout develop
git pull origin develop
git checkout -b feature/cr1-add-search-filter

# 2. 开发完成后创建 release 分支（通过 PR，非直接 push）
#    PR: feature/cr1-add-search-filter -> release/cr1

# 3. UAT 修复只改 feature，再合并回 release
git checkout feature/cr1-add-search-filter
# ...修复...
#    PR: feature/cr1-add-search-filter -> release/cr1

# 4. UAT 通过后合并到 main
#    PR: release/cr1 -> main

# 5. 次日回merge 到 develop
git checkout develop
git pull origin develop
git merge origin/main
git push origin develop
```

---

## 4. 标准开发流程（多需求并行）

当多个需求（cr1、cr2 ...）同时在 `develop` 上并行开发时，流程与单需求一致，但需注意**分支同步**：

- **cr2 的 feature 分支创建前**，务必先从 `develop` 拉取最新代码（图中步骤 7），避免落后于已合并的 cr1。
- **cr2 的 release 分支**，从 `feature/cr2` 拉取最新代码后再创建（图中步骤 8）。
- 每个 CR 各自独立完成「feature → release → main → 回merge develop」的完整闭环，互不干扰。

```bash
# cr2 开始前，先同步 develop 最新代码（此时 cr1 可能已合并）
git checkout feature/cr2-xxx
git pull origin develop        # 或 git rebase origin/develop

# release/cr2 创建前同样先同步 feature/cr2 最新代码
git checkout release/cr2
git pull origin feature/cr2-xxx
```

> 💡 **建议**：并行需求越多，越应该缩短每个 CR 的生命周期，尽快合并回 develop，减少分支漂移（drift）和后续冲突成本。

---

## 5. Conventional Commits 提交规范

采用 [Angular 提交规范](https://github.com/angular/angular/blob/main/CONTRIBUTING.md#commit) 作为统一标准，格式如下：

```
<type>(<scope>): <subject>
<空一行>
<body>
<空一行>
<footer>
```

- **type**：提交类型（见第 6 节），必填。
- **scope**：影响范围，建议使用模块/组件名，选填但强烈建议填写。
- **subject**：简短描述，祈使语气、动词开头、不超过 50 字符、结尾不加句号。
- **body**：详细说明改动动机与实现方式，选填，说明"为什么"而不只是"做了什么"。
- **footer**：破坏性变更（`BREAKING CHANGE:`）、关联的工作项/CR 编号（`Closes #1024`）。

**Scope 建议清单**（示例，各项目组可结合自身模块/技术栈自行扩展）：

| Scope | 适用范围 |
|---|---|
| `api` | 后端 API / 服务接口 |
| `ui` | 前端界面/组件 |
| `auth` | 认证与权限模块 |
| `db` | 数据库结构/迁移脚本 |
| `integration` | 第三方系统集成 |
| `config` | 配置文件/环境变量 |
| `ci` | 流水线/构建脚本 |
| `deps` | 依赖包 |

> 💡 各项目组可以在此基础上，补充自己领域内更具体的 scope，例如前端项目用 `component`/`router`，移动端用 `ios`/`android`，数据平台用 `etl`/`pipeline` 等，只要团队内部统一即可。

---

## 6. 提交类型详解与示例

### 6.1 `feat` — 新功能

引入新的功能特性，会触发语义化版本的 **MINOR** 升级。

```
feat(auth): 新增基于角色的访问控制（RBAC）中间件

支持通过配置文件定义角色与接口权限的映射关系，
统一在网关层拦截未授权请求。

Closes #CR1024
```

```
feat(ui): 新增订单列表页的多条件筛选组件

支持按状态、日期区间、客户名称组合筛选，筛选条件保存在 URL 参数中。
```

### 6.2 `fix` — 缺陷修复

修复 bug，会触发语义化版本的 **PATCH** 升级。

```
fix(api): 修复并发请求下用户余额扣减出现负数的问题

原实现未对余额扣减加锁，高并发场景下会出现竞态条件，
改为数据库行级锁 + 乐观锁重试。

Fixes #CR1030
```

```
fix(integration): 修复第三方支付回调签名校验大小写不一致导致的失败
```

### 6.3 `docs` — 文档变更

仅文档相关改动，不涉及代码逻辑。

```
docs(readme): 补充本地开发环境搭建与常见问题排查步骤
```

```
docs(api): 更新用户认证接口的请求/响应示例
```

### 6.4 `style` — 代码格式

不影响代码逻辑的格式调整（空格、缩进、分号、命名风格等）。

```
style(api): 统一 Controller 层代码缩进为 4 空格并移除多余空行
```

```
style(ui): 按 ESLint/Prettier 规则格式化组件代码
```

### 6.5 `refactor` — 重构

既不是修复 bug，也不是新增功能的代码结构调整。

```
refactor(db): 将数据库连接逻辑抽取为独立的 ConnectionFactory 类

原先分散在多个 Service 中重复创建连接实例，
统一收敛到工厂类，便于后续替换连接池实现。
```

```
refactor(api): 拆分过大的 OrderService 为多个职责单一的处理类
```

### 6.6 `perf` — 性能优化

专门以提升性能为目的的代码改动。

```
perf(api): 使用批量插入替代逐条写入，减少数据库往返次数

原实现对每条记录单独发起 INSERT 请求，1000 条记录场景下耗时约 90s，
改为批量写入后降至约 12s。
```

```
perf(ui): 对下拉列表数据源结果增加本地缓存，减少重复请求
```

### 6.7 `test` — 测试

新增或修改测试代码，不涉及生产代码逻辑变更。

```
test(api): 补充数据库连接失败场景的单元测试
```

```
test(auth): 为登录接口新增密码错误次数超限锁定的边界测试
```

### 6.8 `build` — 构建系统 / 外部依赖

影响构建系统或外部依赖（npm、Maven、NuGet 等）的改动。

```
build(deps): 升级核心框架版本并处理相关的破坏性 API 变更
```

```
build(ui): 升级前端构建工具链与相关依赖至最新稳定版本
```

### 6.9 `ci` — 持续集成

CI/CD 配置文件或脚本的改动。

```
ci(pipeline): 新增 release/sit* 分支自动触发 SIT 环境部署的流水线规则
```

```
ci(pipeline): 修复分支命名校验规则未拦截 drfix 与 hotfix 混用的问题
```

### 6.10 `chore` — 杂项

不影响 src 或测试文件的日常维护性变更（如构建工具配置、依赖版本号维护等），Angular 规范中常与 `build` 并列使用。

```
chore(release): 更新版本号至 1.4.2
```

```
chore(deps): 清理未使用的依赖包引用
```

### 6.11 `revert` — 回退提交

撤销此前的某次提交。

```
revert: feat(auth): 新增基于角色的访问控制（RBAC）中间件

This reverts commit a1b2c3d.
原因：该功能在 UAT 中触发了权限误拦截，暂时回退待修复后重新上线。
```

### 6.12 破坏性变更（Breaking Change）

任何类型都可能携带破坏性变更，需在 footer 中用 `BREAKING CHANGE:` 明确标注，会触发语义化版本的 **MAJOR** 升级。

```
feat(api): 重构 GetCustomerSummary 接口入参结构

BREAKING CHANGE: 入参 customerId 类型由 string 改为 UUID，
调用方需同步更新序列化逻辑。
```

---

## 7. Pull Request 规范

- PR 标题建议沿用 Conventional Commits 格式，如：`feat(ui): 新增多条件筛选组件`。
- PR 描述中应包含：变更目的、关联 CR/工作项编号、测试方式、是否有破坏性变更。
- `release/*` → `main` 的 PR，必须附上 UAT 测试通过证据（截图/测试记录链接）。
- 所有针对受保护分支（`main`、`develop`、`release/*`）的合并，禁止直接 push，一律走 PR + Review。

---

## 8. 减少 Commit 噪音的实践

开发过程中难免产生大量"wip"、"fix typo"、"debug log"之类的中间提交。以下方法用于在**不影响开发效率**的前提下，让最终合入 `release`/`main` 的历史保持干净、语义完整。

### 8.1 本地开发阶段：随便提交，合并前整理

feature 分支是"草稿区"，开发过程中可以自由提交，但在发起 PR 前必须整理成语义清晰的 commit。

**修正最近一次提交（漏改一行、打错字）：**

```bash
git add .
git commit --amend --no-edit      # 不改 message，直接并入上一条
# 或
git commit --amend                # 顺便修改 message
```

> ⚠️ 仅对**尚未 push**，或已 push 但确定无人基于此分支继续开发的 commit 使用 amend，避免改写他人已拉取的历史。

**交互式 rebase：把一堆中间提交 squash 成 1~2 个：**

```bash
# 整理最近 5 个提交
git rebase -i HEAD~5
```

打开的编辑器中，把要合并的提交前缀由 `pick` 改为 `squash`（或简写 `s`），保留第一条为 `pick`：

```
pick a1b2c3d feat(ui): 初始化筛选组件框架
squash b2c3d4e wip
squash c3d4e5f fix typo
squash d4e5f6a debug log 移除
squash e5f6a7b 补充单元测试
```

保存后会进入合并 commit message 的编辑界面，整理成一条符合规范的提交，例如：

```
feat(ui): 新增订单列表页的多条件筛选组件

支持按状态、日期区间、客户名称组合筛选，筛选条件保存在 URL 参数中。

Closes #CR1024
```

**针对某个具体历史提交打补丁（推荐用于修正非最近一次的提交）：**

```bash
# 先开启 autosquash 支持
git config --global rebase.autosquash true

# 对某个 commit 追加修复，Git 会自动关联
git commit --fixup=<commit-hash>

# rebase 时自动把 fixup 提交排到目标提交后面并合并
git rebase -i --autosquash origin/develop
```

### 8.2 PR 合并策略：统一 Squash Merge

对开发者本地提交习惯依赖较小、见效最直接的方式，是在代码托管平台（GitHub / Azure DevOps）层面统一合并策略：

- `feature/* → release/*`、`release/* → main` 的 PR，**统一设置为 Squash Merge**（关闭 Merge Commit 和 Rebase Merge 选项）。
- 无论 feature 分支上本地历史多零散，合入目标分支时都会被压缩成**一条** commit。
- Squash 后的 commit message 默认取自 **PR 标题**，因此要求 PR 标题必须符合 Conventional Commits 格式，例如：`feat(ui): 新增多条件筛选组件`。
- 效果：`release/*` 和 `main` 分支的历史，每条都是一次完整、可追溯的语义化变更，天然适合生成 changelog。

### 8.3 提交时强制校验格式：commitlint + husky

在仓库根目录引入自动校验，把"要求写规范的 commit message"从口头约定变成硬性拦截：

```bash
npm install --save-dev @commitlint/cli @commitlint/config-conventional husky
```

`commitlint.config.js`：

```js
module.exports = { extends: ['@commitlint/config-conventional'] };
```

配置 husky 的 `commit-msg` hook：

```bash
npx husky init
echo "npx --no -- commitlint --edit \$1" > .husky/commit-msg
```

之后任何不符合 `<type>(<scope>): <subject>` 格式的提交，会在 `git commit` 时直接被拒绝，无需等到 PR review 才发现。

**（可选）配合 commitizen 提供交互式填写向导，减少格式错误：**

```bash
npm install --save-dev commitizen cz-conventional-changelog
npx commitizen init cz-conventional-changelog --save-dev --save-exact
```

之后开发者用 `git cz` 代替 `git commit`，通过命令行菜单逐步选择 type、填写 scope 和 subject，自动生成合规的 message。

### 8.4 同步 develop 最新代码：优先 rebase 而非 merge

从 `develop` 同步最新代码到 feature 分支时，频繁的 `git merge` 会在历史中留下大量 merge commit，干扰阅读。除非分支已被他人共同开发或已发起 PR 且不便改写历史，否则优先使用：

```bash
git checkout feature/cr2-xxx
git fetch origin
git rebase origin/develop
```

保持提交历史线性、无多余 merge 噪音。

### 8.5 小结：噪音处理责任分工

| 环节 | 负责人 | 手段 |
|---|---|---|
| feature 分支开发中 | 开发者 | 自由提交，无需顾虑 |
| feature 分支 PR 前 | 开发者 | `rebase -i` 整理 / `commit --amend` |
| 提交时格式校验 | 工具自动化 | commitlint + husky |
| 合入 release/main | 平台策略 | 统一 Squash Merge |
| 同步 develop | 开发者 | `rebase` 优先于 `merge` |

---

## 9. 常见问题 FAQ

**Q1：UAT 期间发现 bug，能不能直接改 release 分支？**
不可以。所有修复必须在对应的 `feature/*` 分支上进行，测试通过后再合并回 `release/*`，保证 feature 分支始终是唯一的代码真源（source of truth）。

**Q2：release 分支能不能跳过 develop，直接从别的 feature 分支拉代码？**
不可以。`release/*` 只能从已经合入 `develop` 的 commit 上创建，保证发布内容可追溯。

**Q3：生产出现紧急问题，应该走哪个分支？**
仅影响 PROD → 使用 `hotfix/*`；仅影响 DR → 使用 `drfix/*`；同时影响 PROD 和 DR → 使用已批准的正式 release tag，不要分别走两个分支。

**Q4：main 合并后多久需要回 merge 到 develop？**
按约定为合并后的**次日**完成回merge，避免 develop 长期落后于 main。

**Q5：commit type 应该选 `fix` 还是 `bugfix`？**
Conventional Commits 中固定类型为 `fix`（无论对应分支叫 `bugfix/*` 还是 `hotfix/*`），分支命名规则与 commit type 是两套独立体系，不要混用。

---

## 10. 附录：Commit 速查表（可直接复制修改）

以下按类型整理常用 commit 示例，直接复制后把 scope 和描述改成实际改动内容即可。前几条为**纯标题**格式（日常小改动够用），每类末尾附一条**带 body/footer 的完整格式**示例（重大改动、需要说明背景时使用）。

### feat（新功能）

```
feat(api): 新增用户导出接口
feat(ui): 新增数据表格列排序功能
feat(auth): 支持第三方 OAuth 登录
feat(db): 新增订单表的软删除字段
feat(integration): 接入短信验证码服务商
feat(config): 支持通过环境变量切换日志级别
```

```
feat(api): 新增批量导入接口，支持 Excel 文件解析

支持上传 xlsx 文件并逐行校验后写入数据库，
校验失败的行会返回具体错误行号与原因。

Closes #1234
```

### fix（缺陷修复）

```
fix(api): 修复分页参数为负数时返回全部数据的问题
fix(ui): 修复移动端弹窗遮罩层未覆盖底部导航栏
fix(auth): 修复 token 刷新后旧 token 未失效的问题
fix(db): 修复唯一索引未生效导致的重复数据
fix(integration): 修复第三方接口超时未捕获异常导致进程崩溃
fix(config): 修复生产环境误读取本地配置文件的问题
```

```
fix(api): 修复并发请求下库存扣减出现负数的问题

原实现未对库存扣减加锁，高并发下单场景会出现竞态条件，
改为数据库行级锁并增加扣减前校验。

Fixes #1240
```

### docs（文档）

```
docs(readme): 补充项目启动与环境变量配置说明
docs(api): 更新接口文档中的错误码列表
docs(contributing): 新增 Conventional Commits 提交规范说明
docs(changelog): 补充 v1.3.0 版本变更记录
```

### style（代码格式）

```
style(api): 统一使用 4 空格缩进并移除行尾空格
style(ui): 按 Prettier 规则格式化组件代码
style(*): 统一 import 顺序，按第三方库/内部模块分组
```

### refactor（重构）

```
refactor(api): 提取公共校验逻辑为独立中间件
refactor(db): 将原生 SQL 查询迁移为 ORM 写法
refactor(ui): 拆分过大的表单组件为多个子组件
refactor(integration): 统一第三方接口调用的重试与超时逻辑
```

```
refactor(api): 将认证逻辑从 Controller 抽取为独立 AuthService

原先每个 Controller 各自处理 token 校验，逻辑重复且不一致，
统一收敛到 AuthService，便于后续扩展多种认证方式。
```

### perf（性能优化）

```
perf(api): 使用批量查询替代 N+1 查询，减少数据库往返
perf(ui): 长列表启用虚拟滚动，减少 DOM 节点数量
perf(db): 为高频查询字段新增复合索引
perf(integration): 对第三方接口响应结果增加短期缓存
```

### test（测试）

```
test(api): 补充分页参数边界值的单元测试
test(auth): 新增 token 过期场景的集成测试
test(ui): 为表单校验逻辑补充测试用例
test(db): 补充唯一约束冲突场景的测试
```

### build（构建/依赖）

```
build(deps): 升级核心依赖包至最新稳定版本
build(deps): 移除未使用的第三方库依赖
build(ui): 升级前端构建工具链配置
build(api): 调整编译目标框架版本
```

### ci（持续集成）

```
ci(pipeline): 新增 PR 合并前自动运行单元测试的步骤
ci(pipeline): 新增 commitlint 校验提交信息格式
ci(pipeline): 修复 release 分支未正确触发部署的问题
ci(pipeline): 新增分支命名规则校验，拦截不合规分支
```

### chore（杂项）

```
chore(release): 更新版本号至 1.5.0
chore(deps): 清理未使用的依赖包引用
chore(config): 更新 .gitignore 忽略本地调试文件
chore: 更新 LICENSE 年份
```

### revert（回退）

```
revert: feat(api): 新增批量导入接口，支持 Excel 文件解析

This reverts commit a1b2c3d.
原因：生产环境发现大文件导入导致内存溢出，回退待优化后重新上线。
```

### 破坏性变更（BREAKING CHANGE）

```
feat(api): 重构用户信息接口返回结构

BREAKING CHANGE: 响应字段 userName 改为 name，
调用方需同步更新前端解析逻辑。
```

```
refactor(db): 将订单状态字段由字符串改为枚举整型

BREAKING CHANGE: order.status 字段类型变更，
历史依赖字符串比较的代码需同步修改为枚举比较。
```

> 💡 **使用建议**：日常小改动直接复制"纯标题"示例改一下 scope 和描述即可，几秒钟搞定；涉及重大逻辑变更、修复复杂 bug、或有破坏性变更时，务必补充 body 说明背景，方便日后追溯"为什么这么改"，而不仅是"改了什么"。
