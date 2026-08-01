---
name: e2e-requirements
description: >-
  E2E 平台阶段1（产品发现/需求）执行 skill：把已立项（门禁⓪=go）的想法变成可测、有边界、
  有优先级、可追溯的 PRD。Use when: "写 PRD" / "需求" / "整理需求" / "e2e requirements" / "需求确认"。
  第0步硬校验 prfaq 门禁⓪，未 go 拒绝启动；产出 specs/<feature>/prd.md 并停在门禁①等人批，绝不越门写设计。
---

# e2e-requirements — 阶段1：产品发现/需求

> SOP 权威定义：`docs/process/stages/stage-1-requirements.md`（冲突以定义文档为准并回修本文件）
> 制品模板：`.claude/skills/e2e-requirements/templates/prd-template.md` ｜ 验收探针：`.claude/skills/e2e-requirements/scripts/check-prd.sh`

## 硬约束（先读）

1. **第 0 步门禁校验**：读 `specs/<feature>/prfaq.md` 门禁⓪记录——非 `决定：go` → **拒绝启动**，告知用户先回阶段0；不存在 prfaq → 同样拒绝（想法先走 e2e-discovery）
2. **门禁①是人的**：产出 prd 后停下等裁决（批准/打回）；未批前拒绝任何阶段2 动作（spec/plan/原型）
3. **需求不是方案**：PRD 写"要什么/多好算好"，不写"怎么实现"；实现细节出现即移到"给阶段2 的备注"
4. **防需求通胀**：MoSCoW 之外强制 Kano 标注——若 Must 占比 >60%，向用户出示并要求重分层
5. modify 循环 ≤2 次；第 3 次建议缩范围或回阶段0 重新下注

## 流程（六步）

### 第 0 步：门禁校验
`bash .claude/skills/e2e-requirements/scripts/check-prd.sh specs/<feature>/ --gate-only`。不过即停。（门禁解析只走 `scripts/lib/gate.sh` 单一实现——**不得手工 grep 决定行**：朴素 grep 取全文首匹配，会重现已修复的"正文伪造批准"fail-open，SPEC-5）

### 第 1 步：输入盘点
读 prfaq（假设陈述/判据/no-gos/知识缺口）+ 既有 stories/访谈记录。列出：已答字段（只需确认）vs 空白字段（必须问）。

### 第 2 步：用户×路径 backbone
角色清单 × 每角色主路径（mile wide, inch deep——先横向铺完整旅程，再纵深）。标注**行走骨架**（端到端最小可用线 = MVP 线）。

### 第 3 步：需求条目化
- 用户可见功能 → User Story（As a…I want…so that）+ 每条 2-4 条 **GWT 验收标准**（单条只测一事）
- 系统级/自动行为（hook/门禁/定时）→ **EARS 句式**：`When <触发>, the <系统> shall <行为>` / `While <状态>…` / `If <异常>, then…shall…`
- 每条过 INVEST 自检（独立/可谈/有价值/可估/够小/可测）

### 第 4 步：范围与优先级
- MoSCoW 定档 + **Won't-have 显式列出**（范围外=承诺不做，不是忘了）
- Kano 标注：基本型（缺了即死）/ 绩效型 / 惊喜型（熔断先砍）
- Must >60% → 触发重分层对话

### 第 5 步：NFR + 追溯 + 探针
- 非功能需求逐条可验证（环境/性能/安全/合规/可维护）
- 追溯表：每条 Story ↔ prfaq 痛点/假设；孤儿需求（无追溯）→ 删或补立项理由
- `bash .claude/skills/e2e-requirements/scripts/check-prd.sh specs/<feature>/` 探针绿才许交付
- 待澄清项：能问就单点澄清（一次一问，spec-kit clarify 式）；确实定不了的**显式移交**并标注移交对象

### 第 6 步：停在门禁①
输出摘要（backbone 一图 + Must 清单 + Won't 清单 + 待移交项）请产品负责人裁决：
- **批准** → 门禁①记录块填齐 → 告知可进阶段2（e2e-design）
- **打回** → 记录意见回第 3 步（计一次循环）

## 自检清单（结束前逐条核）

- [ ] 门禁⓪=go 已校验
- [ ] 探针绿；每条 Story 有 GWT AC；MoSCoW+Kano 双标注；Won't 段非空
- [ ] 追溯表无孤儿需求
- [ ] 待澄清项清零或显式移交
- [ ] 门禁①记录块存在（待批=<待填>）；用户明确知道轮到 ta 裁决
