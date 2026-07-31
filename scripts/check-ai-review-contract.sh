#!/usr/bin/env bash
# check-ai-review-contract.sh — AI 评审 workflow 必须遵守三通道契约
#
# 为什么需要：本平台的核心契约是「确定性规则是唯一 blocker 来源，LLM 只出建议」。
# 而 `ai-review.yml(.template)` 早期版本写的是 `blocks>0 → exit 1` ——
# **直接把阻断权交给了 LLM**，违反平台自己的契约（自举安全评审 finding）。
#
# 更麻烦的是它的连带效应：`pull_request` 触发时 fork PR 拿不到 secrets → job 红，
# 踩到的人最可能的"修法"是改成 `pull_request_target` —— 那是经典 pwn request 漏洞
# （GitHub 2026-06 已让 actions/checkout v7 默认拒绝该组合）。
#
# 本探针把三条性质钉死：
#   ① 不得有基于 LLM 输出的失败路径（exit 1 / ::error / blocks -gt 之类）
#   ② 触发器不得是 pull_request_target
#   ③ 必须显式声明"本 job 不得设为 required check"
#
# 用法：bash scripts/check-ai-review-contract.sh [<repo-root>]
# 退出码：0=合规  1=违反契约  66=自检失败/无可检对象（fail-closed）

set -uo pipefail

if [ $# -ge 1 ]; then
  ROOT="$(cd "$1" 2>/dev/null && pwd)" || { echo "自检失败：目录不存在 $1" >&2; exit 66; }
else
  ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || ROOT="$(pwd)"
fi
cd "${ROOT}"

# ---- 自检金丝雀：判定引擎必须真能区分「注释里提到」与「真实代码」 ----
_c=$(mktemp)
printf '# 早期写的是 blocks>0 则 exit 1，已废弃\n          exit 1\n' > "$_c"
_hit=$(grep -nE 'exit 1' "$_c" | grep -cvE '^\s*[0-9]+:\s*#' || true)
rm -f "$_c"
if [ "${_hit:-0}" -ne 1 ]; then
  echo "自检失败：注释剔除逻辑异常（金丝雀应命中 1 条真实代码，实得 ${_hit}）" >&2
  exit 66
fi

# ---- 收集待检文件（.yml 与 .yml.template 都要检）----
FILES=$(ls .github/workflows/ai-review.yml .github/workflows/ai-review.yml.template 2>/dev/null || true)
if [ -z "${FILES}" ]; then
  echo "跳过：本仓无 ai-review workflow（该能力可选）"
  exit 0
fi

echo "== AI 评审三通道契约检查 ｜ ${ROOT} =="
bad=0

while IFS= read -r f; do
  [ -n "$f" ] || continue
  printf '  -- %s --\n' "$f"

  # ① 不得有基于 LLM 输出的失败路径（剔除注释行）
  fail_paths=$(grep -nE 'exit 1|::error|blocks[^)]*-gt' "$f" 2>/dev/null \
               | grep -vE '^\s*[0-9]+:\s*#' | grep -vE 'ai-review-contract' || true)
  if [ -n "${fail_paths}" ]; then
    echo "     ❌ 存在可能让 LLM 结果决定 CI 成败的路径（违反通道③ 无阻断权）："
    printf '%s\n' "${fail_paths}" | head -3 | sed 's/^/        /'
    bad=$((bad + 1))
  else
    echo "     ✅ 无基于 LLM 输出的失败路径"
  fi

  # ② 触发器不得是 pull_request_target（剔除注释）
  if grep -nE '^[[:space:]]*pull_request_target[[:space:]]*:' "$f" 2>/dev/null | grep -qvE '^\s*[0-9]+:\s*#'; then
    echo "     ❌ 使用了 pull_request_target —— 经典 pwn request 漏洞"
    bad=$((bad + 1))
  else
    echo "     ✅ 未使用 pull_request_target"
  fi

  # ③ 必须显式声明不得设为 required check
  if grep -qE '不能设为 required check|不得设为 required check|不要.*加进 required checks' "$f" 2>/dev/null; then
    echo "     ✅ 已显式声明不得设为 required check"
  else
    echo "     ❌ 未声明「不得设为 required check」—— 契约要靠读的人看见"
    bad=$((bad + 1))
  fi
done <<EOF
$FILES
EOF

echo
if [ "${bad}" -gt 0 ]; then
  cat >&2 <<EOF
❌ FAIL：${bad} 处违反 AI 评审三通道契约。
   契约：确定性规则是**唯一** blocker 来源；LLM 只出证据与建议，不出判决。
   LLM 提的问题若真的该阻断，正确做法是**把它变成一条会失败的可执行断言**，
   由那条断言（通道①）来阻断 —— 而不是让模型的输出直接决定 CI 成败。
EOF
  exit 1
fi
echo "PASS: AI 评审 workflow 遵守三通道契约"
