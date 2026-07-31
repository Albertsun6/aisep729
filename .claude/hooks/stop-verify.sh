#!/usr/bin/env bash
# stop-verify.sh — Stop hook：测试未过不许收工（SPEC-16，Spotify 实证模式）
#
# 定位（宪法 C3）：**本地快反馈，不是安全边界**。
#   真正拦不住的门禁在服务端（受保护分支 + required checks）。本 hook 防的是
#   "改完没验证就说完成了"这种最常见的自欺——Spotify 实测：Stop hook 拦在开 PR 前最省时。
#
# 输入：stdin 收到 Stop 的 JSON（含 stop_hook_active，用于防无限循环）
# 输出：exit 0=放行收工；exit 2=阻断（stderr 回喂 Claude，要求先修）
#
# 逃生阀：E2E_SKIP_STOP_HOOK=1 跳过（用于纯讨论/纯文档会话；**用了要自己知道为什么用**）
set -u
_root=$(cd "$(dirname "$0")/../.." && pwd)
payload=$(cat 2>/dev/null || echo "{}")

# 防循环：Claude 因本 hook 阻断后继续工作再次 Stop 时，stop_hook_active=true
case "$payload" in *'"stop_hook_active":true'*|*'"stop_hook_active": true'*) exit 0 ;; esac
[ "${E2E_SKIP_STOP_HOOK:-0}" = "1" ] && exit 0

cd "$_root" || exit 0

# 只在工作区真有改动时才验（纯讨论会话不打扰）
if git rev-parse --git-dir >/dev/null 2>&1; then
  git diff --quiet && git diff --cached --quiet && exit 0
fi

fails=""
run() {  # run <名称> <命令...>
  local name="$1"; shift
  "$@" >/tmp/e2e-stop.$$ 2>&1 || fails="${fails}\n[${name}]\n$(tail -12 /tmp/e2e-stop.$$)"
  rm -f /tmp/e2e-stop.$$
}

run "bash 高危写法" bash scripts/check-shell-traps.sh
run "六件套结构"   bash scripts/check-structure.sh
run "自包含"       bash scripts/check-selfcontained.sh
run "探针负样本"   bash tests/probe-negative/run.sh

if [ -n "$fails" ]; then
  printf '🛑 收工前验证未通过——先修好再结束（宪法 C2：能验证的绝不用"我觉得对了"）：%b\n\n（确需跳过：E2E_SKIP_STOP_HOOK=1，但你要知道自己在跳过什么）\n' "$fails" >&2
  exit 2
fi
exit 0
