---
name: e2e-implement
description: >-
  E2E 平台阶段3（构建与交付）执行 skill：把已批设计（门禁②=批准）拆成逐条可验证的 tasks 并实现。
  Use when: "实现" / "开工" / "写 tasks" / "任务拆解" / "e2e implement"。
  第0步硬校验门禁②；tasks 每条强制带验证方式；spike 先行；熔断信号（验证连续失败 3 次 /
  spike 超时间盒）停下报告并砍线；不越门做评审/PR（阶段4）。
---

# e2e-implement — 阶段3：构建与交付

> SOP 权威定义：`docs/process/stages/stage-3-implement.md`（冲突以定义文档为准并回修本文件）
> 模板：`.claude/skills/e2e-implement/templates/tasks-template.md` ｜ 探针：`.claude/skills/e2e-implement/scripts/check-tasks.sh`

## 硬约束（先读）

1. **第 0 步门禁校验**：`spec.md` 门禁②非 `批准` → 拒绝启动，指路阶段2
2. **无验证不成任务**：每条任务必须有 `验证：` 行（可执行命令或可观测判据）。写不出验证方式 = 任务定义不清，拆细或改写，**不许写"完成 X 功能"这类无判据任务**
3. **spike 先行**：plan 中排在本里程碑的 spike 必须先跑出结论（写回 plan/新 ADR），其依赖任务才能开始
4. **熔断即停**（ADR-012）：任务验证连续失败 3 次 / spike 超时间盒无结论 → 停下报告用户，按 plan 里程碑砍线执行（砍范围保交付），**不静默硬扛**。人类工时预算已弃用——AI 执行下工时失去校准意义
5. **不越门**：评审、开 PR、合并属阶段4；本 skill 只到"代码+测试就位、探针绿"

## 流程（四步）

### 第 0 步：门禁校验
`bash .claude/skills/e2e-implement/scripts/check-tasks.sh specs/<feature>/ --gate-only`（校验门禁②）。不过即停。

### 第 1 步：产 tasks.md
按 `.claude/skills/e2e-implement/templates/tasks-template.md`，任务分三组：
- **A 组 spike**（时间盒，出结论）
- **B 组 纵向骨架**（端到端最小可用链路）
- **C 组 增量**（骨架之上的功能/加固）

每条格式：`- [ ] T-N <描述> ｜ SPEC-x ｜ 复杂度 N ｜ 依赖 T-y ｜ 验证：<命令或判据>`（复杂度∈{1,3,8}；**格式契约以 check-tasks.sh 为准**——它会对"预算 Xh"工时写法直接 FAIL，本行只是指针不是第二权威）
跑探针 `bash .claude/skills/e2e-implement/scripts/check-tasks.sh specs/<feature>/` 绿才进下一步。

### 第 2 步：跑 spike
逐个执行 A 组，每个必须落**结论**（写进 plan 风险表对应行 或 新 ADR）。结论触发设计调整时，回阶段2 修订（记录一次 modify），不许带着未决 spike 往下做。

### 第 3 步：按任务实现
- 有测试栈：TDD（先写失败测试→实现→重构）；无测试栈（脚本/文档类）：先写探针再写内容
- 小步推进：每条任务完成即跑其 `验证：` 命令，绿了才勾选 `- [x]`
- hooks 会本地拦截（lint/测试未过不许收工）——不要绕过，绕过=违反宪法 C2
- 每完成一组报告一次进度（已完成/剩余复杂度点，是否出现熔断信号）

### 第 4 步：出口自检
`bash .claude/skills/e2e-implement/scripts/check-tasks.sh specs/<feature>/ --final`：全任务已勾选、无未决 spike、无占位符 → 绿则交阶段4（e2e-review + PR），并向用户报告完成的复杂度点与是否触发砍线。

## 自检清单

- [ ] 门禁②=批准 已校验
- [ ] 每条任务有 SPEC 映射 + 验证行 + 复杂度点
- [ ] A 组 spike 全部有结论
- [ ] 所有任务勾选且各自验证命令实跑过
- [ ] `--final` 探针绿；熔断信号（若出现）已如实报告
