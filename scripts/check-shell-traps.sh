#!/usr/bin/env bash
# check-shell-traps.sh — bash 高危写法探针（ADR-007 的"高危写法清单"可执行化）
#
# 起源：M1 期间同一个 bug 犯了两次——`$var` 后紧跟中文全角标点时，
# bash 把标点字节并入变量名，导致 `unbound variable`（set -u 下直接崩）。
# 这类陷阱靠"记得小心"防不住，必须做成常驻探针（宪法 C2/C13）。
#
# 用法: bash scripts/check-shell-traps.sh [目录]
# 退出码: 0=无命中 / 66=有高危写法
set -u
cd "$(dirname "$0")/.." || exit 1
target="${1:-.}"
hits=0

echo "== bash 高危写法扫描 =="

# 陷阱1：$var 紧跟非 ASCII 字符（中文标点）→ 变量名污染
# 正确写法：${var}中文
t1=$(grep -rnP '\$[a-zA-Z_][a-zA-Z0-9_]*(?=[^\x00-\x7F])' --include="*.sh" "$target" 2>/dev/null || true)
if [ -n "$t1" ]; then
  echo "❌ 陷阱1：\$var 紧跟中文标点（bash 会并入变量名）——改用 \${var}"
  printf '%s\n' "$t1" | sed 's/^/   /'
  hits=$((hits + $(printf '%s\n' "$t1" | grep -c .)))
fi

# 陷阱2：GNU-only 写法（ADR-007：仅 macOS 实测，但避免绑死 BSD 之外无法迁移）
# sed -i 无备份参数在 BSD 上语法不同；grep -P 在部分 BSD 上缺失（本机可用，故仅 WARN）
# 排除本脚本自身（其注释与提示串含被检模式，会自指误报）与注释行
t2=$(grep -rn "sed -i " --include="*.sh" "$target" 2>/dev/null \
     | grep -v "sed -i ''" | grep -v "check-shell-traps.sh" | grep -vE ':[0-9]+:[[:space:]]*#' || true)
if [ -n "$t2" ]; then
  echo "⚠️  陷阱2（WARN）：sed -i 无 '' 参数——BSD/GNU 语法分歧点"
  printf '%s\n' "$t2" | sed 's/^/   /'
fi

if [ "$hits" -gt 0 ]; then
  echo "FAIL(66): $hits 处高危写法"
  exit 66
fi
echo "PASS: 无高危写法"
exit 0
