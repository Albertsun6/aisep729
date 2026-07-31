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
_here=$(cd "$(dirname "$0")/.." && pwd)
target="${1:-.}"
# 单文件时用绝对路径且不加 --include（-r --include 对单文件路径不生效——hook 实测踩过）
if [ -f "$target" ]; then
  case "$target" in /*) : ;; *) target="$(cd "$(dirname "$target")" && pwd)/$(basename "$target")" ;; esac
  GREP_SCOPE=""
else
  cd "$_here" || exit 1
  GREP_SCOPE="--include=*.sh"
fi
hits=0

echo "== bash 高危写法扫描 =="

# 扫描封装。两条实测教训（都造成过"探针静默失效"）：
#   ① 单文件不能用 -r（`-r --include` 组合对单文件路径返回空）
#   ② **不得用 grep -P**：macOS 自带 BSD grep 不支持 PCRE，会报 "invalid option -- P"，
#      配上 2>/dev/null || true 就变成"永远 PASS"——最危险的失败模式。改用 BSD/GNU 通吃的 ERE。
#      LC_ALL=C 让 [^ -~] 按字节匹配，从而命中中文（UTF-8 每字节 >0x7F）。
scan() {  # scan <ERE 模式>
  if [ -f "$target" ]; then LC_ALL=C grep -nE "$1" "$target" 2>/dev/null || true
  else LC_ALL=C grep -rnE "$1" --include="*.sh" "$target" 2>/dev/null || true; fi
}
scan_fixed() {  # 固定串版本（陷阱2 用）
  if [ -f "$target" ]; then grep -n "$1" "$target" 2>/dev/null || true
  else grep -rn "$1" --include="*.sh" "$target" 2>/dev/null || true; fi
}

# 自检：确认扫描引擎真的能工作（防"探针静默失效"复发，宪法 C13）
_canary=$(mktemp); printf 'v=1\necho "$v（陷阱）"\n' > "$_canary"
if ! LC_ALL=C grep -qE '\$[a-zA-Z_][a-zA-Z0-9_]*[^ -~]' "$_canary" 2>/dev/null; then
  rm -f "$_canary"; echo "FAIL(66): 扫描引擎自检未通过——grep 无法匹配已知陷阱，探针不可信"; exit 66
fi
rm -f "$_canary"

# 陷阱1：$var 紧跟非 ASCII 字符（中文标点）→ 变量名污染
# 正确写法：${var}中文
# 排除本脚本的自检金丝雀行（它刻意含陷阱样本，用于证明扫描引擎可用）
t1=$(scan '\$[a-zA-Z_][a-zA-Z0-9_]*[^ -~]' | grep -v '_canary=\$(mktemp)' || true)
if [ -n "$t1" ]; then
  echo "❌ 陷阱1：\$var 紧跟中文标点（bash 会并入变量名）——改用 \${var}"
  printf '%s\n' "$t1" | sed 's/^/   /'
  hits=$((hits + $(printf '%s\n' "$t1" | grep -c .)))
fi

# 陷阱2：GNU-only 写法（ADR-007：仅 macOS 实测，但避免绑死 BSD 之外无法迁移）
# sed -i 无备份参数在 BSD 上语法不同（仅 WARN）
# 排除本脚本自身（其注释与提示串含被检模式，会自指误报）与注释行
t2=$(scan_fixed "sed -i " \
     | grep -v "sed -i ''" | grep -v "check-shell-traps.sh" | grep -vE '(^|:)[0-9]+:[[:space:]]*#' || true)
if [ -n "$t2" ]; then
  echo "⚠️  陷阱2（WARN）：sed -i 无 '' 参数——BSD/GNU 语法分歧点"
  printf '%s\n' "$t2" | sed 's/^/   /'
fi

# 陷阱3：macOS 上不存在的 GNU coreutils 命令（实测：`timeout` 让一次异构评审静默失败）
# macOS 基础系统没有 timeout/realpath/sha256sum/gsed 等；它们只在装了 coreutils 后以 g* 前缀存在。
# 危害与陷阱2 同类：命令不存在 → `command not found` → 若外层吞了退出码就变成"跑过了"。
# 排除注释行与本脚本自身（其提示串含被检词，会自指误报）。
# 两类例外：
#   ① `command -v X` 探测行自身（不排除的话，正确的守卫写法反被判违规）
#   ② 显式 pragma `# shell-traps:ok <理由>` —— 豁免必须写在代码里、看得见、可审计，
#      不做"猜上下文"的启发式（猜错会静默放行，正是本探针要防的东西）
t3=$(scan '(^|[^a-zA-Z0-9_./-])(timeout|realpath|sha256sum|sha1sum|md5sum|readlink -f)[[:space:]]' \
     | grep -v "check-shell-traps.sh" | grep -vE '(^|:)[0-9]+:[[:space:]]*#' \
     | grep -v 'command -v' | grep -v 'shell-traps:ok' || true)
if [ -n "$t3" ]; then
  echo "❌ 陷阱3：macOS 无此 GNU 命令（timeout/realpath/sha256sum/md5sum/readlink -f）"
  echo "   替代：timeout→后台跑+轮询或 gtimeout；realpath→cd+pwd；sha256sum→shasum -a 256；md5sum→md5"
  printf '%s\n' "$t3" | sed 's/^/   /'
  hits=$((hits + $(printf '%s\n' "$t3" | grep -c .)))
fi

if [ "$hits" -gt 0 ]; then
  echo "FAIL(66): $hits 处高危写法"
  exit 66
fi
echo "PASS: 无高危写法"
exit 0
