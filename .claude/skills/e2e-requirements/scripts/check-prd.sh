#!/usr/bin/env bash
# check-prd.sh — 阶段1 制品验收探针 + 门禁⓪前置校验
# 用法: bash check-prd.sh <specs/feature-dir> [--gate-only]
# 退出码: 0=PASS / 64=门禁⓪未通过 / 65=文件缺失 / 66=结构或质量缺项
set -u
dir="${1:-}"; mode="${2:-full}"
prfaq="$dir/prfaq.md"; prd="$dir/prd.md"

# ---- 门禁⓪ 前置(阶段1 的启动钥匙) ----
[ -f "$prfaq" ] || { echo "FAIL(64): 无 prfaq.md——先走 e2e-discovery(阶段0)"; exit 64; }
if ! grep -qE "决定：\s*go" "$prfaq"; then
  echo "FAIL(64): 门禁⓪ 非 go(当前: $(grep -oE '决定：.*' "$prfaq" | head -1))——拒绝进入阶段1"
  exit 64
fi
echo "GATE0: go ✓"
[ "$mode" = "--gate-only" ] && exit 0

# ---- prd 结构 ----
[ -f "$prd" ] || { echo "FAIL(65): 缺 prd.md"; exit 65; }
required=( "## 概述" "## 用户与路径" "## 功能需求" "## 非功能需求" "## 范围外" "## 追溯表" "## 待澄清" "门禁① 记录" )
missing=0
for h in "${required[@]}"; do
  grep -qF "$h" "$prd" || { echo "MISSING: $h"; missing=$((missing+1)); }
done

# ---- 质量检查 ----
stories=$(grep -cE "^### (US|SR)-" "$prd")
[ "$stories" -ge 1 ] || { echo "MISSING: 至少 1 条 US-/SR- 需求"; missing=$((missing+1)); }
for kw in "Given" "When" "Then"; do
  grep -q "$kw" "$prd" || { echo "MISSING: 验收标准缺 $kw(GWT 不完整)"; missing=$((missing+1)); }
done
grep -q "Must" "$prd" || { echo "MISSING: MoSCoW 标注"; missing=$((missing+1)); }
grep -q "Kano" "$prd" || { echo "MISSING: Kano 标注"; missing=$((missing+1)); }

# Must 占比通胀警告——统计口径=内联块 + 摘要表行;已有 Kano 分层则降级为 INFO
# (SOP 本意:通胀警告是为逼出 Kano 分层;分层已做即达目的,不再 WARN)
blk_must=$(grep -cE "^### (US|SR)-.*\[Must" "$prd"); blk_total=$stories
tbl_must=$(grep -cE "^\| (US|SR)-[0-9]+ \|.*\| Must \|" "$prd")
tbl_total=$(grep -cE "^\| (US|SR)-[0-9]+ \|" "$prd")
must=$(( blk_must + tbl_must )); total=$(( blk_total + tbl_total ))
if [ "$total" -gt 0 ]; then
  pct=$(( must * 100 / total ))
  if [ "$pct" -gt 60 ]; then
    if grep -qE "Kano: *(基本|绩效|惊喜)" "$prd"; then
      echo "INFO: Must 占比 ${pct}%但 Kano 分层已标注(基本/绩效/惊喜)——熔断砍序有据,不计通胀"
    else
      echo "WARN: Must 占比 ${pct}%(>60%)且无 Kano 分层——需求通胀,先分层再过门禁"
    fi
  fi
fi

# 待澄清残留(未勾选的 checkbox 且未标移交)
pending=$(grep -cE "^- \[ \] " "$prd")
[ "$pending" -gt 0 ] && echo "WARN: ${pending} 项待澄清未闭环(澄清或显式移交后再过门禁①)"

# 门禁①状态
if grep -qE "决定：<待填>" "$prd"; then gate1="PENDING(待人批)"
elif grep -qE "决定：\s*(批准|打回)" "$prd"; then gate1="$(grep -oE '决定：\s*(批准|打回)' "$prd" | head -1)"
else gate1="UNKNOWN(门禁块格式异常)"; fi

[ "$missing" -gt 0 ] && { echo "FAIL(66): 缺 $missing 项"; exit 66; }
echo "PASS: 结构完整 | 需求条目=$stories(Must=$must) | 门禁①=$gate1"
exit 0
