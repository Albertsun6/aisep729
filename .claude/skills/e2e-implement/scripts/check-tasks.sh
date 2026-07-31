#!/usr/bin/env bash
# check-tasks.sh — 阶段3 制品验收探针 + 门禁②前置校验
# 用法: bash check-tasks.sh <specs/feature-dir> [--gate-only|--final]
# 退出码: 0=PASS / 64=门禁②未通过 / 65=文件缺失 / 66=结构或质量缺项
set -u
dir="${1:-}"; mode="${2:-full}"
spec="$dir/spec.md"; tasks="$dir/tasks.md"

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

# ---- 门禁② 前置 ----
gate_require "$spec" 批准 || exit 64
echo "GATE2: 批准 ✓"
[ "$mode" = "--gate-only" ] && exit 0

[ -f "$tasks" ] || { echo "FAIL(65): 缺 tasks.md"; exit 65; }
missing=0

# ---- 结构 ----
for h in "## A 组" "## B 组" "## 进度与容量" "## spike 结论"; do
  grep -qF "$h" "$tasks" || { echo "MISSING: $h"; missing=$((missing+1)); }
done

# ---- 逐条任务解析(SPEC-21 核心契约) ----
total=$(grep -cE "^- \[[ x]\] T-[0-9]+" "$tasks")
[ "$total" -ge 1 ] || { echo "MISSING: 无任务条目(T-N)"; missing=$((missing+1)); }

noverify=$(grep -E "^- \[[ x]\] T-[0-9]+" "$tasks" | grep -cv "验证：")
[ "$noverify" -eq 0 ] || { echo "MISSING: ${noverify} 条任务缺'验证：'(无验证不成任务)"; missing=$((missing+1)); }

# 复杂度点(ADR-012：弃人类工时,AI 执行下工时失去校准意义)
nocx=$(grep -E "^- \[[ x]\] T-[0-9]+" "$tasks" | grep -cvE "复杂度 [138]")
[ "$nocx" -eq 0 ] || { echo "MISSING: ${nocx} 条任务缺'复杂度 1/3/8'标注"; missing=$((missing+1)); }
# 明令禁止工时回潮
hours=$(grep -cE "^- \[[ x]\] T-[0-9]+.*预算 [0-9]+h" "$tasks")
[ "$hours" -eq 0 ] || { echo "MISSING: ${hours} 条任务仍用人类工时(ADR-012 已弃用)"; missing=$((missing+1)); }

nospec=$(grep -E "^- \[[ x]\] T-[0-9]+" "$tasks" | grep -cvE "SPEC-[0-9]+|SPEC 无关|ADR-[0-9]+")
[ "$nospec" -eq 0 ] || { echo "MISSING: ${nospec} 条任务缺 SPEC/ADR 映射"; missing=$((missing+1)); }

# 任务编号唯一
dup=$(grep -oE "^- \[[ x]\] T-[0-9]+" "$tasks" | grep -oE "T-[0-9]+" | sort | uniq -d | wc -l | tr -d ' ')
[ "$dup" -eq 0 ] || { echo "MISSING: 任务编号重复 ${dup} 处"; missing=$((missing+1)); }

# 空话式验证检测(与宪法 C2 一致)
vague=$(grep -E "^- \[[ x]\] T-[0-9]+" "$tasks" | grep -cE "验证：.*(人工确认没问题|看起来对|应该可以|自己检查一下)")
[ "$vague" -eq 0 ] || { echo "MISSING: ${vague} 条任务是空话式验证"; missing=$((missing+1)); }

done_n=$(grep -cE "^- \[x\] T-[0-9]+" "$tasks")
todo_n=$((total - done_n))

# ---- --final 出口模式 ----
if [ "$mode" = "--final" ]; then
  [ "$todo_n" -eq 0 ] || { echo "MISSING(final): 仍有 ${todo_n} 条任务未勾选"; missing=$((missing+1)); }
  # spike 结论表须有有效行(非表头非分隔)
  spike_rows=$(sed -n '/## spike 结论/,/^## /p' "$tasks" | grep -cE "^\|" || true)
  [ "$spike_rows" -ge 3 ] || { echo "MISSING(final): spike 结论表无有效行"; missing=$((missing+1)); }
  stripped=$(sed 's/`[^`]*`//g' "$tasks")
  echo "$stripped" | grep -qE "<待填>|<待跑>|<N>" && { echo "MISSING(final): 存在未决占位符"; missing=$((missing+1)); }
fi

[ "$missing" -gt 0 ] && { echo "FAIL(66): 缺 $missing 项"; exit 66; }
echo "PASS: tasks 结构完整 | 任务 ${done_n}/${total} 已完成"
exit 0
