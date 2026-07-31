#!/usr/bin/env bash
# check-retire.sh — 阶段6 制品验收探针 + 门禁④ 前置校验
# 用法: bash check-retire.sh <specs/feature-dir> [--gate-only|--final]
# 退出码: 0=PASS / 64=上游门禁未过 / 65=文件缺失 / 66=结构或质量缺项
#
# 契约 SPEC-23：deprecation 计划三节非空（数据迁移/用户通知/支持期义务）+ 正文引用门禁④记录。
# 另按 stage-6 定义硬化两条实践教训：compulsory 型必须有迁移工具与强制截止日（只发公告=退役永不完成）；
# 支持期义务必须有具体到期日（EU CRA 语境下口头承诺不可审计）。
set -u
dir="${1:-}"; mode="${2:-full}"
[ -n "${dir}" ] || { echo "FAIL(65): 用法 bash check-retire.sh <specs/feature-dir> [--gate-only|--final]"; exit 65; }
release="$dir/release.md"; dep="$dir/deprecation.md"

# ---- 门禁解析公共库(SPEC-5：单一实现) ----
_root=$(cd "$(dirname "$0")/../../../.." && pwd)
. "$_root/scripts/lib/gate.sh" || { echo "FAIL(65): 无法加载 scripts/lib/gate.sh"; exit 65; }

# 制品判定公共库（reviewer finding #3：原 sec_lines 两份拷贝且判定过宽）
. "$_root/scripts/lib/artifact.sh" || { echo "FAIL(65): 无法加载 scripts/lib/artifact.sh"; exit 65; }
sec_lines() { art_sec_lines "$1" "$2"; }

# ---- 门禁④ 前置（没放行过生产就谈不上退役）----
gate_require "$release" 批准 || exit 64
echo "GATE4: 批准 ✓"
[ "$mode" = "--gate-only" ] && exit 0

[ -f "$dep" ] || { echo "FAIL(65): 缺 ${dep}（deprecation 计划）"; exit 65; }
missing=0

# ---- 结构 ----
for h in "## 退役类型" "## 依赖方盘点" "## 数据迁移" "## 用户通知" "## 支持期义务" \
         "## 时间线与不可逆点" "## 退役完成核对" "门禁⑤ 记录"; do
  grep -qF "$h" "$dep" || { echo "MISSING: ${h}"; missing=$((missing+1)); }
done

# ---- SPEC-23 核心①：三节非空 ----
for s in "## 数据迁移" "## 用户通知" "## 支持期义务"; do
  n=$(sec_lines "$dep" "$s")
  [ "$n" -ge 2 ] || { echo "MISSING: ${s} 节为空或仅占位符（SPEC-23 三节非空）"; missing=$((missing+1)); }
done

# ---- SPEC-23 核心②：正文引用门禁④记录 ----
grep -qE "门禁④.*批准" "$dep" \
  || { echo "MISSING: 正文缺门禁④ 批准记录引用（SPEC-23：串锁要看得见）"; missing=$((missing+1)); }

# ---- 退役类型：advisory / compulsory 二选一（finding #8：精确取值，不用子串）----
tline=$(grep -E "^- \*\*类型\*\*：|^- 类型：" "$dep" | head -1 || true)
tval=$(printf '%s' "$tline" | sed -E 's/^- (\*\*)?类型(\*\*)?：[[:space:]]*//; s/[[:space:]（(｜|].*$//; s/`//g')
rtype=""
case "$tval" in
  advisory)   rtype=advisory ;;
  compulsory) rtype=compulsory ;;
  *) echo "MISSING: 退役类型须精确取 advisory 或 compulsory 之一（当前=\"${tval}\"；两型不许含糊）"; missing=$((missing+1)) ;;
esac
if [ "$rtype" = "compulsory" ]; then
  # finding #8：先剥反引号再判——模板里 `迁移工具：\`<…>\`` 曾被判为"有工具"
  mtool=$(grep -E "迁移工具：" "$dep" | head -1 | sed -E 's/.*迁移工具：[[:space:]]*//; s/`//g; s/[[:space:]].*$//')
  { [ -n "$mtool" ] && ! printf '%s' "$mtool" | grep -qE '^<[^>]*>$'; } \
    || { echo "MISSING: compulsory 型无迁移工具（只发公告=把成本甩给用户，退役永不完成）"; missing=$((missing+1)); }
  grep -qE "强制截止日：[[:space:]]*[0-9]{4}-[0-9]{2}-[0-9]{2}" "$dep" \
    || { echo "MISSING: compulsory 型无具体强制截止日"; missing=$((missing+1)); }
fi

