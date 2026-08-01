#!/usr/bin/env bash
# check-gate-immutability.sh — 批准绑定内容：门禁批准后正文再改必须重批（B2' · SPEC-3 落地）
#
# 为什么：SPEC-3 承诺"CI 比对门禁记录块 git 历史，改写即 FAIL"却从未实现（与
# review.md F-3 抓过的"声明了探针却不存在"同款，评估 D7）；且已实际发生两起：
# release.md 批④后 23 分钟被改正文、deprecation.md 批⑤后被改，均无重批留痕——
# "被批准的文档"与"当前文档"不是同一份，签字语义被掏空。
#
# 方案：git 历史对账，不用同文件内容摘要——能改正文的人同样能改摘要行（异构评审
# G3/P2 共识），而 CI 语境下 git 历史是服务端事实，伪造需改写已推送历史（被
# 禁 force-push 的分支保护拦住）。门禁块"尾部四行"契约零改动。
#
# 判定：对每份已批制品（决定≠PENDING/UNKNOWN）——
#   批准锚 = 最近一次"门禁块区域内容发生变化"的 commit
#   正文（门禁记录标题之上的全部内容）在批准锚之后（含未提交工作区）被改 → FAIL
#   重批 = 再次触碰门禁块区域（如追加一行"- 重批：<理由+日期+批准人>"）→ 锚前移
#
# 用法: bash scripts/check-gate-immutability.sh
# 退出码: 0=全部一致 / 1=有批后正文漂移 / 66=判据失效（非 git 仓/无可检对象）
set -u
cd "$(dirname "$0")/.." || exit 1
git rev-parse --git-dir >/dev/null 2>&1 || { echo "FAIL(66): 非 git 仓库——无历史可对账，拒绝 PASS"; exit 66; }

# ---- 门禁解析公共库（SPEC-5 单一实现，取 gate_decision）----
. "scripts/lib/gate.sh" || { echo "FAIL(66): 无法加载 scripts/lib/gate.sh"; exit 66; }

# 门禁记录标题行号（最后一个）；无块输出空
_blkline() { grep -nE '门禁.{0,3}记录' 2>/dev/null | tail -1 | cut -d: -f1; }
# 输入全文从 stdin，输出正文（标题行之上）；$1=标题行号
_body_part()  { awk -v n="$1" 'NR <  n' ; }
# 输出块区域（标题行起到文件尾）
_block_part() { awk -v n="$1" 'NR >= n' ; }

_body_of()  { local c; c=$(cat); local n; n=$(printf '%s\n' "$c" | _blkline); [ -n "$n" ] || { printf '%s\n' "$c"; return; }; printf '%s\n' "$c" | _body_part "$n"; }
_block_of() { local c; c=$(cat); local n; n=$(printf '%s\n' "$c" | _blkline); [ -n "$n" ] || return 0; printf '%s\n' "$c" | _block_part "$n"; }

echo "== 门禁批准绑定内容（git 历史对账，B2'）=="
files=$(ls specs/*/prfaq.md specs/*/prd.md specs/*/spec.md specs/*/review.md specs/*/release.md specs/*/deprecation.md 2>/dev/null || true)
[ -n "$files" ] || { echo "FAIL(66): specs/ 下无任何门禁制品——无可检对象，拒绝 PASS"; exit 66; }

bad=0; checked=0
for f in $files; do
  d=$(gate_decision "$f")
  case "$d" in PENDING|UNKNOWN) echo "   ⏳ ${f}（${d}，未批不约束）"; continue ;; esac
  checked=$((checked+1))

  # 批准锚：最新一个"块区域相对父版本有变化"的 commit
  ac=""
  for c in $(git log --format=%H -- "$f"); do
    cur=$(git show "$c:$f" 2>/dev/null | _block_of)
    par=$(git show "$c^:$f" 2>/dev/null | _block_of || true)
    if [ "$cur" != "$par" ]; then ac="$c"; break; fi
  done
  if [ -z "$ac" ]; then
    echo "   ❌ ${f}：已批却在历史中找不到门禁块变更——批准从未入库（fail-closed）"
    bad=$((bad+1)); continue
  fi

  body_ac=$(git show "$ac:$f" | _body_of)
  body_now=$(_body_of < "$f")
  if [ "$body_ac" != "$body_now" ]; then
    printf '   ❌ %s：正文在批准锚 %s 之后被修改，且无重批留痕\n' "$f" "$(git rev-parse --short "$ac")"
    printf '      修法：确属需要的修订 → 在门禁块区域追加一行重批记录（含理由/日期/人类批准人）并入库\n'
    bad=$((bad+1))
  else
    printf '   ✅ %s（批准锚 %s，正文一致）\n' "$f" "$(git rev-parse --short "$ac")"
  fi
done

[ "$checked" -ge 1 ] || { echo "FAIL(66): 0 份已批制品——判据无对象，拒绝 PASS"; exit 66; }
if [ "$bad" -gt 0 ]; then
  echo "FAIL(1): ${bad} 处批后正文漂移——签的字与现在的文不是同一份"
  exit 1
fi
echo "PASS: ${checked} 份已批制品的正文与批准时点一致"
exit 0
