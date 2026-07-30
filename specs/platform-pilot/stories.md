# E2E 研发平台试点 — User Stories

生成时间：2026-07-30
访谈轮次：情境锚定 1 轮 + 结构化访谈 2 轮 + 追加讨论 2 次（brownfield / 选择性评审）
方法：/req-discovery 访谈式共创
设计依据：《Claude企业级E2E研发平台-完整报告.md》（v2.1）+《企业级软件开发端到端阶段划分-完整报告.md》

## 北极星（访谈锚定结论）

> 平台本身就是产品——一套可对外输出（**企业培训/咨询落地包**，中文为主）的 AI 开发方法论落地件，解决三大痛点：**AI 产出质量失控、多项目流程不一致、需求/设计文档环节缺失**。现有个人 skills 以 **vendored 副本产品化**方式整合；试点 = 平台仓 + demo 业务仓（一个真实 web 小工具，选题待定）；新用户经**一键脚手架**上手，存量项目经 **assess→adopt 非破坏接入**。

## 六段阶段边界（每段的入口 / 出口 / 门禁 / 试点程度）

| 段 | 入口条件 | 核心产物 | 出口 = 门禁 | 试点程度 |
|---|---|---|---|---|
| 1 战略/立项 | 有一个想法 | `prfaq.md`（一页纸：价值/appetite/不做什么） | **⓪ 立项/下注**（人批） | ✅ 全做（e2e-discovery） |
| 2 产品发现 | 门禁⓪通过 | `prd.md` + User Stories（G/W/T + MoSCoW） | **① 需求确认**（人批） | ✅ 全做（e2e-requirements） |
| 3 定义/设计 | 门禁①通过 | `spec.md` + `plan.md` + ADR-NNN | **② 架构评审**（architect subagent 预审 + 人批） | ✅ 全做（e2e-design） |
| 4 构建与交付 | 门禁②通过 | `tasks.md`（带验证方式）→ code+tests → PR → release | 代码：hooks 本地阻断 + **CI required checks**；**③ 合并批准**（风险分级路由）；**④ 生产放行**（PRR 清单） | ✅ skill+hooks+CI 双环真跑；真实部署仅 demo 级 |
| 5 运营/演进 | 门禁④通过 | runbook、监控、事故回流 | 事故→新需求回到段 1/2 | ◐ runbook 产出真做；监控/DORA 仪表文档化 |
| 6 退役 | 功能拟下线 | deprecation 计划（数据迁移/通知/支持期） | **⑤ 退役评审**（人批） | ◐ skill 真做；demo 中文档级演练 |

**边界铁律**：产物未过门禁，下一段 skill 拒绝启动（检查门禁记录，缺即停）；门禁由证据触发而非日期；门禁密度按 `risk-tiers.md` 分档（NASA 硬 gate ↔ Amazon 一页纸谱系）。

---

## User Stories（13 条：11 Must / 2 Should）

### US-1：双模式接入 `e2e init`（绿地）/ `e2e assess + adopt`（存量）
**Story**：作为被培训团队的开发者，我想要新项目一键初始化、存量项目先体检再非破坏性接入，以便平台能落在我们真实的代码库上（存量是培训受众的主场景）。
**优先级**：Must Have
**验收标准（init 绿地）**
- Given 空 git 仓库，When 运行 init，Then 生成完整目录树（AGENTS.md、CLAUDE.md<200 行、`.claude/`{settings/skills×7/agents×4/hooks×2/rules}、`docs/`{constitution/architecture/process}、`specs/`、`.github/workflows/` 双环）
- Given 生成完成，When 运行自检探针，Then 必需文件齐全、hooks 可执行、配置合法
- Given 任一生成文档，When 打开，Then 中文且含"是什么/怎么用"
**验收标准（assess + adopt 存量）**
- Given 存量仓库，When 运行 assess，Then 产出健康度基线（churn×complexity 热图、死代码、依赖缠绕、覆盖率、文档缺口）+ `risk-tiers.md` 初稿（雷区路径=高风险档）+ 热点清单
- Given 存量仓库（可能已有 CLAUDE.md/docs），When 运行 adopt，Then 非破坏性叠加：已有文件一律保留，冲突项列清单报告而不覆盖
- Given adopt 完成，Then 自动产出架构基线：代码反推 `spine.md`（as-is 真实结构，不写理想架构）+ AGENTS.md + 3-5 条追认 ADR（git 考古，标 retroactive）
- Given 存量项目新变更，When 走流程，Then 用 delta-spec 模式（`specs/<change>/` 描述增量，归档合并进 docs），不要求给存量补全量 spec
- Given 手册 brownfield 章，Then 有渐进接入路径：先只挂门禁③ → 跑顺再向两端扩⓪-⑤
**边界**：assess 的体检维度产品化自 project-health skill；基线提取产品化自 architecture-blueprint-generator / diagramming-code 思路

