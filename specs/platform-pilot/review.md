# REVIEW：platform-pilot（门禁③ 评审材料 · 平台自举）

> 阶段 4 产物 · 门禁③（合并批准）· 2026-07-31 · 模板见 docs/process/stages/stage-4-review.md
> 上游：tasks.md（阶段3 出口 9/9，`check-tasks.sh --final` 绿）
> 状态：**待批** → 批准后进阶段 5
>
> **这是平台评审平台自己。** 被审对象就是门禁系统本身，因此重点不是"代码有没有 bug"，
> 而是**"门禁能不能被绕过"**。

## 定档结论

- **风险档**：**高**
- **依据**：命中多条高档 glob —— `.github/workflows/**`、`scripts/lib/**`、
  `scripts/check-*.sh`、`docs/architecture/adr/**`、`.claude/skills/e2e-review/**`、`bin/**`
- **动态升档**：⚠️ **双触发**
  - 净改动 **1194 行 > 1000** → 按 §升档触发 #3，本表规定 **"默认要求拆分"**
  - 文件数 **19 > 15** → 独立升档
- **评审强度**：reviewer + security 双 agent + 跨模型异构评审（宪法 C12）

### 关于"本应拆分"这条，如实交代

分档表自己写了 >1000 行"默认要求拆分"。本轮**没有拆**，理由与代价都摆在这里：
这 19 个文件是**已合并的历史**（分 4 个 PR + 3 次直推），本次是**回溯评审**，拆已无意义。
但**如果这是一个待合并的 PR，按本仓自己的规则它应当先拆**。
记录在此，不因"反正已合并"而略过 —— 下一轮若再出现这个规模，必须拆。

## 规模统计

| 项 | 值 | 阈值 | 判定 |
|---|---|---|---|
| 净改动行数 | **1194**（+1189/−5） | >400 升档 / **>1000 要求拆分** | ⚠️ **双双触发** |
| 文件数 | **19** | >15 升档 | ⚠️ 触发 |

## 覆盖声明（fail-closed，不得省略）

- **已审**：`scripts/lib/gate.sh`、`scripts/check-{manual,demo-video,shell-traps,selfcontained,structure,action-pins}.sh`、
  `tests/probe-negative/run.sh`、`.github/workflows/quality-gates.yml`、`.github/workflows/ai-review.yml.template`、
  `.github/CODEOWNERS`、`.claude/settings.json`、`.gitignore`、`ops/check-branch-protection.sh`、
  `.claude-plugin/marketplace.json`、`docs/process/risk-tiers.md`、`docs/architecture/adr/ADR-014`、`ADR-015`、
  `docs/constitution.md`、7 个阶段探针的 `gate_assert_legal` 接线
- **未审及原因**（两个 agent 各自声明的缺口，此处合并，**不得省略**）：
  - `bin/e2e` 约 400 行未通读（`assess`/`adopt`/`doctor` 主体）—— 仅审本次 diff 涉及的拷贝清单与 `tpl_ci`
  - `docs/implementation-manual.md` 约 460 行操作指引**未逐条核实技术正确性** ——
    异构评审只审了"有没有夸大表述"这一个维度
  - `USAGE.md` +117 行（纯用户手册，无可执行断言）
  - `.claude/agents/{reviewer,security,architect}.md`、`.claude/hooks/*.sh` —— 本次未改动故未审，
    但它们是高档路径；**"评审能力本身能否被关掉"需单独一轮**

## 通道① 确定性检查（唯一 blocker 来源，先于任何 LLM 评审）

| 探针 | 结果 |
|---|---|
| `check-structure.sh` / `check-selfcontained.sh` | ✅ |
| `check-shell-traps.sh` | ✅ |
| `check-skill-deps.sh` / `check-clause-refs.sh` | ✅ |
| `check-manual.sh`（SPEC-24） | ✅ |
| `check-action-pins.sh`（C15，**本轮新建**） | ✅ |
| `tests/probe-negative/run.sh` | ✅ **66/66** |
| `ops/check-branch-protection.sh`（行为证明） | ✅ CONFIRMED |
| `check-demo-video.sh`（SPEC-25） | ✅ |

**通道① blocker 数：0**

## Findings

> `source`：`deterministic`（唯一 blocker 来源）/ `llm-advisory`（建议，无阻断权）
> **通道归属判据**：能写成"对旧实现会失败"的可执行断言 → authority 来自那条测试。

### 通道① 补录：由三方评审线索转化的确定性阻断

