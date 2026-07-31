#!/usr/bin/env bash
# check-release.sh — 阶段5 制品验收探针 + 门禁③（服务端账本）双路径校验
# 用法: bash check-release.sh <specs/feature-dir> [--gate-only|--final]
# 退出码: 0=PASS / 64=上游门禁未过 / 65=文件缺失 / 66=结构或质量缺项
#
# 门禁③ 的账本在服务端（ADR-009 / ADR-013；SPEC-2 对其显式豁免制品文本块），所以这里不读文件读事实：
#   路径A 远程（权威）：gh pr view --json state,statusCheckRollup → PR=MERGED 且 checks 无红
#   路径B 本地降级：目标分支有 merge commit + 全量测试绿（gh 缺失/未登录/无远端/无 PR 时自动走，不报错）
#   两条都证不出 = fail-closed 拒绝进入本阶段（宪法 C3：只认可验证的事实）
# 可选环境变量：E2E_PR（PR 号或 URL）｜E2E_BASE（目标分支，默认 main）｜E2E_TEST_CMD（降级路径的全量测试命令）
set -u
dir="${1:-}"; mode="${2:-full}"
[ -n "${dir}" ] || { echo "FAIL(65): 用法 bash check-release.sh <specs/feature-dir> [--gate-only|--final]"; exit 65; }
feature=$(basename "${dir%/}")
release="$dir/release.md"

# ---- 门禁解析公共库(SPEC-5：单一实现) ----
_root=$(cd "$(dirname "$0")/../../../.." && pwd)
# 插件模式下 scripts/lib/ 不在分发范围内（source.path 只有 .claude）——
# 冷启动验收实测：4 个探针死在 bash 的 "No such file"，对用户毫无意义。
# 现在：抑制 bash 噪音，给出**能照做**的提示。
if [ ! -f "$_root/scripts/lib/gate.sh" ]; then
  cat >&2 <<'NOLIB'
FAIL(65): 找不到 scripts/lib/gate.sh —— 本探针需要**完整平台**才能运行。

  最可能的原因：你是通过 `claude plugin install` 装的。
  插件只分发 .claude/ 能力层，**不含** bin/e2e、scripts/lib/、平台探针与负样本套件。

  要用门禁，请改用完整安装：
    git clone https://github.com/Albertsun6/aisep729.git
    bash aisep729/bin/e2e init <你的项目>

  详见 docs/architecture/adr/ADR-015-plugin-marketplace-distribution.md
NOLIB
  exit 65
fi
. "$_root/scripts/lib/gate.sh" || { echo "FAIL(65): scripts/lib/gate.sh 存在但加载失败" >&2; exit 65; }
runbook="$_root/docs/runbooks/${feature}.md"

# 制品判定公共库（reviewer finding #3：原 sec_lines 两份拷贝且判定过宽）
. "$_root/scripts/lib/artifact.sh" || { echo "FAIL(65): 无法加载 scripts/lib/artifact.sh"; exit 65; }
sec_lines() { art_sec_lines "$1" "$2"; }

# ---- 门禁③ 路径A：远程服务端事件 ----
# reviewer finding #2 修复：rollup 为空**不得判绿**——区分"查询失败"（落降级）与"零 checks"（拒绝）
# E2E_PR 白名单校验 —— 曾有一个 critical 参数注入：
#   `gh pr view ${E2E_PR:-}` **未加引号**，bash 词分割使
#   `E2E_PR="--repo cli/cli 6000"` 展开成 `gh pr view --repo cli/cli 6000 --json state`，
#   gh 接受注入的 `--repo` 去查了**另一个仓**。填一个任意公开仓里 MERGED+全绿的 PR 号，
#   门禁③ 就用**别人仓的证据**开门。（实测：bash 下分成 3 个参数）
#   这与 ops/check-branch-protection.sh 已修过的"读 A 仓却操作 B 仓"是同一类。
# 现在：只接受纯数字 PR 号或本仓 PR URL；且显式 --repo 钉死当前仓。
_e2e_pr_arg() {
  local v="${E2E_PR:-}"
  [ -n "$v" ] || return 0                       # 未指定 → 让 gh 用当前分支的 PR
  case "$v" in
    ''|*[!0-9]*)
      # 允许完整 URL 形式，但必须是**本仓**的
      local own; own=$(gh repo view --json nameWithOwner --jq '.nameWithOwner' 2>/dev/null || true)
      case "$v" in
        "https://github.com/${own}/pull/"[0-9]*) printf '%s' "$v"; return 0 ;;
      esac
      echo "FAIL(64): E2E_PR 非法（只接受纯数字 PR 号或本仓 PR URL）：${v}" >&2
      exit 64 ;;
    *) printf '%s' "$v" ;;
  esac
}

