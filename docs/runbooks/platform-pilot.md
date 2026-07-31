# Runbook：platform-pilot（E2E 研发平台）

> 阶段5 产物 · SPEC-22 三节非空硬契约 · 2026-07-31
> 形态：**方法论 + 工具包**，交付物是一个 git 仓 + 一份手册 + 一个插件市场入口。
> 没有服务进程、没有部署管线，因此"启动/回滚/故障"的含义与服务端系统不同，每节开头写明。

**先记住四个入口**（下面所有命令都基于它们）：

| 入口 | 是什么 | 怎么自己确认 |
|---|---|---|
| `bash bin/e2e doctor` | 前置分层自检 | 退出 0 = 基础层齐备 |
| `bash bin/e2e init /path/to/your-project` | 绿地脚手架 | 生成 23+ 文件 |
| `bash tests/probe-negative/run.sh` | 探针自身可证伪（71 条） | 全绿才算平台健康 |
| `bash ops/check-branch-protection.sh` | 服务端门禁行为证明 | CONFIRMED 才算企业模式 |

---

## 启动

「启动」= 让一个新项目（或新客户）用上这套流程。**没有服务进程要拉起。**

### 方式一：完整平台（要门禁就走这条）

```bash
git clone https://github.com/Albertsun6/aisep729.git
cd aisep729
bash bin/e2e doctor                      # 前置自检
bash bin/e2e init /path/to/your-project  # 幂等，既有文件一律不覆盖
```

### 方式二：只要能力层（**没有门禁**）

```bash
claude plugin marketplace add Albertsun6/aisep729
claude plugin install aisep@aisep
```

> ⚠️ 只装插件**拿不到探针**（`bin/e2e`、`scripts/check-*.sh`、`tests/probe-negative/` 都不在内）。
> skill 会照常引导流程，但每步的"验证"环节无法执行。详见 ADR-015。

### 健康检查判据（四条，全绿才算启动成功）

```bash
# ① 前置齐备（退出 0；可选项缺失会明说降级，不算失败）
bash bin/e2e doctor

# ② 平台自身的探针链全绿
bash scripts/check-structure.sh && bash scripts/check-selfcontained.sh && \
bash scripts/check-shell-traps.sh && bash scripts/check-skill-deps.sh && \
bash scripts/check-clause-refs.sh && bash scripts/check-action-pins.sh

# ③ 探针自身可证伪（这条最重要 —— 探针没被证伪过就不可信）
bash tests/probe-negative/run.sh          # 期望：71/71 符合预期

# ④ 服务端门禁行为证明（企业模式才有；试点模式会 exit 2 并明说降级）
bash ops/check-branch-protection.sh       # 期望：CONFIRMED
```

### 新项目接入后的验收

```bash
cd /path/to/your-project
bash scripts/check-skill-deps.sh && bash scripts/check-clause-refs.sh && \
bash tests/probe-negative/run.sh
```
三条全绿才算接入成功。任一条红，看它输出的 `MISSING:` 行——它会指出缺什么、为什么。

---

## 回滚

### 「回滚」在这里是什么意思

平台的交付物有三种形态，**回滚方式各不相同，且有一种回滚不了**：

| 形态 | 能不能回滚 | 怎么回滚 |
|---|---|---|
| **git 仓**（clone 方式接入的人） | ✅ 能 | 见下方命令 |
| **插件缓存**（marketplace 装的人） | ⚠️ 部分 | 改 `marketplace.json` 的 `sha` 后，他们下次 `update` 才生效 |
| **已经 `e2e init` 进客户项目的文件** | ❌ **完全回滚不了** | 那些文件是**客户仓的一部分**了，我们无权也无法触碰 |

### 仓库侧回滚（可执行）

```bash
# 1. 从 main 切回滚分支（main 受保护，不能直推——已行为证明）
git switch -c revert-sha-pin origin/main   # 分支名换成你这次回滚的东西

# 2. 回退目标 commit（squash 合并的 PR 是单亲，不带 -m）
git log --oneline -10          # 找到要回退的 commit
git revert --no-edit 8ab7968   # 换成上一步找到的 sha

# 3. 本地先过门禁，别浪费一轮 CI
bash scripts/check-structure.sh && bash scripts/check-shell-traps.sh && \
bash scripts/check-skill-deps.sh && bash scripts/check-clause-refs.sh && \
bash scripts/check-action-pins.sh && bash tests/probe-negative/run.sh

# 4. 开 PR（required check 必须绿）
git push -u origin revert-sha-pin
gh pr create --fill
gh pr checks --watch
gh pr view --json mergeStateStatus --jq '.mergeStateStatus'   # 必须 CLEAN
gh pr merge --squash --delete-branch
```