| ID | severity | source | 提出方 | 定位 | 问题 | 状态 | 可证伪断言（对旧实现的结果） |
|---|---|---|---|---|---|---|---|
| F-1 | **block** | deterministic | security ×1 | `scripts/lib/gate.sh` `gate_decision` | **CRITICAL：门禁台账可被正文隐形伪造。** 旧实现取全文**首个** `- 决定：`，而门禁块契约是**尾部四行**。执行者在正文早处写一行 `- 决定：go`、尾部保持 `<待填>`，探针即判 PASS、下游打印 `GATE0: go ✓` —— **人翻到文末只看到"待批"**。同时击穿 C1（串锁）与 C14（不得自批），**且自批在人的视野里不可见**。这击穿的正是整套门禁存在的理由 | fixed | 3 条负样本。**对旧实现实测：期望 66 实得 0；且"探针把正文伪造行当成决定值"、"多条决定行未判歧义"两条同时红** |
| F-2 | **block** | deterministic | security ×1 | `check-release.sh:31,35` | **CRITICAL：`E2E_PR` 参数注入 → 用别人仓的证据开门禁③。** `gh pr view ${E2E_PR:-}` 未加引号，bash 词分割使 `E2E_PR="--repo cli/cli 6000"` 展开成 `gh pr view --repo cli/cli 6000`，gh 去查了**另一个仓**。填任意公开仓里 MERGED+全绿的 PR 号即可开门 | fixed | 负样本断言注入型 `E2E_PR` 被白名单拒绝。**实测 bash 下确实分成 3 个参数**（注：zsh 默认不分词，用 zsh 测会漏掉——探针脚本是 bash） |
| F-3 | **block** | deterministic | security ×1 | `.github/workflows/*` + `bin/e2e` 的 `tpl_ci` | **C15 声明了探针却从未实现。** 宪法 C15「检查」栏白纸黑字写着「workflows 中 Action 引用含 SHA（探针 grep）」，而平台仓两处、**发给每个客户仓的 CI 模板三处**全是可变 tag。**我此前以为"已 SHA-pin"——那是 demo 仓，平台仓从没钉过** | fixed | 新建 `check-action-pins.sh`（含金丝雀自检 + 无可检对象即 66）。三向验证：正样本 PASS / 退回 tag 判 1 / 空目录判 66。已接进平台 CI + 脚手架 + 客户 CI 模板 |
| F-4 | **block** | deterministic | reviewer ×1 | `check-manual.sh:66` | 占位符守卫是**行内**匹配，而章节标题与字段行**永远不同行** → 守卫结构上不可能触发 | fixed | 改按节切片。**对旧实现实测：把平台版本填成 `<待填>` 仍报 ✅** |
| F-5 | **block** | deterministic | reviewer ×1 | `tests/probe-negative/run.sh` | `gate_assert_legal` 负样本**只断言消息文本、不断言退出码** | fixed | 改用 `expect` 断言退出码。**对旧实现实测：把接线退化成 `\|\| true`（打印但不阻断），6 条用例仍全绿 60/60** |
| F-6 | **block** | deterministic | reviewer ×1 | `check-release.sh:140` / `check-retire.sh:110` | `gate_assert_legal` 在门禁④⑤ 的调用点**零执行覆盖**（插桩实测）—— 而这两道门恰是 `gate.sh` 注释里引用的事故现场。**修复打在了没有任何测试跑得到的行上** | fixed | 补门禁④ fixture 负样本（`rc=64` 拒绝「放行」、合法值不因决定值原因失败） |

### 通道③ llm-advisory（无阻断权；已修，但阻断权不来自它们）

| ID | severity | source | 定位 | 问题 | 状态 | 处置证据 |
|---|---|---|---|---|---|---|
| F-7 | major | llm-advisory | `risk-tiers.md` | **门禁台账本体被定为最低档、人审「否」** —— `- 批准人：`/`- 决定：` 两行就是全部批准证据 | fixed | `specs/*/{prfaq,prd,spec,review,release,deprecation}.md` 升高档。**但升档只是缓解不是解决**，见 F-12 |
| F-8 | major | llm-advisory ×2 | 同上 | 分档表还有 6 处覆盖漏洞：`.claude/skills/*/scripts/check-*.sh`（七道门禁真正执行体）、`scripts/ratchet.sh`（棘轮唯一执行体，而它守的基线已是高档 —— **规则的数据是高档、规则的引擎是中档**）、`.claude/skills/*/templates/**`（门禁块**出生形态**，改模板后每份新制品天生已批准）、`.claude/skills/*/SKILL.md`（C1 的"第 0 步"写在这里，删掉即归零）、`.claude-plugin/**`（L3 分发信任根）、`.gitignore`（`settings.local.json` 不入库的**唯一屏障**） | fixed | 六处全部升高档；分档表追加教训⑤⑥⑦ |
| F-9 | major | llm-advisory | `check-manual.sh:85` | 夸大表述检查被 `grep -v '不得'` **无差别行级豁免**绕过 | fixed | 改为显式 pragma `manual:ok`。**实测：插入「本平台完全安全…不得质疑」→ 旧版放行，新版判 66** |
| F-10 | major | llm-advisory | `ADR-015` 后果段 | ADR 称 spike「未留下副作用」，实测注册表虽已清空但 **`~/.claude/plugins/cache/` 下 9 个 .sh 仍在盘上**（带 `.orphaned_at` 标记）。**高档 ADR 的实测记录不准确** | open | 见 §未采纳/部分采纳 |
| F-11 | major | llm-advisory | `ai-review.yml.template` | **仓已公开 → fork PR 首次成为可能**，PR diff 是攻击者完全可控的输入，却直接喂给一个**有阻断权**的 LLM（`blocks>0 → exit 1`）。与本平台自己的三通道契约「AI 无阻断权」**直接冲突** | open | 见 §未采纳/部分采纳 |
| F-12 | major | llm-advisory | 手册 §7 | 异构评审（gemini）逐条指出 **6 处夸大表述**，每处都与 §7 已知限制自相矛盾：「每一条主张都有可执行断言」（§7 承认升档无强制力）、「永远发现不了」、「守住整类」、「行号漂移不误报」、棘轮「防改基线绕棘轮」「守住不恶化」（§7 承认分档可手填绕过） | fixed | **6/6 全部采纳改写**；另补 §7.1b 专章说明「文本台账不是防伪凭证」 |

