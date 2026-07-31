---
name: e2e-discovery
description: >-
  E2E 平台阶段0（战略/立项）执行 skill：把一个模糊想法经"快筛三问→塑形访谈→PR-FAQ→门禁⓪下注"
  变成立项决策。只学习不建造，多数想法应死在本阶段。
  Use when: "立项" / "新想法" / "想做个 X" / "值不值得做" / "e2e discovery" / "写个 prfaq"。
  产出 specs/<feature>/prfaq.md 并停在门禁⓪等人裁决（go/modify/kill），绝不自行越门。
---

# e2e-discovery — 阶段0：战略/立项

> SOP 权威定义：`docs/process/stages/stage-0-discovery.md`（本 skill 是其可执行形态，两者冲突以定义文档为准并修此文件）
> 制品模板：`.claude/skills/e2e-discovery/templates/prfaq-template.md` ｜ 验收探针：`.claude/skills/e2e-discovery/scripts/check-prfaq.sh`

## 硬约束（先读）

1. **只学习不建造**：本阶段禁止写代码、禁止创建 `specs/<feature>/` 之外的文件
2. **门禁⓪是人的**：产出 prfaq 后**停下**，明确说"等你裁决 go / modify / kill"；用户未批前，任何下一阶段动作（含起草 PRD）一律拒绝
3. **modify 循环 ≤2 次**：第 3 次仍不过 → 建议 kill 或进机会背囊
4. **kill 是合法出口**：kill/暂缓的想法登记 `docs/process/opportunity-backlog.md`（一行：想法/日期/原因/复活条件）

## 流程（四步）

### 第 1 步：快筛三问（5 分钟，SVPG）

对用户的想法直接问（或从上下文提取后向用户确认）：

1. 这解决**什么问题**？
2. **为谁**解决？
3. **怎么知道成功**？

→ 任何一问答不上：不立项。写入机会背囊，告知用户"想清楚这问再回来"，**流程结束**。
→ 三问都有答案：进第 2 步。

### 第 2 步：塑形访谈（≤2 轮，每轮 ≤5 问，用 AskUserQuestion 给选项）

只问**用户才能答**的字段（能从上下文推的不问）：

- **问题故事**：一个具体场景，说明现状为什么不行（Shape Up：单一具体故事，不要抽象描述）
- **Appetite**：投入上限（时间/预算）+ 到期砍序（砍什么保什么）
- **深坑**：用户已知的险坑（技术/依赖/时机）
- **No-gos**：明确不做什么
- **go/kill 判据**：结束时怎样算值得继续（注意分层：appetite 内可控的熔断线 vs 观察窗信号）

### 第 3 步：生成 prfaq.md

- 按 `.claude/skills/e2e-discovery/templates/prfaq-template.md` 填写，落盘 `specs/<feature>/prfaq.md`（feature 名 kebab-case）
- **一页纸纪律**：正文 ≤120 行；FAQ 只预答最尖锐的 3-5 问
- 大 feature 才另写 `discovery-notes.md`（访谈记录/现有方案扫描/知识缺口）
- 跑探针自检：`bash .claude/skills/e2e-discovery/scripts/check-prfaq.sh specs/<feature>/prfaq.md`——结构不齐不许交付

### 第 4 步：停在门禁⓪（下注桌）

向用户输出一段话摘要（假设陈述 + appetite + 熔断线）并请裁决：

- **go** → 在 prfaq 尾部门禁⓪记录块填：批准人/决定/日期/备注 → 告知"可进阶段1（e2e-requirements）"
- **modify** → 记录意见，改后回到第 3 步（计一次循环）
- **kill** → 门禁块记录 kill + 理由，登记机会背囊，流程结束

## 自检清单（skill 结束前逐条核）

- [ ] 探针绿（结构完整）
- [ ] 门禁⓪记录块存在（待批时"决定"留 `<待填>`，批后必填）
- [ ] 没有创建 specs/ 与机会背囊之外的任何文件
- [ ] 用户明确知道现在轮到 ta 裁决