# ---- 数据迁移：要有校验方式（宪法 C2）与备份口径 ----
sed -n '/^## 数据迁移/,/^## /p' "$dep" | grep -qE "校验|对账" \
  || { echo "MISSING: 数据迁移无校验方式（迁没迁对要能验，宪法 C2）"; missing=$((missing+1)); }
if sed -n '/^## 数据迁移/,/^## /p' "$dep" | grep -q "销毁"; then
  grep -qE "备份" "$dep" || { echo "MISSING: 有销毁类处置但无备份与保留期（删了回不来）"; missing=$((missing+1)); }
fi

# ---- 用户通知：每条渠道要有责任人 ----
sed -n '/^## 用户通知/,/^## /p' "$dep" | grep -qE "责任人|负责人" \
  || { echo "MISSING: 用户通知无责任人（无人负责的通知发不出去）"; missing=$((missing+1)); }

# ---- 支持期义务：必须有具体到期日 ----
sed -n '/^## 支持期义务/,/^## /p' "$dep" | grep -qE "[0-9]{4}-[0-9]{2}-[0-9]{2}" \
  || { echo "MISSING: 支持期义务无具体到期日（口头承诺不可审计，EU CRA 语境下须写死）"; missing=$((missing+1)); }

# ---- 退役完成核对项：人类核对人（宪法 C14 · C15）----
rn=$(grep -cE "^- \[[ x]\] R-[0-9]+" "$dep" || true)
[ "$rn" -ge 1 ] || { echo "MISSING: 无退役完成核对项（R-N）"; missing=$((missing+1)); }
noowner=$(grep -E "^- \[[ x]\] R-[0-9]+" "$dep" | grep -cv "核对人：" || true)
[ "$noowner" -eq 0 ] || { echo "MISSING: ${noowner} 项完成核对缺'核对人：'"; missing=$((missing+1)); }
fake=$(grep -E "^- \[[ x]\] R-[0-9]+" "$dep" | grep -ciE "核对人：[[:space:]]*(<待填>|agent|claude|ai|自动|系统)" || true)
[ "$fake" -eq 0 ] || { echo "MISSING: ${fake} 项核对人非人类署名（宪法 C14 不得自批）"; missing=$((missing+1)); }

# ---- --final 终检（门禁⑤ 前）----
if [ "$mode" = "--final" ]; then
  open_r=$(grep -cE "^- \[ \] R-[0-9]+" "$dep" || true)
  [ "$open_r" -eq 0 ] || { echo "MISSING(final): ${open_r} 项退役完成核对未勾选——不得过门禁⑤"; missing=$((missing+1)); }
  # 占位符扫描（finding #3 修复：反向设计——code span 外任何 <...> 都算未决，仅门禁块 <待填> 豁免）
  art_has_placeholder "$dep" \
    && { echo "MISSING(final): 存在未决占位符（责任人/日期/证据没填完）"; missing=$((missing+1)); }
  grep -qE "密钥|权限吊销" "$dep" \
    || { echo "MISSING(final): 完成核对未覆盖密钥与权限吊销（宪法 C15）"; missing=$((missing+1)); }
  grep -qE "账单|成本" "$dep" \
    || { echo "MISSING(final): 完成核对未覆盖账单归零（僵尸成本）"; missing=$((missing+1)); }
  sed -n '/^## 时间线与不可逆点/,/^## /p' "$dep" | grep -qE "是|不可逆" \
    || { echo "MISSING(final): 时间线未标不可逆点"; missing=$((missing+1)); }
fi

# ---- 门禁⑤ 记录块批准人校验（finding #9：此前只解析"决定："）----
gate5_owner=$(grep -E '^- 批准人：' "$dep" | head -1 | sed -E 's/^- 批准人：[[:space:]]*//')
if [ -n "$gate5_owner" ] && [ "$gate5_owner" != "<待填>" ]; then
  art_looks_nonhuman "$gate5_owner" \
    && { echo "MISSING: 门禁⑤ 批准人非人类署名（\"${gate5_owner}\"）——宪法 C14 执行者不得自批"; missing=$((missing+1)); }
fi

# 门禁台账 fail-open 修复：校验本文件自己的决定值合法（gate.sh 单一实现）
gate_assert_legal "$dep" 批准 打回 || missing=$((missing+1))
gate5=$(gate_status "$dep")
[ "$missing" -gt 0 ] && { echo "FAIL(66): 缺 ${missing} 项"; exit 66; }
echo "PASS: deprecation 结构完整 | 类型=${rtype:-未知} | 完成核对 ${rn} 项 | 门禁⑤=${gate5}"
exit 0
