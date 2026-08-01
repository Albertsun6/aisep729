#!/usr/bin/env bash
# check-ci-integrity.sh — CI 步骤清单对账（platform-hardening B1 · 评估 D6 部分缓解）
#
# 为什么：分支保护的 required check 只认 **job 名**（probes），job 里跑什么完全由
# PR 可写的 workflow 文件决定——删一个步骤=静默降级，没有任何东西会发现。
# 本探针把"仓里每个探针都必须接进 CI"变成会失败的断言：新加探针忘接线、
# 或 workflow 被阉割掉某步，当场红。
#
# ⚠️ 诚实边界（不得夸大）：本探针与 workflow 同在 PR 可写域——一个 PR 可以把
# 两者一起删掉。它是**提高漂移门槛**（拦疏忽性阉割/漏接线），不是封洞；
# 真正闭合需要 org 级 required workflow / GitHub App 外部信任根，单人个人仓
# 当前不可得（手册 §7"服务端门禁有入场费"同类）。评审共识：不做 CI 内
# marker 计数——跑在被攻击 workflow 自身里的计数是自我证明，不增加保障。
#
# 平台仓专用：客户仓（tpl_ci 三 job）的对账留待与 tpl_ci 同步设计，不随 CAP_FILES 分发。
#
# 用法: bash scripts/check-ci-integrity.sh
# 退出码: 0=全部接线 / 1=有探针未进 CI / 65=workflow 缺失 / 66=判据失效
set -u
cd "$(dirname "$0")/.." || exit 1
WF=".github/workflows/quality-gates.yml"
[ -f "$WF" ] || { echo "FAIL(65): 缺 ${WF} —— CI 定义不存在"; exit 65; }

# 豁免清单（不进 CI 的探针，逐条带理由，可审计）
EXEMPT=(
  "scripts/check-demo-video.sh"        # 需视频文件参数，平台仓无固定 CI 对象（SPEC-25 属 demo 仓交付）
)
in_exempt() { local x="$1"; for e in "${EXEMPT[@]}"; do [ "$x" = "$e" ] && return 0; done; return 1; }

echo "== CI 步骤清单对账（B1）=="
miss=0; n=0
for p in scripts/check-*.sh .claude/skills/e2e-*/scripts/check-*.sh tests/probe-negative/run.sh; do
  [ -e "$p" ] || continue
  in_exempt "$p" && continue
  n=$((n+1))
  # 过滤注释行再对账（评审 G7/S2/R4 实测击穿）：把步骤整行注释掉是最便宜的阉割形态，
  # 路径字符串还在文件里，不滤注释就 PASS
  if grep -vE '^[[:space:]]*#' "$WF" | grep -qF "$p"; then
    echo "   ✅ $p"
  else
    echo "   ❌ CI 未接线：$p —— 新探针没进 CI，或 workflow 步骤被删"
    miss=$((miss+1))
  fi
done

# 判据自身失效要响亮：探针文件抽不到 = glob 断了，不是"没有探针"
[ "$n" -ge 10 ] || { echo "FAIL(66): 仅抽到 ${n} 个探针文件 —— 抽取失效，拒绝 PASS"; exit 66; }

if [ "$miss" -gt 0 ]; then
  echo "FAIL(1): ${miss} 个探针未接进 CI（${WF}）"
  exit 1
fi
echo "PASS: ${n} 个探针全部接线（豁免 ${#EXEMPT[@]} 项，理由见头部）"
exit 0
