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
| `tests/probe-negative/run.sh` | 上述探针**自身能否被证伪**（45 条负样本） | 0/1 |
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

- **Safari 未验证** —— `file://` 下的 localStorage 行为（ADR-003）
- **分档强制** —— `check-review.sh` 只信 `review.md` 自填的档位，手填成低档探针发现不了
- **升档触发无强制力** —— 规模/依赖超限只有建议力，没有 CI job 计算并阻断
- **第三方 Action 未 SHA-pin** —— 供应链条款（C15）尚无探针
- **demo 公开仓无 LICENSE、未做完整历史 secret scan**
