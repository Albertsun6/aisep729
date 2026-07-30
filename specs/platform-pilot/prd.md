# PRD：platform-pilot（Claude 企业级 E2E 研发平台试点）

> 阶段 1 产物 · 门禁①（需求确认）评审材料 · 2026-07-31 · 模板见 docs/process/stages/stage-1-requirements.md
> 上游：specs/platform-pilot/prfaq.md（门禁⓪ go @2026-07-31）｜ 状态：待批 → 批准后进阶段 2（设计）

## 概述

For 需规模化 AI 研发但质量失控的企业工程团队，本平台是可当天落地的全生命周期治理系统（咨询交付件）——用六门禁+产物状态机+存量接入让 AI 研发全程可审计、可复制（prfaq 假设陈述）。本 PRD 覆盖试点范围：平台仓 + demo 业务仓，一个月 appetite。功能需求主体承接《E2E研发平台试点-stories.md》（13 条，本文件为其正式化：补 backbone、系统级需求 SR、NFR、Kano 分层、追溯）。读者：平台作者（自建）、异构评审者（门禁②前审）、未来受训团队（示例样板）。

## 用户与路径（Story Map backbone）

| 角色 | 主路径（mile wide） | 行走骨架（MVP 线）标注 |
|---|---|---|
| 平台作者（自举） | 立项⓪→需求①→设计②→任务→实现→评审③→发布④→退役⑤ 全程留痕 | 全路径均在骨架（平台自己开发自己=US-12） |
| 受训团队·开发者 | e2e init（绿地）或 assess+adopt（存量）→ 六门禁开发一个 feature → PR 合并 | **骨架主线**：init→⓪→①→②→tasks→实现(hooks)→评审③→PR；release④/retire⑤ 文档级演练 |
| 受训团队·管理员 | 装 marketplace plugin → 配 settings → 查审计留痕 | 骨架外（Should，US-11） |
| 培训讲师 | 手册讲解 → demo 演示 → 视频播放 | 手册+demo 在骨架；视频绩效型 |

## 功能需求

**用户故事主体**：US-1 ~ US-13 全文（含 Story/GWT AC/边界）见《[stories.md](stories.md)》（= 本 PRD 附录 A，单一真相源不重复抄录；2026-07-31 依 ADR-002 自仓库根移入本目录）。摘要 + Kano 分层（2026-07-31 用户认可）：

| US | 名称 | MoSCoW | Kano | 备注 |
|---|---|---|---|---|
| US-1 | 双模式接入 init / assess+adopt | Must | 基本型 | 存量是受众主场景 |
| US-2 | 需求段 skills（discovery+requirements） | Must | 基本型 | 已实现并实跑（阶段0/1 自举） |
| US-3 | 设计段 skill + architect | Must | 基本型 | |
| US-4 | 实现段 skill + 2 hooks | Must | 基本型 | |
| US-5 | 评审段 + CI 双环 + 风险路由 | Must | 基本型 | CI 依赖远程仓（见移交项） |
| US-6 | 收尾段（release+retire） | Must | 绩效型 | demo 文档级演练 |
| US-7 | vendored 产品化自包含 | Must | 基本型 | SR-5 探针 |
| US-8 | demo 仓全链路验证 | Must | 基本型 | 选题已定：赌场输赢记录（C-1 闭环） |
| US-9 | 实施手册（中文） | Must | 基本型 | |
| US-10 | 演示视频 | Must | 绩效型 | 熔断降精度不砍项 |
| US-11 | marketplace 分发演示 | Should | 惊喜型 | 熔断先砍 |
| US-12 | 平台仓自举治理 | Should | 惊喜型 | 事实上已在发生（⓪①留痕） |
| US-13 | 存量治理机制（ratchet+台账+fitness fn） | Must | 绩效型 | 咨询差异化 |

### US-8（细化）：demo 仓全链路验证　[Must] [Kano: 基本型]
**Story**：作为培训讲师，我想要一个用平台全流程开发出的真实 demo 应用及全套产物留痕，以便培训展示真实证据链。
**验收标准**
- Given demo 仓，When 检查 `specs/<feature>/`，Then prfaq→prd→spec→plan→tasks 齐全且六门禁记录可查
- Given demo 应用，When 本地启动（macOS），Then 行走骨架 3 步功能可用：记一笔（日期/场次/游戏/输赢金额）→ 看流水列表 → 看汇总（累计输赢/按时段）
- Given demo 仓 CI，When PR 创建，Then 双环真实运行并可阻断
**边界**：选题已定案（C-1，2026-07-31）：**赌场输赢记录工具**——用户真实需求（关联既有"大姨软件/博彩记录本"手工 MVP，本次用平台流程正规化重做，形成"手工 vs 平台"培训对照）。demo 的详细功能需求**不在本 PRD 展开**——它将在 demo 仓走完整六门禁产出自己的 prfaq/prd（这正是 US-8 要验证的内容）；本处三步行走骨架仅为体量上限约束

### 系统级需求（EARS 句式，平台自动行为）

### SR-1：门禁串锁　[Must] [Kano: 基本型]
When 任一阶段 skill 启动, the skill shall 校验上一道门禁记录; If 记录缺失或非批准, then the skill shall 拒绝启动并指路对应阶段。
**验证方式**：探针（如 check-prd.sh 对门禁⓪的 64 退出码）+ 各 skill 第 0 步实测（阶段0/1 已验证 ✅）

