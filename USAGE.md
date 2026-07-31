# AISEP729 使用说明（面向使用者的手册）

> 最近更新：2026-07-31
> 本文件回答「是什么 / 怎么用 / 怎么撤 / 配置在哪」。
> 面向**我（人）**；面向 agent 的指令在 `CLAUDE.md` 与 `AGENTS.md`，两者分工不同。

## 配置速查

| 能力 | 入口命令 | 配置在哪 | 怎么撤 |
|---|---|---|---|
| 脚手架接入（绿地） | `bash bin/e2e init <目录>` | `bin/e2e` 的 `copy_*` / `tpl_*` | 删掉生成的文件；幂等，不覆盖既有文件 |
| 存量项目体检（只读） | `bash bin/e2e assess <仓>` | 同上 | 产物在仓**外**，直接删目录 |
| 存量项目接入（非破坏） | `bash bin/e2e adopt <仓>` | 同上 | 既有文件一律保留，删新增文件即可 |
| 前置工具检查 | `bash bin/e2e doctor` | 同上 | — |
| 七阶段 skill | `/e2e-discovery` … `/e2e-retire` | `.claude/skills/e2e-*/` | 删对应目录 |
| 质量棘轮 | `bash scripts/ratchet.sh` | `quality-baseline.txt` | 删基线文件 |
| 服务端门禁行为证明 | `bash ops/check-branch-protection.sh` | GitHub 分支保护 API | 见下 §分支保护 |

## 交付物在哪（M4 产出）

| 产物 | 位置 | 验收方式 |
|---|---|---|
| **实施手册**（围绕陷阱目录组织） | `docs/implementation-manual.md` | `bash scripts/check-manual.sh` |
| **演示视频** 9 分 04 秒中文旁白 | demo 仓 `docs/demo/win-loss-log-demo.mp4` | `bash scripts/check-demo-video.sh <mp4>` |
| **插件市场入口** | `.claude-plugin/marketplace.json` | `claude plugin marketplace add Albertsun6/aisep729` |
| **许可** | `LICENSE`（说明）+ `LICENSE-CODE`（Apache-2.0）+ `LICENSE-DOCS`（CC BY-SA 4.0） | 见 `LICENSE` 的适用范围表 |
| **平台自己的六门禁台账** | `specs/platform-pilot/{prfaq,prd,spec,plan,tasks,review,release,deprecation}.md` | 七道阶段探针 `--final` 全 PASS |

## 许可（用之前先看清用的是哪一部分）

**双许可**，详见 [`LICENSE`](./LICENSE)：

- **代码**（`.claude/` `scripts/` `ops/` `bin/` `tests/` `.github/` `.claude-plugin/`）→ **Apache-2.0**
- **文档与方法论**（`docs/` `specs/` `USAGE.md` 及调研报告）→ **CC BY-SA 4.0**（署名 + 相同方式共享）

企业内部使用**完全不受限**。基于本方法论做的培训材料/衍生手册**必须同样以 BY-SA 发布**。

> GitHub 会把本仓的许可显示为 `Other` —— 双许可仓的正常结果（它的检测器只认单一标准文件）。
> 把 `LICENSE-CODE` 改名成 `LICENSE` 能让它显示 "Apache-2.0"，但那对文档部分是**误导**，故不做。

## 探针清单（跑什么、拦什么）

全部探针都遵守同一条纪律：**失败必须响亮**。任何"跳过 / 找不到就算过"都视为缺陷。

| 探针 | 拦什么 | 退出码 |
|---|---|---|
| `scripts/check-structure.sh` | 六件套齐备、manifest 驱动（宪法 C4） | 0/66 |
| `scripts/check-selfcontained.sh` | 制品自包含（C9 / SPEC-17） | 0/66 |
| `scripts/check-shell-traps.sh` | macOS bash 三类高危写法（见下） | 0/66 |
| `scripts/check-skill-deps.sh` | skill 引用的文件必须真实存在 | 0/1/66 |
| `scripts/check-clause-refs.sh` | 被引用的宪法条款必须有定义 | 0/1/66 |
| `ops/check-branch-protection.sh` | 服务端门禁真的拦得住（**会写远端**） | 0/1/2/66 |
| `scripts/check-action-pins.sh` | 第三方 Action 必须 SHA-pin（C15） | 0/1/66 |
| `scripts/check-manual.sh` | 实施手册结构 + **夸大表述自查**（SPEC-24） | 0/65/66 |
| `scripts/check-demo-video.sh` | 演示视频交付判据（SPEC-25），**实测音量判静音** | 0/1/66 |
| `tests/probe-negative/run.sh` | 上述探针**自身能否被证伪**（**81 条**负样本，口径见 README） | 0/1 |
| `.claude/skills/*/scripts/check-*.sh` | 各阶段制品结构 + 上游门禁串锁 | 0/64/65/66 |

### `check-shell-traps.sh` 拦的三类写法

1. `$var` 紧跟中文标点 → bash 把标点并入变量名，`set -u` 下崩。改 `${var}`
2. `sed -i` 不带 `''` → BSD/GNU 分歧（WARN）
3. macOS 不存在的 GNU 命令：`timeout` / `realpath` / `sha256sum` / `md5sum` / `readlink -f`

**豁免写法**：行尾加 `# shell-traps:ok <理由>`。豁免必须写在代码里、看得见、可审计。

### `check-skill-deps.sh` 的能力边界（别高估它）

