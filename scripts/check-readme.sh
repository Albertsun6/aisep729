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

# ---- ④ 声称的负样本条数必须等于实跑值 ----
# 冷启动验收 blocker：README 把负样本数称为「这是本项目最重要的数字」，
# 而这个数字在 6 个地方是 6 个值（README 75 / USAGE 71 / marketplace 58 /
# 手册 56 / release.md 66 / 实跑 80），没有一个对。
# 一个把「可证伪断言」当立身之本的项目，最重要的那个数字自己没被任何断言钉住。
# 本探针只钉这一个数字 —— 因为它是被明确标注为「最重要」的那个。
echo "-- 负样本条数对账 --"
if [ -x tests/probe-negative/run.sh ] || [ -f tests/probe-negative/run.sh ]; then
  actual=$(bash tests/probe-negative/run.sh 2>/dev/null | tail -1 | grep -oE '[0-9]+/[0-9]+' | cut -d/ -f2)
  : "${actual:=}"
  if [ -z "$actual" ]; then
    echo "  ❌ 跑不出实际条数 —— 无法对账（fail-closed）"; bad=$((bad+1))
  else
    claimed=$(grep -oE '\*\*负样本\*\* \| \*\*[0-9]+\*\*' "$R" | grep -oE '[0-9]+' | head -1)
    : "${claimed:=}"
    if [ -z "$claimed" ]; then
      echo "  ⚠️  README 未声称负样本条数，跳过对账"
    elif [ "$claimed" = "$actual" ]; then
      printf '  ✅ 负样本条数对账一致：%s\n' "$actual"
    else
      printf '  ❌ README 声称 %s 条，实跑 %s 条 —— 最重要的数字自己对不上账\n' "$claimed" "$actual"
      bad=$((bad+1))
    fi
    # A7（platform-hardening）：手册 §8 验证基线同数对账——"手动数字必漂移"这病
    # 曾在本仓最承重的两处复发（CLAUDE.md 与手册 §8 写 97/97，实跑已 106/106，评估 D4）。
    # CLAUDE.md 未入库、CI 对不了账，已改为不携带硬数字；手册是入库文档，在此钉住。
    if [ -f docs/implementation-manual.md ]; then
      mclaimed=$(grep -oE '负样本 \*\*[0-9]+/[0-9]+\*\*' docs/implementation-manual.md | head -1 | grep -oE '[0-9]+' | head -1)
      : "${mclaimed:=}"
      if [ -z "$mclaimed" ]; then
        echo "  ⚠️  手册未声称负样本基线，跳过对账"
      elif [ "$mclaimed" = "$actual" ]; then
        printf '  ✅ 手册 §8 负样本基线对账一致：%s\n' "$actual"
      else
        printf '  ❌ 手册 §8 声称 %s，实跑 %s —— 手动维护的数字必然过期\n' "$mclaimed" "$actual"
        bad=$((bad+1))
      fi
    fi
  fi
else
  echo "  ⚠️  无 tests/probe-negative/run.sh，跳过对账"
fi

# ---- ④b 声称的探针条数必须等于实际文件数 ----
# 与负样本同一类毛病：手动维护的数字必然过期。实测 README 写 10、实有 13
# —— 差的三个恰是最近加的（README 门面 / 插件 sha / adopt 对等），
# 也就是说**越新的能力越不会被数进去**。
echo "-- 探针条数对账 --"
np=$(ls scripts/check-*.sh ops/check-*.sh 2>/dev/null | grep -c . || true); : "${np:=0}"
if [ "$np" -eq 0 ]; then
  echo "  ⚠️  未找到任何探针文件，跳过对账"
else
  cp_claim=$(grep -oE '\| 探针 \| \*\*[0-9]+\*\*' "$R" | grep -oE '[0-9]+' | head -1)
  : "${cp_claim:=}"
  if [ -z "$cp_claim" ]; then
    echo "  ⚠️  README 未声称探针条数，跳过对账"
  elif [ "$cp_claim" = "$np" ]; then
    printf '  ✅ 探针条数对账一致：%s\n' "$np"
  else
    printf '  ❌ README 声称 %s 个探针，实有 %s 个 —— 新加的能力没被数进去\n' "$cp_claim" "$np"
    bad=$((bad+1))
  fi
fi

# ---- ⑤ 必须有「已知限制」段（门面不许只说好话）----
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
