# SPEC：platform-pilot（行为契约）

> 阶段 2 产物 · 门禁②评审材料 · 2026-07-31 · 模板见 docs/process/stages/stage-2-design.md
> 上游：prd.md（门禁① 批准 @2026-07-31）｜ 状态：待批 → 批准后进阶段 3（tasks）

## 范围与读者

覆盖 PRD 全部 SR-1~5 与 US-1~13 的平台侧行为契约（demo 应用自身的功能契约由 demo 仓走六门禁另出）。读者：实现者（M1-M4）、architect 预审、异构评审、门禁②决策人。

## 行为契约

### 门禁账本（ADR-009 分级：本节契约=**试点/单人模式**；企业强制模式的权威载体=服务端事件，见 SPEC-19 与 ADR-009）

- **SPEC-1**：每个阶段制品在文件尾部必须含门禁记录块，格式固定四行：`- 批准人：`/`- 决定：`/`- 日期：`/`- 备注：`。**定位=流程留痕**，手册与脚手架生成物页脚须标注"流程提示，非防伪审批证据"（ADR-009）。验证：各阶段 check-*.sh 的门禁状态解析非 UNKNOWN + 生成物页脚标注 grep
- **SPEC-2**：`决定：` 合法值——门禁⓪∈{go, modify, kill}；门禁①②④⑤∈{批准, 打回}；待批统一为 `<待填>`。**门禁③显式豁免文本块**：其账本载体=服务端事件（PR 合并 + required checks，见 SPEC-19 与 ADR-003），不落制品文本块。验证：探针正则枚举；非法值报 UNKNOWN 并 WARN
- **SPEC-3**：门禁记录一旦填批准值不得改写（修订=新增备注行，历史行保留）。验证：**可执行探针（M1 git 化后落地）**——CI 中比对门禁记录块 git 历史，已填批准值的行被修改/删除即 FAIL；负样本入 `tests/probe-negative/`。手册条款仅作补充说明，不计为验证

### 门禁串锁（SR-1）

- **SPEC-4**：每个 e2e-* skill 第 0 步必须校验上一门禁：⓪未 go 时 e2e-requirements 拒绝；①未批准时 e2e-design 拒绝；②未批准时 e2e-tasks/implement 拒绝。**门禁③（载体=服务端）的校验方式**：e2e-release 第 0 步——有远程仓时 `gh pr view --json state,statusCheckRollup` 验证 PR 已合并且 checks 全绿；本地 git 时降级为目标分支 merge commit 存在 + 全量测试绿。拒绝时输出所缺门禁与指路。验证：各探针 `--gate-only` 对负样本退出 64（已实证：check-prd/check-design）；门禁③路径 M3 实测
- **SPEC-5**：门禁解析逻辑必须来自公共库 `scripts/lib/gate.sh`（单一实现），各探针 source 之。验证：`grep -L "lib/gate.sh" .claude/skills/*/scripts/check-*.sh` 为空（M1 起生效）

### 探针契约（SR-2 · 宪法 C13）

- **SPEC-6**：每阶段探针退出码统一语义：0=PASS / 64=上游门禁未过 / 65=制品文件缺失 / 66=结构或质量缺项。验证：`tests/probe-negative/` 各码至少一个构造样本
- **SPEC-7**：每个探针必须有负样本测试：对构造的坏制品 FAIL（对应码），对好制品 PASS。验证：`bash tests/probe-negative/run.sh` 全绿（M1 落地）
- **SPEC-8**：探针只读被检文件，不修改任何内容。验证：跑探针前后 `git status` 无差异（M1 git 化后可测）

### 脚手架（US-1 绿地）

- **SPEC-9**：`e2e init` 在空 git 仓库生成完整目录树（AGENTS.md/CLAUDE.md/.claude/{settings,skills×7,agents×4,hooks×2,rules}/docs/{constitution,architecture,process}/specs/.github/workflows），全部中文注释。验证：init 后自检探针（文件清单逐项存在 + hooks 可执行位）
- **SPEC-10**：init 具幂等安全：目标文件已存在时一律不覆盖，输出冲突清单后退出码 2。验证：预置同名文件跑 init，文件内容不变且清单含该文件
- **SPEC-11**：`CLAUDE.md` 生成物 ≤200 行且核心内容用 `@docs/constitution.md`（Claude Code import 语法）引用而非内联。验证：行数探针 + grep `@docs/constitution.md`（正文与验证同一写法，防模板/探针漂移）

