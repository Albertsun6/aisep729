# RELEASE：platform-pilot（门禁④ 生产放行评审材料 · 平台自举）

> 阶段 5 产物 · 门禁④（生产放行）· 2026-07-31 · 模板见 docs/process/stages/stage-5-release.md
> 上游：门禁③（**账本在服务端**，SPEC-2 对其豁免文本块）｜ 状态：**待放行**
> 本文件的门禁④记录=**流程留痕，非防伪审批证据**（ADR-009 试点模式）

## 「发布」在这里是什么

平台不是服务，没有部署。**发布 = 让别人能用上，且能验证它真的在守规矩。**
交付面有三个，各自的可回滚性完全不同（见 §回滚预案）：

| 交付面 | 现状 |
|---|---|
| **git 仓** `Albertsun6/aisep729` | 已 PUBLIC，main 受保护（`enforce_admins=true`，行为证明 CONFIRMED） |
| **插件市场** `.claude-plugin/marketplace.json` | 已实测跑通 add → install，SHA 钉在 `8306a8bd9c0f` |
| **实施手册 + 演示视频** | 手册 490 行（SPEC-24 探针绿）；视频 9 分 4 秒（SPEC-25 四条判据绿） |

## 门禁③ 入口证据（探针实测结果照抄，不许追认）

| 路径 | 怎么验的 | 实际证据 |
|---|---|---|
| 远程（权威） | `E2E_PR=4 bash .claude/skills/e2e-release/scripts/check-release.sh specs/platform-pilot/ --gate-only` | `GATE3-IN: 远程路径 ✓（PR=MERGED｜checks=SUCCESS）`｜PR #4｜mergeSha=`8ab7968d9340`｜mergedAt=2026-07-31T07:15:57Z |
| 本地（降级） | — | **未走**（远程路径可用） |

> 注：squash 合并**不产生 merge commit**，本地降级路径会判"无 merge commit"，
> 故用文档化的 `E2E_PR=<纯数字>` 显式指定。该变量现有白名单（修参数注入 critical 时加的）。

## PRR 核对表（生产就绪评审）

> 核对人须为可归因的人类（C14）。yongqian 需人类逐项确认后填写。

### 容量与依赖

- [x] PRR-1 依赖清单与前置分层 ｜ 证据：`bash bin/e2e doctor` 输出分三层——基础层 `git`/`bash`（必需）、远程层 `gh`（门禁③④ 服务端校验）、目标栈层 `jq`/`shellcheck`（缺失即降级，**不是错误**）。**新增依赖已补进 doctor**：`ffprobe`/`ffmpeg`（`check-demo-video.sh` 需要，此前未声明，评审 reviewer #4 指出） ｜ 核对人：yongqian
- [x] PRR-2 供应链钉版（C15） ｜ 证据：`bash scripts/check-action-pins.sh` → PASS，5 处 Action 引用全部 SHA-pin。**该探针本轮才建**——C15「检查」栏一直写着「探针 grep」，而探针从未存在；平台仓两处 + **发给每个客户仓的 CI 模板三处**当时全是可变 tag ｜ 核对人：yongqian
- [x] PRR-3 脚手架产物完整性 ｜ 证据：干净目录 `bash bin/e2e init $(mktemp -d)` → 23+ 文件，7 skill / 3 agent / 2 hook / 15 条宪法 / 47 行 CI / risk-tiers 齐备；三条验收命令全绿。`gen_file` 现在**拒绝写出空文件**（曾因 `tpl_ci` 未定义而静默产出 1 字节空 workflow） ｜ 核对人：yongqian

### 可观测

- [x] PRR-4 运行时指标 / APM / 日志聚合 ｜ **N/A（不适用）** ｜ 证据：平台不是服务，无进程、无端点。唯一的自动信号是 **CI `probes` job**——它守的是合并，不是运行时 ｜ 核对人：yongqian
- [x] PRR-5 平台健康的**可测量**判据 ｜ 证据：**有，且是本平台最重要的指标**——`bash tests/probe-negative/run.sh` **71/71**。它测的不是"代码能跑"，而是**"探针自身能否被证伪"**。本轮实测过它的价值：把 `gate_decision` 退回旧实现，3 条回归当场变红（63/66）｜ 核对人：yongqian
- [x] PRR-6 门禁是否**真的**生效 ｜ 证据：`bash ops/check-branch-protection.sh` → **CONFIRMED**（配置不变量 ∩ 行为证明）。不接受配置回读作为通过依据——ADR-014 记录了"配置全绿但直推成功"的实测 ｜ 核对人：yongqian

