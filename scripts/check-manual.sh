#!/usr/bin/env bash
# check-manual.sh — 实施手册结构契约（SPEC-24）
#
# 为什么需要：手册是交付物，但文档最容易"看起来齐全"。SPEC-24 列了七个必备章节，
# 缺任何一节都会让客户在那个环节卡住而手册帮不上忙。
#
# 本探针只查**结构与硬事实**，不评判文笔：
#   ① SPEC-24 七个必备章节存在
#   ② 关键命令在本仓真实存在（防手册教人跑一条不存在的命令）
#   ③ 版本基线字段非占位符
#   ④ 已知限制节非空（不许把"已知限制"写成空壳）
#
# 用法：bash scripts/check-manual.sh [<手册路径>]
# 退出码：0=通过  66=结构缺项  65=文件不存在

set -uo pipefail
_root=$(cd "$(dirname "$0")/.." && pwd)
MAN="${1:-$_root/docs/implementation-manual.md}"
[ -f "$MAN" ] || { echo "FAIL(65): 手册不存在：$MAN"; exit 65; }

missing=0
echo "== 实施手册结构检查（SPEC-24）｜ $(basename "$MAN") =="

# ---- ① SPEC-24 七个必备章节 ----
# 用关键词而非精确标题：标题措辞可演进，语义不可缺失
check_sec() {  # check_sec <人类可读名> <ERE 关键词>
  if grep -qiE "$2" "$MAN"; then
    printf '  ✅ %s\n' "$1"
  else
    printf '  ❌ %s（SPEC-24 必备，缺失）\n' "$1"; missing=$((missing+1))
  fi
}
check_sec "安装与前置（doctor）"        '^#+ .*(安装与前置|doctor)'
check_sec "绿地路径"                    '^#+ .*绿地路径'
check_sec "存量治理 playbook"           '^#+ .*存量治理'
check_sec "L4 实施指引"                 '^#+ .*L4 实施指引'
check_sec "已知限制"                    '^#+ .*已知限制'
check_sec "版本基线字段"                '^#+ .*版本基线'
check_sec "门禁分级说明（试点/企业）"   '试点模式.*企业模式|企业模式.*试点模式'

# ---- ② 手册里教的命令必须真实存在（防教人跑不存在的命令）----
echo "-- 命令存在性（手册不许教人跑一条不存在的命令）--"
# 抽取 `bash <路径>` 形式的仓内脚本引用
refs=$(grep -oE 'bash (bin|scripts|ops|tests|\.claude)/[A-Za-z0-9_./-]+\.sh|bash bin/e2e' "$MAN" \
       | sed -E 's/^bash //' | sort -u)
nref=0; nbad=0
while IFS= read -r r; do
  [ -n "$r" ] || continue
  nref=$((nref+1))
  if [ ! -e "$_root/$r" ]; then
    printf '  ❌ 手册引用了不存在的 %s\n' "$r"; nbad=$((nbad+1))
  fi
done <<EOF
$refs
EOF
if [ "$nref" -lt 3 ]; then
  echo "  ❌ 只抽到 ${nref} 条命令引用——抽取失效或手册无可执行指引"; missing=$((missing+1))
elif [ "$nbad" -eq 0 ]; then
  printf '  ✅ %s 条命令引用全部指向真实文件\n' "$nref"
else
  missing=$((missing+nbad))
fi

# ---- ③ 版本基线字段非占位符 ----
echo "-- 版本基线字段 --"
if grep -qE '平台版本' "$MAN" && ! grep -qE '版本基线[^#]*<待填>' "$MAN"; then
  printf '  ✅ 版本基线含具体值\n'
else
  printf '  ❌ 版本基线缺失或仍是占位符\n'; missing=$((missing+1))
fi

# ---- ④ 已知限制节必须有实质内容（不许写成空壳）----
echo "-- 已知限制实质性 --"
lim=$(awk '/^#+ .*已知限制/{f=1;next} /^## /{if(f)exit} f' "$MAN" \
      | grep -vE '^\s*$|^\|[-: |]+\|$' | grep -c . || true)
: "${lim:=0}"
if [ "$lim" -ge 10 ]; then
  printf '  ✅ 已知限制 %s 行实质内容\n' "$lim"
else
  printf '  ❌ 已知限制仅 %s 行——空壳限制节等于没写（诚实交付的底线）\n' "$lim"; missing=$((missing+1))
fi

# ---- ⑤ 不得出现夸大表述（对照已知限制自查）----
echo "-- 表述边界自查 --"
overclaim=$(grep -nE '完全(安全|可靠)|保证不会|100% (安全|正确)|已证明不可能' "$MAN" | grep -v '不得' || true)
if [ -n "$overclaim" ]; then
  echo "  ❌ 存在夸大表述（与 §已知限制 矛盾）："
  printf '%s\n' "$overclaim" | head -3 | sed 's/^/     /'
  missing=$((missing+1))
else
  printf '  ✅ 无夸大表述\n'
fi

echo
if [ "$missing" -gt 0 ]; then
  echo "FAIL(66): 手册缺 ${missing} 项"
  exit 66
fi
echo "PASS: 手册结构完整（SPEC-24）"
exit 0
