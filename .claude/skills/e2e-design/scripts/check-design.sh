#!/usr/bin/env bash
# check-design.sh — 阶段2 制品验收探针 + 门禁①前置校验
# 用法: bash check-design.sh <specs/feature-dir> [--gate-only]
# 退出码: 0=PASS / 64=门禁①未通过 / 65=文件缺失 / 66=结构或质量缺项
set -u
dir="${1:-}"; mode="${2:-full}"
prd="$dir/prd.md"; spec="$dir/spec.md"; plan="$dir/plan.md"
root="$(cd "$dir/../.." 2>/dev/null && pwd)"   # specs/<f>/ -> 仓库根
const="$root/docs/constitution.md"; spine="$root/docs/architecture/spine.md"; adrdir="$root/docs/architecture/adr"

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

# ---- 门禁① 前置 ----
gate_require "$prd" 批准 || exit 64
echo "GATE1: 批准 ✓"
[ "$mode" = "--gate-only" ] && exit 0

missing=0
req_file(){ [ -f "$1" ] || { echo "MISSING FILE: $1"; missing=$((missing+1)); return 1; }; return 0; }

# ---- 平台级 ----
req_file "$const" && {
  n=$(grep -cE "^- \*\*C[0-9]+" "$const" || true)
  [ "$n" -ge 1 ] || { echo "MISSING: constitution 无编号原则(C1..)"; missing=$((missing+1)); }
}
req_file "$spine" && {
  lines=$(grep -vc '^[[:space:]]*$' "$spine")
  [ "$lines" -le 300 ] || echo "WARN: spine.md ${lines} 行(>300)——防腐纪律,精简"
}

# ---- spec ----
req_file "$spec" && {
  for h in "## 行为契约" "## 与 PRD 的追溯" "## 评审记录" "门禁② 记录"; do
    grep -qF "$h" "$spec" || { echo "MISSING(spec): $h"; missing=$((missing+1)); }
  done
  # 逐条 SPEC 解析：每个定义行(**SPEC-N**)必须同行含"验证："(异构评审#10)
  defs=$(grep -cE "^\- \*\*SPEC-[0-9]+\*\*" "$spec")
  [ "$defs" -ge 3 ] || { echo "MISSING(spec): 契约条目不足(SPEC-N 定义行 ≥3)"; missing=$((missing+1)); }
  noverify=$(grep -E "^\- \*\*SPEC-[0-9]+\*\*" "$spec" | grep -cv "验证：")
  [ "$noverify" -eq 0 ] || { echo "MISSING(spec): ${noverify} 条 SPEC 定义行缺'验证：'"; missing=$((missing+1)); }
  dup=$(grep -oE "^\- \*\*SPEC-[0-9]+\*\*" "$spec" | sort | uniq -d | wc -l | tr -d ' ')
  [ "$dup" -eq 0 ] || { echo "MISSING(spec): SPEC 编号重复 ${dup} 处"; missing=$((missing+1)); }
}

# ---- plan ----
req_file "$plan" && {
  for h in "## 结构" "## 技术选型" "## 质量场景" "## Non-goals" "## 风险与 spike" "## Fitness Functions"; do
    grep -qF "$h" "$plan" || { echo "MISSING(plan): $h"; missing=$((missing+1)); }
  done
}

# ---- ADR ----
if [ -d "$adrdir" ]; then
  adrs=$(ls "$adrdir" | grep -cE "^ADR-[0-9]{3}-.*\.md$" || true)
  [ "$adrs" -ge 1 ] || { echo "MISSING: adr/ 目录无 ADR-NNN 文件"; missing=$((missing+1)); }
  # 编号连续性(异构评审#10)
  expect=1
  for num in $(ls "$adrdir" | grep -oE "^ADR-[0-9]{3}" | grep -oE "[0-9]{3}" | sort); do
    printf -v want "%03d" "$expect"
    [ "$num" = "$want" ] || { echo "MISSING: ADR 编号断档(期望 $want 实际 $num)"; missing=$((missing+1)); break; }
    expect=$((expect+1))
  done
  # 每个 ADR 必含备选与后果
  for f in "$adrdir"/ADR-*.md; do
    [ -e "$f" ] || continue
    grep -qF "## 备选方案" "$f" || { echo "MISSING($(basename "$f")): 备选方案段"; missing=$((missing+1)); }
    opts=$(grep -cE "^### 选项" "$f")
    [ "$opts" -ge 2 ] || { echo "MISSING($(basename "$f")): 备选不足 2 个(决定≠决策)"; missing=$((missing+1)); }
    grep -qF "## 后果" "$f" || { echo "MISSING($(basename "$f")): 后果段"; missing=$((missing+1)); }
  done
else
  echo "MISSING DIR: $adrdir"; missing=$((missing+1))
fi

# ---- --final 终检模式(异构评审#10)：WARN 升 FAIL、占位符即缺项 ----
if [ "$mode" = "--final" ]; then
  # 占位检测须区分"使用"与"提及"——反引号内为契约正文的格式定义(提及),先剥离行内代码段
  stripped=$(sed 's/`[^`]*`//g' "$spec")
  echo "$stripped" | grep -q "<待跑>" && { echo "MISSING(final): 评审记录仍有 <待跑> 占位"; missing=$((missing+1)); }
  # 辩论矩阵至少 1 有效行(含 accept/partial/refute)
  grep -E "^\|" "$spec" | grep -qE "accept|partial|refute" || { echo "MISSING(final): 异构辩论矩阵无有效行"; missing=$((missing+1)); }
  # 门禁②块之外不得有 <待填>(门禁块 4 行豁免——待人批本身合法)
  waitfill=$(echo "$stripped" | grep -c "<待填>"); [ "$waitfill" -le 4 ] || { echo "MISSING(final): 门禁块外存在 <待填> 占位($waitfill>4)"; missing=$((missing+1)); }
  if [ -f "$spine" ]; then
    lines=$(grep -vc '^[[:space:]]*$' "$spine")
    [ "$lines" -le 300 ] || { echo "MISSING(final): spine ${lines} 行>300(WARN 升 FAIL)"; missing=$((missing+1)); }
  fi
fi

# ---- 预审/异构评审留痕 ----
grep -qF "architect 预审" "$spec" 2>/dev/null && grep -qF "异构评审" "$spec" 2>/dev/null || \
  echo "WARN: spec 评审记录未见 architect 预审/异构评审留痕(门禁②前须补)"

# ---- 门禁②状态(公共库) ----
# 门禁台账 fail-open 修复：校验本文件自己的决定值合法（gate.sh 单一实现）
gate_assert_legal "$spec" 批准 打回 || missing=$((missing+1))
gate2=$(gate_status "$spec")

[ "$missing" -gt 0 ] && { echo "FAIL(66): 缺 $missing 项"; exit 66; }
echo "PASS: 设计制品结构完整 | 门禁②=$gate2"
exit 0
