# 风险分级路由表（risk-tiers）

> SPEC-20 的规则来源 · 宪法 C12 的执行表 · v1 2026-07-31
> **本文件自身列为高风险路径**——改门禁规则须人审（防"改规则绕规则"）。
> 用法：`e2e-review` 按改动文件路径匹配下表 glob，取**命中的最高档**决定评审强度。

## 分档规则

**判据（先记这条，glob 清单是它的展开）**：
> **凡「定义门禁」或「被 required check 执行」的东西 = 高档。**
> 判断方法：如果把这个文件改成"永远通过"，某道检查会不会因此失效？会 → 高档。

| 档 | 匹配路径（glob） | 为什么高/低 | 评审强度 | 人审 |
|---|---|---|---|---|
| **高** | **规则定义**：`docs/constitution.md`<br/>`docs/process/risk-tiers.md`<br/>`docs/process/skills-manifest.md`<br/>`docs/process/stages/**`<br/>`docs/architecture/adr/**`<br/>**门禁执行体**：`scripts/check-*.sh`<br/>`ops/**`<br/>`scripts/lib/**`<br/>`tests/probe-negative/**`<br/>`bin/**`<br/>`quality-baseline.txt`<br/>**评审能力本身**：`.claude/agents/**`<br/>`.claude/skills/e2e-review/**`<br/>**权限与执行边界**：`.github/workflows/**`<br/>`.github/actions/**`<br/>`.github/CODEOWNERS`<br/>`.claude/settings*.json`<br/>`.claude/hooks/**` | 改的是**规则本身或门禁本身**——错了会让后续所有检查失效（"改规则绕规则"是最危险的路径）。<br/><br/>**三条实测教训**（异构评审 #6 · reviewer #8 · security #4 各自独立指出）：<br/>① `.claude/agents/reviewer.md` 若只算"`*.md` 文档" → 低档 → 把它改成"永远无 finding"即可**关掉整套内环，且无人审**<br/>② `scripts/check-*.sh` 是四个 required check 的**执行体**，若只算中档，改成 `exit 0` 后 required check 变成真空绿<br/>③ `bin/e2e` 一次改动会污染**所有新客户仓**（漏发 risk-tiers 的事故正是这么发生的） | reviewer + security 双 agent + **异构评审**（跨模型，宪法 C12）+ 辩论矩阵留痕 | **强制**，且 approver≠author（C14）<br/>⚠️ 当前试点仓**未启用**，见 §执行层「当前状态」 |
| **中** | `.claude/skills/**`（除 e2e-review）<br/>`scripts/**`（除 `check-*.sh` 与 `lib/`）<br/>`tests/**`（除 `probe-negative/`）<br/>`src/**` `lib/**` `app/**`<br/>业务代码（含单文件产品如 `index.html`） | 可执行代码，错了有真实后果，但有测试与探针兜底 | reviewer 单 agent + 可执行验证必过 | 建议（CI 绿可自动合并，除非 finding 有 block） |
| **低** | `docs/**`（除上列高风险项）<br/>`specs/**`<br/>`*.md` 文档类<br/>`.gitignore` `README*` | 文字与制品记录，错了改起来便宜，且探针已覆盖结构 | 仅 CI 探针（结构/链接/拼写） | 否 |
| **默认（catch-all）** | `*` —— 未命中以上任何一条的路径 | **零命中不是"没风险"，是"没想过"**。原表无兜底档，实测下列真实路径全部落空：`index.html`（**整个产品**）、`.claude/settings.local.json`（权限覆盖文件，且本仓无 `.gitignore` 可入库）、`.github/dependabot.yml` | 按**中档**处理 | 建议 |

**匹配优先级**：命中多档时取**最高档**（如同一 PR 既改 `docs/architecture/adr/` 又改 `README.md` → 按高风险处理）。

**零命中的 fail-closed 语义**（原表未定义，实现者会默认低档或跳过定档 → fail-open）：
未匹配任何具名 glob 的路径一律按**中档**处理，且**必须在定档结论里单独列出该清单**——
让"没被规则覆盖到的东西"在每次评审里可见，而不是悄悄按最低档溜过去。

## 升档触发（动态，覆盖静态路径规则）

以下情况**自动升一档**，与路径无关：

