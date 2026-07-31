# AISEP729 — 企业级端到端研发平台

给 [Claude Code](https://claude.com/claude-code) 装上**六道人审门禁**和**一整套会失败的检查**，
让 AI 写的代码从立项到退役每一步都留下可验证的证据。

**面向 macOS。中文。** 代码 Apache-2.0 · 文档 CC BY-SA 4.0（见 [LICENSE](./LICENSE)）

---

## 凭什么值得用

市面上"AI 时代研发流程"的方法论不缺。本项目的差异不在流程图，
而在于**绝大多数主张都有一个会失败的可执行断言钉着**。

在自建自用过程中，这套门禁抓到了 30+ 条真实缺陷。下面这几条是它的分量：

| 抓到的 | 如果没抓到，会发生什么 |
|---|---|
| `enforce_admins` 默认 `false` | 每个仓配了一道**假门禁**：配置回读全绿、GitHub 打印 "4 of 4 required status checks are expected"，**直推 main 照样成功** |
| 门禁台账取"全文首个决定行" | 执行者在正文早处写一行 `- 决定：go`，尾部保持"待批" → 探针判 PASS、串锁放行，而**人翻到文末只看到"待批"**。批准在人的视野里被隐形伪造 |
| `gh pr view ${E2E_PR:-}` 未加引号 | 参数注入 —— **用别人仓的 PR 证据**打开自己的合并门禁 |
| `tpl_ci` 函数从未定义 | 每个脚手架仓拿到 **1 字节空 workflow**：目录看起来齐全，CI 根本不存在 |
| `grep -P` 在 macOS BSD grep 上不支持 | 配上 `2>/dev/null \|\| true` 后探针**永远 PASS** |
| 评审 agent 定义只算"文档"档 | 改一个 md 文件就能**关掉整套评审内环**，且无人审 |
| 生产就绪评审 21 条断言 | 独立对抗验证后 **16 条被证伪** —— 多数不是结论错，是**证据不实或说得太满** |

**这些不是演示用的假 bug，是这套平台在建造自己时踩到的真坑，每一条都留下了负样本。**
完整目录见 [实施手册 §2](./docs/implementation-manual.md)。

---

## 30 秒了解它是什么

```
⓪ 立项 → ① 需求 → ② 设计 → ③ 合并 → ④ 发布 → ⑤ 退役
   每一道门都停下来等人裁决，上一道没过，下一道的 skill 拒绝启动
```

| 组成 | 数量 | 说明 |
|---|---|---|
| 阶段 skill | **7** | `e2e-discovery` / `requirements` / `design` / `implement` / `review` / `release` / `retire` |
| 评审 agent | **3** | architect（架构预审）/ reviewer（内环）/ security（安全） |
| hook | **2** | 改完文件即时 lint · 收工前强制验证 |
| 探针 | **13** | 结构 / 自包含 / bash 陷阱 / skill 依赖 / 宪法条款 / Action 钉版 / 手册结构 / 视频判据 / AI 评审契约 / 服务端门禁行为证明 / README 门面 / 插件 sha 时效 / adopt 对等 |
| **负样本** | **95** | **探针自身能否被证伪** —— 这是本项目最重要的数字。口径 = `bash tests/probe-negative/run.sh` 的分母，**跑一下就能核对** |
| 工程宪法 | 15 条 | 不可妥协原则，每条含可执行检查 |
| ADR | 15 份 | 每个决策含 ≥2 个真实备选 |

---

## 3 分钟上手

```bash
git clone https://github.com/Albertsun6/aisep729.git
cd aisep729

bash bin/e2e doctor                      # 前置自检（分三层，缺可选项只降级不报错）
bash bin/e2e init /path/to/你的项目       # 幂等，既有文件一律不覆盖
```

然后进你的项目，在 Claude Code 里说一句话：

> 立项：我想做个 XXX

它会走完阶段0 并**停在门禁⓪等你裁决** go / modify / kill。之后每一段同理。

**验收接入是否成功**：

```bash
cd /path/to/你的项目
bash scripts/check-skill-deps.sh && bash scripts/check-clause-refs.sh && bash tests/probe-negative/run.sh
```

三条全绿才算成功。任一条红，看输出的 `MISSING:` 行——它会直说缺什么、为什么。

**存量项目**走 `bash bin/e2e assess <仓>`（只读体检，产物落**仓外**）→ `adopt`（非破坏接入）
→ `scripts/ratchet.sh`（存量违规豁免、新增违规阻断）。详见 [手册 §4](./docs/implementation-manual.md)。

---

## ⚠️ 另一条路：插件市场（**装了也没有门禁**）

```bash
claude plugin marketplace add Albertsun6/aisep729
claude plugin install e2e-platform@aisep729-e2e
```

装完你拿到 **7 个 skill + 3 个 agent**，它们会照常引导你走六段流程。
**但门禁跑不起来**，原因比"没带探针"更微妙 —— 冷启动验收实测：

| 事实 | 说明 |
|---|---|
| 7 个阶段探针**确实被带走了** | 它们就住在 `.claude/skills/*/scripts/` 里，而插件源是 `.claude` |
| 但它们**跑不起来** | 每个都 `source` 仓内的 `scripts/lib/gate.sh`，而 `scripts/` **不在插件里** |
| `bin/e2e`、平台探针、负样本套件 | 同样不在插件里 |
| 两个 hook | 靠 `.claude/settings.json` 注册，那是**项目设置**不是插件机制，**不会自动生效** |

跑到那一步时探针会明确告诉你怎么办（不是一句 bash 报错）：

```
FAIL(65): 找不到 scripts/lib/gate.sh —— 本探针需要完整平台才能运行。
  最可能的原因：你是通过 `claude plugin install` 装的。
  要用门禁，请改用完整安装：git clone … && bash aisep729/bin/e2e init <你的项目>
```

**所以**：插件适合"我只想要那套 SOP 引导"；**要门禁就走上面的 `e2e init`**。
两条路**别同时用**——会出现同名 skill，解析优先级未验证。
详见 [ADR-015](./docs/architecture/adr/ADR-015-plugin-marketplace-distribution.md)。

## 看一眼实际效果

- 🎬 **演示视频**（9 分 04 秒，中文旁白）：
  [aisep729-demo/docs/demo/](https://github.com/Albertsun6/aisep729-demo/tree/main/docs/demo)
  —— 一个走完六道门禁造出来的小工具，从操作到工程决策全讲一遍
- 📦 **demo 仓**：[aisep729-demo](https://github.com/Albertsun6/aisep729-demo)
  —— 六门禁产物齐备（prfaq → prd → spec/plan → tasks → review → release+runbook → deprecation）

---

## 文档去哪找

| 你想干什么 | 看这个 |
|---|---|
| **接入项目 / 了解踩过哪些坑** | [`docs/implementation-manual.md`](./docs/implementation-manual.md)（533 行，**§2 陷阱目录是精华**） |
| 查命令 / 探针拦什么 / 分支保护怎么配 | [`USAGE.md`](./USAGE.md) |
| 哪些改动需要人审 | [`docs/process/risk-tiers.md`](./docs/process/risk-tiers.md) |
| 不可妥协的原则 | [`docs/constitution.md`](./docs/constitution.md)（C1–C15） |
| 为什么这么设计 | [`docs/architecture/adr/`](./docs/architecture/adr/)（15 份 ADR） |
| 每个阶段具体怎么走 | [`docs/process/stages/`](./docs/process/stages/)（7 份） |

---

## 已知限制（**请先读这一节再决定用不用**）

把本项目当作"装上就有门禁"会得到**错误的安全感** —— 这正是它自己反复强调要避免的事。

- **仅 macOS 实测**。Linux / Windows **未验证**
- **升档触发无强制力**：规模/依赖超限只有建议力，没有 CI job 计算并阻断
- **分档可手填绕过**：评审探针只信 `review.md` 自填的档位
- **文本门禁台账不是防篡改凭证**：修过的 critical 只堵了"隐形伪造"，
  **没堵"有写权限的人公开篡改"**。真正解决要把批准移到服务端 review 事件（手册 §7.1b）
- **服务端门禁有入场费**：免费账号的**私有**仓根本配不了分支保护（GitHub 限制）
- **只有一个人跑过**：全部验证来自自建者 + AI 评审，**无真人冷启动验证**
- **"自举"的准确口径**：本仓 commit 中只有一部分经过 PR 门禁——分支保护是**建到后期才配上的**。
  诚实说法是「**配上门禁之后的改动全部走了门禁**」，不是"全程自举"。
  可自行核实：`gh pr list --state merged` 对比 `git rev-list --count main`

完整清单见 [手册 §7](./docs/implementation-manual.md)。

---

## 平台自己走过这套流程吗

走过，但**口径要说准**：

```
门禁⓪ go ｜ ① 批准 ｜ ② 批准 ｜ ③ 批准 ｜ ④ 批准 ｜ ⑤ 批准
```

产物在 [`specs/platform-pilot/`](./specs/platform-pilot/)。
`main` 分支受保护且**经行为证明**（不是只看配置——实际推一次，必须被服务端拒绝）。

自举过程中，平台的探针**多次拦住自己的作者**：门禁②探针拒收缺备选方案的 ADR、
CI 拦下第七次踩同一个 bash 陷阱、收工 hook 拦下不自包含的引用、
三通道契约探针拒绝把 LLM 的发现标成 block。

---

## 许可

**双许可**，用之前请先确认你用的是哪一部分 —— 详见 [LICENSE](./LICENSE)：

| 部分 | 许可 | 你需要做什么 |
|---|---|---|
| **代码**（`.claude/` `scripts/` `ops/` `bin/` `tests/` `.github/` `.claude-plugin/`） | **Apache-2.0** | 保留声明、**标注修改**、遵守专利条款。可闭源再分发 |
| **文档与方法论**（`docs/` `specs/` `USAGE.md`） | **CC BY-SA 4.0** | **署名** + **相同方式共享**：基于本方法论做的培训材料/衍生手册必须同样开放 |

**企业内部使用完全不受限**（有意不选"非商业"：那会挡住企业内用，
而企业内用正是本项目最重要的传播路径）。
