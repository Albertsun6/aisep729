#!/usr/bin/env bash
# check-readme.sh — README 是公开仓的门面，链接烂掉/数字过期最丢人
#
# 为什么需要：README 是**第一眼**看到的东西。它一旦引用不存在的文件、
# 教一条跑不通的命令、或声称一个已经过期的数字，读者对整个项目的信任就没了。
# 而这类腐烂**只随时间发生**（文件改名、探针增减、文档增删），靠人记不住。
#
# 本探针查四件事：
#   ① README 存在且非空壳
#   ② 所有仓内相对链接 `](./path)` 指向真实文件/目录
#   ③ 所有教给读者的 `bash <path>` 命令，那个文件真的存在
#   ④ 必须包含「已知限制」段 —— 门面不许只说好话
#
# 数字（skill 数 / 负样本数等）**不在此机器校验**：它们随版本变化，
# 硬编码校验会变成噪音。改为在 §已知限制 强制存在，逼作者对账。
#
# 用法：bash scripts/check-readme.sh [<repo-root>]
# 退出码：0=通过  1=有失效引用  65=无 README  66=自检失败

set -uo pipefail

if [ $# -ge 1 ]; then
  ROOT="$(cd "$1" 2>/dev/null && pwd)" || { echo "自检失败：目录不存在 $1" >&2; exit 66; }
else
  ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || ROOT="$(pwd)"
fi
cd "${ROOT}"

R="README.md"
[ -f "$R" ] || { echo "FAIL(65): 无 README.md —— 公开仓第一眼没有任何导航"; exit 65; }

# ---- 自检金丝雀：链接抽取引擎必须真能工作 ----
_c=$(mktemp)
printf '见 [手册](./docs/x.md) 与 [许可](./LICENSE)。\n跑 `bash scripts/y.sh` 验收。\n' > "$_c"
_l=$(grep -oE '\]\(\./[^)]+\)' "$_c" | grep -c . || true)
_b=$(grep -oE 'bash (bin|scripts|tests|ops)/[A-Za-z0-9_./-]+' "$_c" | grep -c . || true)
rm -f "$_c"
if [ "${_l:-0}" -ne 2 ] || [ "${_b:-0}" -ne 1 ]; then
  echo "自检失败：抽取引擎异常（金丝雀应命中 链接2/命令1，实得 ${_l}/${_b}）" >&2
  exit 66
fi

echo "== README 门面检查 ｜ ${ROOT} =="
bad=0

# ---- ① 非空壳 ----
lines=$(grep -vcE '^[[:space:]]*$' "$R" || true); : "${lines:=0}"
if [ "$lines" -lt 20 ]; then
  echo "  ❌ README 仅 ${lines} 行实质内容 —— 空壳门面等于没有"; bad=$((bad+1))
else
  echo "  ✅ ${lines} 行实质内容"
fi

# ---- ② 仓内相对链接必须存在 ----
nl=0
while IFS= read -r p; do
  [ -n "$p" ] || continue
  nl=$((nl+1))
  [ -e "$p" ] || { printf '  ❌ 链接指向不存在的 %s\n' "$p"; bad=$((bad+1)); }
done <<EOF
$(grep -oE '\]\(\./[^)]+\)' "$R" | sed 's/^](\.\///; s/)$//' | sort -u)
EOF
if [ "$nl" -eq 0 ]; then
  echo "  ❌ 抽到 0 条仓内链接 —— 抽取失效或 README 无导航"; bad=$((bad+1))
else
  echo "  ✅ ${nl} 条仓内链接全部指向真实路径"
fi

# ---- ③ 教给读者的命令必须真的存在 ----
nc=0
while IFS= read -r c; do
  [ -n "$c" ] || continue
  nc=$((nc+1))
  [ -e "$c" ] || { printf '  ❌ 教了一条跑不通的命令：bash %s\n' "$c"; bad=$((bad+1)); }
done <<EOF
$(grep -oE 'bash (bin|scripts|tests|ops)/[A-Za-z0-9_./-]+' "$R" | sed 's/^bash //' | sort -u)
EOF
if [ "$nc" -eq 0 ]; then
  echo "  ❌ 抽到 0 条命令 —— README 无可执行上手路径"; bad=$((bad+1))
else
  echo "  ✅ ${nc} 条命令全部指向真实文件"
fi

# ---- ④ 必须有「已知限制」段（门面不许只说好话）----
if grep -qE '^#+ .*(已知限制|Known [Ll]imitations)' "$R"; then
  seg=$(awk '/^#+ .*(已知限制|Known [Ll]imitations)/{f=1;next} /^#+ /{if(f)exit} f' "$R" \
        | grep -vcE '^[[:space:]]*$' || true); : "${seg:=0}"
  if [ "$seg" -ge 5 ]; then
    echo "  ✅ 已知限制段 ${seg} 行"
  else
    echo "  ❌ 已知限制段仅 ${seg} 行 —— 空壳限制等于没写"; bad=$((bad+1))
  fi
else
  echo "  ❌ 缺「已知限制」段 —— 门面只说好话是欺骗"; bad=$((bad+1))
fi

echo
if [ "$bad" -gt 0 ]; then
  echo "FAIL(1): README 有 ${bad} 处问题" >&2
  exit 1
fi
echo "PASS: README 门面完好"
