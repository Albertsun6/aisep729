#!/usr/bin/env bash
# check-selfcontained.sh — 平台仓自包含探针（SPEC-17 · US-7 · 宪法 C9）
#
# 为什么：平台仓要对外分发（咨询交付件）。任何个人绝对路径或对 ~/.claude 的
# 运行时依赖，都会让受众第一次跑就断链——这是分发的底线。
#
# 白名单 = 说明性引用（文档里提到"vendored 源在个人目录"是说明，不是依赖）。
# 白名单条目须在此显式登记，不许零散豁免（ADR-006 / 异构评审建议#2）。
#
# 用法: bash scripts/check-selfcontained.sh
# 退出码: 0=自包含 / 66=有个人路径或运行时依赖
set -u
cd "$(dirname "$0")/.." || exit 1

# 白名单：文件路径（说明性引用，非运行时依赖）
WHITELIST=(
  "docs/architecture/adr/ADR-006-vendored-productization.md"  # vendored 源说明
  "docs/architecture/adr/ADR-013-ci-ai-review-headless.md"    # 认证链说明
  "specs/platform-pilot/plan.md"                              # 结构图外部源标注
  "specs/platform-pilot/spec.md"                              # SPEC-17 契约自身
  "specs/platform-pilot/stories.md"                           # US-7 整合映射表
  "scripts/check-selfcontained.sh"                            # 本文件（模式定义）
  "docs/process/skills-manifest.md"                           # vendored 映射登记
  "specs/platform-pilot/prfaq.md"                             # 深坑段：说明"隐性个人依赖"风险
  "specs/platform-pilot/tasks.md"                             # T-6 任务描述含被检模式
  "Claude企业级E2E研发平台-完整报告.md"                        # 调研报告：CLAUDE.md 官方四层分层说明
  "Claude企业级E2E研发平台-完整报告.html"                      # 同上（HTML 版）
  "E2E研发平台-全局视图.html"                                  # 架构图：标注"不依赖个人 ~/.claude"
)

in_whitelist() {
  local f="${1#./}"
  for w in "${WHITELIST[@]}"; do [ "$f" = "$w" ] && return 0; done
  return 1
}

hits=0
echo "== 自包含扫描（宪法 C9 / SPEC-17）=="

scan() {  # scan <模式描述> <grep 正则>
  local desc="$1" pat="$2" out
  out=$(grep -rn --exclude-dir=.git --exclude-dir=node_modules -E "$pat" . 2>/dev/null || true)
  [ -z "$out" ] && return 0
  while IFS= read -r line; do
    local file="${line%%:*}"
    in_whitelist "$file" && continue
    echo "   ❌ [${desc}] ${line}"
    hits=$((hits+1))
  done <<< "$out"
}

# 个人绝对路径（/Users/<name>/ 形式）
scan "个人绝对路径" '/Users/[a-zA-Z0-9_.-]+/'
# 对个人 claude 目录的引用
scan "个人 claude 目录" '~/\.claude|\$HOME/\.claude|CLAUDE_CONFIG_DIR'

if [ "$hits" -gt 0 ]; then
  echo "FAIL(66): $hits 处非自包含引用（白名单外）"
  echo "   修法：改为相对路径 / 或确属说明性引用则登记进本脚本 WHITELIST"
  exit 66
fi
echo "PASS: 自包含（白名单 ${#WHITELIST[@]} 项为说明性引用）"
exit 0
