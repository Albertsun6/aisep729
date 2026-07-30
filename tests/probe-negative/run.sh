#!/usr/bin/env bash
# run.sh — 探针负样本总入口（SPEC-6/7 · 宪法 C13：探针自身必须能证伪）
#
# 为什么必须有：只对好样本 PASS 的探针是安慰剂。每个探针至少要对一个构造的坏样本 FAIL，
# 且 FAIL 的退出码要符合契约（64=上游门禁未过 / 65=文件缺失 / 66=结构或质量缺项）。
#
# 用法: bash tests/probe-negative/run.sh
# 退出码: 0=全部符合预期 / 1=有用例不符合预期
set -u
cd "$(dirname "$0")/../.." || exit 1
ROOT=$(pwd)
WORK=$(mktemp -d); trap 'rm -rf "$WORK"' EXIT
fails=0; total=0

P0="$ROOT/.claude/skills/e2e-discovery/scripts/check-prfaq.sh"
P1="$ROOT/.claude/skills/e2e-requirements/scripts/check-prd.sh"
P2="$ROOT/.claude/skills/e2e-design/scripts/check-design.sh"
P3="$ROOT/.claude/skills/e2e-implement/scripts/check-tasks.sh"

# expect <用例名> <期望码> <命令...>
expect() {
  local name="$1" want="$2"; shift 2
  local out rc
  out=$("$@" 2>&1); rc=$?
  total=$((total+1))
  if [ "$rc" = "$want" ]; then
    echo "  ✅ ${name}（期望 ${want}，实际 ${rc}）"
  else
    echo "  ❌ ${name}（期望 ${want}，实际 ${rc}）"; echo "$out" | head -3 | sed 's/^/     /'; fails=$((fails+1))
  fi
}

# 造一个门禁块（$1=决定值）
gate_block() { printf -- '---\n门禁 记录：\n- 批准人：测试\n- 决定：%s\n- 日期：2026-01-01\n- 备注：负样本\n' "$1"; }

echo "== 探针负样本验证（宪法 C13）=="

# ---------- 阶段0 探针 ----------
echo "-- check-prfaq.sh --"
expect "P0/65 文件不存在" 65 bash "$P0" "$WORK/nonexistent.md"
printf '# PR-FAQ\n只有标题没有必需段\n' > "$WORK/bad-prfaq.md"
expect "P0/66 结构缺段" 66 bash "$P0" "$WORK/bad-prfaq.md"

# ---------- 阶段1 探针（门禁⓪ 串锁）----------
echo "-- check-prd.sh --"
mkdir -p "$WORK/f1"
expect "P1/64 无上游 prfaq" 64 bash "$P1" "$WORK/f1"
{ printf '# PR-FAQ\n'; gate_block "kill"; } > "$WORK/f1/prfaq.md"
expect "P1/64 门禁⓪=kill 拒绝放行" 64 bash "$P1" "$WORK/f1"
{ printf '# PR-FAQ\n'; gate_block "<待填>"; } > "$WORK/f1/prfaq.md"
expect "P1/64 门禁⓪ 待批拒绝放行" 64 bash "$P1" "$WORK/f1"
{ printf '# PR-FAQ\n'; gate_block "go"; } > "$WORK/f1/prfaq.md"
expect "P1/65 门禁⓪过但缺 prd" 65 bash "$P1" "$WORK/f1"
printf '# PRD\n只有标题\n' > "$WORK/f1/prd.md"
expect "P1/66 prd 结构缺段" 66 bash "$P1" "$WORK/f1"

# ---------- 阶段2 探针（门禁① 串锁）----------
echo "-- check-design.sh --"
mkdir -p "$WORK/f2"
expect "P2/64 无上游 prd" 64 bash "$P2" "$WORK/f2"
{ printf '# PRD\n'; gate_block "打回"; } > "$WORK/f2/prd.md"
expect "P2/64 门禁①=打回 拒绝放行" 64 bash "$P2" "$WORK/f2"