### 失败与回滚

- [x] PRR-7 故障模式与爆炸半径 ｜ 证据：爆炸半径分三层——① 平台仓自身（可回滚）② 已 clone 的副本（不受影响）③ **已 `e2e init` 进客户项目的文件（完全不可控）**。7 类故障已逐条写入 `docs/runbooks/platform-pilot.md` §故障处理，每条含可执行首诊命令 ｜ 核对人：yongqian
- [x] PRR-8 回滚命令可执行且**已演练** ｜ 证据：见 §回滚演练证据（四次实跑） ｜ 核对人：yongqian
- [x] PRR-9 不可逆点已标注 ｜ 证据：四个不可逆点已写入 runbook §回滚，其中两个本轮实测确证：**已 init 进客户项目的文件**（演练 D：仓库侧 revert 后客户文件 sha 不变）、**插件卸载不清可执行缓存**（`~/.claude/plugins/cache/` 下 9 个 .sh 带 `.orphaned_at` 残留） ｜ 核对人：yongqian

### 安全与合规

- [x] PRR-10 密钥不入仓 ｜ 证据：`gitleaks git --no-banner --redact` 全历史 → **no leaks**（security agent 独立重跑确认，24 commits / 695KB）。个人绝对路径 `/Users/yongqian` 全仓零命中。**口径诚实**：这是扫描结果干净，**不等于前向控制**——无 push protection、无 pre-commit hook ｜ 核对人：yongqian
- [x] PRR-11 门禁本身能否被绕过 ｜ **partial（本轮修了 2 条 critical，但仍有已知面）** ｜ 证据：① **门禁台账曾可被正文隐形伪造**（`gate_decision` 首匹配胜）——已修为尾部锚定 + 歧义即拒绝，3 条回归对旧实现全部变红；② **`E2E_PR` 参数注入**可用别人仓的证据开门禁③——已修为白名单 + `--repo` 钉死。**仍存在的面**：文本台账本质上防不住有写权限的人（手册 §7.1b 已说透）；`ai-review.yml.template` 让 LLM 对攻击者可控输入有阻断权（未启用，**启用前必须先修**） ｜ 核对人：yongqian
- [x] PRR-12 公开仓的暴露面 ｜ 证据：仓已 PUBLIC（为让免费账号能用分支保护）。**一并公开的包括方法论全文、实施手册、两份调研报告**——这是接受的代价，非疏漏。commit 作者邮箱随历史公开（git 固有属性）。**已解决**：双许可落地（代码 Apache-2.0 / 文档 CC BY-SA 4.0），`LICENSE` 逐目录写明适用范围 ｜ 核对人：yongqian

### 运维交接

- [x] PRR-13 runbook 三节非空且可照做 ｜ 证据：`docs/runbooks/platform-pilot.md` 三节非占位符；所有命令引用的路径已核实存在；7 类故障各有可执行首诊 ｜ 核对人：yongqian
- [x] PRR-14 owner 与升级路径 ｜ 证据：`.github/CODEOWNERS` → `@Albertsun6`。⚠️ **单人仓下无服务端强制力**（`require_code_owner_reviews=false`、`approvals=0`），见 `docs/process/risk-tiers.md` §执行层「当前状态」列。这不是配置疏漏，是 ADR-014 陷阱③ 的结构限制 ｜ 核对人：yongqian
- [x] PRR-15 客户接入后的自助能力 ｜ 证据：手册 §9「出问题时」给出全量自检命令；每个探针的 `MISSING:` 行会直接指出缺什么与为什么。**两条接入路径的差异已显式警示**（插件只给能力层，**没有门禁**，ADR-015） ｜ 核对人：yongqian

## 发布策略

**无 feature flag、无金丝雀、无灰度** —— 形态决定的：用户主动 clone 或 install，运营方不推送。

