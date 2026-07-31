# ADR-015：用 Claude Code plugin marketplace 做 L3 分发

- 状态：accepted
- 日期：2026-07-31
- 关联：四层架构 L3（分发）· C15（供应链钉版）· ADR-014（服务端门禁）
- 来源：S2 spike 实测（`Albertsun6/aisep729`），**全链路跑通**

## 背景与驱动力

L3 分发要回答：客户怎么拿到这套能力？手册教的 `bash bin/e2e init` 需要先克隆平台仓，
对企业客户来说是个摩擦点。Claude Code 有原生的 plugin marketplace 机制，
但**它到底能不能承载这套东西、装完是什么形态、有什么副作用**——不实测说不清。

## 备选方案

### 选项 A：只靠 `git clone` + `bin/e2e init`（现状）

- 优点：零额外机制；客户仓拿到的是**自己的一份拷贝**，可自由改；与门禁探针的路径假设完全一致
- 代价：客户要先知道仓在哪、要手动更新；没有版本概念，"我用的是哪个版本"说不清

### 选项 B：Claude Code plugin marketplace（**选中**）

- 优点（**均已实测**）：
  - 一行命令接入：`claude plugin marketplace add Albertsun6/aisep729`
  - 一行命令安装：`claude plugin install e2e-platform@aisep729-e2e`
  - **原生支持 SHA 钉版**（`source.sha`），与 C15 供应链要求天然吻合
  - 装完自动缓存到 `~/.claude/plugins/cache/<market>/<plugin>/<sha>-<hash>/`，**版本可追溯**
- 代价（见「后果」）：只分发 `.claude/` 能力层，**不分发 L1 制品与探针**

### 选项 C：npm 包 / Homebrew formula

- 优点：生态成熟，版本管理完善
- 代价：Claude Code 的 skill/agent/hook 不是 npm 的一等公民，装完还要手动摆位置；
  且引入 Node 依赖，与"基础层零额外安装"（ADR-010）冲突

## 实测记录（可证伪断言 → 判定）

| # | 断言 | 判定 | 证据 |
|---|---|---|---|
| S2-a | 平台仓可作为 marketplace 被识别 | ✅ CONFIRMED | 加 `.claude-plugin/marketplace.json` 后 `claude plugin marketplace add` → `Successfully added marketplace: aisep729-e2e` |
| S2-b | 插件可被安装 | ✅ CONFIRMED | `claude plugin install e2e-platform@aisep729-e2e` → `Successfully installed (scope: user)` |
| S2-c | 安装后能力完整落地 | ✅ CONFIRMED | 缓存目录含 `skills/`（**7 个 SKILL.md**）、`agents/`、`hooks/`，版本目录名为 `8306a8bd9c0f-e026f56c`（**SHA 前缀可追溯**） |
| S2-d | 分发的是完整平台 | ❌ **REFUTED** | `source.path` 指向 `.claude`，故**只分发 L2 能力层**；`bin/e2e`、`scripts/*.sh`、`tests/probe-negative/`、`docs/process/` **都不在内** |

## 决定

**采用 marketplace 作为 L3 分发通道，但明确它只承载 L2，不承载 L1。**

### 1. 两种接入方式并存，不是二选一

| 方式 | 拿到什么 | 适合谁 |
|---|---|---|
| `claude plugin install` | **仅 L2 能力层**：7 skill + 3 agent + 2 hook | 想在**已有项目**里立刻用上七阶段 SOP 的人 |
| `git clone` + `bin/e2e init` | **完整平台**：L2 + 探针 + 负样本 + 宪法 + 阶段定义 + CI + `bin/e2e` | 要**完整门禁**（探针/棘轮/CI/负样本）的人 |

**必须写进手册的一句话**：只装插件**拿不到探针，也就没有门禁**。
skill 会照常引导流程，但每一步的"验证"环节会因找不到 `scripts/check-*.sh` 而无法执行——
这正是 `check-skill-deps.sh` 要拦的 fail-open 场景。**不得**把"装了插件"等同于"接入了平台"。

### 2. `marketplace.json` 的 `sha` 字段必须钉住

C15 要求供应链钉版。marketplace schema 原生支持 `source.sha`，本仓已钉。
**每次平台发版必须同步更新该 sha**，否则客户装到的是"ref: main 的当前状态"，不可复现。

### 3. 重名风险须在手册标注

同时用两种方式接入时，项目内 `.claude/skills/e2e-*` 与插件提供的 `e2e-*` **同名**。
本次 spike 未观察到报错（插件状态 `enabled`，项目 skill 也在），
但**解析优先级未验证**——手册应建议**二选一**，不要同时用。

## 后果

- ✅ L3 分发从"设想"变成**一行命令可复现**的通路，且原生 SHA 钉版
- ✅ 客户获得版本可追溯性（缓存目录名含 SHA）
- ⚠️ **插件 ≠ 完整平台**：只装插件的客户没有探针、没有门禁强制力，
  手册必须显式说明，否则会出现"我装了你们的插件，为什么没拦住"的误解
- ⚠️ 重名解析优先级**未验证**，列入 backlog
- ⚠️ 本次 spike 在本机装了又卸，**未留下副作用**（`claude plugin list` 已确认清空）
- 可复议条件：若 marketplace 支持分发 `.claude/` 之外的路径（多 source 或整仓模式），
  则可考虑用它承载完整平台，届时重开本 ADR