### SR-2：制品探针　[Must] [Kano: 基本型]
When 阶段制品生成完成, the skill shall 运行该阶段 check-*.sh; If 退出码非 0, then the skill shall 阻止交付并列出缺项。
**验证方式**：故意构造缺段制品，探针须 FAIL（阶段0 已实测：抓出格式漂移与缺段）

### SR-3：实现段本地阻断　[Must] [Kano: 基本型]
When 文件被编辑, the PostToolUse hook shall 立即执行 lint; While 测试未全部通过, the Stop hook shall 阻止会话收工。
**验证方式**：demo 仓构造 lint 违规/失败测试，hook 须触发（M3 实测）

### SR-4：存量棘轮　[Must] [Kano: 绩效型]
When CI 运行于存量样例仓, the ratchet shall 豁免基线内违规并阻断新增违规; If 基线数上升, then the CI shall 失败。
**验证方式**：存量样例仓注入新违规，CI 须红（M3 实测）

### SR-5：自包含　[Must] [Kano: 基本型]
Ubiquitous: The 平台仓 shall 不含任何个人绝对路径/私有依赖。
**验证方式**：grep 探针零命中（M1 起挂常跑）

## 非功能需求（NFR）

| # | 类别 | 需求（可验证表述） | 验证方式 |
|---|---|---|---|
| NFR-1 | 环境 | **仅 macOS 实测支持**（用户决策 2026-07-31）；Linux 未验证，记为已知限制——观察窗出现企业线索即触发二期 Linux 验证 | 手册"已知限制"节存在；macOS 全链路探针绿 |
| NFR-2 | 语言 | 全部制品/文档/skill 输出中文 | 交付物抽查 |
| NFR-3 | 版本基线 | 实测 Claude Code 版本记录于手册；plugin 锁版本发布 | 手册版本字段存在 |
| NFR-4 | 自包含 | 同 SR-5 | grep 探针 |
| NFR-5 | 制品纪律 | prfaq ≤120 行；各制品含门禁记录块 | 各阶段探针 |
| NFR-6 | 托管演进 | M1-M2 本地 git 即可；**M3 CI 双环前必须有远程仓**（GitHub Actions 依赖） | M3 入口检查 |

## 范围外（Won't-have，显式承诺不做）

- L4 managed settings / OTel→SIEM / gateway 实配（手册文档化；二期）
- Tier 2 权限探针实测（随 L4 实配；二期）
- 培训 PPT、英文文档（二期）
- 真实生产部署（demo 级即止）
- **Linux/Windows 实测**（仅 macOS；复活条件=观察窗企业线索）
- SaaS 化/自助订阅形态（咨询交付件定位；观察窗信号后重估）

## 追溯表

| 需求 | ↔ prfaq 痛点/假设 | ↔ 下游（阶段2 已回填） |
|---|---|---|
| US-1/13、SR-4 | 痛点②流程不一致 + brownfield 主场景 | SPEC-9~14；plan spike S4 |
| US-2/3/9、SR-1 | 痛点③文档缺失无留痕 | SPEC-1~5、18；ADR-004/008 |
| US-4/5/8、SR-2/3 | 痛点①AI 质量失控 | SPEC-6~8、15~16；ADR-003；plan spike S3 |
| US-7、SR-5 | 最险假设（付费的是落地件）→ 可分发 | SPEC-17；ADR-006 |
| US-10/11 | 最险假设 → 可演示 | 无 SPEC（纯交付物/分发演示）：落 plan 里程碑 M4 与 spike S2 |
| US-5、US-8（CI 侧） | 痛点①质量失控 → 双环兜底 | SPEC-19/20；ADR-003 |
| US-6/12 | 差异化主张（两端管到位/自举证据链） | US-6→SPEC-1~4；US-12 复用 SPEC-1~4 既有契约（无新增 SPEC） |
| NFR-1/3/6 | Appetite 约束（一个月业余） | plan 质量场景表；ADR-005/007 |

孤儿检查：13 US + 5 SR + 6 NFR 全部有上游追溯 ✅

## 待澄清与移交

- [x] **C-1 已闭环**（2026-07-31）：demo=赌场输赢记录工具（用户真实需求，关联大姨软件既有手工 MVP；体量=行走骨架 3 步；详细需求由 demo 仓自走六门禁产出）
- 移交-M3：远程仓命名与接入时点（约束：CI 双环前必须闭环；用户决策"本地 git 先跑"）
- 移交-阶段2：门禁记录 grep 机制的健壮性（是否升级 gates.yaml 结构化）——设计决策
- 移交-M4：Usability 假设"手册不提问可走通"的验证（干净环境实测）

## FAQ / 给阶段2 的备注

- 门禁校验目前依赖制品内文本格式（`决定：go`），格式漂移会破坏 SR-1——阶段2 评估结构化门禁账本（gates.yaml/JSON）的取舍
- e2e-* skill 与个人 skills 的 vendored 映射关系表已在 stories US-7，设计阶段落实产品化改造清单

---
门禁① 记录：
- 批准人：平台作者（用户本人）
- 决定：批准
- 日期：2026-07-31
- 备注：C-1（demo=赌场输赢记录）闭环、Kano 分层认可、探针全绿后批准。用户附加指令：后续所有阶段均须实现 skill（六件套定式确认）。进入阶段 2（设计）。