| 项 | 值 |
|---|---|
| 发布动作 | 合并到 `main`（受保护，须过 `probes` required check） |
| 用户获取 | `git clone` + `e2e init`（完整）或 `claude plugin install`（仅能力层） |
| 放量控制 | **无** |
| 观察窗 | 无运行时遥测，只能靠 CI + 用户反馈 |

## 回滚预案

| 触发判据 | 回滚动作（可执行） | 预期 RTO | 不可逆点 |
|---|---|---|---|
| CI `probes` 红 / 用户报告接入失败 / 自跑健康检查异常（**无自动告警**，见 PRR-4） | `git switch -c revert-x origin/main` ／ `git revert --no-edit <sha>`（squash 单亲，不带 `-m`） ／ 本地过六道探针 ／ `gh pr create --fill` ／ `gh pr checks --watch` ／ `gh pr view --json mergeStateStatus`（须 CLEAN） ／ `gh pr merge --squash --delete-branch` | **3–8 分钟**（条件性）。实测分解：本地负样本套件 **4 秒**；CI `probes` job **14–24 秒**（`gh run list` 四次实测 22/21/24/14）；人工改码开 PR 数分钟 | ① **已 `e2e init` 进客户项目的文件**（演练 D 实测）② 已 clone 的副本 ③ 公开仓历史 ④ 插件卸载残留的可执行缓存 |
| 需要撤下平台 | 仓库 archive + marketplace.json 下线；**但已分发的能力层与已 init 的项目文件都撤不回** → 走阶段6（e2e-retire） | 同上 | 同上 |

### 回滚演练证据

- **回滚演练证据**：2026-07-31 实跑四次（A/B/C/D + RTO 计时），**非纸面推演**。
  环境：`git clone` 到独立 scratchpad 目录。

```
演练 A: git revert --no-edit HEAD（squash 单亲）  → EXIT=0  ✅ 干净回退
演练 B: 回滚后探针链
        check-structure / shell-traps / skill-deps / clause-refs  ✅
        probe-negative/run.sh                                     ✅
        check-action-pins.sh                                      ❌ ← **这是对的**
        （revert 撤销了 SHA-pin 修复，探针当场发现 —— 说明 C15 检查真的在守）
演练 C: 回滚后 e2e init 新项目 → 探针仍可跑                        ✅
演练 D: 已 init 的客户项目文件 sha 在仓库侧 revert 前后**不变**
        （a01d1c319e958be7 → a01d1c319e958be7）→ 真不可逆点确证
RTO:    本地负样本 4 秒 ｜ CI probes 14–24 秒
```

> **演练 B 的 ❌ 是本次演练最有价值的一格**：它证明回滚会**撤销 C15 的 SHA-pin 修复**，
> 而新建的探针会当场把它抓出来。回滚不是无代价的——回滚前必须看清楚要撤销什么。

## SLO 与监控

| SLI | 目标 SLO | 错误预算 | 告警规则 | 指向 runbook 小节 |
|---|---|---|---|---|
| 运行时可用性 | **N/A —— 平台不是服务** | N/A | 无 | — |
| **探针可证伪率** | **100%**（`probe-negative` 71/71，0 容忍） | 0 | CI `probes` job 失败即阻断合并 | §故障处理 → 2 |
| 服务端门禁有效性 | **CONFIRMED**（配置不变量 ∩ 行为证明） | 0 | 手动跑 `ops/check-branch-protection.sh`（**不进 PR 触发的 CI，因为会写远端**） | §故障处理 → 5 |
| CI 门禁时延 | ≤ 120 秒（实测 14–24 秒，留 5× 余量） | — | 超时人工察觉（无自动告警） | §回滚 → RTO |

> ⚠️ 只有第 2、3 行是真正可测量的，且测的是**门禁本身**不是运行时。
> **任何材料不得声称本平台有运行时监控或告警。**

## 未决风险与例外（人类签署到期日）