### 存量接入（US-1 brownfield + US-13）

- **SPEC-12**：`e2e assess` 只读体检，**试点技术栈限定**（异构评审#1）：md/bash（平台仓自审）与 demo 的 web 栈；口径钉死为最小可算——热点=git log 一年内改动次数 × 文件非空行数（浅历史降级见 plan S4）、死代码线索=无引用文件清单（grep 交叉）、覆盖缺口=有测试目录但无对应测试的源文件清单。三产物（健康度报告/risk-tiers 初稿/热点清单）输出到**目标仓同级目录** `<repo>/../e2e-assess-<仓名>-<时间戳>/`（`-o` 可改）。验证：assess 前后目标仓 `git status --porcelain=v1 -uall` 完整快照（tracked+untracked+index）零差异 + 三产物在仓外输出目录存在
- **SPEC-13**：`e2e adopt` 非破坏叠加，产出清单钉死（承 US-1 AC）：①叠加目录树（同 SPEC-9 减去已存在项）②架构基线=spine.md 初稿（as-is 扫描）+AGENTS.md+3~5 条追认 ADR 框架文件 ③delta-spec 目录约定生效（`specs/<change>/`）。冲突时保留原文件、清单落 `docs/adopt-conflicts.md`；**该文件已存在时写仓外时间戳文件并退出 2**。验证：预置冲突样例仓实测（M2），产物清单逐项探针
- **SPEC-14**：ratchet 基线机制（ADR-010 行式格式）：基线=`quality-baseline.txt`，一行一 violation 身份 `工具:规则:文件:指纹`（首行注释记 tool/version/日期）；判定用**集合差**——`comm -13 <(sort baseline) <(sort current)` 非空即失败（防"删旧增新总数不变"）；基线更新仅经 `e2e ratchet --rebaseline` 显式命令且该文件列入高风险路径（改动须人审，SPEC-20）。验证：存量样例仓两类负样本——注入新违规、**替换违规（总数不变）**均须红（M3）

### hooks（SR-3，demo 仓）

- **SPEC-15**：PostToolUse hook 在文件编辑后同步执行 lint，lint 失败输出进会话上下文。验证：demo 仓构造 lint 违规实测（M3）
- **SPEC-16**：Stop hook 在测试未全绿时阻止收工并回显失败用例。验证：demo 仓构造失败测试实测（M3）

### 自包含（SR-5 · 宪法 C9）

- **SPEC-17**：平台仓任意文件不得含个人绝对路径（`/Users/<name>` 等）或对 `~/.claude` 的**运行时依赖**。验证：`scripts/check-selfcontained.sh` grep 零命中。白名单=说明性引用（非运行时依赖），清单维护于该脚本头部数组，初始含：ADR-006（vendored 源说明）、plan.md（结构图外部源标注）、本条

### 评审与 CI 双环（US-5/US-8 · 宪法 C12）

- **SPEC-19**：demo 仓每个 PR 必触发双环，**阻断条件钉死**（异构评审#4）：required checks 命名固定为 `quality-gates`（lint+test+ratchet）与 `ai-review`；ai-review 中 severity=block 级 finding ≥1 → check 红；任一 required check 红或高风险路径无人类 approve（分支保护 required review，且 approver≠author，宪法 C14）→ 不可合并。**企业模式下这些服务端事件即门禁③权威账本**（ADR-009：记录 actor/时间/SHA/URL）。验证：三类端到端负样本 PR——lint/test 违规、高风险路径无人审、AI block 级 finding——均须被阻断（M3）
- **SPEC-20**：评审深度按 `docs/process/risk-tiers.md` 分档路由，**匹配规则=该文件中的 glob 路径清单**；高风险 PR 强制人审+加深评审（CODEOWNERS/分支保护 required review ≥1，approver≠author）；高风险制品的评审记录块必须含异构辩论矩阵（意见/立场/论据三列，≥1 有效行）；**risk-tiers.md 与 quality-baseline.txt 自身列入高风险路径**（改门禁规则须人审）。验证：探针检查矩阵结构（M2 入 check-design `--final`）+ 高/低风险两类 PR 路由实测（M3）

