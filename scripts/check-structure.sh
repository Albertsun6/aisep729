#!/usr/bin/env bash
# check-structure.sh — 六件套结构探针（SPEC-18 · ADR-008 · 宪法 C4）
#
# 唯一能力拓扑来源 = docs/process/skills-manifest.md（异构评审#3 的修复：
# 此前"七 skill"散落在 stories/plan/spec 三处口径不一，manifest 是唯一真相）。
# 本探针读 manifest 逐行比对，scaffold（e2e init）也读同一份——不许两套清单。
#
# 检查项：
#   1. manifest 登记的每个 skill：SKILL.md + templates/ + scripts/check-*.sh 三件齐
#   2. 每个已实现 skill 有对应阶段定义文档 docs/process/stages/
#   3. glossary 有对应阶段词条节
#   4. .claude/ 下无业务真相文件（宪法 C4：产物是真相，工具是适配）
#
# 用法: bash scripts/check-structure.sh
# 退出码: 0=结构完整 / 65=manifest 缺失 / 66=结构缺项
set -u
cd "$(dirname "$0")/.." || exit 1
MANIFEST="docs/process/skills-manifest.md"
GLOSSARY="docs/glossary.md"
miss=0; checked=0; pending=0

[ -f "$MANIFEST" ] || { echo "FAIL(65): 缺 $MANIFEST（能力拓扑唯一来源）"; exit 65; }
echo "== 六件套结构扫描（manifest 驱动）=="

# ---- 1-3：逐 skill 比对 ----
while IFS='|' read -r _ name stage gate product probe _; do
  name=$(echo "$name" | tr -d ' `')
  case "$name" in e2e-*) ;; *) continue ;; esac
  checked=$((checked+1))
  d=".claude/skills/$name"
  if [ ! -d "$d" ]; then
    echo "   ⏳ ${name}：未实现（manifest 已登记，M2 待建）"; pending=$((pending+1)); continue
  fi
  [ -f "$d/SKILL.md" ]      || { echo "   ❌ ${name}：缺 SKILL.md"; miss=$((miss+1)); }
  [ -d "$d/templates" ]     || { echo "   ❌ ${name}：缺 templates/"; miss=$((miss+1)); }
  ls "$d"/scripts/check-*.sh >/dev/null 2>&1 || { echo "   ❌ ${name}：缺 scripts/check-*.sh"; miss=$((miss+1)); }
  # 探针必须接公共库（SPEC-5）
  local_ok=1
  for p in "$d"/scripts/check-*.sh; do
    [ -e "$p" ] || continue
    grep -q "lib/gate.sh" "$p" || { echo "   ❌ ${name}：$(basename "$p") 未接 gate.sh 公共库（SPEC-5）"; miss=$((miss+1)); local_ok=0; }
  done
  [ "$local_ok" = 1 ] && echo "   ✅ ${name}：三件齐 + 接公共库"
done < "$MANIFEST"

# 阶段定义文档（已实现的阶段各一份）
for f in docs/process/stages/stage-*.md; do
  [ -e "$f" ] || { echo "   ❌ 无阶段定义文档 docs/process/stages/"; miss=$((miss+1)); break; }
done
nstage=$(ls docs/process/stages/stage-*.md 2>/dev/null | wc -l | tr -d ' ')
echo "   ✅ 阶段定义文档 ${nstage} 份"

# glossary 阶段词条节
for s in 0 1 2 3; do
  grep -qE "^## 阶段 ${s}" "$GLOSSARY" || { echo "   ❌ glossary 缺阶段 ${s} 词条节"; miss=$((miss+1)); }
done

# ---- 4：宪法 C4——.claude/ 下不得有业务真相 ----
stray=$(find .claude -maxdepth 1 -mindepth 1 -not -name skills -not -name agents \
        -not -name hooks -not -name rules -not -name 'settings*.json' 2>/dev/null || true)
if [ -n "$stray" ]; then
  echo "   ❌ .claude/ 下有非适配层内容（宪法 C4）："; printf '%s\n' "$stray" | sed 's/^/      /'
  miss=$((miss+1))
fi

echo
if [ "$miss" -gt 0 ]; then
  echo "FAIL(66): $miss 项结构缺失（已检 $checked 个登记 skill，$pending 个未实现）"
  exit 66
fi
echo "PASS: 结构完整（manifest 登记 $checked 个 skill：$((checked-pending)) 已实现 / $pending 待建）"
exit 0
