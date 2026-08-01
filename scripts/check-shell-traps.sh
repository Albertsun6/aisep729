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
# 排除 vendored / 第三方目录：本探针查的是**我们自己**的编码约定，
# 扫别人的代码既改不了也不该拦（risk-tiers 的计数排除里已有 vendor/ dist/ 同理）。
# 注意：只排除目录，不排除任何我们自己的 .sh —— 用负样本双向验证过。
EXCL=(--exclude-dir=node_modules --exclude-dir=.git --exclude-dir=vendor --exclude-dir=dist)
scan() {  # scan <ERE 模式>
  if [ -f "$target" ]; then LC_ALL=C grep -nE "$1" "$target" 2>/dev/null || true
  else LC_ALL=C grep -rnE "$1" --include="*.sh" "${EXCL[@]}" "$target" 2>/dev/null || true; fi
}
scan_fixed() {  # 固定串版本（陷阱2 用）
  if [ -f "$target" ]; then grep -n "$1" "$target" 2>/dev/null || true
  else grep -rn "$1" --include="*.sh" "${EXCL[@]}" "$target" 2>/dev/null || true; fi
}

# ---- 正则单源：生产与金丝雀共用同一变量（platform-hardening A2）----
# 2026-08-01 mutation 实测：金丝雀与生产各存一份字面量时，改坏生产正则金丝雀照绿、
# 探针永远 PASS。金丝雀必须复用生产同一条正则（CLAUDE.md 陷阱 E/F/G），此处是唯一定义点。
T1_RE='\$[a-zA-Z_][a-zA-Z0-9_]*[^ -~]'
T2_STR=$(printf '\x73ed -i ')   # 固定串（陷阱2）；\x 转义防本文件自指命中
T3_RE='(^|[^a-zA-Z0-9_./-])(timeout|realpath|sha256sum|sha1sum|md5sum|readlink -f)[[:space:]]'
T4_RE='(^|[^a-zA-Z0-9_./-])grep[[:space:]]+(-[a-zA-Z]*P|--perl-regexp)'
T5_RE='grep[[:space:]]+-[a-zA-Z]*c[a-zA-Z]*[^|]*\)[[:space:]]*\|\|[[:space:]]*echo'
T6_RE='\|[[:space:]]*(cut|head|tail|tr|awk|sed)[[:space:]][^|]*\|\|[[:space:]]*[a-zA-Z]'

# 自检：六条陷阱各一只金丝雀，样本用 \x 转义保持本文件 ASCII 无陷阱（防自指误报）。
# 任一未命中 = 生产正则被改坏或引擎失效 → 当场 66，绝不带病扫描。
_canary=$(mktemp)
canary() {  # canary <陷阱号> <模式> [fixed]
  if [ "${3:-ere}" = fixed ]; then grep -qF "$2" "$_canary" 2>/dev/null && return 0
  else LC_ALL=C grep -qE "$2" "$_canary" 2>/dev/null && return 0; fi
  rm -f "$_canary"
  echo "FAIL(66): 金丝雀「陷阱$1」未命中已知坏样本——生产正则被改坏或扫描引擎失效，探针不可信"
  exit 66
}
printf 'echo "$v\xe3\x80\x82"\n'           > "$_canary"; canary 1 "$T1_RE"
printf '\x73ed -i x f\n'                   > "$_canary"; canary 2 "$T2_STR" fixed
printf '\x74imeout 5 x\n'                  > "$_canary"; canary 3 "$T3_RE"
printf '\x67rep -P x f\n'                  > "$_canary"; canary 4 "$T4_RE"
printf 'n=$(\x67rep -c a f) || echo 0\n'   > "$_canary"; canary 5 "$T5_RE"
printf 'md5 -q f | \x63ut -c1 || echo x\n' > "$_canary"; canary 6 "$T6_RE"
rm -f "$_canary"

# 陷阱1：$var 紧跟非 ASCII 字符（中文标点）→ 变量名污染
# 正确写法：${var}中文
t1=$(scan "$T1_RE" | grep -v "check-shell-traps.sh" || true)
if [ -n "$t1" ]; then
  echo "❌ 陷阱1：\$var 紧跟中文标点（bash 会并入变量名）——改用 \${var}"
  printf '%s\n' "$t1" | sed 's/^/   /'
  hits=$((hits + $(printf '%s\n' "$t1" | grep -c .)))
fi

# 陷阱2：GNU-only 写法（ADR-007：仅 macOS 实测，但避免绑死 BSD 之外无法迁移）
# sed -i 无备份参数在 BSD 上语法不同（仅 WARN）
# 排除本脚本自身（其注释与提示串含被检模式，会自指误报）与注释行
t2=$(scan_fixed "$T2_STR" \
     | grep -v "sed -i ''" | grep -v "check-shell-traps.sh" | grep -vE '(^|:)[0-9]+:[[:space:]]*#' \
     | grep -v 'shell-traps:ok' || true)