gate3_remote() {
  command -v gh >/dev/null 2>&1 || return 1
  local st rollup rc pr repo
  pr=$(_e2e_pr_arg)
  repo=$(gh repo view --json nameWithOwner --jq '.nameWithOwner' 2>/dev/null || true)
  [ -n "$repo" ] || return 1
  st=$(gh pr view ${pr:+"$pr"} --repo "$repo" --json state --jq '.state' 2>/dev/null) || return 1
  [ -n "${st}" ] || return 1
  [ "$st" = "MERGED" ] || { echo "FAIL(64): 门禁③ 未过——PR 状态=${st}（需 MERGED）"; exit 64; }

  rollup=$(gh pr view ${pr:+"$pr"} --repo "$repo" --json statusCheckRollup \
    --jq '[.statusCheckRollup[]?|(.conclusion // .state // "")]|join(",")' 2>/dev/null); rc=$?
  # 查询本身失败 → 事实取不到，回落降级路径（不是判绿）
  [ $rc -eq 0 ] || return 1
  # 零 checks → 无服务端证据，fail-closed 拒绝（宪法 C3：只认可验证的事实）
  [ -n "${rollup}" ] || { echo "FAIL(64): 门禁③ 未过——PR 已合并但**零 required checks**，无服务端证据（fail-closed）"; exit 64; }
  case "$rollup" in
    *FAILURE*|*ERROR*|*TIMED_OUT*|*CANCELLED*|*PENDING*|*STARTUP_FAILURE*|*ACTION_REQUIRED*)
      echo "FAIL(64): 门禁③ 未过——required checks 未全绿（${rollup}）"; exit 64 ;;
  esac
  # SPEC-19：required checks 命名钉死；缺 quality-gates 即证据不完整
  case "$rollup" in
    *SUCCESS*) : ;;
    *) echo "FAIL(64): 门禁③ 未过——checks 无 SUCCESS 记录（${rollup}）"; exit 64 ;;
  esac
  echo "GATE3-IN: 远程路径 ✓（PR=MERGED｜checks=${rollup}）"
}

# ---- 门禁③ 路径B：本地降级（merge commit + 全量测试绿）----
# reviewer finding #5 修复：去掉隐式回落 run.sh（会造成 run.sh→check-release→run.sh 无界再入，
#   且"探针的测试"不是"被发布变更的测试"）；finding #6 修复：base 解析失败即拒，不静默换标
gate3_local() {
  local base mc tcmd
  git -C "$_root" rev-parse --git-dir >/dev/null 2>&1 \
    || { echo "FAIL(64): 门禁③ 无从验证——gh 不可用且非 git 仓库（fail-closed，不放行）"; exit 64; }
  base="${E2E_BASE:-main}"
  git -C "$_root" rev-parse --verify "$base" >/dev/null 2>&1 \
    || { echo "FAIL(64): 门禁③ 未过——目标分支 ${base} 不存在（设 E2E_BASE；不静默换标的）"; exit 64; }
  mc=$(git -C "$_root" log --merges -n 1 --format=%h "$base" 2>/dev/null || true)
  [ -n "${mc}" ] || { echo "FAIL(64): 门禁③ 未过——${base} 上无 merge commit（降级路径要求合并留痕）"; exit 64; }
  tcmd="${E2E_TEST_CMD:-}"
  [ -n "${tcmd}" ] || { echo "FAIL(64): 门禁③ 未过——未设 E2E_TEST_CMD（须显式给出本变更的全量测试命令；证不出即不放行）"; exit 64; }
  ( cd "$_root" && eval "$tcmd" ) >/dev/null 2>&1 \
    || { echo "FAIL(64): 门禁③ 未过——全量测试未绿（${tcmd}）"; exit 64; }
  echo "GATE3-IN: 本地降级路径 ✓（base=${base}｜merge=${mc}｜测试绿：${tcmd}）"
}

gate3_remote || gate3_local
[ "$mode" = "--gate-only" ] && exit 0

# ---- 制品存在性（SPEC-22 两件产物）----
[ -f "$release" ] || { echo "FAIL(65): 缺 ${release}（PRR 核对记录）"; exit 65; }
[ -f "$runbook" ] || { echo "FAIL(65): 缺 docs/runbooks/${feature}.md（SPEC-22 runbook）"; exit 65; }
missing=0

# ---- release.md 结构 ----
for h in "## 门禁③ 入口证据" "## PRR 核对表" "## 发布策略" "## 回滚预案" "## SLO 与监控" "## 观察窗" "门禁④ 记录"; do
  grep -qF "$h" "$release" || { echo "MISSING: ${h}"; missing=$((missing+1)); }
done

