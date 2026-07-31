#!/usr/bin/env bash
# check-plugin-name.sh — 文档教的安装命令必须与 marketplace.json 声明的名字一致
#
# 起源（2026-07-31 更名 e2e-platform → aisep）：一次改名要同时改四个地方
# （marketplace.json / README / 实施手册 / runbook）。漏掉一个的后果**不是报错**，
# 是读者照着复制的那行命令装不上 —— 而作者本机早装好了，永远发现不了。
# 与「探针条数」「负样本条数」是同一类毛病：手动维护的字符串必然漂移；
# 差别在于这条漂了会让门面上最关键的一行命令直接失效。
#
# 判据：`.claude-plugin/marketplace.json` 是唯一真相。仓内 markdown 里每一处
#   `claude plugin install <plugin>[@<market>]`，plugin 必须在 plugins[].name 中，
#   market（写了的话）必须等于 manifest 顶层 name。
#
# 有意**不**查的两处（写在这里，免得后人当成漏洞补上）：
#   ① `docs/architecture/adr/` —— ADR 是决策记录，记的是**当时实际跑过**的命令；
#      更名后改写它等于声称跑过一条从未跑过的命令。这些出现只打印、不阻断。
#      代价是有人能把过期命令藏进 ADR 躲过检查 —— 已知、可接受、打印出来看得见。
#   ② 插件缓存落点 `plugins/cache/<市场名>/` 一类路径 —— 旧名的缓存路径是**事实**
#      （用旧版本装过的人就落在那），退役核对要覆盖新旧两处，不能按现名一刀切。
#
# 用法：bash scripts/check-plugin-name.sh [<repo-root>]
# 退出码：0=一致（或本仓无 marketplace.json）  1=有命令与 manifest 不一致
#         66=自检失败/无法判定（fail-closed）

set -uo pipefail

if [ $# -ge 1 ]; then
  ROOT="$(cd "$1" 2>/dev/null && pwd)" || { echo "自检失败：目录不存在 $1" >&2; exit 66; }
else
  ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || ROOT="$(pwd)"
fi
cd "${ROOT}"

M=".claude-plugin/marketplace.json"
[ -f "$M" ] || { echo "跳过：本仓无 ${M}（未做插件分发）"; exit 0; }
command -v python3 >/dev/null 2>&1 || { echo "自检失败：需要 python3 解析 JSON" >&2; exit 66; }

# ---- 抽取模式（BSD/GNU 通吃的 ERE；陷阱4：不得用 grep -P）----
PAT='claude plugin install[[:space:]]+[A-Za-z0-9_.-]+(@[A-Za-z0-9_.-]+)?'

# ---- 自检金丝雀：抽取引擎必须真能工作（C13，防"探针静默失效"）----
# 两种形态各一条：带 @market 的、不带的。命不中 2 条就说明模式退化了。
_c=$(mktemp)
printf '装：`claude plugin install aa@bb`，也可 `claude plugin install cc`。\n' > "$_c"
_n=$(grep -oE "$PAT" "$_c" | grep -c .); : "${_n:=0}"
rm -f "$_c"
if [ "${_n}" -ne 2 ]; then
  echo "自检失败：抽取引擎异常（金丝雀应命中 2 条，实得 ${_n}）" >&2
  exit 66
fi

echo "== 插件名一致性检查 ｜ ${ROOT} =="

# ---- 从 manifest 取唯一真相：第一行=市场名，其余=插件名 ----
INFO=$(python3 - "$M" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
print(d.get('name', ''))
for p in d.get('plugins', []):
    print(p.get('name', ''))
PY
) || { echo "FAIL(66): marketplace.json 解析失败 —— 无法判定（fail-closed）" >&2; exit 66; }

MARKET=$(printf '%s\n' "${INFO}" | head -1)
PLUGINS=$(printf '%s\n' "${INFO}" | tail -n +2 | grep -v '^[[:space:]]*$' || true)
if [ -z "${MARKET}" ]; then
  echo "FAIL(66): manifest 未声明 marketplace name —— 无法判定" >&2; exit 66
fi
if [ -z "${PLUGINS}" ]; then
  echo "FAIL(66): manifest 里没有任何 plugin —— 无可比对的真相" >&2; exit 66
fi
printf '  真相：market=%s ｜ plugin=%s\n' "${MARKET}" "$(printf '%s' "${PLUGINS}" | tr '\n' ',')"

# ---- 待扫文件：优先 git 跟踪的（那才是会发出去的），否则退回 find ----
if git rev-parse --git-dir >/dev/null 2>&1; then
  FILES=$(git ls-files '*.md' 2>/dev/null || true)
else
  FILES=$(find . -name '*.md' -not -path './.git/*' 2>/dev/null || true)
fi

bad=0; checked=0; adr=0
while IFS= read -r f; do
  [ -n "$f" ] || continue
  [ -f "$f" ] || continue
  case "$f" in
    docs/architecture/adr/*|./docs/architecture/adr/*) is_adr=1 ;;
    *) is_adr=0 ;;
  esac
  while IFS= read -r tok; do
    [ -n "$tok" ] || continue
    p=${tok%%@*}
    m=${tok#*@}
    [ "$m" = "$tok" ] && m=""      # 没写 @market 的形态
    if [ "$is_adr" = "1" ]; then
      adr=$((adr + 1))
      printf '  ℹ️  %s：历史命令 %s（ADR 记录，不阻断）\n' "$f" "$tok"
      continue
    fi
    checked=$((checked + 1))
    if ! printf '%s\n' "${PLUGINS}" | grep -qx -- "$p"; then
      printf '  ❌ %s：插件名 %s 不在 manifest 里（现为 %s）\n' \
        "$f" "$p" "$(printf '%s' "${PLUGINS}" | tr '\n' ',')"
      bad=$((bad + 1)); continue
    fi
    if [ -n "$m" ] && [ "$m" != "${MARKET}" ]; then
      printf '  ❌ %s：市场名 %s 与 manifest 的 %s 不一致\n' "$f" "$m" "${MARKET}"
      bad=$((bad + 1)); continue
    fi
    printf '  ✅ %s：%s\n' "$f" "$tok"
  done <<EOF
$(grep -oE "$PAT" "$f" 2>/dev/null | sed -E 's/^claude plugin install[[:space:]]+//' | sort -u)
EOF
done <<EOF
${FILES}
EOF

# ---- 一条都没抽到 = 无法判定，不是通过（这正是本探针要防的 fail-open）----
if [ "$checked" -eq 0 ]; then
  cat >&2 <<EOF
FAIL(66): 有 marketplace.json，却在 ADR 之外的文档里找不到任何安装命令 —— 无法判定。
   两种可能，都得治：① 抽取模式退化了；② 门面根本没教读者怎么装。
   （ADR 里另有 ${adr} 处历史命令，按设计不参与判定）
EOF
  exit 66
fi

echo
if [ "$bad" -gt 0 ]; then
  cat >&2 <<EOF
❌ FAIL：${bad} 处安装命令与 marketplace.json 不一致。
   后果不是报错，是读者复制那行命令**装不上**，而作者本机早装好了看不见。
   修法：以 ${M} 为准改文档，或确认 manifest 里的名字才是要改的那个。
EOF
  exit 1
fi
printf 'PASS: %s 处安装命令与 manifest 一致（另有 %s 处 ADR 历史命令未参与判定）\n' "$checked" "$adr"
