#!/usr/bin/env bash
# check-gate-immutability.sh — 批准绑定内容 + 已填批准行不可改写（B2' · SPEC-3 落地）
#
# 为什么：SPEC-3 承诺"已填批准值的行被修改/删除即 FAIL；CI 比对门禁块 git 历史"
# 却从未实现（与 review.md F-3 同款"声明了探针却不存在"，评估 D7）；且已实际发生
# 两起批后正文漂移（release.md/deprecation.md）。首版实现被异构评审击穿（R1 block）：
# 任意块变更都当"重批"移锚——改写 `决定：打回`→`批准` 反而被放行。现版三条规则：
#   ① 批准锚 = 最近一次门禁块区域变更的 commit；
#   ② 锚处若父版本已是**已填合法批准**，块变更必须**只增不改删**（父块每一行原样保留）
#      ——改写/删除已填行=SPEC-3 主场景，当场红；父版本待批时的首次填批豁免；
#   ③ 正文（块之上全部内容，含未提交工作区）与锚版本必须一致；已批制品被降回
#      待批（历史上有已填版本、现在 PENDING）同样红。
#
# 诚实边界：删除整文件后另起炉灶、rename 两步舞属"有写权限者的公开篡改"（手册
# §7.1b 声明的域外），git 历史会留痕但本探针不拦；merge 锚定以第一父为准。
#
# 用法: bash scripts/check-gate-immutability.sh
# 退出码: 0=全部一致 / 1=有违规 / 66=判据失效（非 git 仓/浅克隆/无可检对象）
set -u
cd "$(dirname "$0")/.." || exit 1
git rev-parse --git-dir >/dev/null 2>&1 || { echo "FAIL(66): 非 git 仓库——无历史可对账，拒绝 PASS"; exit 66; }
# 浅克隆的历史是截断的，锚定会错位（G5）——与 check-marketplace-sha 同规则
[ -f "$(git rev-parse --git-dir)/shallow" ] && { echo "FAIL(66): 浅克隆无完整历史——CI 请设 fetch-depth: 0"; exit 66; }

# ---- 门禁解析公共库（SPEC-5 单一实现：gate_decision / gate_block_line）----
. "scripts/lib/gate.sh" || { echo "FAIL(66): 无法加载 scripts/lib/gate.sh"; exit 66; }

_TMP=$(mktemp); trap 'rm -f "$_TMP"' EXIT
# _dec_of <内容字符串> → 走 gate_decision 单一实现（经临时文件）
_dec_of() { printf '%s\n' "$1" > "$_TMP"; gate_decision "$_TMP"; }
_body_of()  { local c n; c=$(cat); printf '%s\n' "$c" > "$_TMP"; n=$(gate_block_line "$_TMP"); [ -n "$n" ] || { printf '%s\n' "$c"; return; }; printf '%s\n' "$c" | awk -v n="$n" 'NR < n'; }
_block_of() { local c n; c=$(cat); printf '%s\n' "$c" > "$_TMP"; n=$(gate_block_line "$_TMP"); [ -n "$n" ] || return 0; printf '%s\n' "$c" | awk -v n="$n" 'NR >= n'; }

