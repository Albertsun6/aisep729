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
# 基线必须真实存在；diff 出错=判据失效，不许吞成"空改动"（评审 G8）
git rev-parse -q --verify "${base}^{commit}" >/dev/null 2>&1 \
  || { echo "FAIL(66): 基线 ${base} 不是有效 commit"; exit 66; }
c1=$(git diff --name-only "$base" HEAD --) || { echo "FAIL(66): git diff 失败——无从判定"; exit 66; }
c2=$(git diff --name-only) || { echo "FAIL(66): git diff 失败——无从判定"; exit 66; }
c3=$(git diff --name-only --cached) || { echo "FAIL(66): git diff 失败——无从判定"; exit 66; }
changed=$(printf '%s\n%s\n%s\n' "$c1" "$c2" "$c3")

if ! printf '%s\n' "$changed" | grep -q '^docs/constitution\.md$'; then
  echo "PASS: 本次改动未触碰宪法（基线 $(git rev-parse --short "$base")）"
  exit 0
fi
# 陪同证据必须是**新增**的独立 ADR（评审 G9：改/删一个旧 ADR 不算修宪留痕）；
# 未提交的新 ADR（尚未 add）也认——本探针兼作本地快反馈
added_adr=$(git diff --name-only --diff-filter=A "$base" HEAD -- docs/architecture/adr/ 2>/dev/null || true)
untracked_adr=$(git ls-files --others --exclude-standard docs/architecture/adr/ 2>/dev/null || true)
staged_adr=$(git diff --name-only --cached --diff-filter=A -- docs/architecture/adr/ 2>/dev/null || true)
if printf '%s\n%s\n%s\n' "$added_adr" "$untracked_adr" "$staged_adr" | grep -q '\.md$'; then
  echo "PASS: 修宪伴随新增 ADR（修宪=独立 ADR 留痕，宪法头部约定）"
  exit 0
fi
echo "FAIL(1): docs/constitution.md 被修改而无**新增**的 docs/architecture/adr/*.md（改旧 ADR 不算）"
echo "   修宪是不可协商流程：先写独立 ADR（含 ≥2 真实备选与 superseded 留痕），再动宪法条文"
exit 1
