# E2E 研发平台 实施手册

> 版本基线：见文末 §版本基线字段 · 契约：SPEC-24 · 最近更新 2026-07-31
> 适用：macOS（Linux/Windows **未验证**，见 §已知限制）
> 本手册面向**要把这套流程落到自己项目里的人**。给 agent 的指令在 `AGENTS.md` / `CLAUDE.md`。

---

## 0. 先看这一节：这套东西凭什么值得用

市面上"AI 时代研发流程"的方法论不缺。本平台的差异不在于流程图画得更漂亮，
而在于**每一条主张都有一个会失败的可执行断言钉着**。

在自建 + 自用的过程中，这套门禁抓到了 **30+ 条真实缺陷**，其中相当一部分
**光看代码、光靠"我觉得对了"永远发现不了**。下面这张表是本手册的核心：

| 抓到的缺陷 | 如果没抓到，客户会遭遇什么 |
|---|---|
| `enforce_admins` 默认 `false` | **每个客户仓都配了一道假门禁**：配置回读全绿、GitHub 打印 "4 of 4 required status checks are expected"，直推 main 照样成功 |
| 探针的 `git commit --allow-empty` 会提交已暂存内容 | **门禁探针把客户暂存的机密推进公开仓** |
| `tpl_ci` 函数从未定义 | **每个脚手架仓拿到 1 字节空 workflow** —— 目录看起来齐全，CI 根本不存在 |
| `grep -P` 在 macOS BSD grep 上不支持 | 配上 `2>/dev/null \|\| true` 后探针**永远 PASS** |
| 分档表漏了 `.claude/agents/**` | 改一个 md 文件就能**关掉整套评审内环**，且无人审 |
| `scripts/check-*.sh` 只算中风险 | 四个 required check 的**执行体**改成 `exit 0` → 检查变成真空绿 |
| 6/7 阶段探针不校验自己那道门的决定值 | 门禁记录写错一个词能过自己那道门，**下一阶段才炸或永远不炸** |
| PRR 21 条断言里 16 条被独立证伪 | 一份**带着 16 处美化**的生产就绪评审通过放行 |

**这些不是演示用的假 bug，是这套平台在建造自己时踩到的真坑，每一条都留下了负样本。**
完整目录见 §2。

---

## 1. 安装与前置（doctor）

### 1.1 前置分层

工具按"缺了会怎样"分三层，不是一刀切要求全装（ADR-010）：

| 层 | 工具 | 缺了会怎样 |
|---|---|---|
| **基础层**（必需） | `git`、`bash` | 全流程跑不起来 |
| **远程层** | `gh`（GitHub CLI，需 `gh auth login`） | 门禁③④ 的服务端校验降级为本地路径；CI 相关能力不可用 |
| **目标栈层** | `jq`、`shellcheck`、你项目的 lint/test | 相应能力降级，**不是错误** |

### 1.2 一条命令自检

```bash
bash bin/e2e doctor
```

- 退出 0 = 基础层齐备（可能有可选项缺失，会明确列出并说明降级到什么）
- 退出 1 = 基础层缺项，按输出的安装指引装完再来

**设计原则**：`doctor` **不会**因为可选工具缺失而失败。降级是明说的，不是静默的。

---

## 2. 陷阱目录（本手册的核心）

每条都是**实测踩到的**，每条都有一个**对旧实现会失败**的负样本钉着。
按"最容易伪装成正常"排序 —— 越靠前的越危险，因为它们**看起来是绿的**。

### 2.1 服务端门禁类：配置绿 ≠ 控制有效

#### 陷阱 A ｜ `enforce_admins` 默认 `false` —— 最危险的一条

**现象**：配置 PUT 成功、API 回读四项 required checks 全在、push 时 GitHub 还打印
`4 of 4 required status checks are expected` —— **然后照样让你推上去**。

**为什么危险**：所有"看起来像验证"的信号都是绿的。而小团队/单人仓里**每个人都是 admin**，
所以默认配置下分支保护对**实际会推代码的所有人**都不生效。