echo "== 门禁批准绑定内容（git 历史对账，B2'/SPEC-3）=="
bad=0; checked=0; seen=0
for pat in prfaq prd spec review release deprecation; do
for f in specs/*/"$pat".md; do
  [ -e "$f" ] || continue
  seen=$((seen+1))
  d=$(gate_decision "$f")

  # 在途批准（R3）：工作区块 ≠ HEAD 版本块 → 批准正在落地，入库后再对账，不给"补重批"的错误修法
  head_content=$(git show "HEAD:$f" 2>/dev/null || true)
  if [ -n "$head_content" ]; then
    wt_block=$(_block_of < "$f"); head_block=$(printf '%s\n' "$head_content" | _block_of)
    if [ "$wt_block" != "$head_block" ]; then
      echo "   ⏳ ${f}：门禁块改动尚未入库——先提交该批准 commit，本探针以入库历史为准"
      continue
    fi
  fi

  if [ "$d" = "PENDING" ] || [ "$d" = "UNKNOWN" ]; then
    # 降批检测（G5）：历史上出现过已填批准、现在退回待批/异常 → 不是"未批"，是被洗掉
    degraded=0
    for c in $(git log --format=%H -- "$f"); do
      hd=$(_dec_of "$(git show "$c:$f" 2>/dev/null || true)")
      case "$hd" in PENDING|UNKNOWN) : ;; *) degraded=1; break ;; esac
    done
    if [ "$degraded" -eq 1 ]; then
      echo "   ❌ ${f}：历史上已有已填批准（$(git rev-parse --short "$c")），现被降回 ${d}——批准被洗掉"
      bad=$((bad+1))
    else
      echo "   ⏳ ${f}（${d}，未批不约束）"
    fi
    continue
  fi
  checked=$((checked+1))

  # 批准锚：最新一个"块区域相对父版本有变化"的 commit
  ac=""; par_content=""
  for c in $(git log --format=%H -- "$f"); do
    cur=$(git show "$c:$f" 2>/dev/null | _block_of)
    par_content=$(git show "$c^:$f" 2>/dev/null || true)
    par=$(printf '%s\n' "$par_content" | _block_of)
    if [ "$cur" != "$par" ]; then ac="$c"; break; fi
  done
  if [ -z "$ac" ]; then
    echo "   ❌ ${f}：已批却在历史中找不到门禁块变更——批准从未入库（fail-closed）"
    bad=$((bad+1)); continue
  fi

  # 规则②（SPEC-3 主场景，评审 R1）：父版本已是已填合法批准 → 只增不改删
  par_dec=$(_dec_of "$par_content")
  if [ -n "$par_content" ] && [ "$par_dec" != "PENDING" ] && [ "$par_dec" != "UNKNOWN" ]; then
    ac_block=$(git show "$ac:$f" | _block_of)
    par_block=$(printf '%s\n' "$par_content" | _block_of)
    lost=0
    while IFS= read -r line; do
      [ -n "$line" ] || continue
      # -e 传参：块行以 "-" 开头，直接作 pattern 会被 BSD grep 当选项（实测踩过）
      printf '%s\n' "$ac_block" | grep -qxF -e "$line" || { lost=$((lost+1)); }
    done <<EOF
$par_block
EOF
    if [ "$lost" -gt 0 ]; then
      printf '   ❌ %s：锚 %s 改写/删除了已填批准块的 %s 行——SPEC-3 禁止（修订只许追加，如重批记录行）\n' \
        "$f" "$(git rev-parse --short "$ac")" "$lost"
      bad=$((bad+1)); continue
    fi
  fi

  # 规则③：正文与批准锚一致
  body_ac=$(git show "$ac:$f" | _body_of)
  body_now=$(_body_of < "$f")
  if [ "$body_ac" != "$body_now" ]; then
    printf '   ❌ %s：正文在批准锚 %s 之后被修改，且无重批留痕\n' "$f" "$(git rev-parse --short "$ac")"
    printf '      修法：确属需要的修订 → 在门禁块区域**追加**重批记录行（理由/日期/人类批准人）并入库\n'
    bad=$((bad+1))
  else
    printf '   ✅ %s（批准锚 %s，正文一致）\n' "$f" "$(git rev-parse --short "$ac")"
  fi
done
done

[ "$seen" -ge 1 ] || { echo "FAIL(66): specs/ 下无任何门禁制品——无可检对象，拒绝 PASS"; exit 66; }
if [ "$bad" -gt 0 ]; then
  echo "FAIL(1): ${bad} 处违规——签的字与现在的文不是同一份，或已填批准被改写"
  exit 1
fi
echo "PASS: ${checked} 份已批制品与批准时点一致（另 $((seen-checked)) 份待批/在途）"
exit 0