### 回滚后的校验

```bash
git switch main && git pull
bash tests/probe-negative/run.sh                 # 探针链仍可证伪
bash ops/check-branch-protection.sh              # 门禁仍生效
T=$(mktemp -d) && bash bin/e2e init "$T" >/dev/null && \
  (cd "$T" && bash scripts/check-skill-deps.sh) && rm -rf "$T"   # 脚手架仍可用
```

### 不可逆点（四个，都实测或推理确证）

1. **已 `e2e init` 进客户项目的文件回滚不了。** 那些文件已属客户仓，
   我方无权触碰。这是本平台最硬的不可逆点。
2. **已 clone 的副本不受影响。** 与 demo 产品同理，仓库侧任何操作改不了别人手上的 clone。
3. **公开仓历史不可撤回。** 仓已 PUBLIC，历史 commit 可能已被 clone / fork / 缓存 / 索引。
   包括**方法论全文与两份调研报告**——这是把仓改公开时接受的代价。
4. **插件卸载不清可执行缓存。** 实测：`claude plugin uninstall` 后注册表已清空，
   但 `~/.claude/plugins/cache/` 下对应的插件版本目录 下 **9 个 .sh 仍在盘上**
   （带 `.orphaned_at` 标记）。需手动 `rm -rf` 该目录。

### 预期 RTO（条件性数字，不是保证上界）

| 环节 | 实测 |
|---|---|
| 本地六道探针 | ~5 秒 |
| CI `probes` job | ~40–60 秒 |
| 人工改码 + 开 PR + 合并 | 数分钟 |

→ **仓库侧 RTO ≈ 3–8 分钟**。**客户侧 RTO 不可控**——取决于他们何时 pull 或重新 init。

### 触发回滚的判据（诚实版）

平台**没有运行时遥测**（它不是服务）。真实触发源只有三个：

1. CI `probes` job 红（这是唯一的自动信号）
2. 用户报告接入失败
3. 自己跑 §启动 的四条健康检查发现异常

**不得**声称本平台有运行时监控或告警。

---

## 故障处理

格式：**症状 → 首诊命令 → 处置 → 升级路径**

### 1. `e2e init` 后新项目的探针跑不起来

- **首诊**：
  ```bash
  cd /path/to/new-project
  ls -la bin/e2e scripts/check-*.sh tests/probe-negative/run.sh 2>&1 | head
  bash scripts/check-skill-deps.sh
  ```
- **处置**：`check-skill-deps.sh` 会明确指出 skill 引用了哪个不存在的文件。
  根因通常是**脚手架拷贝清单漏了它**（历史上发生过三次：`risk-tiers.md`、`bin/e2e`、宪法只发 C1-C5）。
- **升级**：在平台仓 `bash bin/e2e init $(mktemp -d)` 复现，修 `bin/e2e` 的拷贝清单，
  **并补一条负样本**（否则会再犯）。

### 2. 门禁探针"通过"了但明显不该通过

- **首诊**：
  ```bash
  bash tests/probe-negative/run.sh          # 探针自身可证伪吗
  bash scripts/check-shell-traps.sh         # 是不是踩了静默失效的写法
  ```
- **处置**：这是本平台最危险的故障类型（**探针存在但什么都没检查**）。已知模式见手册 §2.2：
  `grep -P` 在 BSD 上静默失效、管道吞退出码、"跳过"当成通过、金丝雀用了和生产不同的正则。
- **升级**：**先写一条对当前实现会失败的负样本**，再改探针。
  没有负样本的探针修复不算修复（本轮 F-5 就是这么被抓到的）。

### 3. 门禁记录写了却不生效 / 或没写却生效