### 六件套结构（ADR-008 · manifest 驱动）

- **SPEC-18**：能力拓扑唯一来源=`docs/process/skills-manifest.md`（七 skill：discovery/requirements/design/implement/review/release/retire；tasks 归 implement 第 1 步）。结构探针**读 manifest 逐行比对**：每登记 skill 的目录含 SKILL.md+templates/+scripts/check-*.sh、阶段定义文档存在、glossary 有对应阶段节。scaffold 生成也读同一 manifest。验证：结构探针遍历 manifest 比对（M1 增强）

### 后段能力最小契约（异构评审#2：Must 不许空转）

- **SPEC-21**：e2e-implement 第 1 步产出 `tasks.md`：每条任务含 `验证：` 行（可执行命令或可观测判据），无验证行的任务探针拒绝；实现按任务推进并回勾。验证：check-tasks.sh 逐条解析（M2）
- **SPEC-22**：e2e-release 产出两件：PRR 核对记录（逐项勾选+核对人）与 `docs/runbooks/<feature>.md`（启动/回滚/故障三节非空）。验证：check-release.sh 结构探针（M2）
- **SPEC-23**：e2e-retire 产出 deprecation 计划：数据迁移/用户通知/支持期义务三节非空 + 门禁④记录引用。验证：check-retire.sh（M2）
- **SPEC-24**：实施手册结构契约：含章节——安装与前置（doctor）/绿地路径/存量治理 playbook/L4 实施指引/已知限制（Linux 未验证+高危写法清单）/版本基线字段/门禁分级说明（ADR-009 试点 vs 企业模式）。验证：章节 grep 探针 + 干净 macOS 环境 smoke（新用户按手册跑通 init→⓪，M4）
- **SPEC-25**：演示视频交付判据：m4a/mp4 存在、时长 ≥8 分钟、中文旁白、覆盖 init→PR 全链（抽帧联络表人工核）。验证：文件属性探针 + 抽帧核（M4）
- **SPEC-26**：`e2e doctor`（ADR-010）：分层检查基础层（git/Claude Code）/远程层（gh）/目标栈层（demo lint/test 工具），缺项输出安装指引并退出非 0；全绿退出 0。验证：在缺 gh 的环境实测（M1）

## 数据与接口

- 探针 CLI 约定：`check-<stage>.sh <specs/feature-dir> [--gate-only|--final]`；stdout 人类可读，最后一行以 `PASS:`/`FAIL(码):` 开头；`--final`=门禁终检模式，WARN 升 FAIL、占位符（`<待填>`/`<待跑>`）视为缺项
- 基线文件：`quality-baseline.txt` 行式（ADR-010）——`# tool=<x> version=<v> date=<d>` 头 + 每行 `工具:规则:文件:指纹`；集合差用 `sort`+`comm`

## 与 PRD 的追溯

| SPEC | ↔ US/SR | 备注 |
|---|---|---|
| SPEC-1~3 | SR-1 · US-2/3/6 | 门禁账本（ADR-004） |
| SPEC-4~5 | SR-1 | 串锁（含门禁③服务端路径）+ 公共库 |
| SPEC-6~8 | SR-2 · US-2~6 | 探针契约（宪法 C13） |
| SPEC-9~11 | US-1（绿地）· US-9 | 脚手架 |
| SPEC-12~14 | US-1（存量）· US-13 · SR-4 | 体检/接入/棘轮 |
| SPEC-15~16 | SR-3 · US-4 · **US-8** | hooks（demo 仓实测） |
| SPEC-17 | SR-5 · US-7 | 自包含（白名单清单于脚本头） |
| SPEC-18 | US-2~6 · ADR-008 | 六件套结构 |
| SPEC-19 | **US-5 · US-8** | CI 双环+分支保护（企业模式=门禁③权威账本，ADR-009；hooks 内环侧由 SPEC-15~16 承接） |
| SPEC-20 | **US-5** · 宪法 C12/C14 | 风险分档评审路由（含门禁规则文件自身高风险化） |
| SPEC-21 | US-4 | tasks 逐条带验证（异构评审#2 修复） |
| SPEC-22~23 | US-6 · US-9（runbook 入手册体系） | release/retire 产物契约 |
| SPEC-24 | US-9 | 手册结构+smoke 验收 |
| SPEC-25 | US-10 | 视频交付判据（原"无 SPEC"已补） |
| SPEC-26 | ADR-010 · NFR-1 | doctor 前置检查 |
| （无新增 SPEC） | US-11/12 | US-11 分发演示落 S2；US-12 自举留痕**复用 SPEC-1~4 既有契约**；显式标注防漏读 |

