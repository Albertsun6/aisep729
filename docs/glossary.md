# 平台名词表（Glossary）

> 全平台唯一名词权威。各阶段定义文档只写本阶段词条，收录汇总到这里。冲突以本文件为准。
> v1 · 2026-07-30 · 当前收录：全局 + 阶段0

## 全局

| 名词 | 定义 |
|---|---|
| E2E（端到端） | 战略/立项 → 产品发现 → 定义/设计 → 构建与交付 → 运营/演进 → 退役 的全生命周期（超出教科书 SDLC 的"不含两端"惯常含义） |
| 两视图 | 治理视图（6 段底图，对齐预算/评审/责任）× 执行视图（产物状态机，每天实际做的事）；过程可在任何阶段迭代发生（ISO/IEC/IEEE 12207:2026） |
| 产物状态机 | prfaq → prd → spec → plan/ADR → tasks → code+tests → PR → release/runbook → 退役 的文档产物流转链；流程由产物驱动而非对话驱动 |
| 六门禁 | ⓪立项/下注 ①需求确认 ②架构评审 ③合并批准 ④生产放行 ⑤退役评审——人审介入点，证据触发而非日期 |
| 门禁密度 | 按风险/合规强度在"NASA 硬 gate ↔ Amazon 一页纸"谱系上取档（risk-tiers.md 定档） |
| 四层架构 | L1 工具无关真相层 / L2 Claude 适配层（.claude/）/ L3 能力分发层（plugin marketplace）/ L4 企业控制平面 |
| 四级验证强度 | CLAUDE.md 建议 → LLM 评审 → hooks 本地确定性检查 → 服务端不可绕过门禁（安全边界只认最后一级） |
| 棘轮 Ratchet | 存量项目 CI 策略：存量违规豁免入基线、新增违规阻断、基线数只许降不许升 |
| 绞杀 Strangler | 存量改善策略：新功能走全流程在旁生长，老代码触碰时顺手改，重构须⓪立项 |
| 特征测试 Characterization Test | 改动前先用测试锁住存量代码现状行为（哪怕行为是"错"的），为改动提供安全网 |
| Fitness Function | 架构约束的可执行断言（依赖方向/层间调用/模块大小），进 CI 防架构恶化 |
| delta-spec | 存量项目的增量规格：`specs/<change>/` 只描述变更，归档时合并进当前真相（OpenSpec 模式） |
| vendored 产品化 | 把个人 skills 复制进平台仓改造为自包含组件（去个人路径依赖、统一命名），个人版保留不动 |
| 选择性评审 | 制品按风险档配评审强度：高=异构评审+人审 / 中=可执行验证+单lens / 低=抽查+探针；门禁打回≥2次自动升档 |
| 探针 | 可执行的验证脚本：证明"文件在/链接活/权限拦得住/基线没涨"，替代"我觉得对了" |

## 阶段 0（战略/立项）

| 名词 | 定义 |
|---|---|
| PR-FAQ | 立项一页纸：未来新闻稿+FAQ（Amazon Working Backwards） |
| Appetite（胃口） | 投入上限承诺——不是工期估算而是约束：到期砍范围不展期（Shape Up） |
| 深坑 Rabbit Holes | 提前声明的高风险细节与绕行方案（Shape Up Pitch 第 4 要素） |
| No-gos | 显式排除项："这次明确不做的" |
| 假设陈述 | 一句式价值假设：For…who…the…is a…that…（SAFe Epic Hypothesis） |
| 快筛三问 | 什么问题/为谁/怎么算成功——5 分钟分诊（SVPG 机会评估核心三问） |
| 下注桌 Betting | 门禁⓪的表决时刻；此前所有评论只挑刺不表决（Shape Up） |
| go / modify / kill | 门禁⓪三种裁决（PMI phase-gate 判据形式） |
| 机会背囊 Opportunity Backlog | 被 kill/暂缓想法的留档处，含复活条件（SVPG） |
| 熔断 | appetite 到期强制收敛：砍范围保交付，不展期 |
| 观察窗 | 试点交付后收集市场侧 go 信号的时间窗（本平台扩展词条） |
| 知识缺口 | 阶段0 结束时"已知不知道"清单，移交阶段1（GOV.UK Discovery） |
| MECE | 互斥且穷尽（Mutually Exclusive, Collectively Exhaustive）——阶段0 用它检验立项决策维度 D1-D7 无重叠无遗漏 |
| Cagan 四风险 | Value（价值）/ Usability（可用）/ Feasibility（可行）/ Viability（商业成立）——discovery 要逐一消解的四类风险，D1-D7 的穷尽性检验基准 |
| 最险假设 RAT | Riskiest Assumption Test：最核心且最没证据的那条假设，用最便宜的实验先证伪（Lean Startup leap-of-faith） |
| must-meet / should-meet | Stage-Gate 双层门禁判据：must-meet 一票否决（=本平台熔断线），should-meet 计分权衡（=观察窗信号） |