### US-2：需求段 skills（e2e-discovery + e2e-requirements）
**Story**：作为开发者，我想要访谈式地从模糊想法产出 prfaq/PRD/Story，以便补上"从想法直接跳代码"缺失的环节。
**优先级**：Must Have
**验收标准**
- Given 一个想法，When 跑 e2e-discovery，Then 产出 `specs/<feature>/prfaq.md`（含 appetite 与不做什么），停在门禁⓪等人批
- Given 门禁⓪通过，When 跑 e2e-requirements，Then 产出 prd.md + G/W/T Story 列表，停在门禁①
- Given 门禁未批准，When 试图进下一段，Then skill 拒绝并提示缺失的门禁记录

### US-3：设计段 skill（e2e-design + architect subagent）
**Story**：作为开发者，我想要从 PRD 推导 spec/plan/ADR 并经架构预审，以便设计决策强制留痕。
**优先级**：Must Have
**验收标准**
- Given 已批 PRD，When 跑 e2e-design，Then 产出 spec.md/plan.md/ADR-NNN，architect subagent 完成预审意见，停在门禁②
- Given plan 与 constitution 冲突，When 预审，Then 冲突被显式列出

### US-4：实现段 skill（e2e-implement + 2 个 hooks）
**Story**：作为开发者，我想要任务清单驱动的 TDD 实现且改完即验，以便治住"AI 产出质量失控"。
**优先级**：Must Have
**验收标准**
- Given 已批 plan，When 跑 e2e-implement，Then 先产出带验证方式的 tasks.md，再按任务 TDD 实现
- Given 任一文件被编辑，When PostToolUse hook 触发，Then lint 立即执行
- Given 测试未过，When 会话试图收工，Then Stop hook 阻断（Spotify 模式）

### US-5：评审段 skill（e2e-review + CI 双环 + 选择性评审路由）
**Story**：作为开发者，我想要内环对抗评审 + 外环 CI 双绿才能合并、且评审深度按风险分档，以便验证税花在刀刃上。
**优先级**：Must Have
**验收标准**
- Given 代码完成，When 跑 e2e-review，Then reviewer/security subagent 产出结构化 findings（accept/refute 留痕）
- Given PR 创建，When 外环触发，Then GitHub Actions 质量门禁 + claude-code-action 评审真实运行并阻断不达标合并（门禁③）
- Given PR 触及 risk-tiers.md 高风险路径，Then 强制人审+加深评审；低风险路径 CI 绿即可合并（选择性评审的机器执行）

### US-6：收尾段 skills（e2e-release + e2e-retire）
**Story**：作为开发者，我想要发布走 PRR 清单、退役走 deprecation 评审，以便两端不再留在"项目外"。
**优先级**：Must Have（demo 中文档级演练，不真实部署）
**验收标准**
- Given 合并完成，When 跑 e2e-release，Then 产出 PRR 核对记录 + runbook，停在门禁④
- Given 功能拟下线，When 跑 e2e-retire，Then 产出 deprecation 计划（数据迁移/用户通知/支持期），停在门禁⑤

### US-7：vendored 产品化与自包含
**Story**：作为平台作者，我想要把个人 skills 产品化为平台仓内自包含副本，以便对外分发不依赖我的 `~/.claude`。
**优先级**：Must Have
**验收标准**
- Given 平台仓任意文件，When grep 个人绝对路径/私有依赖，Then 零命中（可执行探针）
- Given 一台干净环境，When 仅凭平台仓走 US-1 路径，Then 全流程可运行
- 整合映射：req-discovery→e2e-requirements、feature-fullstack→e2e-implement、debate-review 思路→e2e-review、project-health→assess、architecture-blueprint-generator→基线提取（个人版保留不动）

