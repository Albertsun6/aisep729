# ADR-014：服务端门禁的真实边界（分支保护三层默认值陷阱）

- 状态：accepted
- 日期：2026-07-31
- 关联：C3（安全边界只认服务端强制）· C13（探针必须可证伪）· C14（批准可归因，执行者不得自批）· ADR-009（门禁权威分级）
- 来源：S6 spike 实测（demo 仓 `Albertsun6/aisep729-demo`），**三条断言中第一条被证伪**

## 背景与驱动力

宪法 C3 规定"安全边界只认服务端强制"，ADR-009 规定企业模式下门禁以服务端事件为准。落到 GitHub 就是**分支保护 + required status checks**。

S6 spike 要回答：这个前提在真实环境里成立吗？成立的**入场条件**是什么？

结论：**它有三层默认值会让"配了 = 没配"**，且其中两层不报错、静默失效。这是本平台交付给客户时最容易踩的坑，必须写死在手册与探针里。

## 实测记录（可证伪断言 → 判定）

| # | 断言 | 判定 | 证据 |
|---|---|---|---|
| S6-a | 免费账号的**私有**仓可配分支保护 | ❌ **REFUTED** | `403 Upgrade to GitHub Pro or make this repository public` |
| S6-b | 配置 PUT 成功且回读一致 ⇒ 直推 main 会被拒 | ❌ **REFUTED** | 回读四项 required checks 全在、GitHub 还打印 `4 of 4 required status checks are expected`，**但 push 成功**（`6ac4119..b8e6328`）——因 `enforce_admins` 默认 `false` |
| S6-c | 打开 `enforce_admins` 后直推 main 被拒 | ✅ **CONFIRMED** | `! [remote rejected] s6-probe -> main (protected branch hook declined)` |
| S6-d | 单人仓设 `approvals=0` 后 PR 可合并（**本 ADR 初稿自己开的方子**） | ❌ **REFUTED** | 四检查全 SUCCESS、approvals=0，PR 仍 `mergeStateStatus: BLOCKED`。A/B 对照：`require_last_push_approval=false` → `CLEAN`；改回 `true` → `BLOCKED` |

## 三层陷阱

### 陷阱①：免费账号 + 私有仓 = 完全没有分支保护

GitHub Free 的分支保护只对**公开仓**开放。私有仓要分支保护须 Pro/Team/Enterprise。

对咨询产品的含义：**"服务端硬门禁"不是免费的**，它是有**入场费**的。三级实施包必须把"GitHub 计划"列为入场条件，而不是假设客户都有。

### 陷阱②：`enforce_admins` 默认 false —— 最危险的一条

配置写进去了、API 回读全对、push 时 GitHub 甚至会打印 required checks 清单——**然后照样让你推上去**。这是**静默失效**：所有"看起来像验证"的信号都是绿的。

小团队/单人仓里**每个人都是 admin**，所以默认配置下分支保护对**实际会推代码的所有人**都不生效。

> 这与 `check-shell-traps.sh` 当初 `grep -P` 静默永远 PASS 是**同一类失败**：验证信号存在但不承载真相。故本 ADR 的处置也相同——**不看配置，看行为**。

### 陷阱③：`required_approving_review_count ≥ 1` 在单人仓 = 永久阻塞

GitHub 不允许 PR 作者批准自己的 PR。单人仓开了"需 1 人批准"，PR **永远无法合并**（除非 admin bypass，而 bypass 又被陷阱②的修复关掉了）。

这不是 bug，是 C14（执行者不得自批）在单人场景下的**必然后果**。见「决定」中的分级处置。

### 陷阱④：`require_last_push_approval` 会独立造成死锁，**即使 approvals=0**

本 ADR 初稿写"`require_last_push_approval` 与 `dismiss_stale_reviews` 两项在所有场景下都开"。
**这条是错的，且被自己的 demo PR 当场证伪**：