# ---------- 阶段3 探针（门禁② 串锁 + tasks 质量）----------
echo "-- check-tasks.sh --"
mkdir -p "$WORK/f3"
expect "P3/64 无上游 spec" 64 bash "$P3" "$WORK/f3"
{ printf '# SPEC\n'; gate_block "批准"; } > "$WORK/f3/spec.md"
expect "P3/65 门禁②过但缺 tasks" 65 bash "$P3" "$WORK/f3"
# 任务缺"验证："——SPEC-21 的核心契约，必须被抓
cat > "$WORK/f3/tasks.md" <<'EOF'
# TASKS
## A 组
- [ ] T-1 干点什么 ｜ SPEC-1 ｜ 复杂度 3 ｜ 依赖 -
## B 组
## 进度与容量
## spike 结论
EOF
expect "P3/66 任务缺'验证：'（SPEC-21）" 66 bash "$P3" "$WORK/f3"
# 空话式验证——宪法 C2 明令禁止
cat > "$WORK/f3/tasks.md" <<'EOF'
# TASKS
## A 组
- [ ] T-1 干点什么 ｜ SPEC-1 ｜ 复杂度 3 ｜ 依赖 - ｜ 验证：人工确认没问题
## B 组
## 进度与容量
## spike 结论
EOF
expect "P3/66 空话式验证被拒（宪法 C2）" 66 bash "$P3" "$WORK/f3"
# 工时回潮——ADR-012 已弃用
cat > "$WORK/f3/tasks.md" <<'EOF'
# TASKS
## A 组
- [ ] T-1 干点什么 ｜ SPEC-1 ｜ 预算 4h ｜ 依赖 - ｜ 验证：`bash x.sh` 退出 0
## B 组
## 进度与容量
## spike 结论
EOF
expect "P3/66 人类工时回潮被拒（ADR-012）" 66 bash "$P3" "$WORK/f3"

# ---------- 阶段4 探针（三通道契约 + 闭环状态机）----------
echo "-- check-review.sh --"
P4="$ROOT/.claude/skills/e2e-review/scripts/check-review.sh"
mkdir -p "$WORK/f4"
expect "P4/64 无上游 tasks" 64 bash "$P4" "$WORK/f4"
# 任务未勾选 → 阶段3 未完成
cat > "$WORK/f4/tasks.md" <<'EOF'
# TASKS
- [ ] T-1 还没做完 ｜ SPEC-1 ｜ 复杂度 1 ｜ 依赖 - ｜ 验证：`true`
EOF
expect "P4/64 阶段3 任务未勾选" 64 bash "$P4" "$WORK/f4"
printf '# TASKS\n- [x] T-1 done ｜ SPEC-1 ｜ 复杂度 1 ｜ 依赖 - ｜ 验证：`true`\n' > "$WORK/f4/tasks.md"
expect "P4/65 缺 review.md" 65 bash "$P4" "$WORK/f4"
# 核心契约负样本：block 级 finding 来自 LLM 通道（AI 无阻断权）
cat > "$WORK/f4/review.md" <<'EOF'
# REVIEW
## 定档结论
高
## 规模统计
## 覆盖声明
未审及原因：无
## Findings
| ID | severity | source | 类型 | 定位 | 问题 | 状态 | 闭环证据 |
|---|---|---|---|---|---|---|---|
| F-1 | block | llm-advisory | correctness | a.sh:1 | AI 说这里有问题 | open | - |
## 环境留痕
门禁③ 记录：
- 决定：<待填>
EOF
expect "P4/66 block 来自 LLM 通道（违反三通道契约）" 66 bash "$P4" "$WORK/f4"
# 状态机负样本：非法状态
sed -i '' 's/| open | -/| 差不多了 | -/' "$WORK/f4/review.md"
sed -i '' 's/llm-advisory/deterministic/' "$WORK/f4/review.md"
expect "P4/66 finding 状态非法" 66 bash "$P4" "$WORK/f4"

# ---------- ratchet 负样本（S5，独立脚本）----------
echo "-- ratchet.sh --"
expect "ratchet 六用例（含替换违规总数不变）" 0 bash "$ROOT/tests/probe-negative/ratchet-negative.sh"

echo
echo "== 结果：$((total-fails))/$total 符合预期 $([ $fails -eq 0 ] && echo '✅' || echo '❌') =="
exit $([ $fails -eq 0 ] && echo 0 || echo 1)
