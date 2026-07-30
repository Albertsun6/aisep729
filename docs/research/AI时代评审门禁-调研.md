# AI 时代的评审与合并门禁：调研报告 v2

> 2026-07-31 · /survey 五路并行（Claude×3 官方/实证/社区反证 + GPT 族 + Gemini 族）· 异构终审 Dissent 13 条全部采纳后重写
> 用途：修订本平台阶段4（评审）设计 · 输出分档=内部输入（仅 md）

## 版本说明

**v1 → v2 的修订**（异构终审 gpt-5.6-sol-xhigh 判 Dissent，13 条阻断级建议全部 accept）：
- 修复 R1-R3 的**权限自相矛盾**（v1 允许 LLM 借"误报抑制"解除确定性告警）
- 修正三处**数字误读**（precision/F1 混用、行级闭环率误读、Meta 因果性夸大）
- 补 v1 完全缺失的**失效语义**（非确定性、超时、解析失败、fail-closed）
- 反证从"列出来"变成"改变设计"（新增 R13-R16）
- 加**三级实施包**（v1 把 Cloudflare/Meta 级基础设施写成通用基线，中小团队做不到）
- 关键数字补**证据账本**（来源 + 研究范围 + 局限）

## TL;DR：五条会直接改设计的结论

1. **阻断权与解除权必须是无歧义的三通道契约**——这是本次评审抓出的最严重设计缺陷（详见 §R1-R3）。
2. **AI 评审默认只出证据，不出判决**。GitHub 官方产品级判据：Copilot 评审不计入 required approvals、不阻断合并。
3. **约束是 precision 不是 recall**，但**当前没有可直接采用的行业阈值**——必须自己 shadow mode 标注后再定（v1 写的 80% 是设计假设，非实证）。
4. **门禁最常见的失效不是误报，是橡皮图章**（无人评审直接合并的 PR +31.3%）。判据要测评审行为，不能只测审批事件。
5. **反证必须转化为硬规则**：LLM 同一 diff 多次运行结果不同、超时、截断——这些不处理，门禁就是自欺。

---

## 一、阻断权契约（R1-R3 重写，本报告核心）

v1 的三条互相冲突，v2 改为**三条互不重叠的通道**：

### R1 确定性阻断通道（唯一的 blocker 来源）
- 阻断只由**确定性规则**产生：探针退出码、lint、测试、SAST Block 级规则、结构检查
- **确定性 blocker 不得被 LLM 单独解除**——这是 v1 最危险的漏洞
- 解除路径只有两条：① 修掉 ② 独立人类以 `accepted-risk` 签署（带理由/到期日/跟踪票据）

### R2 LLM 分诊通道（只提供建议，不生效）
- LLM 对确定性告警做误报分诊，输出 `likely-FP` **建议**，但**不自动解除**
- 解除仍须人审确认（人可以采信 LLM 建议，但责任在人）
- 证据边界：腾讯工业实证（消除 94–98% 误报）**仅覆盖 433 条 C/C++ 告警、三类缺陷，真实缺陷召回 72–88%，作者明确说低于企业期望的 90% 且仍需人工复核**——不足以支撑自动放行

### R3 LLM 自主发现通道（默认 advisory）
- LLM 自己发现的问题**默认非阻断**（advisory），只进建议区
- 升级为可阻断的唯一路径：**按具体规则 + 模型版本 + prompt 版本**完成本地 shadow 验证，且 precision 经独立标注达标
- 跌破阈值自动降级回 advisory

> **为什么这样切**：v1 把"AI 无阻断权"和"LLM 抑制误报"写在一起，实际效果是 AI 可以让一条真实的安全告警消失，却对外宣称 AI 没有阻断权。三通道后，**AI 永远不能让告警消失，只能建议人去看**。

---

## 二、Precision 与阈值（R4，修正 v1 的数字错误）