- **首诊**：
  ```bash
  grep -n '^- 决定：' specs/*/[a-z]*.md          # 全文有几条？
  tail -6 specs/platform-pilot/release.md                  # 尾部块长什么样
  ```
- **处置**：
  - 全文 **>1 条** `- 决定：` → 探针判 `UNKNOWN`（歧义即拒绝）。删掉正文里的多余行。
  - 决定行**不在**门禁记录块之后 → 同样判 `UNKNOWN`。把它移进尾部块。
  - 决定值不在契约集合内（`①②③④⑤∈{批准,打回}`、`⓪∈{go,modify,kill}`）→ 判非法。
- **背景**：这两条规则是修一个 **critical** 加的——旧实现取全文首个决定行，
  **执行者能在人看不见的地方伪造批准**。详见手册 §7.1b。

### 4. 门禁③ 校验说"未过"但 PR 明明合并了

- **首诊**：
  ```bash
  gh pr view 4 --json state,statusCheckRollup --jq '{state, checks:[.statusCheckRollup[].conclusion]}'
  git log --oneline -3 origin/main
  ```
- **处置**：
  - squash 合并**不产生 merge commit**，本地降级路径会说"无 merge commit"。
    用 `E2E_PR=4`（纯数字 PR 号） 显式指定（这是文档化的用法）。
  - `E2E_PR` **只接受纯数字或本仓 PR URL**——这是修一个参数注入 critical 加的白名单，
    传别的会直接 exit 64。
- **升级**：`gh` 不可用时会自动降级为本地路径；**降级也证不出就 fail-closed 拒绝**，不是放行。

### 5. `ops/check-branch-protection.sh` 报 REFUTED

- **首诊**：
  ```bash
  gh api repos/Albertsun6/aisep729/branches/main/protection --jq '.enforce_admins.enabled'
  ```
- **处置**：几乎总是 `enforce_admins=false`（**GitHub 默认值，官方文档未声明**）。
  ```bash
  gh api -X POST repos/Albertsun6/aisep729/branches/main/protection/enforce_admins
  ```
  若报 `403 Upgrade to GitHub Pro` → 免费账号私有仓，**服务端门禁不可用**，
  只能按试点模式运行，**此状态下禁止声称"门禁已启用"**。
- **升级**：见手册 §2.1 的四层陷阱与 ADR-014。

### 6. PR 显示 `BLOCKED` 但检查全绿

- **首诊**：
  ```bash
  gh api repos/Albertsun6/aisep729/branches/main/protection --jq \
    '{approvals:.required_pull_request_reviews.required_approving_review_count,
      last_push:.required_pull_request_reviews.require_last_push_approval}'
  ```
- **处置**：单人仓必须 `require_last_push_approval: false`。
  它**不看 `approvals` 数值**，独立要求"非推送者批准"——单人仓里那个人不存在 → 永久死锁。
  ```bash
  gh api -X PATCH repos/Albertsun6/aisep729/branches/main/protection/required_pull_request_reviews \
    -F "require_last_push_approval=false"
  ```
- **升级**：≥2 人团队开 `true` 时，**须同时评估是否关掉 `strict`**（组合会互锁，见手册陷阱 D）。

### 7. CI 红在"高危写法"上

- **首诊**：`bash scripts/check-shell-traps.sh`
- **处置**：输出会直接指出行号与替代写法。最常见的是 **`$var` 紧跟中文标点**——
  本平台自建过程中这一个坑踩了**七次**，每次都被探针或 CI 当场抓住。
  改成 `${var}` 即可。确属误报（如注释、字符串字面量）用 `# shell-traps:ok 理由写这里` 显式豁免。
- **升级**：豁免必须写明理由、可审计；不得为了让 CI 过而放宽扫描规则。

### 通用升级路径

1. 全量自检：§启动 的四条健康检查
2. 仍无法定位 → 开 issue，附：`bin/e2e version`、失败探针的完整输出、`bash bin/e2e doctor` 输出
3. 需要改平台 → 走 §回滚 的 PR 流程；**改门禁探针必须双向验证**
   （真违规仍被抓 + 合规不误判），否则容易把门禁改松而不自知
4. Owner：见 `.github/CODEOWNERS`。⚠️ 单人仓下**无服务端强制力**，见 `docs/process/risk-tiers.md` §执行层