**官方文档怎么说**：只描述功能（"Enforce all configured restrictions for administrators"），
**不声明默认值**（[REST 分支保护文档](https://docs.github.com/en/rest/branches/branch-protection)）。
默认值只能实测得知 —— 这就是它咬人的原因。

**处置**：
```bash
gh api -X POST repos/<owner>/<repo>/branches/main/protection/enforce_admins
```
**验收**：`bash ops/check-branch-protection.sh` —— 它不看配置，**实际推一次**，必须收到
`protected branch hook declined`。

#### 陷阱 B ｜ 免费账号的**私有**仓完全没有分支保护

**现象**：`403 Upgrade to GitHub Pro or make this repository public`。

**官方文档口径**（这条文档写清楚了）：「Protected branches are available in **public** repositories
with GitHub Free…, and in **public and private** repositories with GitHub **Pro/Team/Enterprise**」。

**对咨询报价的含义**：**"服务端硬门禁"不是免费的，它有入场费**。
三级实施包必须把"GitHub 计划"列为入场条件（见 §5），不能假设客户都有。

#### 陷阱 C ｜ `require_last_push_approval` 在 `approvals=0` 时仍造成永久死锁

**现象**：四项检查全 `SUCCESS`、`required_approving_review_count=0`、`mergeable: MERGEABLE`，
但 `mergeStateStatus` 恒为 `BLOCKED`。

**A/B 对照**（单一变量）：
```
require_last_push_approval=false → CLEAN
require_last_push_approval=true  → BLOCKED
```

**机制**：该开关语义是"最后一次 push 必须由**非推送者**批准"，它**不看** `approvals` 的数值。
单人仓里那个"他人"不存在 → 永久死锁。而「作者不能批准自己的 PR」是
**平台硬规则，无任何配置可覆盖**（社区讨论确认）。

**官方文档口径**：只说 default false 与用途，**完全未提与 `required_approving_review_count` 的交互**。

**处置**：单人仓必须 `require_last_push_approval: false`。分级见 §5.3。

#### 陷阱 D ｜ `require_last_push_approval` + `strict` 组合互锁

点 "Update branch" 会产生一个**空 commit**，它算作"最近一次 push"，于是**又需要一次他人批准**——
形成"更新 → 需批准 → base 又变 → 再更新"的循环。

**处置**：≥2 人团队开 `require_last_push_approval: true` 时，**必须同时评估是否关掉 `strict`**，
否则活跃仓会陷入该循环。

### 2.2 探针自身类：防 fail-open 的东西自己 fail-open

> **这一类是最反直觉的**：你写了一个探针去防某类问题，而**探针自己就有那类问题**。
> 判断方法只有一个 —— **给探针写负样本，并验证负样本对旧实现会失败**。

#### 陷阱 E ｜ `grep -P` 在 macOS 上静默失效

BSD grep 不支持 PCRE，报 `invalid option -- P`。若配了 `2>/dev/null || true`，
就变成**永远 PASS** —— 探针存在、CI 是绿的、什么都没检查。

**处置**：用 ERE（BSD/GNU 通吃）；`LC_ALL=C` 使 `[^ -~]` 按字节匹配从而命中中文。
**并给探针加自检金丝雀**：先用已知陷阱样本验证扫描引擎可用，不可用即 exit 66。

#### 陷阱 F ｜ 金丝雀用的正则与生产不是同一条

自检金丝雀本意是"证明扫描引擎可用"，但若它用**自己的一条正则**，
就只验证了"一条没人用的正则能工作" —— 生产正则写坏了它照样绿。

**处置**：抽成**单一变量**，金丝雀与生产共用。负样本：把生产正则替换成永不匹配的串，
金丝雀必须报警（exit 66）而非静默 PASS。

#### 陷阱 G ｜ 探针"什么都没检查"却退出 0

实测四条真空 PASS 路径：目标目录不存在 / 目录为空 / 没有可检对象 / 抽取器抽出 0 条。
四条全部 `exit 0`。

**处置**：**无可检对象 = 响亮失败（exit 66），不是 PASS。** "跳过"就是静默放行。

#### 陷阱 H ｜ 管道吞掉退出码

```bash
bash some-check.sh | tail -3; echo "exit=$?"   # ← $? 是 tail 的！
```
本次自建过程中**这个坑踩了三次**，包括让一次跨模型评审静默失败。

**处置**：`cmd > log 2>&1; RC=$?` 或 `${PIPESTATUS[0]}`。**任何验证命令都别在管道后取 `$?`。**

#### 陷阱 I ｜ `fp=$(a | cut)` 的 `||` 兜底永不触发

```bash
fp=$(printf '%s' "$x" | md5 -q | cut -c1-8) || fp=$(... | md5sum | ...)
```
赋值的退出码取自管道末端的 `cut`。`md5` 不存在时 `cut` 仍退 0 且输出**空串**，
兜底分支**永远不会触发**，指纹静默变空 → 同 rule+file 的违规全部塌缩成一条。

**处置**：用 `command -v` **显式探测选择**，探不到就响亮失败（fail-closed）。

### 2.3 脚手架类：产物"看起来齐全"但是空的

#### 陷阱 J ｜ 模板函数未定义 → 写出空文件

`gen_file "x.yml" "$(tpl_x)"` 中 `tpl_x` 从未定义 → stderr 一行 `command not found`，
然后**静静写出 1 字节空文件**。业务仓拿到**空 workflow**（GitHub 视为无效 = 根本没有 CI）。

**处置**：`gen_file` 必须**拒绝写出空内容**。
**空脚手架比不产出更危险**：目录看起来齐全，门禁其实不存在。

#### 陷阱 K ｜ skill 引用了脚手架不发的文件

skill 的 SOP 引用仓内文件（分档表 / 阶段定义 / 模板）。脚手架漏发 → skill 跑到那步
**"找不到就跳过"** → 静默降级为不检查。

实测：漏发 `docs/process/risk-tiers.md` → 评审第 1 步定档无数据源 → **一切按低风险处理**
→ 不跑 LLM 与异构评审。

**处置**：`scripts/check-skill-deps.sh` 守住整类。
**但要诚实声明它的能力边界** —— 它只查**显式路径引用**，抓不到 markdown 链接、
花括号展开、变量拼接、传递依赖、外部工具依赖。对外只能说"显式路径引用已守住"。

#### 陷阱 L ｜ 条款号悬空

`.claude/agents/security.md` 写着"按宪法 C14 检查批准归因"，而本仓 `constitution.md`
只定义到 C5 → agent 读不到 C14 后**不报错，按无约束继续**。

**处置**：`scripts/check-clause-refs.sh` —— 被引用的条款必须有定义。

### 2.4 门禁规则类：改门禁绕门禁

#### 陷阱 M ｜ 门禁的**执行体**落在低/中风险档

三个独立评审各自指出的同一件事：

- `.claude/agents/reviewer.md` 只命中"`*.md` 文档" → **低档 = 无人审** → 改成"永远无 finding"
  即可**关掉整套评审内环**
- `scripts/check-*.sh` 是四个 required check 的**执行体**，只算中档 → 改成 `exit 0` 后
  required check 变成**真空绿**
- `docs/process/stages/**`（各 skill 声明的 SOP 权威定义）→ 低档
- `bin/e2e` 一次改动**污染所有新客户仓**

**处置**：分档表前置一条**判据**，让清单可推导而非死记：

> **凡「定义门禁」或「被 required check 执行」的东西 = 高档。**
> 判断方法：把这个文件改成"永远通过"，某道检查会不会因此失效？会 → 高档。

#### 陷阱 N ｜ 分档表没有 catch-all 默认档

零命中行为未定义 → 实现者会默认低档（fail-open）。实测落空的真实路径：
`index.html`（**整个产品**）、`.claude/settings.local.json`（权限覆盖文件）、`.github/dependabot.yml`。

**处置**：加默认档（`*` → 中档）+ **零命中必须在定档结论里单独列出清单**，
让"没被规则覆盖到的东西"每次评审都可见。

#### 陷阱 O ｜ 门禁台账不校验决定值合法性

7 个阶段探针里 **6 个**只用 `gate_status` **显示**决定值，从不校验它属于契约集合。
门禁④ 被填成"放行"（契约是 `批准`/`打回`）后 `--final` 判 PASS 放行，
直到**下一阶段入口**才炸。

**处置**：`gate_assert_legal`（`gate.sh` 单一实现），接入全部阶段探针。

#### 陷阱 P ｜ 能改远端状态的脚本躺在通配放行区

`.claude/settings.json` 有 `Bash(bash scripts/*)` 白名单。把一个**向远端受保护分支 push**
的探针放进这条已授权前缀 → agent 可无提示、带任意参数调用它。

**处置**：远端写操作类脚本移出 `scripts/` → `ops/`（不在 allow 列表，需逐次确认），
并把 `ops/**` 列入高风险档。

### 2.5 评审契约类

#### 陷阱 Q ｜ 把"LLM 发现的问题严重"当成"LLM 有权阻断"

三通道契约的要害：**确定性规则是唯一 blocker 来源；LLM 只做建议**。
违反它的后果是"AI 说这必须阻断"变成事实上的阻断权。

**但这不意味着 LLM 发现的问题不重要。** 正确处置**不是改标签，而是补测试**：
凡能写成**对旧实现会失败**的可执行断言的，authority 就来自那条测试 → 转为确定性通道；
写不出可执行断言的，诚实记为 advisory，**不占用阻断权**。

#### 陷阱 R ｜ 单轮取证的自证倾向

生产就绪评审（PRR）由 5 个独立 agent 取证后，再交独立 agent 逐条**尝试证伪**：
**21 条断言里 16 条被证伪**。绝大多数不是"结论错"，而是**证据不实或射程过宽**——
把 partial 说成 ok、把"做起来麻烦"说成 N/A、引用没跑过的命令输出。

**处置**：任何"已就绪"与"不适用"的断言都必须过独立证伪。
**这个比例（16/21）本身就是结论**：没有对抗验证，评审会带着大量美化通过。

---

## 3. 绿地路径（新项目从零接入）

```bash
# 1. 前置自检
bash bin/e2e doctor

# 2. 生成骨架（幂等，既有文件一律不覆盖）
bash bin/e2e init /path/to/your-project
cd /path/to/your-project

# 3. 立项（阶段0）—— 用 skill，别手写
#    在 Claude Code 里说："立项：<你的想法>"，或 /e2e-discovery
#    产出 specs/<feature>/prfaq.md，停在门禁⓪ 等你裁决 go/modify/kill

# 4. 之后每一段都由对应 skill 驱动，每段结束停在门禁等人批：
#    ① /e2e-requirements → prd.md
#    ② /e2e-design       → spec.md + plan.md + ADR
#    ③ /e2e-implement    → tasks.md + 代码
#    ③ /e2e-review       → review.md + PR
#    ④ /e2e-release      → release.md + runbook
#    ⑤ /e2e-retire       → deprecation.md
```

**init 会发给你什么**：七个 skill、三个 agent、两个 hook、公共库、全套探针与负样本、
宪法 C1-C15、风险分档表、七个阶段定义、CI workflow、`.claude/settings.json`。

**验收**：`bash scripts/check-skill-deps.sh && bash scripts/check-clause-refs.sh && bash tests/probe-negative/run.sh`
三条全绿才算接入成功。

---

## 4. 存量治理 playbook（brownfield）

存量项目的典型状态：代码混乱、文档不全、架构不合理。
**不要一上来就重构** —— 按下面四步走，每步都是非破坏的。

### 4.1 体检（只读，不动目标仓一个字节）

```bash
bash bin/e2e assess /path/to/legacy-repo
```

产物落在**仓外**（`<repo>/../e2e-assess-<name>-<ts>/`），包含热点清单、结构快照、
风险分档初稿。**只读契约的验证方式**：assess 前后 `git status --porcelain=v1 -uall` 完整快照零差异。

> **历史不足时会降级**：commit 数 < 20 或 shallow clone 时，churn 数据不可信，
> 自动改用规模清单并**明说这是降级**。降级不是错误，但降级也不许假装。

### 4.2 接入（非破坏，既有文件一律保留）

```bash
bash bin/e2e adopt /path/to/legacy-repo
```

既有同名文件**一律不覆盖**，冲突进清单并以 exit 2 报告。你逐项人工核对后再决定。

### 4.3 质量棘轮（存量违规豁免，新增违规阻断）

```bash
bash scripts/ratchet.sh --rebaseline   # 一次性：把当前违规收进基线
bash scripts/ratchet.sh                # 之后每次：新增违规即 exit 1
```

**设计要点**（否则会漏报）：
- 违规身份 = `工具:规则:文件:内容指纹`，**不含行号** —— 行号漂移不误报（已实测）
- 判定用**集合差**（`comm -13`），不是数量比较 ——
  数量比较有洞：删一个旧违规 + 加一个新违规，总数不变但质量变了
- `quality-baseline.txt` 属**高风险路径**，改基线须人审（防"改基线绕棘轮"）

### 4.4 绞杀（逐块替换，不做大爆炸重写）

先在热点清单的 Top-N 里选**改动频繁 × 体量适中**的模块，按绿地路径走完整六门禁，
其余部分由棘轮守住不恶化。**不设"全量重构"里程碑。**

---

## 5. L4 实施指引（企业控制平面）与三级实施包

### 5.1 四层架构

| 层 | 是什么 | 换工具会不会丢 |
|---|---|---|
| **L1 工具无关真相** | `docs/` `specs/` `AGENTS.md` —— 制品即真相 | 不丢 |
| **L2 Claude 适配层** | `.claude/`（skill / agent / hook / settings） | 换工具需重写适配层，L1 不动 |
| **L3 分发** | plugin / marketplace / 模板仓 | — |
| **L4 企业控制平面** | 分支保护、required checks、CODEOWNERS、审计事件 | 平台侧能力 |

**宪法 C4**：产物是真相，工具是适配。`.claude/` 里**不放业务真相**。

### 5.2 门禁分级说明（ADR-009：试点模式 vs 企业模式）

| | **试点模式** | **企业模式** |
|---|---|---|
| 门禁记录 | 文本台账 = **过程留痕** | **服务端事件为准** |
| 强制力 | 无（可被绕过） | 服务端硬拦 |
| 入场条件 | 无 | GitHub Pro/Team/Enterprise 或公开仓；`enforce_admins=true` |
| 可否声称"有门禁" | **不可以** —— 只能说"有过程记录" | 可以，但须附**行为证明** |

> **判定命令**：`bash ops/check-branch-protection.sh`
> exit 0 = 企业模式成立（配置不变量 ∩ 行为证明双双通过）
> exit 2 = 降级为试点模式，**此状态下禁止声称"门禁已启用"**

### 5.3 三级实施包（按入场条件分层报价）

| 级 | 入场条件 | 能给到什么 | 给不到什么 |
|---|---|---|---|
| **起步级** | 免费 GitHub、单人或双人 | 全套 skill + 探针 + 棘轮 + 本地门禁；**试点模式**过程留痕 | ❌ 服务端强制（私有仓配不了分支保护）<br/>❌ approver≠author（单人仓 GitHub 硬规则不允许自批） |
| **团队级** | GitHub Team/Pro，≥2 人 | 上述 + **企业模式**服务端硬门禁：`enforce_admins=true`、required checks、`approvals=1`、`require_last_push_approval=true` | ⚠️ 开 `require_last_push_approval` 时需评估是否关 `strict`（陷阱 D） |
| **成熟级** | Enterprise，有安全团队 | 上述 + CODEOWNERS 高风险路径强制人审 + 审计事件外送 + SAST 接入 | ⚠️ 升档触发（规模/依赖）**目前只有建议力**，需自建 CI job 才有强制力 |

**报价时必须说清的一句话**：起步级**没有服务端强制力**。
这不是产品缺陷，是 GitHub 计划的边界。把它说成"有门禁"是欺骗。

### 5.4 单人仓 / 团队仓的分支保护配置

| 场景 | `approvals` | `require_last_push_approval` | `dismiss_stale_reviews` | `enforce_admins` |
|---|---|---|---|---|
| 单人仓 | `0` | **`false`**（开了必死锁，陷阱 C） | `true` | `true` |
| ≥2 人 | `1` | `true`（**同时评估关掉 `strict`**，陷阱 D） | `true` | `true` |
| 高风险路径 | `≥1` + `require_code_owner_reviews: true` | `true` | `true` | `true` |

**验收两条都要过**：
```bash
bash ops/check-branch-protection.sh                      # 配置不变量 ∩ 行为证明
gh pr view <n> --json mergeStateStatus --jq '.'          # 必须 CLEAN，不能 BLOCKED
```
只回读配置**不算数**（陷阱 A 的全部教训）。

---

## 6. 六门禁怎么走

| 门禁 | 何时 | 产物 | 决定值 | 谁批 |
|---|---|---|---|---|
| **⓪ 立项** | 想法 → 是否值得做 | `prfaq.md` | `go` / `modify` / `kill` | 人 |
| **① 需求** | 想法 → 可测需求 | `prd.md` | `批准` / `打回` | 人 |
| **② 设计** | 需求 → 可实现设计 | `spec.md` `plan.md` ADR | `批准` / `打回` | 人 |
| **③ 合并** | 代码 → 可合并 | `review.md` + PR | `批准` / `打回` | 人，且 approver ≠ author |
| **④ 发布** | 合并 → 生产放行 | `release.md` + runbook | `批准` / `打回` | 人，且 ≠ 发布执行者 |
| **⑤ 退役** | 上线 → 有序下线 | `deprecation.md` | `批准` / `打回` | 人 |

**串锁**：每个阶段的 skill 第 0 步硬校验上游门禁，不过即 exit 64 拒绝启动。
**决定值必须精确取契约集合内的词**（陷阱 O）—— 写"放行"而非"批准"会在下一阶段炸。

**每段结束 skill 都会停下等你裁决，不会自己批准**（宪法 C14）。

---

## 7. 已知限制（不得对外声称已解决）

### 7.1 平台级

- **仅 macOS 实测**。Linux / Windows **未验证**。CI runner 显式钉 `macos-latest`。
- **升档触发无强制力**：规模/依赖超限只有建议力，没有 CI job 计算并阻断。
  **手册与销售材料不得声称"规模超限会被自动拦下"。**
- **分档可手填绕过**：评审探针只信 `review.md` 自填的档位；把高风险改动手填成低档，探针发现不了。
- **`check-skill-deps.sh` 只覆盖显式路径引用**，见陷阱 K 的能力边界声明。
- **只有一个人跑过**。全部验证来自自建者 + AI 评审，**没有真人冷启动验证**。
  正式交付前应找人照本手册从零跑一遍 —— 他卡在哪，哪就是手册的洞。

### 7.2 macOS bash 高危写法清单（全部已固化为 `check-shell-traps.sh`）

| # | 高危写法 | 后果 | 正确写法 |
|---|---|---|---|
| 1 | `$var` 紧跟中文标点 | bash 把标点字节并入变量名 → `unbound variable` | `${var}（…）` |
| 2 | `grep -P` | BSD grep 不支持；配 `2>/dev/null \|\| true` 则**静默永远 PASS** | ERE + `LC_ALL=C` |
| 3 | `grep -r --include` 传**单个文件路径** | 静默返回空，单文件检查形同虚设 | 单文件走 `grep -n` |
| 4 | `sed -i` 不带 `''` | BSD/GNU 语法分歧 | `sed -i ''` |
| 5 | `$(cmd \| grep -c …) \|\| echo 0` | `grep -c` 无匹配已输出 0 但退出码 1 → 追加第二行破坏整数比较 | `n=$(…); : "${n:=0}"` |
| 6 | `timeout` / `realpath` / `sha256sum` / `md5sum` / `readlink -f` | **macOS 基础系统没有这些 GNU 命令** | `gtimeout` / `cd+pwd` / `shasum -a 256` / `md5` |
| 7 | 管道后取 `$?` | 拿到的是管道**末端**命令的退出码 | `cmd > log 2>&1; RC=$?` |

**豁免写法**：行尾加 `# shell-traps:ok <理由>`。豁免必须写在代码里、看得见、可审计。

> **注**：本清单在 zsh 下还有第 8 条 —— zsh **不做默认分词**，
> `set -- $VAR` 拿到的是整串。本手册的命令均在 bash 下验证。

### 7.3 供应链（C15）

- 第三方 Action **必须 SHA-pin**（可变 tag 可被移动）。本仓已 pin 并配 Dependabot。
- **注意**：`package-ecosystem: "github-actions"` **不需要任何 manifest 文件** ——
  "没有 package.json 所以 SCA 不适用"是错的，GitHub Actions 本身就是依赖生态。
- secret 扫描当前是**结果干净**，不等于**前向控制**（无 push protection / pre-commit hook）。

---

## 8. 版本基线字段

| 字段 | 值 |
|---|---|
| 平台版本 | `0.1.0-M1`（`bin/e2e version`） |
| 实测环境 | macOS（Darwin 25.5.0）、bash 3.2.57、BSD grep |
| 验证基线 | 负样本 **56/56**；六门禁全链路 PASS；demo 仓 CI 四 job 全绿 |
| gitleaks | 8.30.1（两仓全历史 0 leaks） |
| 门禁行为证明 | 两仓 `ops/check-branch-protection.sh` 均 CONFIRMED |
| Action pin | `actions/checkout@fbc6f3992d24b796d5a048ff273f7fcc4a7b6c09`（v5） |
| 浏览器实测 | Chrome + Safari（macOS）；Windows/Linux/移动端未测 |

---

## 9. 出问题时

1. **先跑全量自检**：
   ```bash
   bash bin/e2e doctor
   bash scripts/check-skill-deps.sh && bash scripts/check-clause-refs.sh
   bash scripts/check-shell-traps.sh && bash tests/probe-negative/run.sh
   ```
2. **门禁卡住** → 看探针输出的 `MISSING:` 行，它会指出缺哪一项与为什么
3. **行为与预期不符且说不出机制** → **先查官方文档再猜**。
   本手册 §2 里有两条陷阱（A、C）就是官方文档没写、只能实测发现的 ——
   但陷阱 B 和 D 读一次文档就能避免，摸索它们纯属浪费时间。
