#!/usr/bin/env bash
# check-action-pins.sh — 第三方 Action 必须 SHA-pin（宪法 C15）
#
# 为什么现在才有：C15 的「检查」栏一直白纸黑字写着
# 「workflows 中 Action 引用含 SHA（探针 grep）」—— **条款有检查声明、无检查实现**。
# 安全评审实测指出：平台仓两处、`bin/e2e` 的 CI 模板（发给**每个客户仓**）三处
# 全是可变 tag（`@v4` / `@v5`）。tag 可被 owner 随时移到别的 commit，
# 等于把 CI 的执行内容托付给一个可变引用。
#
# 检查范围：仓内所有 workflow（含 .template）+ bin/e2e 里的 CI 模板正文。
# 判据：`uses: <owner>/<repo>@<ref>` 的 ref 必须是 40 位 hex（SHA）。
#   - 本仓自有的 `./.github/actions/...` 本地 action 不需要钉（不经网络解析）
#   - 显式 pragma `# action-pin:ok <理由>` 可豁免单行（必须写明理由，可审计）
#
# 用法：bash scripts/check-action-pins.sh [<repo-root>]
# 退出码：0=全部已钉  1=有未钉  66=自检失败/无可检对象（fail-closed）

set -uo pipefail

if [ $# -ge 1 ]; then
  ROOT="$(cd "$1" 2>/dev/null && pwd)" || { echo "自检失败：目录不存在 $1" >&2; exit 66; }
else
  ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || ROOT="$(pwd)"
fi
cd "${ROOT}"

# ---- 自检金丝雀：抽取引擎必须真能从样本里认出「已钉」与「未钉」----
_c=$(mktemp)
printf 'uses: actions/checkout@v5\nuses: actions/checkout@%s\n' \
  'fbc6f3992d24b796d5a048ff273f7fcc4a7b6c09' > "$_c"
_pin=$(grep -cE 'uses:[[:space:]]*[^@[:space:]]+@[0-9a-f]{40}' "$_c" || true)
_tag=$(grep -E 'uses:[[:space:]]*[^@[:space:]]+@' "$_c" | grep -cvE '@[0-9a-f]{40}' || true)
rm -f "$_c"
if [ "${_pin:-0}" -ne 1 ] || [ "${_tag:-0}" -ne 1 ]; then
  echo "自检失败：抽取引擎异常（金丝雀应各命中 1 条，实得 pin=${_pin} tag=${_tag}）" >&2
  exit 66
fi

echo "== 第三方 Action SHA-pin 检查（宪法 C15）｜ ${ROOT} =="

# 收集所有含 `uses:` 的文件：workflow 目录 + bin/（CI 模板住在 bin/e2e 里）
FILES=$(grep -rlE '^[[:space:]]*-?[[:space:]]*uses:' \
        .github bin 2>/dev/null | sort -u || true)
if [ -z "${FILES}" ]; then
  echo "FAIL(66): 找不到任何含 uses: 的文件 —— 无可检对象（判为失败而非跳过）" >&2
  exit 66
fi

bad=0; checked=0
while IFS= read -r f; do
  [ -n "$f" ] || continue
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    case "$line" in *'action-pin:ok'*) continue ;; esac
    ln=${line%%:*}; body=${line#*:}
    ref=$(printf '%s' "$body" | sed -E 's/.*uses:[[:space:]]*//; s/[[:space:]].*$//')
    case "$ref" in
      ./*|.\\*) continue ;;                       # 本地 action，不经网络解析
    esac
    checked=$((checked + 1))
    case "$ref" in
      *@[0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f]) : ;;
      *) printf '  ❌ %s:%s 未 SHA-pin：%s\n' "$f" "$ln" "$ref"; bad=$((bad + 1)) ;;
    esac
  done <<EOF
$(grep -nE '^[[:space:]]*-?[[:space:]]*uses:' "$f" 2>/dev/null || true)
EOF
done <<EOF
$FILES
EOF

echo "  已检查 ${checked} 处 Action 引用"
if [ "${checked}" -eq 0 ]; then
  echo "FAIL(66): 抽到 0 处引用 —— 判为抽取失效而非「没有 Action」" >&2
  exit 66
fi
if [ "${bad}" -gt 0 ]; then
  cat >&2 <<EOF

❌ FAIL：${bad} 处 Action 未 SHA-pin（宪法 C15）。
   tag 可被 owner 随时移到别的 commit —— 等于把 CI 的执行内容托付给可变引用。
   修法：uses: <owner>/<repo>@<40位SHA>  # v5
   取 SHA：gh api repos/<owner>/<repo>/git/ref/tags/<tag> --jq .object.sha
   ⚠️ 注意 bin/e2e 里的 CI 模板 —— 它发给**每个客户仓**，漏钉会扩散。
EOF
  exit 1
fi
echo "PASS: 全部 Action 已 SHA-pin"
