#!/usr/bin/env bash
# check-c8-feature.sh — 大改动须有立项（platform-hardening B5 · C8 可执行看守）
#
# 为什么：C8 的检查栏写"specs/ 下无对应 feature 的大改动=评审阻断"，但它此前
# 零机器执行、违反无代价——tasks 台账只覆盖 M1、M2-M4 大量工作无立项留痕
# （评估 D13 的另一半成因：不只是仪式重，还因为绕过它没有任何信号）。
#
# 判据（粗启发式，advisory 起步）：相对 main 基线，非豁免路径改动文件数 > 阈值(10)
# 且 specs/ 下没有任何文件被触碰 → 警告；--strict 才阻断（负样本钉 strict 行为）。
# 豁免：specs/（立项本身）、docs/research/（调研属阶段0之前的学习，不违 C8）。
#
# 用法: bash scripts/check-c8-feature.sh [--strict] [<base-ref>]
# 退出码: 0=无信号或 advisory 警告 / 1=strict 且触发 / 66=判据失效
set -u
cd "$(dirname "$0")/.." || exit 1
git rev-parse --git-dir >/dev/null 2>&1 || { echo "FAIL(66): 非 git 仓库——无 diff 可判，拒绝 PASS"; exit 66; }

strict=0; base=""
for a in "$@"; do
  case "$a" in --strict) strict=1 ;; *) base="$a" ;; esac
done
if [ -z "$base" ]; then
  base=$(git merge-base HEAD main 2>/dev/null) \
    || base=$(git merge-base HEAD origin/main 2>/dev/null) \
    || { echo "FAIL(66): 找不到 main 基线（需要 main 或 origin/main）"; exit 66; }
fi
THRESHOLD=10

changed=$(git diff --name-only "$base" HEAD -- 2>/dev/null || true)
n=$(printf '%s\n' "$changed" | grep -vE '^$|^specs/|^docs/research/' | grep -c . || true); : "${n:=0}"
touched_specs=$(printf '%s\n' "$changed" | grep -c '^specs/' || true); : "${touched_specs:=0}"

if [ "$n" -le "$THRESHOLD" ] || [ "$touched_specs" -ge 1 ]; then
  echo "PASS: C8 看守无信号（非豁免改动 ${n} 个文件，specs/ 触碰 ${touched_specs} 处）"
  exit 0
fi
echo "⚠️  C8 信号：${n} 个非豁免文件改动而 specs/ 零触碰——大改动没有立项留痕"
echo "   按宪法 C8：新功能/重构/大改先立项（prfaq 走门禁⓪）；紧急通道须 48h 内补票"
if [ "$strict" -eq 1 ]; then
  echo "FAIL(1): --strict 模式阻断"
  exit 1
fi
echo "（advisory 起步：不阻断，仅提示。升级为 blocker 前先观察误报率）"
exit 0