它只查**显式路径引用**的存在性。抓不到：markdown 链接、花括号展开、变量拼接、
传递依赖、外部工具/Action/MCP 依赖、文件存在但内容是旧模板。
对外**不得**说"这一类问题已解决"，只能说"显式路径引用已守住"。

**豁免写法**：行尾加 `<!-- skill-deps:platform-only -->`，用于平台仓 provenance
（设计出处文档，不随脚手架分发）。

## 分支保护（服务端门禁）

### 一次性配置

```bash
gh api -X PUT repos/<owner>/<repo>/branches/main/protection --input - <<'JSON'
{ "required_status_checks": {"strict": true, "contexts": ["<你的 job 名>"]},
  "enforce_admins": true,
  "required_pull_request_reviews": {
    "required_approving_review_count": 0,
    "require_last_push_approval": false,
    "dismiss_stale_reviews": true },
  "restrictions": null, "allow_force_pushes": false, "allow_deletions": false }
JSON
```

**三个必须知道的坑**（全部实测，详见 `docs/architecture/adr/ADR-014-*.md`）：

1. **免费账号的私有仓根本配不了分支保护**（403）。要么仓公开，要么升 Team/Enterprise
2. **`enforce_admins` 默认 `false`** —— 配置回读全绿、GitHub 打印 "4 of 4 required
   status checks are expected"，**直推 main 仍然成功**。小团队里人人都是 admin，
   所以默认配置 = 对所有实际推代码的人都不生效
3. **单人仓必须 `require_last_push_approval: false`** —— 它不看 `approvals` 数值，
   独立要求"非推送者批准"。单人仓里这个人不存在 → PR 永久 `BLOCKED`

### 验收（两条都要过）

```bash
bash ops/check-branch-protection.sh            # 配置不变量 ∩ 行为证明
gh pr view <n> --json mergeStateStatus         # 必须 CLEAN，不能 BLOCKED
```

只回读配置**不算数**——这是 ADR-014 的核心结论。

### 怎么撤

```bash
gh api -X DELETE repos/<owner>/<repo>/branches/main/protection
```

## 目录约定

| 目录 | 放什么 | 为什么单独分出来 |
|---|---|---|
| `scripts/` | **本地只读**检查器 | 在 `.claude/settings.json` 的 `Bash(bash scripts/*)` 通配放行区内 |
| `ops/` | **会改远端状态**的脚本 | **故意不在**放行区——agent 调用它需逐次确认（能改远端的东西不该躺在通配放行区） |
| `.claude/skills/*/scripts/` | 各阶段制品探针 | 随 skill 分发 |
| `tests/probe-negative/` | 探针的负样本 | 宪法 C13：探针自身必须能证伪 |

## 风险分档（谁需要人审）

判据一句话：**凡「定义门禁」或「被 required check 执行」的东西 = 高档。**
判断方法：把这个文件改成"永远通过"，某道检查会不会因此失效？会 → 高档。

完整 glob 与当前生效状态见 `docs/process/risk-tiers.md`。

⚠️ **当前试点仓的高档人审是关闭的**（单人仓开了必死锁），
把关由 CI 检查 + 跨模型异构评审留痕承担。**不得**因为存在 `CODEOWNERS` 文件
就宣称"有人审"。

## 已知未完成（不得对外声称已解决）

> 本节**必须与实施手册 §7 对账**。过期的"已知限制"比没有更危险——
> 它会让人以为某个问题还在、或已经解决了，两个方向都会误导。

**仍未解决**：

- **分档可手填绕过** —— `check-review.sh` 只信 `review.md` 自填的档位，手填成低档探针发现不了
- **升档触发无强制力** —— 规模/依赖超限只有建议力，没有 CI job 计算并阻断
- **文本门禁台账不是防篡改凭证** —— 本轮修的 critical 只堵了"隐形伪造"，
  **没堵"有写权限的人公开篡改"**。真正解决要把批准移到服务端 review 事件（手册 §7.1b）
- ~~`ai-review.yml.template` 的 LLM 阻断权~~ —— **已修 @2026-07-31**：LLM 侧永不影响 CI 成败，
  只发 PR 评论；`check-ai-review-contract.sh` + 4 条负样本钉死。
  **顺带更正**：当时说"攻击者可控输入"那一半不成立——`pull_request` 下 fork PR 拿不到 secrets，
  LLM 根本跑不起来。真陷阱是"job 恒红 → 有人改成 `pull_request_target`"（经典 pwn request）
- **只有一个人跑过** —— 全部验证来自自建者 + AI 评审，**无真人冷启动验证**。
  正式交付前应找人照手册从零跑一遍
- **`Bash(bash bin/e2e*)` 是任意目录写入原语** —— `init`/`adopt` 可往任意目录写文件且自动放行
- **仅 macOS 实测** —— Linux / Windows 未验证

**已闭环（记录在此以免重复排查）**：

| 曾经的限制 | 闭环方式 | 日期 |
|---|---|---|
| ~~Safari 未验证~~ | osascript 实测 C1-C11 全过；**证伪了 ADR-003 原判断**（Safari 同样允许且同样共享 origin） | 2026-07-31 |
| ~~第三方 Action 未 SHA-pin~~ | 三处全钉 + 新建 `check-action-pins.sh`（C15 声明的探针此前根本不存在） | 2026-07-31 |
| ~~两仓无 LICENSE~~ | demo=MIT；平台=双许可（代码 Apache-2.0 / 文档 CC BY-SA 4.0） | 2026-07-31 |
| ~~未做完整历史 secret scan~~ | `gitleaks` 两仓全历史 + 自建全 blob 扫描，均 0 命中 | 2026-07-31 |
