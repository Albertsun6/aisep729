#!/usr/bin/env bash
# check-prfaq.sh — 阶段0 制品验收探针
# 用法: bash check-prfaq.sh <specs/xxx/prfaq.md>
# 退出码: 0=结构通过(门禁可能待批,见输出) / 65=文件不存在 / 66=结构缺段
set -u
f="${1:-}"
[ -f "$f" ] || { echo "FAIL(65): 文件不存在: $f"; exit 65; }

# ---- 门禁解析公共库(SPEC-5：单一实现) ----
_root=$(cd "$(dirname "$0")/../../../.." && pwd)
# 插件模式下 scripts/lib/ 不在分发范围内（source.path 只有 .claude）——
# 冷启动验收实测：4 个探针死在 bash 的 "No such file"，对用户毫无意义。
# 现在：抑制 bash 噪音，给出**能照做**的提示。
if [ ! -f "$_root/scripts/lib/gate.sh" ]; then
  cat >&2 <<'NOLIB'
FAIL(65): 找不到 scripts/lib/gate.sh —— 本探针需要**完整平台**才能运行。

  最可能的原因：你是通过 `claude plugin install` 装的。
  插件只分发 .claude/ 能力层，**不含** bin/e2e、scripts/lib/、平台探针与负样本套件。

  要用门禁，请改用完整安装：
    git clone https://github.com/Albertsun6/aisep729.git
    bash aisep729/bin/e2e init <你的项目>

  详见 docs/architecture/adr/ADR-015-plugin-marketplace-distribution.md
NOLIB
  exit 65
fi
. "$_root/scripts/lib/gate.sh" || { echo "FAIL(65): scripts/lib/gate.sh 存在但加载失败" >&2; exit 65; }

# 制品不得是一字未改的模板（冷启动 MAJOR：曾对模板原样副本判 PASS）
_tpl="$(dirname "$0")/../templates/prfaq-template.md"
gate_assert_filled "$f" "$_tpl" || exit $?

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