PR #1 四项检查全 `SUCCESS`、`required_approving_review_count=0`、`mergeable: MERGEABLE`，
但 `mergeStateStatus` 恒为 `BLOCKED`。A/B 对照锁定单一变量：

```
require_last_push_approval=false → CLEAN
require_last_push_approval=true  → BLOCKED
```

原因：该开关的语义是"最后一次 push 必须由**非推送者**批准"。它**不看** `approvals` 的数值——
即便要求 0 个批准，它仍独立要求一个来自他人的批准事件。单人仓里这个人不存在 → 永久死锁。

**教训**：`approvals=0` 直觉上意味着"不需要人审"，但 GitHub 的批准语义由**两个独立开关**共同决定。
只调其一会得到一个"看起来配好了、实际永远合不了"的仓——又一次"配置合理但行为不符"。

## 决定

**1. 服务端门禁的验收标准改为「行为证明」，不接受「配置回读」。**

新增 `ops/check-branch-protection.sh`：不解析配置 JSON 作为通过依据，而是**实际尝试直推受保护分支**，要求得到 `protected branch hook declined`；推成功即 exit 非零。配置回读只作为诊断信息打印。

**2. `enforce_admins: true` 是本平台的强制项，写进 `e2e init` 与手册。**

任何声称"启用了服务端门禁"的仓，必须 `enforce_admins = true`。否则按 ADR-009 只能算**试点模式**（文本台账留痕），不得声称企业模式。

**3. 批准数按仓库人数分级（C14 的可执行形态）：**

| 场景 | `approvals` | `require_last_push_approval` | `dismiss_stale_reviews` | C14 如何满足 |
|---|---|---|---|---|
| 单人仓（试点/demo） | `0` | **`false`**（开了必死锁，陷阱④实测） | `true` | 由 **CI 四检查 + 异构评审留痕** 承担把关；PR 记录必须写明"单人仓，批准由确定性检查代行"，**不得声称有人审** |
| ≥2 人团队 | `1` | `true` | `true` | 真人批准，且批准者 ≠ 最后推送者 |
| 高风险路径（见 CODEOWNERS） | `≥1` 且 `require_code_owner_reviews: true` | `true` | `true` | 指定 owner 必须在场 |

`dismiss_stale_reviews: true` 在所有场景下都开（堵"旧批准盖新代码"）。
`require_last_push_approval` **只在 ≥2 人时开**——它堵的是"批准后偷改"，但在单人仓会独立造成永久死锁（陷阱④）。

**验收方式**：不看配置，跑 `bash ops/check-branch-protection.sh` 拿行为证明；
合并性另看 `gh pr view <n> --json mergeStateStatus`——必须是 `CLEAN` 而非 `BLOCKED`，
否则这个仓的门禁虽然"配好了"，实际是一条谁也过不去的死路。

**4. 免费账号私有仓：fail-closed 降级，不许假装。**

`e2e doctor` 检测到"私有仓 + 分支保护 403"时，明确输出：

```
⚠️ 服务端门禁不可用（免费账号私有仓）。当前仓按【试点模式】运行：
   门禁记录为过程留痕，不具备服务端强制力。
   要升级为企业模式，需：① 仓库改公开，或 ② GitHub Team/Enterprise 计划。
```

**绝不**在这种仓里输出"门禁已启用"。

## 后果

- ✅ "服务端强制"从一句口号变成一条**跑得出 REFUTED 的探针**
- ✅ 三级实施包获得了明确的**入场条件**（GitHub 计划 / 团队人数），咨询报价可据此分层
- ⚠️ 单人仓的批准数只能是 0，C14 的"人审"在此场景**名义上不成立**——手册必须诚实写明，不得用"有门禁"含混过去
- ⚠️ 本次 spike 在 demo 仓 main 上留下一个空 commit（`b8e6328`，S6 探针）。force-push 清理被本机 git guardrail 拦下（策略正确），故**保留为证据留痕**，不视为污染
- 可复议条件：GitHub 若改变 `enforce_admins` 默认值或放开 Free 私有仓分支保护 → 重跑三条断言