## 异构评审（高风险档强制，宪法 C12）

外部 lens：cursor-agent。**前两次失败，如实记录**（不得留空假装审过）：

| 轮次 | 模型族 | 结果 |
|---|---|---|
| 1 | gpt | ❌ `cursor-agent timeout (>570s)` —— prompt 要求读 8 个文件，范围过大 |
| 2 | gpt | ❌ `ECONNRESET` |
| 3 | **gemini** | ✅ 成功（按 survey 降级矩阵换模型族），产出 30 行、5 类共 6 处夸大表述 |

| 意见 | 立场 | 论据 |
|---|---|---|
| 「每一条主张都有可执行断言」与 §7「升档无强制力」矛盾 | **accept** | 改为「绝大多数」并指向 §7 |
| 棘轮「防改基线绕棘轮」「守住不恶化」被 §7「分档可手填绕过」推翻 | **accept** | 两处均加"这是规范不是强制"的限定 |
| 「守住整类」夸大 | **accept** | 改为「守住显式路径引用这一部分」 |
| 「行号漂移不误报」把实测写成保证 | **accept** | 改为「实测中未出现」 |
| 「永远发现不了」绝对化 | **accept** | 改为「极难在早期发现」 |

**教训**：这 6 处全是**我自己写的手册**里的话，而且**每一处都与我自己写的已知限制矛盾**。
单独写限制、单独写卖点，两边不对账 —— 这正是异构评审的价值。

## 未采纳 / 部分采纳（fail-closed：不采纳必须写明理由）

| 意见 | 立场 | 理由 |
|---|---|---|
| F-10 修正 ADR-015「未留下副作用」的表述 | **open** | 成立。ADR 不可变只追加，需另起追加记录；本轮时间未及。**已记入 backlog，且在此明确：ADR-015 那句话不准确，卸载不清理可执行缓存** |
| F-11 `ai-review.yml.template` 让 LLM 对攻击者可控输入有阻断权 | **open** | 成立且严重。但它是 `.template`（**未启用**），修它需重新设计 AI 评审的输入通道（改为确定性预处理后的结构化摘要），超出本轮范围。**在启用前必须先修**，已写入 backlog 与手册已知限制 |
| security #11：`Bash(bash bin/e2e*)` 是"任意目录写入原语" | **partial** | 成立。`bin/e2e init/adopt` 会往任意目标目录写 `CLAUDE.md`/`.claude/`/`scripts/`，而白名单自动放行。**已记入 backlog**（收紧为 `doctor`/`version`）；本轮未改，因为收紧后会影响正常的脚手架工作流，需先确认使用习惯 |
| security #9：fork 场景下 `gh repo view` 可能解析到 upstream | **partial** | 需要人工确认 gh 的 base-repo 解析行为，仓内证不出。**已加显式一致性断言到 backlog**；本轮未改 |
| security #12：平台仓自身无 `CLAUDE.md` @import 宪法 | **open** | 成立（`bin/e2e` 只给目标仓生成）。记入 backlog |
| security #16 / reviewer：平台仓无 LICENSE | **open** | 仓已公开且通过 marketplace 邀请安装，却无 LICENSE。**需用户裁决许可证类型**，不由我代定 |
| reviewer #8：手册命令抽取正则重复两份且已不一致 | **open** | 成立（SPEC-5 单一实现原则）。记入 backlog |

## 环境留痕

- 评审运行次数：reviewer ×1、security ×1、异构 ×3（前两次失败）—— **均未重跑到过**
- 通道① 先于通道②③ 执行：是
- 修复后复跑：确定性检查 8/8 绿，负样本 **60 → 66**
- **回归非空性验证**：F-1 的 3 条回归对旧实现实测**全部变红**（63/66），证明不是空测试

## C14 归因声明

平台仓为**单人仓**（owner = author）。批准人与执行者为同一账号，
**C14「执行者不得自批」在服务端层面不成立**。
把关由 ① 确定性检查 ② 三方独立评审（reviewer / security / 跨模型异构）承担。

**而本轮 F-1 恰恰证明了这件事有多重要**：文本台账曾能被执行者在人看不见的地方伪造。
即便修复后，它仍**只是过程留痕**（见手册 §7.1b）。

---
门禁③ 记录（批后"决定"填 批准/打回 之一；批准人须为人类且 ≠ 作者/最后 push 者）：
- 批准人：<待填>
- 决定：<待填>
- 日期：<待填>
- 备注：<待填>