### US-8：demo 业务仓全链路验证
**Story**：作为培训讲师，我想要一个用平台全流程开发出的 demo web 应用及全套产物留痕，以便培训展示真实证据链而非口说。
**优先级**：Must Have　**边界**：选题待澄清（PRD 阶段定；候选：门禁看板自举方案）
**验收标准**
- Given demo 仓，When 检查 `specs/<feature>/`，Then prfaq→prd→spec→plan→tasks 产物齐全且六门禁记录可查
- Given demo 应用，When 本地启动，Then 功能可用；CI 双环在该仓真实通过

### US-9：实施手册（中文）
**Story**：作为被培训团队，我想要从安装到走通全流程的落地手册（含 L4 文档化部分：managed settings/OTel→SIEM/gateway 实施指引；含存量项目治理 playbook），以便脱离讲师也能落地。
**优先级**：Must Have
**验收标准**
- Given 手册，When 新用户按步骤执行，Then 不需要额外提问即可完成 init/adopt 并走通首个门禁循环
- Given 手册目录，Then 含：安装上手 / 绿地路径 / 存量治理 playbook（体检→基线→围栏→绞杀四阶段 + 门禁升级时机）/ L4 实施指引 / FAQ

### US-10：演示视频
**Story**：作为培训讲师，我想要带中文旁白的平台全流程演示视频，以便培训与售前直接播放。
**优先级**：Must Have（依赖 US-8 完成后录制；用 demo-video skill 自动化）

### US-11：marketplace 分发演示
**Story**：作为受训团队管理员，我想要通过私有 marketplace 安装 e2e-core plugin，以便理解官方分发机制。
**优先级**：Should Have

### US-12：平台仓自举治理
**Story**：作为平台作者，我想要平台仓自身也按六门禁开发留痕（constitution/ADR/specs），以便"平台用自己开发自己"成为最强培训素材。
**优先级**：Should Have

### US-13：存量治理机制（ratchet + 台账 + fitness functions）
**Story**：作为存量项目的开发者，我想要棘轮门禁与治理台账，以便老代码不恶化、改善有数据依据。
**优先级**：Must Have（对咨询受众是差异化能力）
**验收标准**
- Given 存量仓有 N 个 lint 违规，When CI ratchet 运行，Then 存量豁免、新增违规阻断、基线数上升即失败（只许降不许升）
- Given 体检完成，When 查看 `docs/tech-debt.md`，Then 热点按 churn×complexity 排序且各有处置状态（观察/围栏/已立项重构）
- Given 拟重构某模块，When 走流程，Then 必须从门禁⓪立项（有 prfaq），禁止无立项大重构
- Given 架构约束（依赖方向/层间调用/模块大小），When CI 运行 fitness functions，Then 违反即失败（架构不恶化的可执行断言）
- 特征测试（characterization tests）：热点模块改动前先锁现状行为——写进手册 playbook，工具不强制

---

## 全局边界（试点不做什么）

- L4 的 managed settings / OTel→SIEM / gateway：**不实配**，手册文档化（含实施指引）
- 敏感路径权限探针（Tier 2 防护实测）：随 L4 实配放二期
- 培训 PPT、英文文档：二期
- 真实生产部署：demo 级即止（发布/退役文档级演练）
- 平台不承诺"治好烂架构"：只承诺看清（体检）、锁住（围栏）、按数据逐步改（热点+绞杀）；重构立项是门禁⓪的业务决策

## 制作过程的选择性评审（对我们自己，也写进 constitution）

| 产物风险档 | 例子 | 评审方式 |
|---|---|---|
| 高（返工代价大/对外承诺） | spec、plan、ADR、constitution、六门禁定义 | 异构评审（debate-review 式）+ 用户人审 |
| 中（可执行代码类） | 脚手架脚本、hooks、skill 可执行部分 | 可执行验证优先（探针/测试必过）+ 单 lens AI 评审一轮 |
| 低（文字类） | 手册正文、README、旁白稿 | 用户抽查 + 链接/拼写探针 |
| 触发式升级 | 任何产物门禁被打回 ≥2 次 | 自动升一档 |

## 待澄清项

- [ ] demo web 小工具选题（PRD 阶段定；候选：门禁看板自举）
- [ ] 平台仓/demo 仓的仓库命名与托管位置（GitHub 私有→成熟后公开？）

## 下一步

1. 全局可视化文档（`E2E研发平台-全局视图.html`）→ 用户过目
2. 按阶段逐级展开详细讨论（顺序：立项⓪ → 需求① → 设计② → …）
3. 起草 prfaq.md + prd.md（门禁⓪①评审材料）→ 设计文档（异构评审）→ tasks → 动工