## 阶段 1（产品发现/需求）

| 名词 | 定义 |
|---|---|
| EARS | 需求句式标准（Rolls-Royce 2009，AWS Kiro 采用）：Ubiquitous/Event-driven/State-driven/Unwanted/Optional 五型——系统级行为用 "When/While/If…the system shall…" 写法 |
| ISO 29148 九特性 | 单条需求质量标准：necessary/appropriate/unambiguous/complete/singular/feasible/verifiable/correct/traceable；集合级另有 complete/consistent |
| backbone / 行走骨架 | Story Mapping：backbone=横向铺完的用户旅程（mile wide, inch deep）；行走骨架=端到端最小可用线（MVP 线，Cockburn） |
| INVEST | 好 Story 六判据：Independent/Negotiable/Valuable/Estimable/Small/Testable |
| Kano 三型 | 基本型（缺了即死）/绩效型（线性加分）/惊喜型（可砍）——防"全是 Must"的需求通胀 |
| Won't-have | MoSCoW 第四档的显式化：范围外=承诺不做并记录理由，不是忘了 |
| GWT | Given/When/Then 验收标准句式（Gherkin/BDD），单条只测一事 |
| DoR | Definition of Ready：需求"就绪可进开发"的判定清单——本平台=门禁①判据 |
| 孤儿需求 | 追溯表里对不上任何 prfaq 痛点/假设的需求——删或补立项理由 |
| 需求通胀 | Must 占比过高（>60%）失去优先级意义——触发 Kano 重分层 |

## 阶段 2（定义/设计）

| 名词 | 定义 |
|---|---|
| ADR / MADR | 架构决策记录（Nygard）/ 其 Markdown 模板（背景/备选+代价/决定/后果）；一事一文、不可变只追加 |
| 备选方案 | ADR 里被认真考虑过的 ≥2 个选项及代价——没有备选的"决策"只是"决定" |
| 稻草人备选 | 为凑数写的明显不可行陪衬选项——architect 预审阻断项 |
| 质量场景 | ATAM 句式：刺激→期望响应与度量→设计应对→牺牲了什么；每条 NFR 一场景 |
| 权衡点/敏感点 | 改善一个质量属性会损害另一个的位置 / 单个决策强烈影响某质量属性的位置（ATAM） |
| 视点 | ISO 42010：按利益方关注点组织架构视图的约定 |
| non-goals | 设计明确不解决的问题（RFC 惯例），承 PRD Won't 再加设计级排除 |
| spike | 时间盒的技术探索任务：消解高不确定项，超时即按失败处理 |
| Architecture Spine | ≤300 行的 as-is 架构主干（BMAD 教训：大文档必腐化） |
| Fitness Function | （见全局词条）阶段2 定义清单，M3 落 CI |

## 阶段 3（构建与交付）

| 名词 | 定义 |
|---|---|
| 任务验证行 | 每条任务强制的 `验证：` 行——可执行命令或可观测判据；无验证行=任务定义不清（SPEC-21，宪法 C2） |
| 垂直切片 | 一条任务贯穿各层交付一小块可用功能，而非按层横切 |
| 纵向骨架 | B 组任务：端到端最小可用链路优先打通，再做增量（异构评审#9 采纳） |
| DoD | Definition of Done：单条=验证命令绿；整批=全勾选+`--final` 探针绿+spike 全结论 |
| spike 结论 | 时间盒探索的产出：必须写回 plan 风险表或新 ADR，不许无结论继续 |
| 砍线 | 超预算 20% 时按 plan 里程碑砍序执行的范围削减，须记录于 tasks 砍线表 |
| 空话式验证 | "人工确认没问题/看起来对"类不可执行判据——探针直接拒绝 |

<!-- 阶段4-5 词条随各阶段定义文档展开时追加 -->