if [ -n "$t2" ]; then
  echo "⚠️  陷阱2（WARN）：sed -i 无 '' 参数——BSD/GNU 语法分歧点"   # shell-traps:ok 自身提示文本
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
t3=$(scan "$T3_RE" \
     | grep -v "check-shell-traps.sh" | grep -vE '(^|:)[0-9]+:[[:space:]]*#' \
     | grep -v 'command -v' | grep -v 'shell-traps:ok' || true)
if [ -n "$t3" ]; then
  echo "❌ 陷阱3：macOS 无此 GNU 命令（timeout/realpath/sha256sum/md5sum/readlink -f）"
  echo "   替代：timeout→后台跑+轮询或 gtimeout；realpath→cd+pwd；sha256sum→shasum -a 256；md5sum→md5"
  printf '%s\n' "$t3" | sed 's/^/   /'
  hits=$((hits + $(printf '%s\n' "$t3" | grep -c .)))
fi

# 陷阱4（表 #2）：grep -P —— BSD grep 不支持 PCRE。
# 危害是**最阴的一类**：配上 `2>/dev/null || true` 之后它永远返回空，
# 于是探针"永远 PASS"。实测踩过：一条本该拦人的检查静默失效了整整两天。
t4=$(scan "$T4_RE" \
     | grep -v "check-shell-traps.sh" | grep -vE '(^|:)[0-9]+:[[:space:]]*#' \
     | grep -v 'shell-traps:ok' || true)
if [ -n "$t4" ]; then
  echo "❌ 陷阱4：grep -P 在 macOS BSD grep 上不支持——改用 ERE（grep -E）+ LC_ALL=C"   # shell-traps:ok 自身提示文本
  echo "   最危险的地方：配上 2>/dev/null || true 后它**永远返回空**，检查静默失效"
  printf '%s\n' "$t4" | sed 's/^/   /'
  hits=$((hits + $(printf '%s\n' "$t4" | grep -c .)))
fi

# 陷阱5（表 #5）：`n=$(... | grep -c ...) || echo 0` 之类的"兜底"
# grep -c 无匹配时**已经输出了 0**，但退出码是 1 → `|| echo 0` 再追加一行 0，
# 变量成了两行 "0\n0"，后续 [ "$n" -gt 0 ] 直接语法崩。
# 正确：n=$(...); : "${n:=0}"
t5=$(scan "$T5_RE" \
     | grep -v "check-shell-traps.sh" | grep -vE '(^|:)[0-9]+:[[:space:]]*#' \
     | grep -v 'shell-traps:ok' || true)
if [ -n "$t5" ]; then
  echo "❌ 陷阱5：\$(… grep -c …) || echo 0 —— grep -c 已输出 0，|| 会再追加一行"   # shell-traps:ok 自身提示文本
  echo "   结果是两行的 \"0\\n0\"，后续整数比较直接崩。改：n=\$(…); : \"\${n:=0}\""
  printf '%s\n' "$t5" | sed 's/^/   /'
  hits=$((hits + $(printf '%s\n' "$t5" | grep -c .)))
fi

# 陷阱6（表 #7）：管道之后取 $? / 用 || 兜底 —— 拿到的是**末端**命令的退出码。
# 实测踩过：`md5 -q "$f" | cut -c1-12 || md5sum ...` —— 退出码来自 cut（永远 0），
# 于是 md5 不存在时 fallback **永不触发**，指纹静默为空。
# 只报"管道 + || 兜底"这一种可判定的形态；裸 $? 的上下文判定不可靠，不猜。
t6=$(scan "$T6_RE" \
     | grep -v "check-shell-traps.sh" | grep -vE '(^|:)[0-9]+:[[:space:]]*#' \
     | grep -v 'shell-traps:ok' || true)
if [ -n "$t6" ]; then
  echo "❌ 陷阱6：管道后接 || 兜底——退出码来自**管道末端**命令，兜底永不触发"
  echo "   实测：md5 -q f | cut … || md5sum … 里 md5 缺失时 fallback 从不执行，指纹静默为空"   # shell-traps:ok 自身提示文本
  echo "   改：先 command -v 探测，或 set -o pipefail 后分步取值"
  printf '%s\n' "$t6" | sed 's/^/   /'
  hits=$((hits + $(printf '%s\n' "$t6" | grep -c .)))
fi

if [ "$hits" -gt 0 ]; then
  echo "FAIL(66): $hits 处高危写法"
  exit 66
fi
echo "PASS: 无高危写法"
exit 0