## 评审记录

### architect 预审
2026-07-31 五查完成（agent 只读）：初审 **4 阻断 + 6 建议**——①US-8/US-10 追溯零承接 ②US-5 的 CI 双环与风险路由无契约 ③SPEC-3 验证空话式 ④门禁③合法值缺失致串锁 ③→④ 断链。全部修复（新增 SPEC-19/20、门禁③改服务端载体、SPEC-3 改 git 历史探针、追溯表对齐、模板注释清理、stories 归位）。复核确认**阻断清零**，3 项建议级残留亦已修正。质量场景覆盖 6/6 NFR ✅；8 ADR 备选真实性 ✅ 无稻草人；宪法 C1-C13 无违反。

### 异构评审辩论矩阵

2026-07-31 · reviewer=gpt-5.6-sol-xhigh（独立 lens，实读全部制品）· Verdict=Refine（10 阻断+1 建议）· **11/11 采纳，Round 1 收敛**

| 意见 | 立场 | 论据/落改 |
|---|---|---|
| #1 存量接入只承接名称无行为契约 | accept | SPEC-12/13 重写：钉试点技术栈+最小可算口径+基线产物清单；业务仓 fitness fn 入 plan |
| #2 implement/release/retire/手册/视频无契约（Must 空转） | accept | 新增 SPEC-21~25 最小可观测契约 |
| #3 能力拓扑 7≠8、六件套检查缩水 | accept | 建唯一 manifest（docs/process/skills-manifest.md），tasks 归 implement；SPEC-18 manifest 驱动 |
| #4 CI 双环可能"运行但不阻断" | accept | SPEC-19/20 钉死：check 命名/severity 阈值/三类负样本/approver≠author/门禁规则文件自身高风险 |
| #5 Markdown 门禁证明不了"人批"（单点风险） | accept | ADR-009 权威载体分级：试点=留痕（诚实标注非防伪）；企业模式=服务端事件为权威+投影校验；C14 入宪 |
| #6 assess 输出路径悖论/冲突文件自冲突 | accept | SPEC-12 改仓同级目录+全快照比对；SPEC-13 冲突文件自冲突时外部时间戳文件退出 2 |
| #7 ratchet 数量比较有洞 | accept | SPEC-14 改行式身份+集合差（comm）；补"替换违规"负样本；基线更新须人审 |
| #8 bash 零依赖名不副实 | accept | ADR-010：分层前置+e2e doctor（SPEC-26）；baseline 弃 JSON 改行式保零依赖 |
| #9 排期不现实/S1 错位/缺硬 spike | accept | plan 重排：纵向骨架 M1、S1 提前首日（需用户确认测试远程仓）、新增 S5/S6、每里程碑小时预算+砍线 |
| #10 探针错误绿灯 | accept | check-design 增强：逐条 SPEC 验证段/编号唯一/ADR 连号/`--final` 占位检测与 WARN 升 FAIL；负样本 M1 |
| #11 宪法补不得自批/供应链固定/C8 紧急通道 | accept | 修宪 v1.1（C14/C15/C8 紧急通道），ADR-011 留痕 |

单点风险裁定：成立且已出清（ADR-009 分级）——试点模式诚实降级为"流程留痕"，企业模式权威在服务端事件（actor/SHA/URL），与宪法 C3/C14 同构。

---
门禁② 记录（spec/plan/ADR 三制品共用；批后"决定"填 批准/打回 之一）：
- 批准人：平台作者（用户本人）
- 决定：批准
- 日期：2026-07-31
- 备注：双审通过后批准——architect 预审 4 阻断清零 + 异构评审（gpt-5.6-sol-xhigh）Refine 11 条全采纳落改（含单点风险出清：ADR-009 门禁权威载体分级、修宪 v1.1）；探针 normal+--final 双绿。附带子决策：**同意 S1 spike 提前至 M1 首日**（建测试用私有远程仓做 claude-code-action CI 冒烟，主开发仍本地 git）。进入阶段 3（tasks）。