# ---- PRR 核对项：逐项勾选 + 人类核对人（SPEC-22 · 宪法 C14）----
total=$(grep -cE "^- \[[ x]\] PRR-[0-9]+" "$release" || true)
[ "$total" -ge 1 ] || { echo "MISSING: 无 PRR 核对项（PRR-N）"; missing=$((missing+1)); }
noowner=$(grep -E "^- \[[ x]\] PRR-[0-9]+" "$release" | grep -cv "核对人：" || true)
[ "$noowner" -eq 0 ] || { echo "MISSING: ${noowner} 项 PRR 缺'核对人：'（逐项勾选+核对人）"; missing=$((missing+1)); }
noev=$(grep -E "^- \[[ x]\] PRR-[0-9]+" "$release" | grep -cv "证据：" || true)
[ "$noev" -eq 0 ] || { echo "MISSING: ${noev} 项 PRR 缺'证据：'（宪法 C2 不接受'我觉得就绪了'）"; missing=$((missing+1)); }
# 非人类署名启发式（finding #7：关键词表不可能穷尽，故 WARN 不 block；真判定靠人审/服务端 actor）
while IFS= read -r line; do
  [ -n "$line" ] || continue
  owner=$(printf '%s' "$line" | sed -E 's/.*核对人：[[:space:]]*//; s/[[:space:]｜|].*$//')
  art_looks_nonhuman "$owner" && echo "WARN: PRR 核对人疑似非人类署名（\"${owner}\"）——宪法 C14 要求人类归因，请人审确认"
done < <(grep -E "^- \[[ x]\] PRR-[0-9]+" "$release" | grep "核对人：" || true)

# ---- 回滚预案：非空 + 有可执行命令 ----
rb=$(sec_lines "$release" "## 回滚预案")
[ "$rb" -ge 2 ] || { echo "MISSING: 回滚预案为空或仅占位符"; missing=$((missing+1)); }
sed -n '/^## 回滚预案/,/^## /p' "$release" | grep -q '`' \
  || { echo "MISSING: 回滚预案无可执行回滚命令（宪法 C2）"; missing=$((missing+1)); }

# ---- runbook 三节非空（SPEC-22 硬契约）----
for s in "## 启动" "## 回滚" "## 故障"; do
  if grep -qF "$s" "$runbook"; then
    n=$(sec_lines "$runbook" "$s")
    [ "$n" -ge 2 ] || { echo "MISSING: runbook ${s} 节为空或仅占位符"; missing=$((missing+1)); }
  else
    echo "MISSING: runbook 缺 ${s} 节"; missing=$((missing+1))
  fi
done

# ---- --final 终检（门禁④ 前）----
if [ "$mode" = "--final" ]; then
  open_prr=$(grep -cE "^- \[ \] PRR-[0-9]+" "$release" || true)
  [ "$open_prr" -eq 0 ] || { echo "MISSING(final): ${open_prr} 项 PRR 未勾选——不得过门禁④"; missing=$((missing+1)); }
  # 占位符扫描（finding #3 修复：反向设计——code span 外任何 <...> 都算未决，仅门禁块 <待填> 豁免）
  art_has_placeholder "$release" \
    && { echo "MISSING(final): release.md 存在未决占位符（证据/核对人/日期没填完）"; missing=$((missing+1)); }
  # finding #3 修复：runbook 也纳入终检扫描（此前从不扫，空壳 runbook 可过）
  art_has_placeholder "$runbook" \
    && { echo "MISSING(final): runbook 存在未决占位符（模板骨架未填实）"; missing=$((missing+1)); }
  # finding #1 修复：容忍加粗与空格（模板写法为 `- **回滚演练证据**：…`，旧正则永不匹配→按文档填也过不了）
  grep -qE "回滚演练证据[*_[:space:]]*：[[:space:]]*[^<[:space:]]" "$release" \
    || { echo "MISSING(final): 无回滚演练证据（未演练过的回滚预案=纸面预案）"; missing=$((missing+1)); }
  sed -n '/^## SLO 与监控/,/^## /p' "$release" | grep -qE "[0-9]" \
    || { echo "MISSING(final): SLO 表无量化目标"; missing=$((missing+1)); }
fi

# ---- 门禁④ 记录块的批准人也要校验（finding #9：此前只解析"决定："，批准人从不检查）----
gate4_owner=$(grep -E '^- 批准人：' "$release" | head -1 | sed -E 's/^- 批准人：[[:space:]]*//')
if [ -n "$gate4_owner" ] && [ "$gate4_owner" != "<待填>" ]; then
  art_looks_nonhuman "$gate4_owner" \
    && { echo "MISSING: 门禁④ 批准人非人类署名（\"${gate4_owner}\"）——宪法 C14 执行者不得自批"; missing=$((missing+1)); }
fi

# 门禁台账 fail-open 修复：校验本文件自己的决定值合法（gate.sh 单一实现）
gate_assert_legal "$release" 批准 打回 || missing=$((missing+1))
gate4=$(gate_status "$release")
[ "$missing" -gt 0 ] && { echo "FAIL(66): 缺 ${missing} 项"; exit 66; }
echo "PASS: release 结构完整 | PRR ${total} 项 | runbook 三节非空 | 门禁④=${gate4}"
exit 0
