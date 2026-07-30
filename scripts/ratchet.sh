#!/usr/bin/env bash
# ratchet.sh — 存量项目质量棘轮（SPEC-14 / US-13 / SR-4）
#
# 机制：基线内违规豁免、新增违规阻断、基线只降不升。
# 核心设计（S5 spike 结论，ADR-010 行式格式）：
#   身份 = 工具:规则:文件:指纹    ——【不含行号】
#   指纹 = 违规行内容的 md5 前 8 位 ——【对行号漂移稳定】
#   判定 = comm -13 基线 当前     ——【集合差，不是数量比较】
#          数量比较有洞：删一个旧违规+加一个新违规，总数不变但质量变了
#
# 用法:
#   bash scripts/ratchet.sh --rebaseline   生成/更新基线（高风险操作，须人审 SPEC-20）
#   bash scripts/ratchet.sh                检查（新增违规即退出 1）
#   RATCHET_LINTER=<cmd> 覆盖 linter 适配器（默认内置 selfcheck）
#
# 退出码: 0=无新增违规 / 1=有新增违规 / 65=基线缺失
set -u
cd "$(dirname "$0")/.." || exit 65
BASELINE="${RATCHET_BASELINE:-quality-baseline.txt}"

# ---- linter 适配器（ADR-010：复杂分析走适配器，此处内置零依赖实现）----
# 契约：输出每行一条 `规则|文件|违规行内容`
run_linter() {
  if [ -n "${RATCHET_LINTER:-}" ]; then
    eval "$RATCHET_LINTER"; return
  fi
  # 内置 selfcheck：对 bash 脚本的最小规则集
  while IFS= read -r f; do
    grep -n 'TODO\|FIXME' "$f" 2>/dev/null | while IFS=: read -r _ln content; do
      printf 'no-todo|%s|%s\n' "$f" "$(echo "$content" | tr -s ' ')"
    done
    grep -q '^set -u' "$f" || printf 'require-set-u|%s|missing set -u\n' "$f"
  done < <(find . -name '*.sh' -not -path './.git/*' | sort)
}

# ---- 身份指纹：工具:规则:文件:内容hash（无行号 → 行号漂移不误报）----
to_identity() {
  local tool="${RATCHET_TOOL:-selfcheck}"
  while IFS='|' read -r rule file content; do
    [ -z "${rule:-}" ] && continue
    fp=$(printf '%s' "$content" | md5 -q 2>/dev/null | cut -c1-8) \
      || fp=$(printf '%s' "$content" | md5sum | cut -c1-8)
    printf '%s:%s:%s:%s\n' "$tool" "$rule" "$file" "$fp"
  done | sort -u
}

current=$(run_linter | to_identity)

if [ "${1:-}" = "--rebaseline" ]; then
  {
    printf '# tool=%s date=%s\n' "${RATCHET_TOOL:-selfcheck}" "$(date +%Y-%m-%d)"
    printf '%s\n' "$current"
  } > "$BASELINE"
  n=$(printf '%s\n' "$current" | grep -c . || true)
  echo "REBASELINE: 基线已更新，收录 $n 条存量违规 → $BASELINE"
  echo "⚠️  基线文件属高风险路径（SPEC-20），改动须人审"
  exit 0
fi

# 注意 ${BASELINE} 必须带花括号：中文标点紧跟 $VAR 会被 bash 并入变量名（负样本框架实测抓出）
[ -f "$BASELINE" ] || { echo "FAIL(65): 无基线 ${BASELINE}——先跑 --rebaseline"; exit 65; }

baseline=$(grep -v '^#' "$BASELINE" | grep . | sort -u)
# 集合差：当前有、基线无 = 新增违规（核心判定，非数量比较）
new=$(comm -13 <(printf '%s\n' "$baseline") <(printf '%s\n' "$current"))
fixed=$(comm -23 <(printf '%s\n' "$baseline") <(printf '%s\n' "$current"))

nb=$(printf '%s\n' "$baseline" | grep -c . || true)
nc=$(printf '%s\n' "$current" | grep -c . || true)
nn=$(printf '%s\n' "$new" | grep -c . || true)
nf=$(printf '%s\n' "$fixed" | grep -c . || true)

echo "RATCHET: 基线 $nb | 当前 $nc | 新增 $nn | 已修 $nf"
[ "$nf" -gt 0 ] && { echo "✅ 已修复（可 --rebaseline 收紧基线）:"; printf '%s\n' "$fixed" | sed 's/^/   - /'; }

if [ "$nn" -gt 0 ]; then
  echo "❌ 新增违规（棘轮阻断，基线只降不升）:"
  printf '%s\n' "$new" | sed 's/^/   + /'
  exit 1
fi
echo "✅ 无新增违规"
exit 0
