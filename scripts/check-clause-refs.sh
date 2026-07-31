#!/usr/bin/env bash
# check-clause-refs.sh — 被引用的宪法条款号必须真实存在（条款层的 fail-open 防线）
#
# 根因（与 check-skill-deps.sh 同类，只是发生在条款层）：
#   `.claude/agents/security.md` 写着"按宪法 C14 检查批准归因"，若本仓 constitution.md
#   只定义到 C5，agent 读不到 C14 —— **不会报错，而是按无约束继续**。
#   实测：demo 仓宪法只有 C1-C5，全仓却引用 C6-C15，其中 C12（异构评审）、C13（探针可
#   证伪）、C14（不得自批）正是整套评审门禁的规范依据 —— 全部悬空。
#
# 用法：bash scripts/check-clause-refs.sh [<repo-root>]
# 退出码：0=全部有定义  1=有悬空引用  66=自检失败/无宪法（fail-closed）

set -euo pipefail

if [ $# -ge 1 ]; then
  ROOT="$(cd "$1" 2>/dev/null && pwd)" || { echo "自检失败：目录不存在 $1" >&2; exit 66; }
else
  ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || ROOT="$(pwd)"
fi
cd "${ROOT}"

CONST="docs/constitution.md"
[ -f "${CONST}" ] || { echo "FAIL(66): 无 ${CONST} —— 无法校验条款引用（判为失败，不跳过）" >&2; exit 66; }

# ---- 定义集：宪法里以 `- **CN ` 形式声明的条款 ----
# `|| true` 不可省：pipefail 下 grep 无匹配退出 1，命令替换会直接终止脚本，
# 使下面"抽取失效 → 66"的分支**永远到不了**（负样本当场抓到：期望 66 实得 1）。
defined=$(grep -oE '^- \*\*C[0-9]+' "${CONST}" 2>/dev/null | grep -oE 'C[0-9]+' | sort -u || true)
ndef=$(printf '%s\n' "${defined}" | grep -c . || true)

# 自检金丝雀：定义集为空说明抽取失效（宪法格式变了），不是"没有条款"
if [ "${ndef}" -lt 1 ]; then
  echo "FAIL(66): 从 ${CONST} 抽出 0 条条款定义 —— 判为抽取失效而非'宪法为空'" >&2
  exit 66
fi

echo "== 宪法条款引用校验 ｜ ${ROOT} =="
echo "   已定义 ${ndef} 条：$(printf '%s' "${defined}" | tr '\n' ' ')"

# ---- 引用集：全仓 md 里出现的 CN（排除宪法自身的定义行）----
# 只认「宪法 C14」「C14（…）」「宪法 C12/C13」这类形态，避免把 C4 引擎名之类误抓。
refs=$(grep -rhoE '(宪法|Constitution)[^。\n]{0,20}C[0-9]+|C[0-9]+（|C[0-9]+[[:space:]]*：' \
        --include='*.md' docs .claude specs 2>/dev/null \
        | grep -oE 'C[0-9]+' | sort -u || true)

dangling=""
for r in ${refs}; do
  printf '%s\n' "${defined}" | grep -qx "${r}" || dangling="${dangling} ${r}"
done

if [ -n "${dangling}" ]; then
  cat >&2 <<EOF
❌ FAIL：以下条款被引用但**未在 ${CONST} 中定义**：${dangling}
   后果不是"报错"，而是 agent/skill 读不到该条款后**按无约束继续**（fail-open）。
   修复：补齐条款定义，或把引用改成本仓真实存在的编号。
   引用位置：
EOF
  for r in ${dangling}; do
    grep -rn --include='*.md' -E "(宪法|Constitution)[^。]{0,20}${r}|${r}（|${r}[[:space:]]*：" \
      docs .claude specs 2>/dev/null | head -3 | sed 's/^/     /' >&2
  done
  exit 1
fi

echo "PASS: 所有被引用的条款均有定义"
