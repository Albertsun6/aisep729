#!/usr/bin/env bash
# check-constitution-adr.sh — 修宪必须伴随 ADR（platform-hardening B6 · 评估 D9 部分缓解）
#
# 为什么：mutation 实测——把 C14 改成"执行者可自批，检查：无"后，check-clause-refs
# 与 check-structure 双绿：守规则的探针只验条款编号可解析，从不验条款内容。
# 宪法头部本就约定"修宪=独立 ADR（superseded 留痕）"，但它此前只是文字。
# 本探针把它变成会失败的断言：相对 main 基线改了 constitution.md（含未提交改动）
# 而没有任何 docs/architecture/adr/ 文件同行变更 → 红。
#
# 诚实边界：同域探针，防疏忽与"顺手修宪"；防不了把本探针连 workflow 一起删的
# 恶意 PR（与 B1 同类，真正闭合需服务端外部信任根，手册 §7）。
#
# 用法: bash scripts/check-constitution-adr.sh [<base-ref>]
# 退出码: 0=未修宪或已伴随 ADR / 1=裸修宪 / 66=判据失效
set -u
cd "$(dirname "$0")/.." || exit 1
git rev-parse --git-dir >/dev/null 2>&1 || { echo "FAIL(66): 非 git 仓库——无 diff 可判，拒绝 PASS"; exit 66; }

base="${1:-}"
if [ -z "$base" ]; then
  base=$(git merge-base HEAD main 2>/dev/null) \
    || base=$(git merge-base HEAD origin/main 2>/dev/null) \
    || { echo "FAIL(66): 找不到 main 基线（需要 main 或 origin/main；浅克隆请设 fetch-depth: 0）"; exit 66; }
fi

changed=$(printf '%s\n%s\n%s\n' \
  "$(git diff --name-only "$base" HEAD -- 2>/dev/null || true)" \
  "$(git diff --name-only 2>/dev/null || true)" \
  "$(git diff --name-only --cached 2>/dev/null || true)")

if ! printf '%s\n' "$changed" | grep -q '^docs/constitution\.md$'; then
  echo "PASS: 本次改动未触碰宪法（基线 $(git rev-parse --short "$base")）"
  exit 0
fi
if printf '%s\n' "$changed" | grep -q '^docs/architecture/adr/'; then
  echo "PASS: 修宪伴随 ADR 变更（修宪=独立 ADR 留痕，宪法头部约定）"
  exit 0
fi
echo "FAIL(1): docs/constitution.md 被修改而无 docs/architecture/adr/ 同行变更"
echo "   修宪是不可协商流程：先写独立 ADR（含 ≥2 真实备选与 superseded 留痕），再动宪法条文"
exit 1