1. **门禁打回 ≥2 次**的制品（宪法 C12）——反复打回=风险信号
2. finding 中出现 `severity=block` 且分类为 `security`
3. **规模触发**（调研 v2 修订，标为**默认启发值非实证安全线**）：
   - 净改动 **>400 行** → 升档；**>1000 行** → 默认要求拆分（[Google 官方口径](https://google.github.io/eng-practices/review/developer/small-cls.html)：100 行合理、1000 行过大，比 2006 年的 SmartBear 200-400 更严且更新）
   - **文件分散度独立计**：>15 个文件即升档，即便总行数不大（Google："200 行散在 50 个文件通常就太大"）
   - **计数算法**（v1 缺失，必须明确）：只计 additions + deletions 的**非生成、非 lockfile、非 vendored** 文件；排除清单维护于本文件 §计数排除
4. 改动涉及**新增外部依赖**或第三方 Action（宪法 C15 供应链）
5. **删除测试** / 跨公共 API 变更 / 标记为 AI 生成且无人类逐行确认

## 计数排除（规模触发的分母定义）

以下路径不计入规模统计：`*.lock` `*-lock.json` `*.sum` `vendor/**` `dist/**` `*.min.*` `**/generated/**` `*.svg` `*.png`

## 阈值的演进方式（调研 v2 新增）

本表用**显式路径 glob + 事件规则**，这是**没有风险模型与事故标签时的正确做法**。
[Meta RADAR](https://arxiv.org/html/2605.30208v1) 的百分位阈值（P25→P50 渐进标定）属**成熟级能力**——需要已校准的风险模型、大量事故标签、单调性验证与漂移监控；且其 revert 率 1/3、事故率 1/50 是**观察性比较，论文明确非因果估计**。本平台在积累足够事故标签前**不采用百分位**。

## 降档禁止

- 任何情况下**不得**把高风险路径降档处理；确需例外须记 ADR 并由人批准
- `--force`/`--no-verify` 类绕过操作在高风险路径上一律视为违规（宪法 C3）

---

## 执行层：分档如何在 GitHub 上真生效（S6 spike 实测，ADR-014）

上表是**判据**，本节是**执行机制**。判据写在文档里没有强制力——分档必须落到服务端才算数（宪法 C3）。

### 三条通路（各自的强制力不同）

> ⚠️ **本表描述的是机制的能力，不是当前仓的状态。** 「当前状态」列是实测值，
> 不看它就引用本表，会得到"高档有人审"的错误印象（security 评审 #6 指出：
> 原表用现在时声称"服务端硬拦、无人能绕过"，而实测 `approvals=0`，作者可自合）。

| 分档 | 服务端机制 | 机制的强制力 | **当前试点仓状态（实测）** |
|---|---|---|---|
| **高** | `CODEOWNERS` + `require_code_owner_reviews: true` | 服务端硬拦，PR 不合规无法合并 | 🔴 **未启用**——`require_code_owner_reviews=false`、`approvals=0`。改宪法/风险表/workflow 的 PR，四检查绿后**作者可自合，零人审**。C14「approver≠author」服务端强制力为 **0** |
| **中** | required status checks（CI 四检查） | 服务端硬拦 | ✅ 已启用（`enforce_admins=true`，行为探针 CONFIRMED） |
| **低** | 同上 CI 检查，但无人审要求 | 服务端硬拦（仅结构类） | ✅ 已启用 |
| 升档触发 | `e2e-review` 计算后打 label + 在 PR 正文写明档位 | **无强制力**（label 可人工改） | 🔴 未实现强制 |

**"高档人审"在单人试点仓不可用**，这不是配置疏漏而是结构限制（ADR-014 陷阱③：
单人仓 owner 即作者，GitHub 不允许自批，开了必永久死锁）。扩员至 ≥2 人前，
高档改动的把关只能由 ① 确定性检查 ② 跨模型异构评审留痕 承担，**且必须如此声明**。

**必须诚实的一点**：升档触发（§升档触发 1-5 条）**目前只有建议力**。GitHub 没有"按 diff 规模自动提高必审人数"的原生能力，label 也不能作为 required check 的输入。要让它有强制力，需要一个 CI job 自行计算档位并在不达标时 exit 非零——这条列入 backlog，**在实现前手册不得声称"规模超限会被自动拦下"**。

### CODEOWNERS 的前置条件（否则形同虚设）

1. `enforce_admins: true` —— 否则 admin 直推绕过一切（ADR-014 陷阱②，实测证伪过）
2. `require_code_owner_reviews: true` —— 光有 CODEOWNERS 文件**不产生任何强制力**，它只决定"自动请谁来审"
3. **仓库人数 ≥2** —— 单人仓里 owner 就是作者，GitHub 不允许自批，PR 会永久阻塞（ADR-014 陷阱③）

故单人仓（试点/demo）的正确配置是：**放 CODEOWNERS 文件**（作为路径→责任人的声明，供未来扩员即时生效），但 `require_code_owner_reviews` 保持 `false`，并在 PR 记录中写明"单人仓，高风险人审由异构评审留痕代行"。

### 验证方式

`bash ops/check-branch-protection.sh` —— **行为证明探针**：实际尝试直推受保护分支，必须收到 `protected branch hook declined`。不接受"配置回读一致"作为通过依据（理由见 ADR-014）。
