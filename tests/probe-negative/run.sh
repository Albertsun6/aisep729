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

# ---------- 阶段5 探针（门禁③服务端双路径 fail-closed）----------
echo "-- check-release.sh --"
P5="$ROOT/.claude/skills/e2e-release/scripts/check-release.sh"
mkdir -p "$WORK/f5"
# 非 git 目录 + 无 gh 上下文 → 两条路径都证不出 → fail-closed 拒绝（不是放行）
expect "P5/64 门禁③无从验证 → fail-closed" 64 env -u E2E_PR -u E2E_TEST_CMD GH_TOKEN= PATH=/usr/bin:/bin bash "$P5" "$WORK/f5" --gate-only
# 降级路径：不再隐式回落跑 run.sh（finding #5：会造成无界再入且证据与变更无关）
expect "P5/64 降级路径未设 E2E_TEST_CMD → 拒绝" 64 env -u E2E_TEST_CMD PATH=/usr/bin:/bin bash "$P5" "$WORK/f5" --gate-only

# ---------- 阶段6 探针（门禁④串锁）----------
echo "-- check-retire.sh --"
P6="$ROOT/.claude/skills/e2e-retire/scripts/check-retire.sh"
mkdir -p "$WORK/f6"
expect "P6/64 无上游 release.md" 64 bash "$P6" "$WORK/f6" --gate-only
{ printf '# RELEASE\n'; gate_block "打回"; } > "$WORK/f6/release.md"
expect "P6/64 门禁④=打回 拒绝放行" 64 bash "$P6" "$WORK/f6" --gate-only
{ printf '# RELEASE\n'; gate_block "批准"; } > "$WORK/f6/release.md"
expect "P6/65 门禁④过但缺 deprecation" 65 bash "$P6" "$WORK/f6"

