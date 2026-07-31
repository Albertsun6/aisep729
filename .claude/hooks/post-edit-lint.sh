#!/usr/bin/env bash
# post-edit-lint.sh — PostToolUse hook：文件编辑后立即检查（SPEC-15）
#
# 定位（宪法 C3）：**本地快反馈，不是安全边界**。
#   hooks 的过滤是 best-effort/fail-open（官方明示），硬策略靠 permission system + 服务端 CI。
#   本 hook 的价值是"改完 3 秒内就知道踩了坑"，而不是"拦住坏人"。
#
# 输入：stdin 收到 PostToolUse 的 JSON（含 tool_name / tool_input.file_path）
# 输出：exit 0=通过；exit 2=有问题（stderr 内容回喂给 Claude，让它当场修）
set -u
_root=$(cd "$(dirname "$0")/../.." && pwd)
payload=$(cat 2>/dev/null || echo "{}")

# 取被编辑的文件路径（无 jq 时退化为 grep，保持零依赖 ADR-010）
if command -v jq >/dev/null 2>&1; then
  fp=$(printf '%s' "$payload" | jq -r '.tool_input.file_path // empty' 2>/dev/null || echo "")
else
  fp=$(printf '%s' "$payload" | grep -o '"file_path"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*"\([^"]*\)"$/\1/')
fi
[ -n "$fp" ] || exit 0          # 拿不到路径就静默放行（本地反馈层，不阻塞工作）
[ -f "$fp" ] || exit 0

problems=""

# --- shell 脚本：bash 高危写法（本仓踩过三次的 $var+中文标点陷阱）---
case "$fp" in
  *.sh)
    if out=$(bash "$_root/scripts/check-shell-traps.sh" "$fp" 2>&1); then :; else
      problems="${problems}\n[bash 高危写法]\n${out}"
    fi
    # 语法检查（比风格重要得多）
    if ! bash -n "$fp" 2>/tmp/e2e-syntax.$$; then
      problems="${problems}\n[语法错误]\n$(cat /tmp/e2e-syntax.$$)"
    fi
    rm -f /tmp/e2e-syntax.$$
    ;;
esac

# --- 制品类：门禁块格式（防模板/探针漂移）---
case "$fp" in
  */specs/*/prfaq.md|*/specs/*/prd.md|*/specs/*/spec.md|*/specs/*/review.md|*/specs/*/release.md)
    if grep -q "门禁" "$fp" 2>/dev/null; then
      grep -qE '^- 决定：' "$fp" || problems="${problems}\n[门禁块] 缺 '- 决定：' 行（各阶段探针依赖此格式）"
    fi
    ;;
esac

if [ -n "$problems" ]; then
  printf '⚠️ post-edit 检查发现问题（本地快反馈，非阻断门禁）：%b\n' "$problems" >&2
  exit 2
fi
exit 0
