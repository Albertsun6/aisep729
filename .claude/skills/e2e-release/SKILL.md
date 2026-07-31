---
name: e2e-release
description: >-
  E2E 平台阶段5（发布与运营）执行 skill：门禁③（账本在服务端）过后做 PRR 生产就绪评审，
  产出 PRR 核对记录与 runbook（启动/回滚/故障三节非空），停在门禁④等人放行。
  Use when: "发布" / "上线" / "release" / "生产放行" / "写 runbook" / "e2e release"。
  第0步双路径校验门禁③：远程 gh 验 PR 已合并+checks 绿，gh 不可用则降级为 merge commit+全量测试绿；
  无可执行回滚命令与回滚演练证据不许申请放行；绝不自行填写门禁④。
---

# e2e-release — 阶段5：发布与运营

> SOP 权威定义：`docs/process/stages/stage-5-release.md`（冲突以定义文档为准并回修本文件）
> 模板：`.claude/skills/e2e-release/templates/release-template.md`（PRR 核对记录 + runbook 骨架，一份模板两个落点）
> 探针：`.claude/skills/e2e-release/scripts/check-release.sh` ｜ 契约：SPEC-22 ｜ 门禁载体分级：ADR-009 · ADR-013

## 硬约束（先读）

1. **门禁③ 的账本不在文件里**（SPEC-2 显式豁免文本块，ADR-009）。第 0 步必须走**双路径**校验：
   - **远程路径（权威）**：`gh pr view --json state,statusCheckRollup` → state 必须是 `MERGED`，且 checks 无 `FAILURE/ERROR/TIMED_OUT/CANCELLED`
   - **本地降级路径**：`gh` 缺失 / 未登录 / 无远端 / 当前分支无 PR → 自动降级为「目标分支存在 merge commit + 全量测试绿」。**降级不是报错，但降级也证不出就 fail-closed 拒绝启动**（宪法 C3：安全边界只认可验证的事实）
   - 探针替你做这件事：`bash .claude/skills/e2e-release/scripts/check-release.sh specs/<feature>/ --gate-only`
2. **PRR 每项要人签**：核对人必须是可归因的人类姓名。写 `agent` / `claude` / `AI` / `自动` / `<待填>` 一律探针拒绝（宪法 C14）
3. **回滚不是口号**：回滚预案必须含可执行命令 + 触发判据 + 预期 RTO + **不可逆点**；`--final` 还要求**回滚演练证据**——没演练过的预案是纸面预案
4. **runbook 三节非空是硬契约**（SPEC-22）：`docs/runbooks/<feature>.md` 的 `## 启动` / `## 回滚` / `## 故障处理` 三节，只有占位符视同为空
5. **部署 ≠ 发布**：默认用 feature flag 把"代码上线"与"用户可见"解耦；金丝雀要有步长、每档观察时长与**指标化的中止判据**
6. **不得自行填写门禁④**（宪法 C14）：批准人须为人类且 ≠ 发布执行者
7. **不越门**：退役/弃用属阶段6（e2e-retire）

## 流程（五步）

### 第 0 步：入口校验（门禁③ 双路径）
```bash
bash .claude/skills/e2e-release/scripts/check-release.sh specs/<feature>/ --gate-only
```
- 退出码 0 → 继续；64 → 停下并指路（回阶段4 把 PR 合了/把 checks 修绿，或在本地把测试跑绿）
- 可选环境变量：`E2E_PR`（指定 PR 号/URL，分支已删时用）、`E2E_BASE`（目标分支，默认 `main`）、`E2E_TEST_CMD`（降级路径的全量测试命令）
- 把实际走的是哪条路径、拿到的证据（PR 状态 / checks 汇总 / merge sha / 测试命令）**如实抄进** release.md 的「门禁③ 入口证据」表

### 第 1 步：PRR 核对（生产就绪评审）
按 `.claude/skills/e2e-release/templates/release-template.md` 建 `specs/<feature>/release.md`，逐项过五类核对项：容量与依赖 / 可观测 / 失败与回滚 / 安全与合规 / 运维交接。
每项格式：`- [ ] PRR-N <核对项> ｜ 证据：<命令输出或链接> ｜ 核对人：<人名>`
**核对不了的项不许勾**——写进「未决风险与例外」并由人类签署到期日。

### 第 2 步：写 runbook
把模板尾部的 runbook 骨架另存为 `docs/runbooks/<feature>.md`（文件名 = feature 目录名，探针据此定位）。
三节都要写成"能照着敲"的程度：启动含健康检查判据、回滚含校验命令与不可逆点、故障含症状→首诊命令→处置→升级路径。

### 第 3 步：发布策略 + 回滚演练
- 写清 flag 名与默认值、金丝雀步长与观察时长、**中止判据的指标阈值**
- **实跑一次回滚演练**（预发/影子环境亦可），把命令与输出留成证据写回 release.md
- 有 DB/消息/外部副作用的改动，显式标出 expand/contract 的不可逆点

### 第 4 步：探针 + 停门禁④
```bash
bash .claude/skills/e2e-release/scripts/check-release.sh specs/<feature>/ --final
```
绿后输出摘要请人裁决：门禁③走的路径与证据 / PRR 勾选情况 / 未决风险 / 回滚 RTO 与不可逆点 / SLO 与告警接线。
- **批准** → 人类填门禁④记录 → 按步长放量，进观察窗
- **打回** → 回第 1 步

### 第 5 步（放量后）：观察窗回写
观察窗结论（SLO 实测、错误预算消耗、是否触发中止/回滚）回写 release.md；事故引出的改动**回门禁⓪立项**（宪法 C8 紧急通道：可先动手，48h 内补票）。

## 自检清单

- [ ] 门禁③ 已用探针校验，走的哪条路径与证据已写进 release.md
- [ ] PRR 每项有证据且核对人是人类姓名
- [ ] runbook 三节非空且命令可复制
- [ ] 回滚预案有可执行命令 + RTO + 不可逆点 + **演练证据**
- [ ] SLO 每条告警都指向 runbook 的具体小节
- [ ] `--final` 探针绿；门禁④记录留空待人批，未自行填写