### 数字更正
| v1 写法 | 实际 | 出处与局限 |
|---|---|---|
| "主流工具 precision <10%" | SWR-Bench 中**四类方法**低于 10%，**最佳 PR-Review precision 为 16.65%**；19.38% 是 **F1 不是 precision**；后续实验有 20.85%、23.84% F1 | [SWR-Bench](https://arxiv.org/html/2509.01494v1)；**局限**：人为平衡的 500 Change-PR + 500 Clean-PR，precision 不可直接移植到生产分布 |
| "precision ≥80% 才允许阻断" | **纯设计假设，无一手出处** | 降级为待验证试点值 |

### R4：precision 的可执行定义（v1 完全没定义）
- **按什么算**：按 `规则 ID × severity × 模型版本 × prompt 版本` 分别计算，不算全局单一数字
- **怎么标注**：独立人工标注（非 agent 自评），规定最小样本量
- **怎么判**：滚动窗口 + **95% 置信区间下界**达标才授予阻断权（小样本时置信区间会很宽，这正是要防的）
- **同时监测 recall**：只看 precision 会诱导"少报保准确"，必须配套逃逸缺陷监测
- **降级条件**：跌破阈值自动回 advisory

---

## 三、失效语义（v1 完全缺失，本次新增 R13-R16）

异构终审指出：v1 的 Q9 列了反证却没形成任何设计条款——**反证被当装饰**。补齐：

### R13 非确定性处理
- LLM 同一 diff 多次运行结果不同已有实测（[arXiv 2502.20747](https://arxiv.org/html/2502.20747v1)；HN 亦有实践者报告）
- **硬规则**：记录 `模型 hash + prompt hash`；同一 diff hash **缓存结果**；**禁止反复重跑直到通过**（这是绕过门禁的最简单方式）

### R14 失败语义 fail-closed
- 超时、解析失败、结构错误、部分 diff 未审——**一律不得解释为"零 finding"**
- 按风险档定义失败语义：高风险路径 **fail-closed**（工具挂了就不许合并）；低风险可 fail-open 但必须留痕
- 输出**已审/未审文件清单**（证明覆盖范围，防"大 PR 静默漏审"）

### R15 注意力锚定防护
- HN 实证观察：AI 给出"重点看这几处"后，人只看这几处 → **摘要是风险项不是便利项**
- **硬规则**：高风险路径的人审必须**先独立判断再显示 AI 摘要**（顺序不可颠倒）

### R16 评审 agent 的安全边界
- PR 内容是**不可信输入**（prompt injection 是新攻击面）
- agent 按最小权限运行（只读）；生成端与评审端**必须异构隔离**（同源模型有相关盲区——反方论文自己承认的让步条件）
- 客户代码不外发第三方（宪法 C15）

---

## 四、其余修订条款（R5-R12）

| # | v2 结论（修订后） | v1 错在哪 |
|---|---|---|
| **R5** | **限制展示的非阻断项数量**，而非删除候选 finding；**所有 blocker 必须保留**；完整结果写入审计制品 | v1 说"finding 上限 ≤5 按 severity 截断"——**截断可能隐藏真 blocker** |
| **R6** | agent prompt 的"不要报什么"清单须有**规则 ID + 正反例 + 版本 + 回归测试** | v1 直接采信 Cloudflare 自述（无独立因果实验） |
| **R7** | 完整状态机：`open → fixed / false-positive / accepted-risk → reopened`；每条 finding 带 **ID + diff SHA + 修复验证证据 + 审批 actor + 时间**；后两态须独立人类身份 + 理由 + 权限 + **到期日 + 跟踪票据**；**安全 critical 默认禁止 accepted-risk** | v1 只有三个终态，缺 open/reopened 与全部审计字段 |
| **R8** | **以服务端 review 事件与 ruleset 配置为准**：审批者须属允许的人类团队；检查 App/Integration bypass 列表；用 API 探针验证规则生效。**provenance trailer 只作披露信息，不作兜底**（自报字段可漏填可伪造） | v1 让 trailer 兜底 bot bypass 缺口——兜不住 |
| **R9** | 400/1000 行标为**默认启发值非实证安全线**；必须定义：additions/deletions 怎么算、生成文件与 lockfile 是否排除、文件分散度阈值、例外审批规则 | v1 给了数字没给计数算法 |
| **R10** | 百分位阈值（Meta RADAR 模式）**限定为成熟组织高级能力**：需已有风险模型 + 大量事故标签 + 单调性验证 + 漂移监控。无标签时继续用显式路径与事件规则 | v1 把它当通用做法；且 Meta 的 1/3、1/50 是**观察性比较，论文明确非因果估计** |
| **R11** | 硬排除区需**可读取的数据源**（合规标签从哪来）+ 版本化配置 + 例外 actor/期限/审计记录 | v1 写了"安全敏感、合规范围"但没说机器怎么识别 |
| **R12** | 每个指标定义**数据契约**：事件源、分子分母、窗口起点、去重规则、责任人、**最低样本量**；小样本组织同时报原始计数与置信区间。**break-glass 只作"例外使用率"，不命名为信任指标**；评论数可作**噪声护栏**（不作成功指标） | v1 把 Cloudflare 的 0.6% break-glass 当信任/precision 指标——它可能意味着信任，也可能意味着开发者直接修掉误报或组织压力 |

### 分歧点裁定（修正）
v1 把 Cloudflare（critical→block）与"AI precision 低不该阻断"裁定为"前提差异"。**v2 更正**：两者**不可直接比较**——Cloudflare 只公布了运行量、finding 数、显式 break-glass 次数，**没有公布经人工标注的 precision、false-negative 或阻断正确率**。正确表述是「**逻辑上可兼容，但其机制与准确率尚未被公开数据证明**」。本平台必须通过自己的 shadow mode 人工标注授予阻断权，不能照搬。

---

## 五、三级实施包（新增：v1 把大厂基础设施写成通用基线）

| 级别 | 适用 | 门禁配置 | 前提 |
|---|---|---|---|
| **起步级**（1-5 人 / 无 SAST / 无遥测） | 绝大多数咨询客户的起点 | lint + test + secret scan 出阻断；AI **全部 advisory**；人工批准（approver≠author） | 只需 git + CI |
| **成长级**（5-30 人 / 有基础 CI） | 有平台工程雏形 | 加 SAST 确定性阻断 + 结构化 finding 闭环 + 抽样人工标注（为 R4 攒数据） | 需 SAST 工具 + 标注人力 |
| **成熟级**（30+ / 有遥测与事故标签） | Meta/Cloudflare 那一档 | 才启用风险模型、百分位阈值、经验证的 AI 阻断权 | 需风险模型 + 长期遥测 + 事故归因能力 |

**咨询落地纪律**：不许把成熟级配置卖给起步级客户——他们做不到，且会因为噪音把整套门禁关掉。

---

## 六、证据账本（关键数字的出处与局限）

| 数字 | 出处 | 研究范围 | 局限（必读） |
|---|---|---|---|
| SWR-Bench precision 最佳 16.65% | [arXiv 2509.01494](https://arxiv.org/html/2509.01494v1) | 1,000 人工核验 PR | 人为平衡 500/500，**不可移植生产分布** |
| AI 评论 0.9–19.2% 导致改动 vs 人类 60% | [arXiv 2508.18771](https://arxiv.org/html/2508.18771v1) | 16 个 AI reviewer / 22,326 条评论 | 是 **LLM 辅助判定的 addressed rate**，非人工核验 |
| 行级 43.88% vs 文件级 13.89% | 同上 | 同上 | **是"评论后文件被修改的比例"，不是 finding 闭环率**；比较对象是 hunk-level 与 file-level 工具，有工具/触发/项目混杂；论文只主张关联非因果 |
| LLM+静态分析消除 94–98% 误报 | [arXiv 2601.18844](https://arxiv.org/abs/2601.18844) | 433 条告警 / 328 FP，C/C++ 三类缺陷 | **真实缺陷召回仅 72–88%，作者明说低于企业期望的 90%，仍需人工复核** |
| Meta RADAR revert 率 1/3、事故率 1/50 | [arXiv 2605.30208](https://arxiv.org/html/2605.30208v1) | 535K diff 评审 / 331K 落地 | **观察性比较（已资格筛选的低风险 diff vs 非 RADAR diff），论文明确非因果估计**；P25→P50 未公布按阈值的安全结果与统计检验 |
| Cloudflare 1.2 finding/次、break-glass 0.6% | [Cloudflare blog](https://blog.cloudflare.com/ai-code-review/) | 30 天 131,246 次评审 | 自家博客；**未公布人工标注 precision / FN / 阻断正确率**；1.2 是**均值不是安全上限** |
| 无评审直接合并 PR +31.3%、评审时长 +441.5% | [Faros](https://www.faros.ai/blog/ai-acceleration-whiplash-takeaways) | 22,000 开发者 / 4,000 团队 / 2 年 | 厂商遥测（一手但非独立验证） |
| Google：100 行合理 / 1000 行过大 | [Google eng-practices](https://google.github.io/eng-practices/review/developer/small-cls.html) | 官方指南 | 无 AI 时代重新标定 |
| SmartBear 200–400 LOC | [Cisco case study](https://static1.smartbear.co/support/media/resources/cc/book/code-review-cisco-case-study.pdf) | 2,500 次评审 / 320 万行 | **数据来自 2006 年**，AI 时代无人重标 |
| Copilot 评审不计入 approvals、不阻断 | [GitHub 官方](https://docs.github.com/en/copilot/responsible-use/code-review) | 产品级声明 | 官方同时承认 hallucination 与大 diff 漏检 |
| 授权归因四件套 | [GitHub rulesets](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/available-rules-for-rulesets)、[required reviewer GA](https://github.blog/changelog/2026-02-17-required-reviewer-rule-is-now-generally-available/) | 官方规则 | **缺口**：无"仅人类审批者"开关；App 可入 bypass；required reviewer 依赖组织团队（个人仓不可用） |
| SO 2025：84% 用 AI，信任降至 29% | [SO Survey](https://survey.stackoverflow.co/2025/ai) | 大规模开发者调查 | 自报数据 |
| LLM 重复运行不一致 | [arXiv 2502.20747](https://arxiv.org/html/2502.20747v1) | 实测 | — |

**不作判据的二手数字**（未触达原报告）：LinearB 2.6x PR 体量、SAST FP 68–88%、"AI 代码 bug 多 1.7×"（厂商自研报告，HN 质疑方法论）。

---

## 七、待验证风险

- [ ] **precision 阈值本平台需自采数据**：先 shadow mode 标注，样本量与置信区间达标后再定，不照抄 80%
- [ ] **合并队列 × CODEOWNERS 冲突**需 demo 仓实测（M3）
- [ ] **App bypass 缺口**：需用 API 探针验证 ruleset 实际生效（配置写了 ≠ 生效）
- [ ] **起步级客户的最小可行门禁**是否真的够用——需第一个真实客户验证
- [ ] Cloudflare 模式的可复制性：其 precision 未公开，本平台不可假设同等表现

## 调研 metadata

- **方法**：五路并行（Claude×3 + gpt-5.6-sol-xhigh + gemini-3.1-pro），合并取并集不投票
- **中断恢复**：首轮两只异构眼因 Cursor 配额到顶失败，用户充值后重跑——未降级
- **Phase 6 异构终审**：**Dissent，13 条阻断级建议，全部 accept 并重写本报告**。最关键一条：v1 的 R1-R3 允许 LLM 借"误报抑制"实际解除确定性安全告警，同时宣称 AI 无阻断权——已改为三通道契约
- **本次评审的价值**：抓出 1 个逻辑漏洞 + 3 处数字误读 + 1 个整类空白（失效语义）+ 1 个适用性错误（大厂基线当通用）
