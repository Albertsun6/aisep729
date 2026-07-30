#!/usr/bin/env bash
# check-review.sh — 阶段4 制品验收探针 + 阶段3 出口前置校验
# 用法: bash check-review.sh <specs/feature-dir> [--gate-only|--final]
# 退出码: 0=PASS / 64=上游未过 / 65=文件缺失 / 66=结构或质量缺项
#
# 设计依据：docs/research/AI时代评审门禁-调研.md v2（异构终审 Dissent 13 条修订）
# 核心检查：三通道契约不被违反、闭环状态机完整、覆盖声明非空、非终态有人类署名
set -u
dir="${1:-}"; mode="${2:-full}"
tasks="$dir/tasks.md"; review="$dir/review.md"

_root=$(cd "$(dirname "$0")/../../../.." && pwd)
. "$_root/scripts/lib/gate.sh" || { echo "FAIL(65): 无法加载 scripts/lib/gate.sh"; exit 65; }

# ---- 阶段3 出口前置：tasks 全勾选 ----
[ -f "$tasks" ] || { echo "FAIL(64): 无 tasks.md——先走 e2e-implement(阶段3)"; exit 64; }
open_tasks=$(grep -cE "^- \[ \] T-[0-9]+" "$tasks" || true)
[ "$open_tasks" -eq 0 ] || { echo "FAIL(64): 阶段3 未完成（${open_tasks} 条任务未勾选）——拒绝进入阶段4"; exit 64; }
echo "GATE3-IN: 阶段3 出口 ✓（任务全勾选）"
[ "$mode" = "--gate-only" ] && exit 0

[ -f "$review" ] || { echo "FAIL(65): 缺 review.md"; exit 65; }
missing=0

# ---- 结构 ----
for h in "## 定档结论" "## 规模统计" "## 覆盖声明" "## Findings" "## 环境留痕" "门禁③ 记录"; do
  grep -qF "$h" "$review" || { echo "MISSING: $h"; missing=$((missing+1)); }
done

# ---- 覆盖声明非空（fail-closed：未审≠没问题）----
grep -qE "未审.*：" "$review" || { echo "MISSING: 覆盖声明缺'未审及原因'（未审≠没问题）"; missing=$((missing+1)); }

# ---- Findings 表：source 必须是三通道之一 ----
rows=$(grep -cE "^\| F-[0-9]+ \|" "$review" || true)
if [ "$rows" -gt 0 ]; then
  bad_src=$(grep -E "^\| F-[0-9]+ \|" "$review" | grep -cvE "deterministic|llm-advisory|llm-triage" || true)
  [ "$bad_src" -eq 0 ] || { echo "MISSING: ${bad_src} 条 finding 的 source 不属三通道(deterministic/llm-advisory/llm-triage)"; missing=$((missing+1)); }

  # 三通道契约核心检查：block 级 finding 必须来自 deterministic 通道
  bad_block=$(grep -E "^\| F-[0-9]+ \|" "$review" | grep "block" | grep -cE "llm-advisory" || true)
  [ "$bad_block" -eq 0 ] || { echo "MISSING: ${bad_block} 条 block 级 finding 来自 llm-advisory 通道——违反三通道契约(LLM 无阻断权)"; missing=$((missing+1)); }

  # 状态必须是状态机五态之一
  bad_state=$(grep -E "^\| F-[0-9]+ \|" "$review" | grep -cvE "open|fixed|false-positive|accepted-risk|reopened" || true)
  [ "$bad_state" -eq 0 ] || { echo "MISSING: ${bad_state} 条 finding 状态非法(open/fixed/false-positive/accepted-risk/reopened)"; missing=$((missing+1)); }
fi

# ---- 非终态须有人类署名（防 AI 自己判误报）----
if grep -qE "false-positive|accepted-risk" "$review"; then
  grep -qE "签署人" "$review" || { echo "MISSING: 有 false-positive/accepted-risk 但无签署人表（须独立人类署名）"; missing=$((missing+1)); }
fi

# ---- 环境留痕：防重跑到过 ----
runs=$(grep -oE "评审运行次数：\s*[0-9]+" "$review" | grep -oE "[0-9]+" | head -1 || echo "")
if [ -n "$runs" ] && [ "$runs" -gt 1 ]; then
  grep -qE "重跑|原因" "$review" || { echo "MISSING: 评审运行 ${runs} 次但未说明原因（禁止重跑到过）"; missing=$((missing+1)); }
fi

# ---- --final 终检 ----
if [ "$mode" = "--final" ]; then
  stripped=$(sed 's/`[^`]*`//g' "$review")
  echo "$stripped" | grep -qE "<待跑>|<N>|<清单>" && { echo "MISSING(final): 存在未决占位符"; missing=$((missing+1)); }
  # block 级未闭环不得过门禁
  open_block=$(grep -E "^\| F-[0-9]+ \|" "$review" | grep "block" | grep -cE "\| open \||\| reopened \|" || true)
  [ "$open_block" -eq 0 ] || { echo "MISSING(final): ${open_block} 条 block 级 finding 未闭环——不得过门禁③"; missing=$((missing+1)); }
  # 高风险档必须有异构评审段（或显式 unavailable 留痕）
  if grep -qE "风险档.*高" "$review"; then
    grep -qE "异构评审" "$review" || { echo "MISSING(final): 高风险档缺异构评审记录（宪法 C12）"; missing=$((missing+1)); }
  fi
fi

gate3=$(gate_status "$review")

[ "$missing" -gt 0 ] && { echo "FAIL(66): 缺 $missing 项"; exit 66; }
echo "PASS: review 结构完整 | finding ${rows} 条 | 门禁③=$gate3"
exit 0
