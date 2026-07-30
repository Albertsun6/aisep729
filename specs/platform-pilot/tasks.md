# TASKS：platform-pilot / M1 纵向骨架

> 阶段 3 产物 · 2026-07-31 · 模板见 docs/process/stages/stage-3-implement.md
> 上游：spec.md（门禁② 批准 @2026-07-31）
> **度量单位：复杂度点（1=常规/3=中等/8=难）**，不用人类工时——AI 执行使工时估算失去校准意义（用户裁决 2026-07-31，ADR-012）
> M1 容量：**21 点**（超 20%=25 点触发砍线）｜ M1 砍线：assess/adopt 推 M2；init 只出目录树不出引导语
> 格式：`- [ ] T-N 描述 ｜ SPEC-x ｜ 复杂度 N ｜ 依赖 T-y ｜ 验证：<命令/判据>`

## A 组：spike（时间盒，先行，必须出结论）

- [x] T-1 S1 CI 冒烟：在 `Albertsun6/aisep729` 跑质量门禁 workflow + 调研 AI 评审接法 ｜ SPEC-19 ｜ 复杂度 8 ｜ 依赖 T-2 ｜ 验证：✅ `gh run list` → run 30583711579 `completed success` 13s（四阶段探针全绿）；结论已写回 plan S1 行
  - **S1 结论**：①质量门禁外环**实测可用**（macos-latest runner，ADR-007 护栏生效）②AI 评审技术路径定为 `claude -p --bare` headless（ADR-013：`--bare` 保 CI 可复现、`--json-schema` 使 severity 可机器判定、无第三方 action 依赖）③**认证是硬约束**——bare 模式明确跳过 OAuth/keychain，必须 API key；订阅 token 用于 CI 另有受限报告（single-source 未证实）④**触发预定降级**：外环纯质量门禁，AI 评审留内环；`ai-review.yml.template` 已写好，配 secret 改名即启用（零改造）
- [x] T-2 建平台仓 git 与远程仓：本地 `git init` + 首次提交（47 文件）；GitHub 私有仓 `Albertsun6/aisep729` 并推送 ｜ SPEC 无关（基建，ADR-009/010 前置） ｜ 复杂度 1 ｜ 依赖 - ｜ 验证：✅ `git log --oneline | head -1` → `50c7da5`；`gh repo view Albertsun6/aisep729 --json isPrivate` → `true`
  - 实况偏差（优于设计）：**平台仓自身即远程仓**，无需另建测试仓——S1/S6 直接在本仓拆雷，顺带真实自举（US-12）。`.gitignore` 排除 .m4a（可再生成大二进制）与 settings.local.json
- [x] T-3 S5 ratchet 身份指纹：设计并实现 `工具:规则:文件:指纹` 方案 + 集合差判定，六用例负样本验证 ｜ SPEC-14 ｜ 复杂度 8 ｜ 依赖 T-2 ｜ 验证：✅ `bash tests/probe-negative/ratchet-negative.sh` → 全部符合预期（退出 0），两负样本均正确红
  - **S5 结论**：①**指纹不含行号**（=违规行内容 md5 前 8 位）→ 行号漂移不误报（正样本 B 实证）②**判定用集合差 `comm -13`** 而非数量比较 → "替换违规（总数不变）"被抓（负样本 2 实证，这是数量法的致命洞）③**linter 无关**：适配器契约 `规则|文件|内容`，`RATCHET_LINTER` 可换任意 linter（环境无 shellcheck/eslint，内置 selfcheck 作验证载体，符合 ADR-010 分层前置）④基线更新须显式 `--rebaseline` 且属高风险路径（SPEC-20）
  - **负样本框架当场抓到 2 个真缺陷**：脚本 bug（`$BASELINE——` 中文标点被并入变量名，改 `${BASELINE}`）+ 测试用例 bug（填充行含违规关键字自造违规）——宪法 C13"探针必须能证伪"的价值实证

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
| S1（T-1） | ✅ 质量门禁外环实测可用；AI 评审定为 headless `claude -p --bare`，认证是硬约束→按预定降级（模板待启用） | plan S1 行 · **ADR-013** |
| S5（T-3） | ✅ 指纹不含行号（内容 md5）+ 集合差判定 → 行号漂移不误报、替换违规能抓；linter 无关适配器 | plan S5 行 · scripts/ratchet.sh |

## 砍线记录（超预算时填）

| 时间 | 触发原因 | 砍掉什么 | 依据（plan 砍序） |
|---|---|---|---|