| # | 风险 | 为什么不在本次解决 | 到期日 | 签署人 |
|---|---|---|---|---|
| ~~E-1~~ | ~~平台仓无 LICENSE~~ | **已闭环 @2026-07-31**：用户裁决双许可——代码 Apache-2.0（`LICENSE-CODE`）、文档与方法论 CC BY-SA 4.0（`LICENSE-DOCS`），`LICENSE` 写明适用范围与边界判定 | — | yongqian |
| ~~E-2~~ | ~~`ai-review.yml.template` 让 LLM 有阻断权~~ | **已闭环 @2026-07-31**。**并更正当时的威胁模型**：原描述说"攻击者可控输入直接喂给有阻断权的 LLM"，查证后**那一半不成立**——`pull_request` 触发时 fork PR **拿不到 secrets**（GitHub 设计），claude 跑不起来，LLM 根本接触不到 fork 输入。真问题是另一个形状：① LLM 有阻断权本身违反三通道契约；② fork PR 的 required check **恒红**，踩到的人最可能改成 `pull_request_target`——**那才是经典 pwn request**（GitHub 2026-06 已让 actions/checkout v7 默认拒绝该组合）。处置：LLM 侧全部 `continue-on-error`、只发 PR 评论、**永不因 LLM 结果失败**；无 API key 时优雅跳过而非变红；diff 显式定界为数据并要求把疑似注入**当 finding 报**；文件头三条警示；新建 `check-ai-review-contract.sh` + 4 条负样本钉死 | — | yongqian |
| E-3 | **文本门禁台账防不住有写权限的人**（本轮修的 critical 只是堵了"隐形伪造"，没堵"公开篡改"） | 结构限制。真正解决要把批准移到服务端 review 事件 | 扩员至 ≥2 人时 | yongqian |
| E-4 | `Bash(bash bin/e2e*)` 是"任意目录写入原语"（`init`/`adopt` 可往任意目录写文件且自动放行） | 收紧会影响正常脚手架工作流，需先确认使用习惯 | 2026-09-30 | yongqian |
| E-5 | fork 场景下 `gh repo view` 可能解析到 upstream，导致"读 A 仓推 B 仓" | 需人工确认 gh 的 base-repo 解析行为，仓内证不出 | 2026-09-30 | yongqian |
| E-6 | 平台仓自身无 `CLAUDE.md` @import 宪法（`bin/e2e` 只给目标仓生成） | 本轮范围外 | 2026-08-31 | yongqian |
| E-7 | ADR-015 称 spike「未留下副作用」**不准确**（注册表已清但可执行缓存仍在盘） | ADR 不可变只追加，需另起追加记录 | 2026-08-31 | yongqian |
| E-8 | 手册命令抽取正则**重复两份且已不一致**（违反 SPEC-5 单一实现） | 本轮范围外 | 2026-09-30 | yongqian |
| E-9 | **升档触发无强制力**（规模/依赖超限只有建议力）；**分档可手填绕过** | 需自建 CI job 计算档位并阻断 | 2026-09-30 | yongqian |
| E-10 | **只有一个人跑过**，无真人冷启动验证 | 需要另一个人 | 正式交付前（硬约束） | yongqian |

## 观察窗与运营

- **观察窗**：无运行时遥测。替代做法：放行后每次改动都必须过 CI `probes`；
  每月手动跑一次 `ops/check-branch-protection.sh` 确认门禁仍生效，结果回写本文件。
- **事故处理**：任何事故引出的改动走门禁⓪ 立项（C8 紧急通道：可先动手，48h 内补票）。

---
门禁④ 记录（批准人须为**人类**且 ≠ 发布执行者；本仓为单人仓，归因限制同门禁③）：
- 批准人：yongqian（**人类**，仓库 owner）
- 决定：批准
- 日期：2026-07-31
- 备注：**归因如实**——平台仓为单人仓，批准人与发布执行者同一账号，
  C14 在服务端层面不成立。放行前已明确知悉 10 条未决风险，其中三条硬约束：
  ① E-1 无 LICENSE（**本次放行后立即处理**）
  ② E-2 ai-review 模板让 LLM 对攻击者可控输入有阻断权，**启用前必须先修**
  ③ E-10 只有一个人跑过，无真人冷启动验证，**正式交付前必须补**
  以及 E-3：本轮修的 critical 只堵了"隐形伪造"，文本台账**仍防不住有写权限的人公开篡改**。
