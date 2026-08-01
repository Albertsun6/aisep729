# REVIEW：<feature 名>

> 阶段 4 产物 · 门禁③（合并批准）评审材料 · <日期> · 模板见 docs/process/stages/stage-4-review.md
> 上游：tasks.md（阶段3 出口 `--final` 绿 @<日期>）｜ 状态：待批 → 批准后进阶段 5（发布）

## 定档结论

- **风险档**：<高/中/低>
- **依据**：<命中 risk-tiers 的哪条 glob 或哪条动态升档规则>
- **评审强度**：<双 agent+异构 / 单 agent / 仅确定性探针>

## 规模统计

| 项 | 值 | 阈值 | 判定 |
|---|---|---|---|
| 净改动行数（排除生成/lock/vendored） | <N> | >400 升档 / >1000 拆分 | <ok/升档/建议拆分> |
| 文件数 | <N> | >15 升档 | <ok/升档> |

## 覆盖声明（fail-closed，不得省略）

- **已审**：<文件清单或范围>
- **未审及原因**：<清单；无则写"无"> ← 空着不写视为违规，未审≠没问题

## Findings

> source：`deterministic`（通道①，唯一 blocker 来源）/ `llm-advisory`（通道③，建议）/ `llm-triage`（通道②，对①的分诊建议）
> 状态机：`open → fixed | false-positive | accepted-risk → reopened`

| ID | severity | source | 类型 | 定位 | 问题 | 状态 | 闭环证据 |
|---|---|---|---|---|---|---|---|
| F-1 | block | deterministic | contract | scripts/x.sh:42 | 退出码不符 SPEC-6 | fixed | `bash tests/...` 绿 @<commit> |
| F-2 | warn | llm-advisory | maintainability | src/a.ts:88 | 重复逻辑 | open | - |

### 非终态说明（false-positive / accepted-risk 必填）

| ID | 状态 | 签署人（**必须是人类，非 agent**） | 理由 | 到期日 | 跟踪票据 |
|---|---|---|---|---|---|

> 安全 critical **禁止** accepted-risk。

## 异构评审（仅高风险档，宪法 C12）

| 意见 | 立场(accept/partial/refute) | 论据 |
|---|---|---|

> 外部 lens 不可用时：写明 `异构评审: unavailable(<原因>)` + 补审计划，**不得留空假装审过**。

## 环境留痕（防非确定性绕过）

- 模型：<model id>｜prompt 版本：<hash 或版本号>
- diff hash：<sha>｜是否命中缓存：<是/否>
- 评审运行次数：<N>（>1 须说明原因——**禁止重跑到过**）

---
门禁③ 记录（**投影**，非账本：门禁③权威=服务端 PR 合并+required checks（SPEC-2/SPEC-19），冲突以服务端为准；批后"决定"填 批准/打回 之一；批准人须为人类且 ≠ 作者/最后 push 者）：
- 批准人：<待填>
- 决定：<待填>
- 日期：<待填>
- 备注：<待填>