# ---------- 好样本 PASS 用例（reviewer finding #4：结构性缺口）----------
# 此前套件只验"坏的会红"，不验"好的会绿"——这正是"探针按自家模板永远红"能溜过去的原因
echo "-- 好样本（正向回归）--"
# artifact.sh 的判定函数：好内容必须判为实质非空、无占位符
cat > "$WORK/good.md" <<'EOF'
## 启动
- 命令：`make serve`
- 健康检查：curl localhost:8080/healthz 返回 200
## 回滚
- **回滚演练证据**：2026-07-30 staging 演练，RTO 4 分钟，记录见 CI run 123
- 命令：`git revert abc123 && make deploy`
## 故障
- 症状 A → 处置：重启 worker（`make restart`）
EOF
. "$ROOT/scripts/lib/artifact.sh"
total=$((total+1))
if [ "$(art_sec_lines "$WORK/good.md" "## 启动")" -ge 2 ] \
   && [ "$(art_sec_lines "$WORK/good.md" "## 回滚")" -ge 2 ] \
   && ! art_has_placeholder "$WORK/good.md" \
   && grep -qE "回滚演练证据[*_[:space:]]*：[[:space:]]*[^<[:space:]]" "$WORK/good.md"; then
  echo "  ✅ 好样本 填实制品判为合格（含加粗写法的演练证据）"
else
  echo "  ❌ 好样本 填实制品被误判为不合格（模板/探针漂移复发）"; fails=$((fails+1))
fi
# 反向：模板骨架原样（全占位符）必须判为未决
cat > "$WORK/skeleton.md" <<'EOF'
## 启动
- 命令：`<启动命令>`
## 回滚
- **回滚演练证据**：<日期与记录>
EOF
total=$((total+1))
if art_has_placeholder "$WORK/skeleton.md" && [ "$(art_sec_lines "$WORK/skeleton.md" "## 启动")" -lt 2 ]; then
  echo "  ✅ 反向 模板骨架原样被判未决（不许直抄过关）"
else
  echo "  ❌ 反向 模板骨架原样被判合格（finding #3 未修好）"; fails=$((fails+1))
fi

# ---------- 陷阱扫描器可移植性（M2-D 血泪：grep -P 在 BSD 上静默失效）----------
echo "-- check-shell-traps.sh 可移植性 --"
# 坏样本用拼接生成——若把字面量直接写在本文件里，扫描器会（正确地）把本文件也判为含陷阱
{ printf '#!/usr/bin/env bash\nv=1\n'; printf 'echo "$v%s"\n' '（中文标点紧跟变量名）'; } > "$WORK/trap.sh"
expect "陷阱扫描/66 单文件负样本（BSD grep 也须抓到）" 66 bash "$ROOT/scripts/check-shell-traps.sh" "$WORK/trap.sh"
# 强制用 BSD grep（去掉可能的 GNU grep 路径）复测——这是"别人的干净 macOS"的真实情形
expect "陷阱扫描/66 纯 BSD grep 环境下仍能抓到" 66 env PATH=/usr/bin:/bin bash "$ROOT/scripts/check-shell-traps.sh" "$WORK/trap.sh"

# ---------- hooks 本地反馈（SPEC-15/16，M2-D）----------
echo "-- hooks --"
if [ ! -f "$ROOT/.claude/hooks/post-edit-lint.sh" ]; then
  echo "  ⏭  跳过（本仓未配置 hooks）"
else
total=$((total+1))
if printf '{"tool_input":{"file_path":"%s"}}' "$WORK/trap.sh" | bash "$ROOT/.claude/hooks/post-edit-lint.sh" >/dev/null 2>&1; then
  echo "  ❌ post-edit hook 未拦住含陷阱的文件"; fails=$((fails+1))
else
  echo "  ✅ post-edit hook 拦住含陷阱文件（本地快反馈生效）"
fi
total=$((total+1))
if printf '{"tool_input":{"file_path":"%s/scripts/ratchet.sh"}}' "$ROOT" | bash "$ROOT/.claude/hooks/post-edit-lint.sh" >/dev/null 2>&1; then
  echo "  ✅ post-edit hook 放行干净文件（不误伤）"
else
  echo "  ❌ post-edit hook 误伤干净文件"; fails=$((fails+1))
fi

fi

# ---------- assess/adopt 契约（SPEC-12/13，M2-C）----------
# 平台专属能力：业务项目由 e2e init 生成时不含 bin/e2e，此段自动跳过（不算失败）
E2E_BIN="$ROOT/bin/e2e"
if [ ! -x "$E2E_BIN" ]; then
  echo "-- e2e assess/adopt --"
  echo "  ⏭  跳过（本仓无 bin/e2e，属平台专属能力）"
else
echo "-- e2e assess/adopt --"
LEG="$WORK/legacy"; mkdir -p "$LEG/src"
( cd "$LEG" && git init -q && git config user.email t@t && git config user.name t \
  && printf 'x=1\n' > src/a.py && printf '# 我的\n' > CLAUDE.md && git add -A && git commit -qm init ) >/dev/null 2>&1

# SPEC-12：输出目录不得在目标仓内
expect "assess/64 输出目录在仓内 → 拒绝" 64 bash "$E2E_BIN" assess "$LEG" -o "$LEG/out"

# SPEC-12 只读契约：完整快照（含文件内容 md5）零差异
snap() { ( cd "$LEG" && git status --porcelain=v1 -uall; git rev-parse HEAD; \
           find . -type f -not -path './.git/*' | sort | xargs md5 -q 2>/dev/null ) | md5 -q; }
before=$(snap); bash "$E2E_BIN" assess "$LEG" >/dev/null 2>&1; after=$(snap)
total=$((total+1))
if [ "$before" = "$after" ]; then echo "  ✅ assess 只读契约（目标仓完整快照零差异）"
else echo "  ❌ assess 改动了目标仓（违反 SPEC-12）"; fails=$((fails+1)); fi

# SPEC-13：非破坏 + 冲突计数 + exit 2 + 能力层真的复制进去
md5_before=$(md5 -q "$LEG/CLAUDE.md")
bash "$E2E_BIN" adopt "$LEG" >/dev/null 2>&1; arc=$?
total=$((total+1))
if [ "$arc" = "2" ] && [ "$(md5 -q "$LEG/CLAUDE.md")" = "$md5_before" ] \
   && [ -f "$LEG/.claude/skills/e2e-discovery/SKILL.md" ] && [ -f "$LEG/scripts/lib/gate.sh" ] \
   && grep -q 'CLAUDE.md' "$LEG/docs/adopt-conflicts.md" 2>/dev/null; then
  echo "  ✅ adopt 非破坏（既有未覆盖 + 冲突入清单 + exit 2 + 能力层已复制）"
else
  echo "  ❌ adopt 契约不符（exit=${arc}｜CLAUDE.md 变动或能力层未复制或冲突未记录）"; fails=$((fails+1))
fi

fi

# ---------- check-skill-deps 负样本（门禁③ 评审抓出的四条真空 PASS 路径）----------
# 背景：这个探针本身是"防 fail-open"的，异构评审 + reviewer + security 三方各自
# 独立指出它自己有多条"什么都没检查却 exit 0"的路径。以下用例把每条钉死。
echo "-- check-skill-deps.sh --"
SD="$ROOT/scripts/check-skill-deps.sh"

SDW="$WORK/sd-no-skills"; mkdir -p "$SDW"
expect "SD/66 连 .claude/skills 都没有（旧版静默 exit 0）" 66 bash "$SD" "$SDW"

SDW2="$WORK/sd-empty"; mkdir -p "$SDW2/.claude/skills"
expect "SD/66 skills 目录为空（旧版'已检查 0 条 / PASS'）" 66 bash "$SD" "$SDW2"

SDW3="$WORK/sd-noskillmd"; mkdir -p "$SDW3/.claude/skills/foo"
printf 'not a skill\n' > "$SDW3/.claude/skills/foo/README.md"
expect "SD/66 有目录但无 SKILL.md" 66 bash "$SD" "$SDW3"

SDW4="$WORK/sd-zeroref"; mkdir -p "$SDW4/.claude/skills/bar"
printf -- '---\nname: bar\n---\n本 skill 正文不含任何路径引用。\n' > "$SDW4/.claude/skills/bar/SKILL.md"
expect "SD/66 SKILL.md 抽出 0 条引用＝抽取失效，不是'无依赖'" 66 bash "$SD" "$SDW4"

# 命令形式的引用必须被抽到（旧正则要求"整个反引号内容就是一条路径"，抽不到 → 假绿）
SDW5="$WORK/sd-cmdref"; mkdir -p "$SDW5/.claude/skills/baz"
printf -- '---\nname: baz\n---\n跑 `bash docs/process/NOT-EXIST.md` 与 scripts/lib/ghost.sh\n' \
  > "$SDW5/.claude/skills/baz/SKILL.md"
expect "SD/1 命令内引用的缺失依赖必须被抓到" 1 bash "$SD" "$SDW5"

# 中文文件名不得被截断误报（白名单字符类版本会把 `docs/x/AI时代-调研.md` 截成 `docs/x/AI`）
SDW6="$WORK/sd-cjk"; mkdir -p "$SDW6/.claude/skills/qux" "$SDW6/docs/research"
printf 'x\n' > "$SDW6/docs/research/AI时代评审门禁-调研.md"
printf -- '---\nname: qux\n---\n依据：`docs/research/AI时代评审门禁-调研.md`\n' \
  > "$SDW6/.claude/skills/qux/SKILL.md"
expect "SD/0 中文文件名不误报（正样本回归）" 0 bash "$SD" "$SDW6"

# ---------- check-clause-refs 负样本（条款层 fail-open）----------
echo "-- check-clause-refs.sh --"
CR="$ROOT/scripts/check-clause-refs.sh"

CRW="$WORK/cr-noconst"; mkdir -p "$CRW"
expect "CR/66 无宪法文件（不得跳过）" 66 bash "$CR" "$CRW"

CRW2="$WORK/cr-dangling"; mkdir -p "$CRW2/docs" "$CRW2/.claude"
printf '# 宪法\n\n- **C1 x**。检查：y。\n- **C2 z**。检查：w。\n' > "$CRW2/docs/constitution.md"
printf '按宪法 C14 检查批准归因；另见 C12（异构评审）。\n' > "$CRW2/.claude/agent.md"
expect "CR/1 引用了未定义的 C12/C14（agent 会静默无约束继续）" 1 bash "$CR" "$CRW2"

CRW3="$WORK/cr-badfmt"; mkdir -p "$CRW3/docs"
printf '# 宪法\n\n条款格式变了，抽不出定义。\n' > "$CRW3/docs/constitution.md"
expect "CR/66 抽出 0 条定义＝抽取失效，不是'宪法为空'" 66 bash "$CR" "$CRW3"

# ---------- check-branch-protection 负样本（不触网的可测部分）----------
# 这个探针必须真推远端才能出行为证明，故 PR 触发的 CI 不跑它（会写远端）。
# 但它的**前置自检与降级路径**必须可证伪，且必须证明"不存在静默 exit 0"。
echo "-- ops/check-branch-protection.sh --"
BP="$ROOT/ops/check-branch-protection.sh"

BPW="$WORK/bp-notgit"; mkdir -p "$BPW"
( cd "$BPW" && bash "$BP" >/dev/null 2>&1 ); rc=$?
total=$((total+1))
if [ "$rc" = 66 ]; then echo "  ✅ BP/66 不在 git 工作区（自检失败，非静默）"
else echo "  ❌ BP/66 不在 git 工作区（期望 66，实际 ${rc}）"; fails=$((fails+1)); fi

# 关键性质：无论走哪条降级路径，**都不得 exit 0**（exit 0 只允许来自真实行为证明）
BPW2="$WORK/bp-nogh"; mkdir -p "$BPW2"
( cd "$BPW2" && PATH=/usr/bin:/bin bash "$BP" >/dev/null 2>&1 ); rc=$?
total=$((total+1))
if [ "$rc" != 0 ]; then echo "  ✅ BP/非0 gh 不可用时不得静默通过（实际 ${rc}）"
else echo "  ❌ BP 在 gh 不可用时 exit 0 —— 静默通过"; fails=$((fails+1)); fi

# ---------- 陷阱扫描的 vendored 排除（不能把自己的文件也放过）----------
# 起源：装了 node_modules 后探针开始扫第三方脚本并报错。第三方代码既不拥有也改不了，
# 本探针查的是**我们自己**的编码约定。但"排除"极易滑成"整类放过"，故双向钉死。
echo "-- check-shell-traps vendored 排除 --"
STW="$WORK/traps-excl"; mkdir -p "$STW/scripts" "$STW/node_modules/pkg"
printf '#!/usr/bin/env bash\ntimeout 5 x\n' > "$STW/node_modules/pkg/vendor.sh"
expect "陷阱扫描/0 只有 node_modules 里有陷阱时放行" 0 bash "$ROOT/scripts/check-shell-traps.sh" "$STW"
printf '#!/usr/bin/env bash\ntimeout 5 x\n' > "$STW/scripts/ours.sh"
expect "陷阱扫描/66 我们自己的文件有陷阱仍必抓" 66 bash "$ROOT/scripts/check-shell-traps.sh" "$STW"

# ---------- SPEC-24 smoke：手册教的每条命令在新项目里必须真实可跑 ----------
# 起源：手册与 init 的"下一步"提示都让用户在自己项目里跑 `e2e doctor`，
# 但 bin/e2e 从未被发到目标仓 —— 新用户照做即 command not found。
# 文档说的和脚手架发的**漂移**了，只有真跑一次干净 init 才发现。
echo "-- SPEC-24 手册命令可执行性 smoke --"
SMOKE="$WORK/smoke-fresh"; mkdir -p "$SMOKE"
bash "$ROOT/bin/e2e" init "$SMOKE" >/dev/null 2>&1 || true

# 从手册里抽取它教用户跑的仓内命令，逐条验证目标仓里真的有
MAN="$ROOT/docs/implementation-manual.md"
if [ -f "$MAN" ]; then
  man_refs=$(grep -oE 'bash (bin|scripts|ops|tests)/[A-Za-z0-9_./-]+' "$MAN" \
             | sed -E 's/^bash //' | sort -u)
  smoke_bad=0; smoke_n=0
  while IFS= read -r r; do
    [ -n "$r" ] || continue
    smoke_n=$((smoke_n+1))
    [ -e "$SMOKE/$r" ] || { echo "  ❌ 手册教了 ${r}，但 init 没发到目标仓"; smoke_bad=$((smoke_bad+1)); }
  done <<INNER
$man_refs
INNER
  total=$((total+1))
  if [ "$smoke_n" -lt 3 ]; then
    echo "  ❌ 只从手册抽到 ${smoke_n} 条命令——抽取失效"; fails=$((fails+1))
  elif [ "$smoke_bad" -eq 0 ]; then
    echo "  ✅ 手册教的 ${smoke_n} 条命令在新项目里全部存在"
  else
    fails=$((fails+1))
  fi

  # doctor 必须能在目标仓真跑起来（照 init 的"下一步"提示）
  total=$((total+1))
  if (cd "$SMOKE" && bash bin/e2e doctor >/dev/null 2>&1); then
    echo "  ✅ 新项目里 bash bin/e2e doctor 可执行"
  else
    echo "  ❌ 新项目里 doctor 跑不起来（init 的"下一步"提示是假的）"; fails=$((fails+1))
  fi
elif [ -f "$ROOT/bin/e2e" ] && [ -d "$ROOT/specs/platform-pilot" ]; then
  # 平台仓本该有手册却没有 —— 这是真缺失，必须响亮失败
  total=$((total+1)); echo "  ❌ 平台仓缺手册 $MAN"; fails=$((fails+1))
else
  # 业务仓不含手册（手册是平台仓交付物，不随脚手架分发）—— 属平台专属能力，
  # 与 bin/e2e 同一处理方式。判据是"本仓有没有这个能力"，不是"找不到就算了"。
  echo "  ⏭  跳过（本仓无实施手册，属平台专属交付物）"
fi

# ---------- 门禁台账：决定值非法必须被抓（fail-open 修复回归）----------
# 起源：7 个阶段探针里 6 个只用 gate_status **显示**决定值，从不校验它属于契约集合。
# 门禁④ 被填成"放行"（契约是 批准/打回）后 check-release.sh --final 判 PASS 放行，
# 直到门禁⑤ 入口才炸。台账层 fail-open —— 写错一个词能过自己那道门。
echo "-- 门禁决定值合法性（gate_assert_legal）--"
GW="$WORK/gatelegal"; mkdir -p "$GW"
mk_prfaq() {  # mk_prfaq <决定值>
  printf -- '# PRFAQ：t\n\n## 假设陈述\nx\n\n## Appetite\nx\n\n## 熔断线\nx\n\n## 深坑\nx\n\n## No-gos\nx\n\n## FAQ\nQ: a\nA: b\n\n---\n门禁⓪ 记录：\n- 批准人：tester\n- 决定：%s\n- 日期：2026-01-01\n- 备注：t\n' "$1" > "$GW/prfaq.md"
}
P0G="$ROOT/.claude/skills/e2e-discovery/scripts/check-prfaq.sh"

for bad in 放行 批准 随便写; do
  mk_prfaq "$bad"
  total=$((total+1))
  if bash "$P0G" "$GW/prfaq.md" 2>&1 | grep -q "决定值非法"; then
    echo "  ✅ 门禁⓪ 拒绝非法决定值「${bad}」"
  else
    echo "  ❌ 门禁⓪ 放过了非法决定值「${bad}」——台账 fail-open 复发"; fails=$((fails+1))
  fi
done
for good in go modify kill; do
  mk_prfaq "$good"
  total=$((total+1))
  if bash "$P0G" "$GW/prfaq.md" 2>&1 | grep -q "决定值非法"; then
    echo "  ❌ 门禁⓪ 误判合法值「${good}」为非法"; fails=$((fails+1))
  else
    echo "  ✅ 门禁⓪ 接受合法值「${good}」"
  fi
done

# ---------- 三通道契约：block 只能来自 deterministic（改门禁探针后的回归）----------
# 起源：check-review.sh 原用**整行子串匹配**判违规，于是一条 source=deterministic
# 的 finding 只要在「提出方」列写了 llm-advisory 就被误判。改为按列解析后，
# 必须双向钉死：真违规仍抓得到（防改松），归属列提及不误判（防假阳性）。
#
# fixture **自包含**：早期版本依赖 specs/platform-pilot/review.md，该文件不存在时
# 走"跳过"分支，套件照样报绿 —— 又一次静默通过。现在 fixture 就地构造，必须真跑。
echo "-- check-review.sh 三通道契约（按列解析）--"
CRV="$ROOT/.claude/skills/e2e-review/scripts/check-review.sh"
CVW="$WORK/cv/specs/x"; mkdir -p "$CVW"

printf -- '# TASKS：fixture\n\n- [x] T-1 做完了 ｜ SPEC-1 ｜ 复杂度 1 ｜ 依赖 - ｜ 验证：`true`\n' > "$CVW/tasks.md"

cv_review() {  # cv_review <额外的 finding 行>
  {
    printf '# REVIEW：fixture\n\n## 定档结论\n\n- **风险档**：中\n- **依据**：fixture\n\n'
    printf '## 覆盖声明\n\n- **已审**：a.sh\n- **未审及原因**：无\n\n'
    printf '## Findings\n\n'
    printf '| ID | severity | source | 类型 | 定位 | 问题 | 状态 | 证据 |\n'
    printf '|---|---|---|---|---|---|---|---|\n'
    printf '| F-1 | warn | deterministic | correctness | a.sh:1 | 基线条目 | fixed | `true` |\n'
    printf '%s\n' "$1"
    printf '\n## 异构评审\n\n异构评审: unavailable(fixture)\n\n'
    printf -- '---\n门禁③ 记录：\n- 批准人：fixture\n- 决定：批准\n- 日期：2026-01-01\n- 备注：fixture\n'
  } > "$CVW/review.md"
}

# 方向①：真违规（severity=block + source=llm-advisory）必须被抓
cv_review '| F-99 | block | llm-advisory | correctness | a.sh:1 | LLM 声称必须阻断 | fixed | 无 |'
total=$((total+1))
if bash "$CRV" "$CVW/" --final 2>&1 | grep -q "违反三通道"; then
  echo "  ✅ 真违规 block+llm-advisory 被抓到（门禁未被改松）"
else
  echo "  ❌ 真违规漏掉——三通道契约已失效"; fails=$((fails+1))
fi

# 方向②：source=deterministic 但归属列提及 llm-advisory，不得误判
cv_review '| F-98 | block | deterministic | llm-advisory ×3 | correctness | a.sh:1 | 由 LLM 线索转化 | fixed | 负样本对旧实现失败 |'
total=$((total+1))
if bash "$CRV" "$CVW/" --final 2>&1 | grep -q "违反三通道"; then
  echo "  ❌ 归属列提及 llm-advisory 被误判为违规（假阳性）"; fails=$((fails+1))
else
  echo "  ✅ 归属列提及不误判"
fi

# ---------- F-6 回归：行为探针不得碰工作区/索引 ----------
# 起源：异构评审 + reviewer + security 三方独立指出 `git commit --allow-empty`
# **会提交当前 index**。实测复现：暂存机密后跑探针，机密进了"空提交"；
# 且 cleanup 的 branch -D 在**成功路径上也会**销毁那份暂存工作。
# 这条把"不碰工作区"钉成可证伪断言：探针跑完后 index 与分支必须原样。
echo "-- F-6 行为探针的副作用回归 --"
BPREPO="$WORK/bp-sideeffect"
mkdir -p "$BPREPO" && cd "$BPREPO"
git init -q . && git config user.email t@t && git config user.name t
echo base > a.txt && git add a.txt && git commit -qm base
echo "STAGED-SECRET" > secret.txt && git add secret.txt
IDX_BEFORE=$(git diff --cached --name-only | sort | tr '\n' ',')
BR_BEFORE=$(git rev-parse --abbrev-ref HEAD)
# 无 origin，探针会在推断仓库处 exit 2（降级），但**在此之前不得动索引**
bash "$ROOT/ops/check-branch-protection.sh" >/dev/null 2>&1 || true
IDX_AFTER=$(git diff --cached --name-only | sort | tr '\n' ',')
BR_AFTER=$(git rev-parse --abbrev-ref HEAD)
cd "$ROOT"
total=$((total+1))
if [ "${IDX_BEFORE}" = "${IDX_AFTER}" ] && [ "${BR_BEFORE}" = "${BR_AFTER}" ] \
   && [ -f "$BPREPO/secret.txt" ]; then
  echo "  ✅ BP 不碰索引/分支/工作区（索引 ${IDX_BEFORE} 原样，暂存文件仍在）"
else
  echo "  ❌ BP 有副作用：索引 [${IDX_BEFORE}]→[${IDX_AFTER}]，分支 ${BR_BEFORE}→${BR_AFTER}"
  fails=$((fails+1))
fi
total=$((total+1))
if git -C "$BPREPO" branch --list | grep -q '__e2e'; then
  echo "  ❌ BP 残留临时分支"; fails=$((fails+1))
else
  echo "  ✅ BP 无残留临时分支"
fi

# ---------- F-11 回归：金丝雀必须能发现生产正则退化 ----------
# 起源：reviewer + security 指出金丝雀用的正则与生产不是同一条，
# 于是"生产正则写坏了金丝雀照样绿"。共用 PATH_RE 之后，本用例把该性质钉死：
# 把生产 PATH_RE 改坏 → 金丝雀必须 exit 66，而不是继续跑出 PASS。
echo "-- F-11 金丝雀能否发现引擎退化 --"
SD_BROKEN="$WORK/check-skill-deps-broken.sh"
sed -E "s|^PATH_RE=.*|PATH_RE='__NEVER_MATCHES_ANYTHING__'|" \
    "$ROOT/scripts/check-skill-deps.sh" > "$SD_BROKEN"
expect "SD/66 生产正则被改坏时金丝雀必须报警（而非静默 PASS）" 66 bash "$SD_BROKEN" "$ROOT"

# ---------- ratchet 负样本（S5，独立脚本）----------
echo "-- ratchet.sh --"
expect "ratchet 六用例（含替换违规总数不变）" 0 bash "$ROOT/tests/probe-negative/ratchet-negative.sh"

echo
echo "== 结果：$((total-fails))/$total 符合预期 $([ $fails -eq 0 ] && echo '✅' || echo '❌') =="
exit $([ $fails -eq 0 ] && echo 0 || echo 1)
