---
name: e2e-design
description: >-
  E2E 平台阶段2（定义/设计）执行 skill：把已批 PRD（门禁①=批准）变成可实现、可验证、决策留痕、
  宪法一致的设计（spec/plan/ADR，平台级 constitution/spine）。Use when: "设计" / "写 spec" / "技术方案" /
  "架构" / "ADR" / "e2e design"。第0步硬校验门禁①；architect 预审+探针+异构评审后停门禁②等人批，绝不越门写 tasks/代码。
---

# e2e-design — 阶段2：定义/设计

> SOP 权威定义：`docs/process/stages/stage-2-design.md`（冲突以定义文档为准并回修本文件）
> 模板：`.claude/skills/e2e-design/templates/{spec,plan,adr}-template.md` ｜ 探针：`.claude/skills/e2e-design/scripts/check-design.sh` ｜ 预审：`.claude/agents/architect.md`

## 硬约束（先读）

1. **第 0 步门禁校验**：`prd.md` 门禁①非 `批准` → 拒绝启动，指路阶段1
2. **门禁②是人的**，且**前置双审**：architect subagent 预审 + 异构评审（高风险产物按选择性评审矩阵**不许跳过**）都完成后才请人批
3. **设计不是需求复述**：spec 每条行为契约必须可被探针/测试证明；写不出验证方式的句子删掉重写
4. **ADR 必含真实备选**：≥2 个被认真考虑过的选项及其代价；没有备选的"决策"是"决定"，退回重写（稻草人备选=预审阻断项）
5. **as-is 优先**：spine 记录真实现状（含丑陋处），理想态写进 ADR 的 proposed 决策，不混淆
6. modify 循环 ≤2；越门禁产出 tasks/代码一律拒绝

## 流程（七步）

### 第 0 步：门禁校验
`bash .claude/skills/e2e-design/scripts/check-design.sh specs/<feature>/ --gate-only`。不过即停。

### 第 1 步：constitution / spine（平台级，缺则建、有则对照）
- `docs/constitution.md`：不可妥协工程原则（≤15 条，每条一句+为什么+可执行检查方式）；已存在则只对照不改（改宪法=独立 ADR）
- `docs/architecture/spine.md`：as-is 架构主干 ≤300 行（系统边界/核心组件/关键约束）

### 第 2 步：spec.md（行为契约）
按 PRD 的 US/SR 推导组件行为契约：`<组件> 在 <条件> 下必须 <可观测行为>；验证：<探针/测试>`。逐条对照 ISO 29148 可验证性。回填 PRD 追溯表"下游"列。

### 第 3 步：plan.md（技术方案）
结构（C4 Context/Container 级 Mermaid）· 技术选型 · **质量场景**（每条 NFR→ATAM 场景：刺激/响应/度量→设计应对→牺牲了什么）· non-goals · 风险与 spike（高不确定项，时间盒）· fitness functions 清单（M3 落 CI）· 里程碑映射。

### 第 4 步：ADR（每个关键决策一文）
MADR 精简模板：背景→备选（≥2，各带代价）→决定→后果（正负都写）。编号三位连续；改旧决策=新 ADR superseded 旧文，不删改原文。

### 第 5 步：architect 预审
用 Agent 工具（agentType 或按 `.claude/agents/architect.md` 的 prompt）跑五查（宪法/可验证性/追溯/质量场景覆盖/备选真实性）。**阻断项清零**才进下一步；建议项记入待办或 ADR。

### 第 6 步：探针 + 异构评审
- `bash .claude/skills/e2e-design/scripts/check-design.sh specs/<feature>/` 绿
- 异构评审（跨模型 lens 审 spec/plan/ADR）：意见逐条 accept/partial/refute 表态留痕（辩论矩阵记入 spec 尾部评审记录块）

### 第 7 步：停在门禁②
输出摘要（结构图 + 关键决策清单 + 质量权衡 + spike 清单）请架构决策人裁决：批准→门禁②记录填齐、告知可进阶段3（tasks）；打回→记录意见回第 2 步（计一次循环）。

## 自检清单（结束前逐条核）

- [ ] 门禁①=批准 已校验
- [ ] spec 每条契约带验证方式；PRD 追溯表下游列已回填
- [ ] 每条 NFR 有质量场景；non-goals 非空
- [ ] 每个 ADR ≥2 真实备选；编号连续
- [ ] architect 预审阻断项清零；异构评审辩论矩阵留痕
- [ ] 探针绿；门禁②记录块就位；用户明确知道轮到 ta 裁决
