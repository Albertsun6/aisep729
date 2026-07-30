# TASKS：platform-pilot / M1 纵向骨架

> 阶段 3 产物 · 2026-07-31 · 模板见 docs/process/stages/stage-3-implement.md
> 上游：spec.md（门禁② 批准 @2026-07-31）
> **度量单位：复杂度点（1=常规/3=中等/8=难）**，不用人类工时——AI 执行使工时估算失去校准意义（用户裁决 2026-07-31，ADR-012）
> M1 容量：**21 点**（超 20%=25 点触发砍线）｜ M1 砍线：assess/adopt 推 M2；init 只出目录树不出引导语
> 格式：`- [ ] T-N 描述 ｜ SPEC-x ｜ 复杂度 N ｜ 依赖 T-y ｜ 验证：<命令/判据>`

## A 组：spike（时间盒，先行，必须出结论）

- [ ] T-1 S1 CI 冒烟：建测试用私有远程仓，跑最小 claude-code-action workflow，记录配置/权限/计费观察 ｜ SPEC-19 ｜ 复杂度 8 ｜ 依赖 T-2 ｜ 验证：`gh run list --repo <test-repo>` 显示至少 1 次 workflow 结束（成功或明确失败原因），结论写回 plan 风险表 S1 行
- [ ] T-2 建平台仓 git 与测试远程仓：本地 `git init` + 首次提交；GitHub 建私有测试仓（仅供 S1/S6 拆雷） ｜ SPEC 无关（基建，ADR-009/010 前置） ｜ 复杂度 1 ｜ 依赖 - ｜ 验证：`git log --oneline | head -1` 有输出且 `gh repo view <test-repo> --json isPrivate` 返回 true
- [ ] T-3 S5 ratchet 身份指纹：对 demo 候选栈 lint 输出设计 `工具:规则:文件:指纹` 方案，构造"新增违规""替换违规（总数不变）"两负样本验证集合差 ｜ SPEC-14 ｜ 复杂度 8 ｜ 依赖 T-2 ｜ 验证：`bash tests/probe-negative/ratchet-*.sh` 两负样本均非 0 退出，结论写回 plan S5 行

## B 组：纵向骨架（端到端最小可用链路）

- [ ] T-4 gate.sh 公共库：抽出门禁解析（读制品尾部记录块→输出状态/决定），三个既有探针改为 source 之 ｜ SPEC-5 ｜ 复杂度 3 ｜ 依赖 T-2 ｜ 验证：`grep -L "lib/gate.sh" .claude/skills/*/scripts/check-*.sh` 输出为空，且三探针复跑与改前结论一致
- [ ] T-5 负样本测试框架：`tests/probe-negative/run.sh` + 每探针至少一个坏样本（64/65/66 各覆盖） ｜ SPEC-6/7 · 宪法 C13 ｜ 复杂度 3 ｜ 依赖 T-4 ｜ 验证：`bash tests/probe-negative/run.sh` 全绿（每个坏样本命中预期退出码）
- [ ] T-6 自包含探针：`scripts/check-selfcontained.sh`（个人绝对路径/`~/.claude` 运行时依赖 grep，白名单数组在脚本头） ｜ SPEC-17 ｜ 复杂度 1 ｜ 依赖 T-2 ｜ 验证：`bash scripts/check-selfcontained.sh` 退出 0；构造含 `/Users/x` 的临时文件后退出非 0
- [ ] T-7 结构探针（manifest 驱动）：`scripts/check-structure.sh` 读 skills-manifest 逐行比对 skill 目录三件套+阶段文档+glossary 节 ｜ SPEC-18 ｜ 复杂度 3 ｜ 依赖 T-4 ｜ 验证：`bash scripts/check-structure.sh` 对现状 PASS；临时移走某 templates/ 目录后 FAIL

## C 组：增量（骨架之上）

- [ ] T-8 `e2e` CLI 骨架 + `doctor` 子命令：分层检查基础层/远程层/目标栈层，缺项给安装指引 ｜ SPEC-26 · ADR-010 ｜ 复杂度 3 ｜ 依赖 T-4 ｜ 验证：`bash bin/e2e doctor` 退出 0；`PATH= bash bin/e2e doctor` 缺工具时退出非 0 且输出含安装指引
- [ ] T-9 `e2e init` 最小版：按 manifest 生成目录树（M1 砍线内：不出引导语），幂等不覆盖，生成物页脚含门禁分级标注 ｜ SPEC-9/10/11 · ADR-009 ｜ 复杂度 8 ｜ 依赖 T-7,T-8 ｜ 验证：空临时仓跑 init 后 `bash scripts/check-structure.sh` PASS；重复跑 init 退出 2 且既有文件 md5 不变；生成 CLAUDE.md `wc -l` ≤200 且含 `@docs/constitution.md`

## 进度与容量（复杂度点）

| 组 | 点数 | 已完成 | 状态 |
|---|---|---|---|
| A（spike：T-1/2/3） | 17（8+1+8） | 0 | 未开始 |
| B（骨架：T-4~7） | 10（3+3+1+3） | 0 | 未开始 |
| C（增量：T-8/9） | 11（3+8） | 0 | 未开始 |
| **合计** | **38 点** | 0 | - |

> **容量说明**：M1 名义容量 21 点，实际 38 点。**不按点数砍范围**——AI 执行下点数只表达"哪些任务难、值得先拆"，不是产能上限。真正的熔断信号改为**返工次数**（异构评审#9 的纪律换度量落地，ADR-012）：
> - 任一任务**验证连续失败 3 次** → 停下报告，按 plan 砍线（该任务降级或推后）
> - 任一 spike **超出其时间盒仍无结论** → 按 plan 风险表的"失败即触发"执行降级
> - 复杂度 8 的任务（T-1/T-3/T-9）是重点观察对象——它们是返工高发区

## spike 结论

| spike | 结论 | 落点（plan 行/ADR） |
|---|---|---|
| S1（T-1） | 待跑 | plan 风险表 S1 行 |
| S5（T-3） | 待跑 | plan 风险表 S5 行 |

## 砍线记录（超预算时填）

| 时间 | 触发原因 | 砍掉什么 | 依据（plan 砍序） |
|---|---|---|---|
