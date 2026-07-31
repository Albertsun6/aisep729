---
name: e2e-review
description: >-
  E2E 平台阶段4（评审与合并门禁）执行 skill：按风险分档做内环评审，产出可审计的 findings 并逐条闭环。
  Use when: "评审" / "review" / "审一下这些改动" / "e2e review" / "准备合并"。
  三通道契约：确定性规则出阻断、LLM 只做分诊建议、LLM 自主发现默认 advisory。
  停在门禁③等人批（approver≠author），绝不自行批准。
---

# e2e-review — 阶段4：评审与合并门禁

> SOP 权威定义：`docs/process/stages/stage-4-review.md`｜风险路由：`docs/process/risk-tiers.md`
> 模板：`.claude/skills/e2e-review/templates/review-template.md`｜探针：`.claude/skills/e2e-review/scripts/check-review.sh`
> 设计依据（**平台仓 provenance，不随脚手架分发**）：`docs/research/AI时代评审门禁-调研.md`（v2，异构终审 Dissent 13 条修订后） <!-- skill-deps:platform-only -->

## 硬约束（先读，这几条是血的教训）

1. **三通道契约不可混淆**（调研 v2 抓出的最危险设计缺陷）：
   - **通道① 确定性阻断**：探针/lint/测试/SAST 出 blocker。**LLM 不得单独解除**，解除只有两条路——修掉，或独立人类签 `accepted-risk`
   - **通道② LLM 分诊**：对确定性告警可输出 `likely-FP` **建议**，但**不自动解除**，人审确认才生效
   - **通道③ LLM 自主发现**：**默认 advisory 不阻断**；升级为可阻断需按规则+模型版本完成 shadow 验证且 precision 达标
2. **失败不得静默**（fail-closed）：超时、解析失败、部分文件未审——**一律不得视为"零 finding"**。高风险路径工具失灵即拒绝放行
3. **禁止重跑到过**：同一 diff hash 缓存评审结果；LLM 同 diff 多次运行结果不同已有实测，反复重跑直到通过 = 绕过门禁
4. **不得自行批准**（宪法 C14）：批准者必须是人类且 ≠ 作者/最后 push 者，以服务端 review 事件为准
5. **注意力保护**：高风险路径提示用户**先自己看 diff 再看 AI 摘要**（实证：AI 摘要会锚定注意力，人只看"重点"就不看别处了）
6. **不越门**：发布/运维属阶段5

## 流程（六步）

### 第 0 步：入口校验
`bash .claude/skills/e2e-review/scripts/check-review.sh specs/<feature>/ --gate-only`——校验阶段3 出口（tasks 全勾选 + `check-tasks.sh --final` 绿）。不过即停。

### 第 1 步：定档（读 risk-tiers.md）
按改动文件路径匹配 glob，取**命中的最高档**；再检查动态升档触发（打回≥2次 / security block / 规模>400行或>15文件 / 新增依赖 / 删测试）。输出定档结论与依据。

### 第 2 步：通道① 确定性检查（先跑，不依赖 LLM）
跑本仓所有可用探针：`scripts/check-*.sh`、`tests/probe-negative/run.sh`、ratchet、lint/test（若有）。
**任何非 0 退出即产生 blocker**，记入 findings（`source=deterministic`）。

### 第 3 步：通道②③ LLM 评审（按档决定强度）
- **高风险**：reviewer + security 双 agent + 异构评审（宪法 C12；外部 lens 不可用时按降级规则留痕）
- **中风险**：reviewer 单 agent
- **低风险**：跳过 LLM，仅通道①

agent 输出的 finding 标 `source=llm-advisory`；对通道① 告警的分诊意见标 `source=llm-triage`（**建议性**）。

### 第 4 步：写 review.md 并逐条闭环
按模板记录每条 finding：ID / severity / source / 类型 / 定位 / 问题 / 状态。
状态机：`open → fixed | false-positive | accepted-risk → reopened`
- `fixed` 必须绑定验证证据（命令输出或 commit）
- `false-positive` / `accepted-risk` 必须**独立人类**署名 + 理由（+ accepted-risk 还要到期日与跟踪票据）
- **安全 critical 禁止 accepted-risk**

### 第 5 步：探针 + 停门禁③
`bash .claude/skills/e2e-review/scripts/check-review.sh specs/<feature>/ --final` 绿后，输出摘要请人裁决：
- 摘要含：定档结论 / 确定性 blocker 状态 / LLM finding 数（advisory）/ **未审清单** / 规模统计
- **批准** → 门禁③记录（人类署名）→ 告知可进阶段5
- **打回** → 回第 4 步

## 自检清单

- [ ] 阶段3 出口已校验
- [ ] 定档有依据（引用 risk-tiers 具体规则）
- [ ] 通道①先于通道②③执行
- [ ] 无"LLM 说是误报所以放行"的操作
- [ ] 每条 finding 有 ID/source/定位/状态；blocker 无遗漏无截断
- [ ] 覆盖声明完整（未审文件已列明）
- [ ] 门禁③记录留空待人批，未自行填写
