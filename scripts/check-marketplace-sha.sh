#!/usr/bin/env bash
# check-marketplace-sha.sh — 插件市场钉的 sha 不得落后于被分发内容的最新改动
#
# 为什么需要（冷启动验收 blocker）：
#   `.claude-plugin/marketplace.json` 的 `source.sha` 是**手动**维护的。
#   实测它曾落后 main 9 个 commit，而且**正好停在修 2 条 critical 之前** ——
#   于是照 README 装插件的人，拿到的评审探针带着已知的 fail-open bug。
#   钉版（C15）本身是对的，但"钉住一个旧版本"比不钉更危险：
#   它让人以为拿到的是当前版本。
#
# 判据：钉的 sha 之后，**被分发的路径**（source.path，默认 .claude）如果还有改动，
#   就说明分发内容已过期 → FAIL。
#   注意：只看被分发路径的改动。仓里改别的（如 docs/）不影响插件内容，不该报错。
#
# 用法：bash scripts/check-marketplace-sha.sh [<repo-root>]
# 退出码：0=最新  1=已过期  66=自检失败/无法判定（fail-closed）

set -uo pipefail

if [ $# -ge 1 ]; then
  ROOT="$(cd "$1" 2>/dev/null && pwd)" || { echo "自检失败：目录不存在 $1" >&2; exit 66; }
else
  ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || { echo "自检失败：不在 git 工作区" >&2; exit 66; }
fi
cd "${ROOT}"

M=".claude-plugin/marketplace.json"
[ -f "$M" ] || { echo "跳过：本仓无 ${M}（未做插件分发）"; exit 0; }
command -v python3 >/dev/null 2>&1 || { echo "自检失败：需要 python3 解析 JSON" >&2; exit 66; }

echo "== 插件市场 sha 时效检查 ｜ ${ROOT} =="

# ---- 取出每个插件的 sha 与 path ----
INFO=$(python3 - "$M" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
for p in d.get('plugins', []):
    src = p.get('source', {})
    print(f"{p.get('name','?')}\t{src.get('sha','')}\t{src.get('path','.')}")
PY
) || { echo "自检失败：marketplace.json 解析失败" >&2; exit 66; }

[ -n "${INFO}" ] || { echo "FAIL(66): marketplace.json 里没有任何 plugin —— 无可检对象" >&2; exit 66; }

bad=0
while IFS=$'\t' read -r name sha path; do
  [ -n "$name" ] || continue
  printf '  -- %s（path=%s）--\n' "$name" "${path:-.}"

  if [ -z "$sha" ]; then
    echo "     ❌ 未钉 sha —— 客户装到的是 ref 的当前状态，不可复现（C15）"
    bad=$((bad + 1)); continue
  fi
  if ! git cat-file -e "${sha}^{commit}" 2>/dev/null; then
    # 区分「sha 写错」与「历史不全」—— 误诊会让人去改一个没错的东西。
    # CI 默认浅克隆（fetch-depth: 1），本探针在那里会把正确的 sha 报成"不存在"。
    if [ -f "$(git rev-parse --git-dir)/shallow" ]; then
      # 这是**无法判定**（66），不是"已过期"（1）——报成过期会让人去改一个没错的 sha。
      echo "FAIL(66): 无法判定 —— 这是**浅克隆**，历史不全，取不到 sha ${sha:0:12}" >&2
      echo "   这不代表 sha 写错了。修法：CI 的 checkout 加 fetch-depth: 0" >&2
      exit 66
    fi
    echo "     ❌ sha ${sha:0:12} 在本仓不存在（写错或已被 rebase 掉）"
    bad=$((bad + 1)); continue
  fi

  # 该 sha 之后，被分发路径还有没有改动
  n=$(git rev-list --count "${sha}..HEAD" -- "${path:-.}" 2>/dev/null || echo '?')
  if [ "$n" = "?" ]; then
    echo "     ❌ 无法比较（git rev-list 失败）—— fail-closed"
    bad=$((bad + 1)); continue
  fi
  if [ "$n" -eq 0 ]; then
    printf '     ✅ sha %s 已是最新（%s 自该 commit 起无改动）\n' "${sha:0:12}" "${path:-.}"
  else
    printf '     ❌ sha %s 已过期：%s 之后 %s 处改动未分发\n' "${sha:0:12}" "${path:-.}" "$n"
    git log --oneline "${sha}..HEAD" -- "${path:-.}" 2>/dev/null | head -5 | sed 's/^/        /'
    printf '        修法：sha 改为 %s\n' "$(git rev-parse HEAD)"
    bad=$((bad + 1))
  fi
done <<EOF
${INFO}
EOF

echo
if [ "$bad" -gt 0 ]; then
  cat >&2 <<EOF
❌ FAIL：${bad} 个插件的 sha 有问题。
   钉住一个**旧**版本比不钉更危险 —— 它让人以为拿到的是当前版本。
   实测事故：sha 曾停在修 2 条门禁绕过 critical 之前，装插件的人拿到带 bug 的探针。
EOF
  exit 1
fi
echo "PASS: 插件分发内容为最新"
