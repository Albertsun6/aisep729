#!/usr/bin/env bash
# check-prfaq.sh — 阶段0 制品验收探针
# 用法: bash check-prfaq.sh <specs/xxx/prfaq.md>
# 退出码: 0=结构通过(门禁可能待批,见输出) / 65=文件不存在 / 66=结构缺段
set -u
f="${1:-}"
[ -f "$f" ] || { echo "FAIL(65): 文件不存在: $f"; exit 65; }

# ---- 门禁解析公共库(SPEC-5：单一实现) ----
_root=$(cd "$(dirname "$0")/../../../.." && pwd)
. "$_root/scripts/lib/gate.sh" || { echo "FAIL(65): 无法加载 scripts/lib/gate.sh"; exit 65; }

required=(
  "## 假设陈述"
  "## 最险假设"
  "## 未来新闻稿"
  "## 客户与痛点"
  "## 差异化主张"
  "## Appetite"
  "## 深坑"
  "## 不做什么"
  "## FAQ"
  "门禁⓪ 记录"
)
missing=0
for h in "${required[@]}"; do
  if ! grep -qF "$h" "$f"; then
    echo "MISSING: $h"
    missing=$((missing+1))
  fi
done

lines=$(grep -vc '^[[:space:]]*$' "$f")
[ "$lines" -gt 160 ] && echo "WARN: 正文 ${lines} 行(非空)，超一页纸纪律(~120)，考虑精简"

# 分层判据检查(熔断线/信号至少各一条 checkbox)
grep -qF "熔断线" "$f" || { echo "MISSING: go/kill 判据须含「熔断线」分层"; missing=$((missing+1)); }

# 门禁状态(公共库)
# 门禁台账 fail-open 修复：校验本文件自己的决定值合法（gate.sh 单一实现）
gate_assert_legal "$f" go modify kill || missing=$((missing+1))
gate=$(gate_status "$f")

if [ "$missing" -gt 0 ]; then
  echo "FAIL(66): 缺 $missing 段，结构不完整"
  exit 66
fi
echo "PASS: 结构完整 | 行数(非空)=$lines | 门禁⓪=$gate"
exit 0
