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

# 陷阱 4/5/6（手册 §7.2 表 #2/#5/#7）：从"文档里写着"变成"探针真的拦"。
# 手册上一版称 7 条**全部已固化**，实际只实现了 3 条 —— 这三条补齐并在此钉死。
# 坏样本一律拼接生成，否则扫描器会（正确地）把本文件也判为含陷阱。
{ printf '#!/usr/bin/env bash\n'; printf 'grep %sP "x" f\n' '-'; } > "$WORK/trap4.sh"
expect "陷阱4/66 grep -P（BSD 不支持，配 ||true 则永远 PASS）" 66 bash "$ROOT/scripts/check-shell-traps.sh" "$WORK/trap4.sh"

{ printf '#!/usr/bin/env bash\n'; printf 'n=$(grep %sc . f) %s echo 0\n' '-' '||'; } > "$WORK/trap5.sh"
expect "陷阱5/66 grep -c 后 || echo 0（会追加出第二行）" 66 bash "$ROOT/scripts/check-shell-traps.sh" "$WORK/trap5.sh"

# "md5""sum" 也要拼接：整词写出来会被陷阱3（GNU 命令）命中，那就测不到陷阱6 了
{ printf '#!/usr/bin/env bash\n'; printf 'x=$(md5 -q f %s cut -c1-8 %s md5%s f)\n' '|' '||' 'sum'; } > "$WORK/trap6.sh"
expect "陷阱6/66 管道后 || 兜底（退出码来自末端，兜底永不触发）" 66 bash "$ROOT/scripts/check-shell-traps.sh" "$WORK/trap6.sh"

# **双向**：正确写法必须放行，否则规则只会误伤（|| true 里的 true 不得被当成 tr 命令）
{ printf '#!/usr/bin/env bash\n'; printf 'n=$(grep %sc . f %s true); : "${n:=0}"\n' '-' '||'; } > "$WORK/trap-ok.sh"
expect "陷阱4-6/0 正确写法必须放行（true 不得被误判为 tr）" 0 bash "$ROOT/scripts/check-shell-traps.sh" "$WORK/trap-ok.sh"

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

# ---------- CRITICAL 回归：门禁台账不得被正文伪造（首匹配胜）----------
# 安全评审 critical #1：旧实现取全文首个 `- 决定：`，而门禁块契约是**尾部四行**。
# 执行者在正文早处写 `- 决定：go`、尾部保持 <待填>，探针即判 PASS 且下游打印 GATE0 ✓——
# **人翻到文末只看到"待批"，机器却认为已批准**。同时击穿 C1 与 C14，且自批不可见。
echo "-- 门禁台账防伪（尾部锚定 + 歧义 fail-closed）--"
FW="$WORK/forge"; mkdir -p "$FW"
mk_forged() {  # mk_forged <正文里伪造的决定值> <尾部块决定值>
  {
    echo '# PRFAQ：t'; echo
    echo '## 未来新闻稿'; echo '正文里的一行：'; echo "- 决定：$1"; echo
    for h in 客户与痛点 差异化主张 最险假设 假设陈述 Appetite 熔断线 深坑 No-gos 不做什么; do
      echo "## $h"; echo x; echo; done
    echo '## FAQ'; echo 'Q: a'; echo; echo 'A: b'; echo
    echo '---'; echo '门禁⓪ 记录：'
    echo '- 批准人：<待填>'; echo "- 决定：$2"; echo '- 日期：<待填>'; echo '- 备注：<待填>'
  } > "$FW/prfaq.md"
}
mk_forged go '<待填>'
expect "台账/66 正文伪造 go + 尾部待批 → 必须拒绝（不得判 PASS）" 66 \
  bash "$ROOT/.claude/skills/e2e-discovery/scripts/check-prfaq.sh" "$FW/prfaq.md"
total=$((total+1))
if bash "$ROOT/.claude/skills/e2e-discovery/scripts/check-prfaq.sh" "$FW/prfaq.md" 2>&1 | grep -q "决定：go"; then
  echo "  ❌ 探针把正文伪造行当成了决定值（首匹配胜复发）"; fails=$((fails+1))
else
  echo "  ✅ 探针未采信正文伪造行"
fi
# 歧义即 fail-closed：两条决定行（一真一假）也必须拒
mk_forged go 批准
total=$((total+1))
if bash "$ROOT/.claude/skills/e2e-discovery/scripts/check-prfaq.sh" "$FW/prfaq.md" 2>&1 | grep -qE "UNKNOWN|非法|MISSING"; then
  echo "  ✅ 多条决定行判 UNKNOWN（歧义即拒绝，不猜哪条是真的）"
else
  echo "  ❌ 多条决定行未判歧义"; fails=$((fails+1))
fi

# ---------- CRITICAL 回归：E2E_PR 参数注入 ----------
# 安全评审 critical #2：`gh pr view ${E2E_PR:-}` 未加引号，bash 词分割使
# E2E_PR="--repo cli/cli 6000" 展开成 gh pr view --repo cli/cli 6000 → 查了**别人的仓**。
# 填一个任意公开仓里 MERGED+全绿的 PR 号，门禁③ 就用别人仓的证据开门。
echo "-- 门禁③ E2E_PR 参数注入 --"
P5I="$ROOT/.claude/skills/e2e-release/scripts/check-release.sh"
IW="$WORK/prinj/specs/x"; mkdir -p "$IW"
printf -- '# TASKS\n\n- [x] T-1 done ｜ SPEC-1 ｜ 复杂度 1 ｜ 依赖 - ｜ 验证：`true`\n' > "$IW/tasks.md"
total=$((total+1))
if ( cd "$WORK/prinj" && E2E_PR="--repo cli/cli 6000" bash "$P5I" specs/x/ --gate-only 2>&1 \
     | grep -q "E2E_PR 非法" ); then
  echo "  ✅ 注入型 E2E_PR 被白名单拒绝"
else
  echo "  ❌ 注入型 E2E_PR 未被拦（参数注入复发）"; fails=$((fails+1))
fi

# ---------- init 幂等性：第二次跑不得覆盖用户修改（冷启动验收 blocker）----------
# 起源：copy_tree 旧实现是 `cp -R "$src/." "$dst/"` **整目录无条件覆盖**，
# 于是 `e2e init` 第二次跑会静默清除用户对 skill/agent/hook/lib/stages 的**全部修改**，
# 而工具还打印「⚠️ 冲突项已保留原文件（SPEC-10 幂等安全）」—— **给出的是相反的保证**。
# 「改了 skill → 想升级平台 → 再跑一次 init」是完全自然的路径，代价是丢工作。
echo "-- init 幂等性（第二次跑不得覆盖）--"
IDW="$WORK/idempotent"; mkdir -p "$IDW"
bash "$ROOT/bin/e2e" init "$IDW" >/dev/null 2>&1
# 在五个曾被整目录覆盖的位置各留一处标记
for m in ".claude/skills/e2e-discovery/SKILL.md" ".claude/agents/reviewer.md" \
         ".claude/hooks/stop-verify.sh" "scripts/lib/gate.sh" "docs/process/stages/stage-0-discovery.md"; do
  [ -f "$IDW/$m" ] && printf '\n# IDEMPOTENT-PROBE-MARK\n' >> "$IDW/$m"
done
bash "$ROOT/bin/e2e" init "$IDW" >/dev/null 2>&1
lost=0
for m in ".claude/skills/e2e-discovery/SKILL.md" ".claude/agents/reviewer.md" \
         ".claude/hooks/stop-verify.sh" "scripts/lib/gate.sh" "docs/process/stages/stage-0-discovery.md"; do
  if [ -f "$IDW/$m" ] && ! grep -q 'IDEMPOTENT-PROBE-MARK' "$IDW/$m"; then
    echo "  ❌ 第二次 init 覆盖了用户修改：${m}"; lost=$((lost + 1))
  fi
done
total=$((total+1))
if [ "$lost" -eq 0 ]; then
  echo "  ✅ 五处用户修改在第二次 init 后全部保留"
else
  echo "  ❌ ${lost} 处用户修改被静默清除 —— 而工具声称「已保留原文件」"; fails=$((fails+1))
fi

# ---------- README 门面（公开仓第一眼）----------
# 起源：仓已公开且挂在插件市场邀请安装，却**没有 README** —— 别人点开什么导航都没有。
# 这个洞自建者永远发现不了（他知道所有文件在哪），是典型的"只有外人能看见"的缺陷。
echo "-- README 门面 --"
RM="$ROOT/scripts/check-readme.sh"
RW="$WORK/readme"; mkdir -p "$RW"
expect "README/65 无 README（公开仓无导航）" 65 bash "$RM" "$RW"
printf '# x\n' > "$RW/README.md"
expect "README/1 空壳 README" 1 bash "$RM" "$RW"
{ for i in $(seq 25); do echo "行 ${i}"; done
  echo '见 [手册](./docs/NOT-EXIST.md)'; echo '## 已知限制'
  for i in $(seq 6); do echo "- 限制 ${i}"; done; } > "$RW/README.md"
expect "README/1 链接指向不存在的文件" 1 bash "$RM" "$RW"
{ for i in $(seq 25); do echo "行 ${i}"; done
  echo '见 [自己](./README.md)'; echo '跑 `bash scripts/ghost.sh`'
  echo '## 已知限制'; for i in $(seq 6); do echo "- 限制 ${i}"; done; } > "$RW/README.md"
expect "README/1 教了一条跑不通的命令" 1 bash "$RM" "$RW"
{ for i in $(seq 25); do echo "行 ${i}"; done; echo '见 [自己](./README.md)'; } > "$RW/README.md"
expect "README/1 缺「已知限制」段（门面只说好话）" 1 bash "$RM" "$RW"

# ---------- AI 评审三通道契约（LLM 不得有阻断权）----------
# 起源：ai-review 模板早期写 `blocks>0 → exit 1`，把阻断权交给了 LLM，
# 直接违反本平台自己的核心契约。连带效应更麻烦：fork PR 拿不到 secrets → job 红，
# 踩到的人最可能改成 pull_request_target —— 经典 pwn request。
echo "-- AI 评审三通道契约 --"
AIC="$ROOT/scripts/check-ai-review-contract.sh"
AW="$WORK/aireview"; mkdir -p "$AW/.github/workflows"
mk_ai() {  # mk_ai <触发器> <run 内容> <是否含 required-check 声明:yes|no>
  {
    echo "name: ai-review"; echo "on:"; echo "  $1:"
    echo "jobs:"; echo "  review:"; echo "    steps:"; echo "      - run: |"; echo "          $2"
    [ "$3" = yes ] && echo "# 本 job 不能设为 required check"
  } > "$AW/.github/workflows/ai-review.yml"
}
mk_ai pull_request 'echo ok' yes
expect "AI契约/0 合规模板放行" 0 bash "$AIC" "$AW"
mk_ai pull_request 'if [ "$blocks" -gt 0 ]; then exit 1; fi' yes
expect "AI契约/1 LLM 结果决定 CI 成败必须被抓" 1 bash "$AIC" "$AW"
mk_ai pull_request_target 'echo ok' yes
expect "AI契约/1 pull_request_target 必须被抓（pwn request）" 1 bash "$AIC" "$AW"
mk_ai pull_request 'echo ok' no
expect "AI契约/1 缺「不得设为 required check」声明必须被抓" 1 bash "$AIC" "$AW"

# ---------- 门禁台账：决定值非法必须被抓（fail-open 修复回归）----------
# 起源：7 个阶段探针里 6 个只用 gate_status **显示**决定值，从不校验它属于契约集合。
# 门禁④ 被填成"放行"（契约是 批准/打回）后 check-release.sh --final 判 PASS 放行，
# 直到门禁⑤ 入口才炸。台账层 fail-open —— 写错一个词能过自己那道门。
echo "-- 门禁决定值合法性（gate_assert_legal）--"
GW="$WORK/gatelegal"; mkdir -p "$GW"
# fixture 必须**结构完整**，否则合法值用例会因缺章节退 66，
# 那样 `expect ... 0` 断言的就不是"决定值合法"而是别的（评审 finding 2 修复的配套）。
mk_prfaq() {  # mk_prfaq <决定值>
  {
    printf -- '# PRFAQ：t\n\n'
    for h in 未来新闻稿 客户与痛点 差异化主张 最险假设 假设陈述 Appetite 熔断线 深坑 No-gos 不做什么; do
      printf -- '## %s\n\n占位内容一行。\n\n' "$h"
    done
    printf -- '## FAQ\n\nQ: a\n\nA: b\n\n'
    printf -- '---\n门禁⓪ 记录：\n- 批准人：tester\n- 决定：%s\n- 日期：2026-01-01\n- 备注：t\n' "$1"
  } > "$GW/prfaq.md"
}
P0G="$ROOT/.claude/skills/e2e-discovery/scripts/check-prfaq.sh"

# 断言**退出码**而非消息文本（评审 finding 2 实证）：
# 早期只 grep "决定值非法"，于是把接线退化成 `gate_assert_legal ... || true`
# （打印但不阻断，rc=0）时这 6 条用例**仍全绿** —— 把"真拦住了"降格成了"打印了"。
for bad in 放行 批准 随便写; do
  mk_prfaq "$bad"
  expect "门禁⓪/66 拒绝非法决定值「${bad}」（断言退出码非 0）" 66 bash "$P0G" "$GW/prfaq.md"
done
for good in go modify kill; do
  mk_prfaq "$good"
  expect "门禁⓪/0 接受合法值「${good}」" 0 bash "$P0G" "$GW/prfaq.md"
done

# ---- release / retire 的 gate_assert_legal 调用点（评审 finding 3：插桩实测零覆盖）----
# 这两道门（④⑤）恰是 gate.sh 注释里引用的事故现场（门禁④被填成"放行"→ --final 判 PASS），
# 但修复打在了**没有任何测试跑得到的行**上：--gate-only 提前 exit 0，非 gate-only 又在缺文件处 exit 65。
# 造出能走完上游门禁的 fixture，让这两行真的被执行到。
GR="$WORK/gate45"; mkdir -p "$GR/specs/x" "$GR/docs/runbooks"
printf -- '# TASKS

- [x] T-1 done ｜ SPEC-1 ｜ 复杂度 1 ｜ 依赖 - ｜ 验证：`true`
' > "$GR/specs/x/tasks.md"
mk_release() {  # mk_release <门禁④决定值>
  {
    printf '# RELEASE：x

## 门禁③ 入口证据

| 路径 | 怎么验的 | 实际证据 |
|---|---|---|
| 本地 | merge commit | fixture |

'
    printf '## PRR 核对表

- [x] PRR-1 项 ｜ 证据：`true` ｜ 核对人：tester

'
    printf '## 发布策略

fixture

## 回滚预案

| 触发判据 | 回滚动作 | RTO | 不可逆点 |
|---|---|---|---|
| x | `git revert HEAD` | 5 分钟 | 无 |

'
    printf -- '- **回滚演练证据**：fixture 实跑

## SLO 与监控

| SLI | 目标 SLO | 错误预算 | 告警规则 | 指向 runbook |
|---|---|---|---|---|
| x | 99.9%% | 43m | a | ## 故障处理 |

'
    printf -- '---
门禁④ 记录：
- 批准人：tester
- 决定：%s
- 日期：2026-01-01
- 备注：fixture
' "$1"
  } > "$GR/specs/x/release.md"
  printf '# Runbook

## 启动

跑 `x`。健康检查：`true`。

## 回滚

跑 `git revert HEAD`。校验：`true`。不可逆点：无。RTO 5 分钟。

## 故障处理

症状 A → 首诊 `true` → 处置 X → 升级 Y。
' > "$GR/docs/runbooks/x.md"
}
P5G="$ROOT/.claude/skills/e2e-release/scripts/check-release.sh"
mk_release 放行
( cd "$GR" && E2E_TEST_CMD=true E2E_BASE=none bash "$P5G" specs/x/ >/dev/null 2>&1 ); rc=$?
total=$((total+1))
if [ "${rc}" -ne 0 ]; then
  echo "  ✅ 门禁④ 拒绝非法决定值「放行」（rc=${rc}）"
else
  echo "  ❌ 门禁④ 放过了非法决定值「放行」——finding 3 的调用点仍无效"; fails=$((fails+1))
fi
mk_release 批准
( cd "$GR" && E2E_TEST_CMD=true E2E_BASE=none bash "$P5G" specs/x/ >/dev/null 2>&1 ); rc2=$?
total=$((total+1))
# 合法值下不应因"决定值非法"而失败（可能因其它结构项失败，故只断言不含该消息）
if ( cd "$GR" && E2E_TEST_CMD=true E2E_BASE=none bash "$P5G" specs/x/ 2>&1 | grep -q "决定值非法" ); then
  echo "  ❌ 门禁④ 误判合法值「批准」为非法"; fails=$((fails+1))
else
  echo "  ✅ 门禁④ 接受合法值「批准」（rc=${rc2}，非决定值原因）"
fi

# ---------- review 探针：block 闭环检查按列解析（四向钉死）----------
# 实测踩过：一条 severity=major / 状态=open 的 finding，因为问题描述里引用了
# 代码片段 `blocks>0 → exit 1`，被整行 grep "block" 命中，误判为"未闭环的 block"。
# 改按列后又踩第二个坑：两张表列数不同（9 列 / 8 列），$(NF-1) 取到的是证据列，
# **真·block+open 反而漏了** —— 那是把门禁改松，比误报严重得多。
# 最终改为「severity 列判 block + 任一字段精确等于状态机词」。四向全钉。
echo "-- review 探针：block 闭环按列解析 --"
BC="$WORK/blockclose/specs/x"; mkdir -p "$BC"
printf -- '# TASKS\n\n- [x] T-1 done ｜ SPEC-1 ｜ 复杂度 1 ｜ 依赖 - ｜ 验证：`true`\n' > "$BC/tasks.md"
mk_bc() {
  {
    printf '# REVIEW：x\n\n## 定档结论\n\n- **风险档**：中\n\n'
    printf '## 覆盖声明\n\n- **已审**：a\n- **未审及原因**：无\n\n## Findings\n\n'
    printf '| ID | severity | source | 类型 | 定位 | 问题 | 状态 | 证据 |\n|---|---|---|---|---|---|---|---|\n%s\n\n' "$1"
    printf '## 异构评审\n\n异构评审: unavailable(fixture)\n\n'
    printf -- '---\n门禁③ 记录：\n- 批准人：tester\n- 决定：批准\n- 日期：2026-01-01\n- 备注：t\n'
  } > "$BC/review.md"
}
CRV2="$ROOT/.claude/skills/e2e-review/scripts/check-review.sh"
bc_case() {  # bc_case <说明> <期望命中:yes|no> <finding 行>
  mk_bc "$3"; total=$((total+1))
  if bash "$CRV2" "$BC/" --final 2>&1 | grep -q "未闭环"; then hit=yes; else hit=no; fi
  if [ "$hit" = "$2" ]; then echo "  ✅ $1"; else echo "  ❌ $1（期望命中=${2}，实得=${hit}）"; fails=$((fails+1)); fi
}
bc_case "真·block+open 必须被抓（防改松）"          yes '| F-1 | block | deterministic | correctness | a:1 | x | open | - |'
bc_case "加粗 severity + reopened 也要被抓"          yes '| F-2 | **block** | deterministic | correctness | a:1 | x | reopened | - |'
bc_case "major/open 且描述含 blocks 不得误判"        no  '| F-3 | major | llm-advisory | security | a:1 | 描述含 `blocks>0 → exit 1` | open | - |'
bc_case "block/fixed 不得误判"                       no  '| F-4 | block | deterministic | correctness | a:1 | x | fixed | `true` |'

# ---------- review 探针：有 Findings 章节却抽到 0 条不得判 PASS ----------
# 实测踩过：平台自举评审用 P-N 前缀写了 12 条 finding，探针只认 F-N，
# 于是报「finding 0 条」并 PASS —— 所有 findings 相关检查（source 合法性、
# block 闭环、三通道契约）**一条都没跑**，却看起来是绿的。
echo "-- review 探针：findings 抽取失效不得静默 PASS --"
FE="$WORK/fext/specs/x"; mkdir -p "$FE"
printf -- '# TASKS\n\n- [x] T-1 done ｜ SPEC-1 ｜ 复杂度 1 ｜ 依赖 - ｜ 验证：`true`\n' > "$FE/tasks.md"
{
  printf '# REVIEW：x\n\n## 定档结论\n\n- **风险档**：中\n\n'
  printf '## 覆盖声明\n\n- **已审**：a\n- **未审及原因**：无\n\n'
  printf '## Findings\n\n| ID | severity | source | 类型 | 定位 | 问题 | 状态 | 证据 |\n|---|---|---|---|---|---|---|---|\n'
  printf '| P-1 | warn | deterministic | correctness | a.sh:1 | 用了错误前缀 | fixed | `true` |\n\n'
  printf -- '---\n门禁③ 记录：\n- 批准人：tester\n- 决定：批准\n- 日期：2026-01-01\n- 备注：t\n'
} > "$FE/review.md"
expect "review/66 有 Findings 章节却抽到 0 条（前缀写错）必须拒绝" 66 \
  bash "$ROOT/.claude/skills/e2e-review/scripts/check-review.sh" "$FE/"

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

# ---------- 制品不得是没填的模板（冷启动 MAJOR：门禁⓪ fail-open）----------
# 起源：check-prfaq.sh 对**一字未改的模板副本**判 PASS —— 门禁⓪ 可以被
# 一份没人填过的空模板通过（结构齐全、内容全是占位符）。
# 抄模板正是最自然的起手式，忘了填就交是常态，不是理论风险。
echo "-- 制品不得是没填的模板 --"
PF="$ROOT/.claude/skills/e2e-discovery/scripts/check-prfaq.sh"
PT="$ROOT/.claude/skills/e2e-discovery/templates/prfaq-template.md"
if [ -f "$PF" ] && [ -f "$PT" ]; then
  FW="$WORK/filled"; mkdir -p "$FW"
  cp "$PT" "$FW/verbatim.md"
  expect "填充/66 一字未改的模板必须被拒" 66 bash "$PF" "$FW/verbatim.md"

  # 只填 5 个槽（实测 78% 未动）—— 半成品同样不算制品
  awk '/<[^>]+>/ && n<5 { gsub(/<[^>]+>/, "（已认真填写的真实内容）"); n++ } { print }' \
      "$PT" > "$FW/half.md"
  expect "填充/66 只填了少数槽的半成品必须被拒" 66 bash "$PF" "$FW/half.md"

  # 填满所有槽 = 真实产物，必须放行（**双向**：只会拒不会放 = 探针没用）。
  # 这里就地由模板生成，**不引用 specs/platform-pilot/**：本套件会随脚手架发到客户仓，
  # 依赖平台自己的产物会让客户那边直接红（check-adopt-parity 当场抓到过这个回归）。
  # 门禁决定行要留着 <待填>：它是**合法**的待批值，替换掉会变成非法决定值（另一条检查会红）
  awk '{ if ($0 !~ /决定/) gsub(/<[^>]+>/, "（已认真填写的真实内容）"); print }' "$PT" > "$FW/real.md"
  expect "填充/0 槽位填满的制品必须放行" 0 bash "$PF" "$FW/real.md"

  # 判据失效时 fail-closed：模板没了 / 模板没有足够占位符，都不许静默 PASS
  # mutant 必须放在**与真实探针同样的相对深度**上，否则它先死在
  # "找不到 scripts/lib/gate.sh"（exit 65）—— 那就没测到判据本身。
  FR="$FW/fakeroot"; SKD="$FR/.claude/skills/e2e-discovery"
  mkdir -p "$SKD/scripts" "$SKD/templates" "$FR/scripts/lib"
  cp "$ROOT/scripts/lib/gate.sh" "$FR/scripts/lib/gate.sh"
  cp "$ROOT/scripts/lib/artifact.sh" "$FR/scripts/lib/artifact.sh"   # gate.sh 的署名判定依赖（A5）；scripts/lib 本就整树分发
  sed 's|\.\./templates/prfaq-template\.md|../templates/__不存在__.md|' "$PF" > "$SKD/scripts/check-prfaq.sh"
  expect "填充/66 模板缺失时拒绝判定（不得静默放行）" 66 bash "$SKD/scripts/check-prfaq.sh" "$FW/real.md"

  printf '# 标题\n正文没有占位符\n' > "$SKD/templates/thin.md"
  sed 's|\.\./templates/prfaq-template\.md|../templates/thin.md|' "$PF" > "$SKD/scripts/check-prfaq2.sh"
  expect "填充/66 模板占位符过少时拒绝判定" 66 bash "$SKD/scripts/check-prfaq2.sh" "$FW/real.md"
else
  echo "  ⚠️  跳过：无 check-prfaq.sh 或模板"
fi

# ---------- USAGE 已知限制 ↔ 手册 §7 对账（此前是条无人执行的规则）----------
# 起源：USAGE.md 自己写着"本节**必须与实施手册 §7 对账**"，而没有任何东西执行它。
# 实测已漂出 1 条只在 USAGE、手册里没有的限制（Bash(bash bin/e2e*) 任意目录写入原语）。
echo "-- USAGE 已知限制对账 --"
CM="$ROOT/scripts/check-manual.sh"
if [ -f "$CM" ] && [ -f "$ROOT/USAGE.md" ]; then
  # 用**符号链接**搭一棵真实树，只把 USAGE.md 换成变体：
  # 直接复制 manual+USAGE 会让 check-manual 的"引用的脚本必须存在"那几项先红，
  # 于是测不到对账本身（第一版就踩了这个）。
  MW="$WORK/manual"; mkdir -p "$MW/scripts"
  for d in docs bin ops tests .claude; do [ -e "$ROOT/$d" ] && ln -s "$ROOT/$d" "$MW/$d"; done
  cp "$CM" "$MW/scripts/check-manual.sh"
  for f in "$ROOT"/scripts/*.sh; do
    [ "$(basename "$f")" = "check-manual.sh" ] || ln -s "$f" "$MW/scripts/$(basename "$f")"
  done
  # 好样本：条条标了出处 → 放行
  cp "$ROOT/USAGE.md" "$MW/USAGE.md"
  expect "对账/0 条条标了手册出处必须放行" 0 bash "$MW/scripts/check-manual.sh" "$MW/docs/implementation-manual.md"
  # 坏样本：抹掉出处标注 → 必须被抓（否则这条规则又变回"写着但没人执行"）
  sed 's/ （手册 §7）$//; s/ （手册 §7\.1b）$//' "$ROOT/USAGE.md" > "$MW/USAGE.md"
  expect "对账/66 有限制未标手册出处必须被抓" 66 bash "$MW/scripts/check-manual.sh" "$MW/docs/implementation-manual.md"
else
  echo "  ⚠️  跳过：无 check-manual.sh 或 USAGE.md"
fi

# ---------- assess 的风险分级初稿（冷启动 MAJOR：三处假数据）----------
# ① 热点 glob 恒为字面量 `---`（旧写法按固定行号 head -8|tail -3，取到的是表头与分隔行）
#    —— 一条永远匹配不到任何文件的"高风险"规则：看着有、实际没有
# ② 没有兜底档：不匹配任何 glob 的新目录/新语言 = 没有档 = 静默按最低处理
# ③ 降级判据数的是**全部**历史，而 churn 只看近一年 → 老仓判"历史充足"，churn 表却是空的
echo "-- assess 风险分级初稿 --"
if command -v git >/dev/null 2>&1 && [ -f "$ROOT/bin/e2e" ]; then
  AW="$WORK/assess"; mkdir -p "$AW/live"
  ( cd "$AW/live" && git init -q
    for i in 1 2 3 4 5; do printf 'line %s\n' "$i" >> code.sh
      git -c user.email=a@b -c user.name=a commit -qam "c$i" 2>/dev/null || \
      { git add -A; git -c user.email=a@b -c user.name=a commit -qm "c$i"; }; done
    for i in $(seq 6 25); do git -c user.email=a@b -c user.name=a commit -q --allow-empty -m "c$i"; done ) >/dev/null 2>&1
  bash "$ROOT/bin/e2e" assess "$AW/live" -o "$AW/out" >/dev/null 2>&1
  DR="$AW/out/risk-tiers-draft.md"

  total=$((total+1))
  if [ -f "$DR" ] && ! grep -qE '高（热点）\*\* \| -+ *\|' "$DR"; then
    echo "  ✅ assess/热点 glob 不是字面量 --- （旧实现固定行号取到了分隔行）"
  else
    echo "  ❌ assess/热点 glob 又变回 --- 了（匹配不到任何文件的假规则）"; fails=$((fails+1))
  fi

  total=$((total+1))
  if [ -f "$DR" ] && grep -q '兜底' "$DR"; then
    echo "  ✅ assess/存在兜底档（未分类路径不得默认低风险）"
  else
    echo "  ❌ assess/缺兜底档：不匹配任何 glob 的路径没有档 = 静默按最低处理"; fails=$((fails+1))
  fi

  # ③ 老仓：全量 25 commits 够，但**近一年 0** —— 旧判据会误判为历史充足
  # 注意必须设 GIT_COMMITTER_DATE：--since 按 committer date 过滤，--date 只改 author date
  mkdir -p "$AW/stale"
  ( cd "$AW/stale" && git init -q
    for i in $(seq 1 25); do
      GIT_COMMITTER_DATE="2021-01-01T12:00:00" git -c user.email=a@b -c user.name=a \
        commit -q --allow-empty --date="2021-01-01T12:00:00" -m "c$i"
    done ) >/dev/null 2>&1
  bash "$ROOT/bin/e2e" assess "$AW/stale" -o "$AW/out2" >/dev/null 2>&1
  total=$((total+1))
  if grep -q '近一年 0 commits' "$AW/out2/hotspots.md" 2>/dev/null \
     && ! grep -q '高（热点）' "$AW/out2/risk-tiers-draft.md" 2>/dev/null; then
    echo "  ✅ assess/老仓（近一年无提交）正确降级，不产出建立在零数据上的热点档"
  else
    echo "  ❌ assess/老仓未降级：churn 窗口是空的，热点档建立在零数据上"; fails=$((fails+1))
  fi
else
  echo "  ⚠️  跳过：无 git 或 bin/e2e"
fi

# ---------- shell-traps 金丝雀复用生产正则（platform-hardening A2）----------
# 起源：2026-08-01 mutation 实测——金丝雀与生产正则各存一份字面量，改坏生产 t1 正则后
# 金丝雀照绿、含陷阱样本判 PASS exit 0。金丝雀必须复用生产同一条正则（CLAUDE.md 陷阱 E/F/G），
# 生产正则被改坏时要当场响亮 66，不许假绿。样本用 \x 转义防 run.sh 自身被陷阱扫描误伤。
echo "-- shell-traps 金丝雀单源 --"
ST="$ROOT/scripts/check-shell-traps.sh"
STW="$WORK/shelltraps"; mkdir -p "$STW"
printf 'v=1\necho "$v\xe3\x80\x82"\n' > "$STW/t1.sh"
printf '#!/bin/sh\n\x67rep -P x f\n'  > "$STW/t4.sh"
printf '\x73ed -i x f\n'              > "$STW/t2.sh"
expect "traps/66 陷阱1 样本被检出（检出力不回退）" 66 bash "$ST" "$STW/t1.sh"
expect "traps/66 陷阱4 样本被检出" 66 bash "$ST" "$STW/t4.sh"
# 只改坏"生产那一份"（旧实现=scan 调用里的字面量；新实现=共享变量）→ 金丝雀必须当场拦
mut_trap() { sed -e "s/^t${1}=\$(scan '[^']*'/t${1}=\$(scan 'ZZZ_NEVER'/" \
                 -e "s/^T${1}_RE=.*/T${1}_RE='ZZZ_NEVER'/" "$ST" > "$STW/mut.sh"; }
mut_trap 1; expect "traps/66 改坏陷阱1 生产正则→金丝雀拦截（不许假绿）" 66 bash "$STW/mut.sh" "$STW/t1.sh"
mut_trap 4; expect "traps/66 改坏陷阱4 生产正则→金丝雀拦截" 66 bash "$STW/mut.sh" "$STW/t4.sh"
sed -e "s/^T2_STR=.*/T2_STR='ZZZ_NEVER'/" "$ST" > "$STW/mut2.sh"
expect "traps/66 改坏陷阱2 固定串→检出型金丝雀拦截（旧实现无此金丝雀）" 66 bash "$STW/mut2.sh" "$STW/t2.sh"

# ---------- 修宪须伴随 ADR + C8 大改动看守（platform-hardening B6/B5）----------
# 起源：mutation 实测把 C14 改成"可自批，检查：无"后 clause-refs/structure 双绿（评估 D9）；
# C8 检查栏零机器执行、tasks 台账只撑到 M1（评估 D13）。
echo "-- 修宪/C8 diff 看守 --"
if command -v git >/dev/null 2>&1; then
  CW="$WORK/constadr"; mkdir -p "$CW/scripts" "$CW/docs/architecture/adr"
  cp "$ROOT/scripts/check-constitution-adr.sh" "$ROOT/scripts/check-c8-feature.sh" "$CW/scripts/"
  printf '# 宪法\nC1 条文\n' > "$CW/docs/constitution.md"
  printf '# ADR-001\n' > "$CW/docs/architecture/adr/ADR-001.md"
  git -C "$CW" init -q -b main
  git -C "$CW" add docs scripts
  git -C "$CW" -c user.name=t -c user.email=t@t commit -qm base
  git -C "$CW" checkout -qb feat
  printf '# 宪法\nC1 条文（被静默改写）\n' > "$CW/docs/constitution.md"
  git -C "$CW" add docs; git -C "$CW" -c user.name=t -c user.email=t@t commit -qm mut
  expect "修宪/1 裸修宪必须被抓" 1 bash "$CW/scripts/check-constitution-adr.sh"
  printf '# ADR-002 修宪留痕\n' > "$CW/docs/architecture/adr/ADR-002.md"
  git -C "$CW" add docs; git -C "$CW" -c user.name=t -c user.email=t@t commit -qm adr
  expect "修宪/0 伴随 ADR 放行" 0 bash "$CW/scripts/check-constitution-adr.sh"
  git -C "$CW" checkout -q main; git -C "$CW" checkout -qb big
  for i in 1 2 3 4 5 6 7 8 9 10 11; do printf 'x\n' > "$CW/f${i}.txt"; done
  git -C "$CW" add .; git -C "$CW" -c user.name=t -c user.email=t@t commit -qm big
  expect "C8/1 大改动无立项（strict）必须被抓" 1 bash "$CW/scripts/check-c8-feature.sh" --strict
  expect "C8/0 advisory 模式提示不阻断" 0 bash "$CW/scripts/check-c8-feature.sh"
  mkdir -p "$CW/specs/f"; printf 'prfaq\n' > "$CW/specs/f/prfaq.md"
  git -C "$CW" add specs; git -C "$CW" -c user.name=t -c user.email=t@t commit -qm lichang
  expect "C8/0 立项在场放行（strict）" 0 bash "$CW/scripts/check-c8-feature.sh" --strict
else
  echo "  ⚠️  跳过：无 git（修宪/C8 看守负样本）"
fi

# ---------- 门禁批准绑定内容（platform-hardening B2' · SPEC-3 落地）----------
# 起源：评估 D7——已批 release.md/deprecation.md 批后被改正文、无重批留痕；
# SPEC-3 承诺的历史对账探针从未实现。同文件摘要防不了同域篡改（评审 G3/P2），
# 故用 git 历史锚定：批准锚之后正文变更且未再触碰门禁块 → 红。
echo "-- 门禁批准绑定内容 --"
if command -v git >/dev/null 2>&1; then
  GIW="$WORK/gimm"; mkdir -p "$GIW/scripts/lib" "$GIW/specs/f"
  cp "$ROOT/scripts/check-gate-immutability.sh" "$GIW/scripts/"
  cp "$ROOT/scripts/lib/gate.sh" "$ROOT/scripts/lib/artifact.sh" "$GIW/scripts/lib/"
  git -C "$GIW" init -q
  printf '# PRFAQ\n正文 v1\n\n---\n门禁⓪ 记录：\n- 批准人：张三（人类）\n- 决定：go\n- 日期：2026-01-01\n- 备注：t\n' > "$GIW/specs/f/prfaq.md"
  git -C "$GIW" add specs scripts
  git -C "$GIW" -c user.name=t -c user.email=t@t commit -qm approve
  expect "批绑/0 批准后正文未动放行" 0 bash "$GIW/scripts/check-gate-immutability.sh"
  sed -i '' 's/正文 v1/正文 v2 被改/' "$GIW/specs/f/prfaq.md"
  expect "批绑/1 批后改正文（未提交也算）必须被抓" 1 bash "$GIW/scripts/check-gate-immutability.sh"
  git -C "$GIW" add specs
  git -C "$GIW" -c user.name=t -c user.email=t@t commit -qm sneaky
  expect "批绑/1 批后改正文已提交仍被抓" 1 bash "$GIW/scripts/check-gate-immutability.sh"
  printf -- '- 重批：正文修订经复核 ｜ 批准人：张三（人类）\n' >> "$GIW/specs/f/prfaq.md"
  git -C "$GIW" add specs
  git -C "$GIW" -c user.name=t -c user.email=t@t commit -qm rebless
  expect "批绑/0 重批留痕（再触碰门禁块区域）后放行" 0 bash "$GIW/scripts/check-gate-immutability.sh"
else
  echo "  ⚠️  跳过：无 git（check-gate-immutability 负样本）"
fi

# ---------- CI 步骤清单对账（platform-hardening B1）----------
# 起源：评估 D6——required check 只认 job 名，步骤内容 PR 自控，删步骤=静默降级零发现。
# 本探针是漂移门槛（同域可被一并删，诚实边界见其头部），负样本钉"阉割必须被抓"。
echo "-- CI 步骤对账 --"
CIW="$WORK/ciw"; mkdir -p "$CIW/scripts" "$CIW/tests/probe-negative" "$CIW/.github/workflows"
cp "$ROOT/scripts/check-ci-integrity.sh" "$CIW/scripts/"
for i in a b c d e f g h i; do printf '#!/bin/sh\n' > "$CIW/scripts/check-$i.sh"; done
printf '#!/bin/sh\n' > "$CIW/tests/probe-negative/run.sh"
{ echo 'jobs:'; echo '  probes:'; echo '    steps:'
  for i in a b c d e f g h i; do echo "      - run: bash scripts/check-$i.sh"; done
  echo '      - run: bash scripts/check-ci-integrity.sh'
  echo '      - run: bash tests/probe-negative/run.sh'; } > "$CIW/.github/workflows/quality-gates.yml"
expect "CI对账/0 全部接线放行" 0 bash "$CIW/scripts/check-ci-integrity.sh"
grep -v 'check-e.sh' "$CIW/.github/workflows/quality-gates.yml" > "$CIW/.github/workflows/tmp" \
  && mv "$CIW/.github/workflows/tmp" "$CIW/.github/workflows/quality-gates.yml"
expect "CI对账/1 阉割一个步骤必须被抓" 1 bash "$CIW/scripts/check-ci-integrity.sh"
rm "$CIW/.github/workflows/quality-gates.yml"
expect "CI对账/65 无 workflow 拒绝 PASS" 65 bash "$CIW/scripts/check-ci-integrity.sh"

# ---------- 手册 §8 数字对账（platform-hardening A7）----------
# 起源：CLAUDE.md 与手册 §8 写 97/97、实跑 106/106（评估 D4）——对账探针此前只覆盖 README 单文件。
echo "-- 手册数字对账 --"
R7="$WORK/readme7"; mkdir -p "$R7/tests/probe-negative" "$R7/docs"
{ for i in $(seq 22); do echo "行 ${i}"; done
  echo '见 [自己](./README.md)'
  echo '跑 `bash tests/probe-negative/run.sh`'
  echo '## 已知限制'
  for i in $(seq 6); do echo "- 限制 ${i}"; done; } > "$R7/README.md"
printf '#!/bin/sh\necho "== 结果：5/5 符合预期 =="\n' > "$R7/tests/probe-negative/run.sh"
printf '| 验证基线 | 负样本 **4/4** |\n' > "$R7/docs/implementation-manual.md"
expect "手册对账/1 手册基线数与实跑不符必须被抓" 1 bash "$RM" "$R7"
printf '| 验证基线 | 负样本 **5/5** |\n' > "$R7/docs/implementation-manual.md"
expect "手册对账/0 数字一致放行" 0 bash "$RM" "$R7"

# ---------- 门禁批准人可归因（platform-hardening A5 / C14）----------
# 起源：mutation 实测——批准人填 "Claude（AI agent，本制品的生成者）"、决定 go，
# check-prd 串锁照样 `GATE0: go ✓`。C14 在⓪①②③零机器执行。
# 本校验只拦"如实署名的自批"，拦不了填人名说谎（真归因在服务端 actor，手册 §7）。
echo "-- 门禁批准人（C14）--"
AH="$WORK/aphuman"; mkdir -p "$AH"
mk_ap_prfaq() {  # mk_ap_prfaq <批准人>：决定恒 go
  printf '# PR-FAQ\n---\n门禁⓪ 记录：\n- 批准人：%s\n- 决定：go\n- 日期：2026-01-01\n- 备注：t\n' "$1" > "$AH/prfaq.md"
}
mk_ap_prfaq "Claude（AI agent，本制品的生成者）"
expect "批准人/64 AI 如实署名自批必须被串锁拦下" 64 bash "$P1" "$AH"
mk_ap_prfaq "<待填>"
expect "批准人/64 决定已填但批准人待填（无归因不算批准）" 64 bash "$P1" "$AH"
mk_ap_prfaq "张三（人类，评审组）"
expect "批准人/65 人类署名放行（进入下一检查=缺 prd）" 65 bash "$P1" "$AH"

# ---------- 门禁③ 必须核对 required check 的名字（platform-hardening A4）----------
# 起源：2026-08-01 异构评审（GPT）发现 + 主 agent 实测证实——gate3_remote 的 jq 只抽
# conclusion/state，任何**无关** check 的 SUCCESS 都能充当门禁③证据；L89 注释宣称
# "SPEC-19 命名钉死"而实现没做（注释与实现脱节）。gh 用 shim 模拟，PR 恒 MERGED。
echo "-- 门禁③ 核对 check 名 --"
REL="$ROOT/.claude/skills/e2e-release/scripts/check-release.sh"
GH="$WORK/ghshim"; mkdir -p "$GH" "$WORK/relf"
mk_gh() {  # mk_gh <rollup 输出>：statusCheckRollup 分支必须在 "--json state" 之前（前缀撞包）
  { printf '#!/bin/sh\ncase "$*" in\n'
    printf '  *statusCheckRollup*) echo "%s" ;;\n' "$1"
    printf '  *nameWithOwner*) echo "o/r" ;;\n'
    printf '  *"--json state"*) echo "MERGED" ;;\n'
    printf '  *) echo ok ;;\nesac\n'; } > "$GH/gh"
  chmod +x "$GH/gh"
}
mk_gh "lint=SUCCESS,probes=SKIPPED"
expect "门禁③/64 无关 check 成功不算证据（probes 未跑）" 64 env PATH="$GH:$PATH" bash "$REL" "$WORK/relf" --gate-only
mk_gh "probes=SUCCESS"
expect "门禁③/0 命名 required check 全绿放行" 0 env PATH="$GH:$PATH" bash "$REL" "$WORK/relf" --gate-only
mk_gh "probes=FAILURE"
expect "门禁③/64 required check 红拒绝" 64 env PATH="$GH:$PATH" bash "$REL" "$WORK/relf" --gate-only

# ---------- C13 补欠：四个零负样本探针（platform-hardening A3）----------
# 起源：宪法 C13 写"每个 check-*.sh 须对至少一个坏样本 FAIL"，但 selfcontained /
# action-pins / marketplace-sha / demo-video 四探针在本套件零用例（structure 已在 A1 补）。
# 样本里的敏感模式用 \x 转义，防 run.sh 自身被真探针（selfcontained 全仓扫描）抓到。
echo "-- C13 补欠：selfcontained --"
SC="$WORK/selfc"; mkdir -p "$SC/scripts"
cp "$ROOT/scripts/check-selfcontained.sh" "$SC/scripts/"
printf '# doc\nsee /\x55sers/somebody/secret/tool\n' > "$SC/readme.md"
expect "自包含/66 个人绝对路径（白名单外）必须被抓" 66 bash "$SC/scripts/check-selfcontained.sh"
printf '# doc\nclean line\n' > "$SC/readme.md"
expect "自包含/0 干净仓放行" 0 bash "$SC/scripts/check-selfcontained.sh"

echo "-- C13 补欠：action-pins --"
APN="$WORK/pins"; mkdir -p "$APN/.github/workflows"
printf 'jobs:\n  b:\n    steps:\n      - uses: actions/checkout@v5\n' > "$APN/.github/workflows/w.yml"
expect "钉版/1 可变 tag 必须被抓（C15）" 1 bash "$ROOT/scripts/check-action-pins.sh" "$APN"
printf 'jobs:\n  b:\n    steps:\n      - uses: actions/checkout@fbc6f3992d24b796d5a048ff273f7fcc4a7b6c09\n' > "$APN/.github/workflows/w.yml"
expect "钉版/0 40 位 SHA 放行" 0 bash "$ROOT/scripts/check-action-pins.sh" "$APN"
APN2="$WORK/pins-empty"; mkdir -p "$APN2"
expect "钉版/66 无可检对象 fail-closed" 66 bash "$ROOT/scripts/check-action-pins.sh" "$APN2"

echo "-- C13 补欠：marketplace-sha --"
if command -v git >/dev/null 2>&1 && command -v python3 >/dev/null 2>&1; then
  MS="$WORK/mkt"; mkdir -p "$MS/.claude-plugin" "$MS/.claude"
  git -C "$MS" init -q
  printf 'v1\n' > "$MS/.claude/cap.txt"
  git -C "$MS" add .claude/cap.txt
  git -C "$MS" -c user.name=t -c user.email=t@t commit -qm base
  MSHA=$(git -C "$MS" rev-parse HEAD)
  printf '{"plugins":[{"name":"p","source":{"sha":"%s","path":".claude"}}]}\n' "$MSHA" > "$MS/.claude-plugin/marketplace.json"
  git -C "$MS" add .claude-plugin/marketplace.json
  git -C "$MS" -c user.name=t -c user.email=t@t commit -qm pin
  expect "插件sha/0 钉住后被分发路径无改动放行" 0 bash "$ROOT/scripts/check-marketplace-sha.sh" "$MS"
  printf 'v2\n' > "$MS/.claude/cap.txt"
  git -C "$MS" add .claude/cap.txt
  git -C "$MS" -c user.name=t -c user.email=t@t commit -qm drift
  expect "插件sha/1 sha 落后于被分发路径改动必须被抓" 1 bash "$ROOT/scripts/check-marketplace-sha.sh" "$MS"
  printf '{"plugins":[]}\n' > "$MS/.claude-plugin/marketplace.json"
  expect "插件sha/66 零 plugin 无可检对象 fail-closed" 66 bash "$ROOT/scripts/check-marketplace-sha.sh" "$MS"
else
  echo "  ⚠️  跳过：无 git/python3（check-marketplace-sha 负样本）"
fi

echo "-- C13 补欠：demo-video --"
if command -v ffprobe >/dev/null 2>&1 && command -v ffmpeg >/dev/null 2>&1; then
  DV="$WORK/dv"; mkdir -p "$DV"
  ffmpeg -hide_banner -loglevel error -y -f lavfi -i color=black:s=64x64:d=2 -t 2 "$DV/v.mp4" 2>/dev/null
  expect "视频/1 2 秒无声无字幕必须被抓（SPEC-25）" 1 bash "$ROOT/scripts/check-demo-video.sh" "$DV/v.mp4"
else
  echo "  ⚠️  跳过：无 ffmpeg/ffprobe（check-demo-video 负样本，CI macos runner 自带）"
fi

# ---------- 六件套结构探针：零抽取 fail-open（platform-hardening A1）----------
# 起源：2026-08-01 异构评估 mutation 实测——manifest 表内 skill 前缀漂移（如批量更名）后
# 探针打印 'PASS…登记 0 个 skill' exit 0。守的正是刚发生过 e2e-platform→aisep 更名的
# 单一清单，"抽出 0 条一律响亮失败"是本仓自订规则（CLAUDE.md），探针自己却违反。
echo "-- check-structure 零抽取 --"
SZ="$WORK/structzero"
mkdir -p "$SZ/scripts" "$SZ/docs/process/stages" "$SZ/.claude/skills"
cp "$ROOT/scripts/check-structure.sh" "$SZ/scripts/"
{ printf -- '| skill | 段 | 门禁 | 产物 | 探针 |\n|---|---|---|---|---|\n'
  printf -- '| `aisep-discovery` | 0 | ⓪ | prfaq | check-prfaq |\n'; } > "$SZ/docs/process/skills-manifest.md"
{ for s in 0 1 2 3 4 5 6; do printf -- '## 阶段 %s：占位\n\n词条。\n\n' "$s"; done; } > "$SZ/docs/glossary.md"
printf -- '# stage-0\n' > "$SZ/docs/process/stages/stage-0-x.md"
expect "结构/66 manifest 前缀漂移抽出 0 个 skill 必须响亮失败" 66 bash "$SZ/scripts/check-structure.sh"
# 双向钉死：登记 1 个（未实现）时仍应 PASS——守卫不许把"待建"误伤成失败
printf -- '| `e2e-discovery` | 0 | ⓪ | prfaq | check-prfaq |\n' >> "$SZ/docs/process/skills-manifest.md"
expect "结构/0 登记 1 个待建 skill 正常放行" 0 bash "$SZ/scripts/check-structure.sh"

# ---------- adopt/init 能力层对等（冷启动 blocker 回归）----------
# 起源：cmd_adopt 自己维护了一份平行清单，随平台加探针而漂移，最终比 init 少 12 个文件
# （0 hook / 0 CI / 0 负样本 / 无 settings.json）—— 存量仓拿到残废安装却以为装好了。
# 这里把探针**自己能不能发现漂移**钉死：只让 adopt 那一处退回旧式清单，必须被抓。
echo "-- adopt/init 能力层对等 --"
AP="$ROOT/scripts/check-adopt-parity.sh"
if [ -f "$AP" ]; then
  APW="$WORK/ap-mutant"
  mkdir -p "$APW"
  tar cf - --exclude='.git' --exclude='demo-video' --exclude='node_modules' -C "$ROOT" . 2>/dev/null \
    | (cd "$APW" && tar xf -)
  # 只改 cmd_adopt 里那一行（init 里的同名调用保持不变）→ 制造单侧漂移
  awk '/^cmd_adopt\(\) \{/{ina=1}
       ina && /^  install_capability_layer$/{print "  copy_tree \".claude/skills\" || true"; ina=0; next}
       {print}' "$ROOT/bin/e2e" > "$APW/bin/e2e"
  chmod +x "$APW/bin/e2e"
  expect "adopt对等/1 adopt 单侧退回旧式清单必须被抓" 1 bash "$AP" "$APW"

  # fail-closed：没有可检对象时必须 66，绝不能因为"两边都空所以相等"而假绿
  APE="$WORK/ap-empty"; mkdir -p "$APE"
  expect "adopt对等/66 无 bin/e2e 时拒绝 PASS" 66 bash "$AP" "$APE"
else
  echo "  ⚠️  跳过：无 check-adopt-parity.sh"
fi

# ---------- 插件名一致性（更名漂移：读者复制的那行命令装不上）----------
# 起源：e2e-platform → aisep 更名要同时改 4 个地方，漏一个不报错，
# 只是读者装不上，而作者本机早装好了永远看不见。
echo "-- check-plugin-name.sh --"
PN="$ROOT/scripts/check-plugin-name.sh"
if [ -f "$PN" ]; then
  PW="$WORK/pname"; mkdir -p "$PW/.claude-plugin" "$PW/docs/architecture/adr"
  mk_mf() {  # mk_mf <市场名> <插件名>
    printf '{"name":"%s","plugins":[{"name":"%s"}]}\n' "$1" "$2" > "$PW/.claude-plugin/marketplace.json"
  }
  PNONE="$WORK/pn-none"; mkdir -p "$PNONE"
  expect "插件名/0 无 marketplace.json 跳过（非分发仓不该被打扰）" 0 bash "$PN" "$PNONE"

  mk_mf mkt plg
  printf '# 门面\n什么都没教\n' > "$PW/README.md"
  expect "插件名/66 有 manifest 却无任何安装命令（抽取失效/门面没教，fail-closed）" 66 bash "$PN" "$PW"

  printf '装：`claude plugin install plg@mkt`\n' > "$PW/README.md"
  expect "插件名/0 与 manifest 一致时放行" 0 bash "$PN" "$PW"

  printf '装：`claude plugin install old-plugin@mkt`\n' > "$PW/README.md"
  expect "插件名/1 插件名过期必须被抓" 1 bash "$PN" "$PW"

  printf '装：`claude plugin install plg@old-market`\n' > "$PW/README.md"
  expect "插件名/1 市场名过期必须被抓" 1 bash "$PN" "$PW"

  # ADR 是决策记录，记的是当时真跑过的命令 —— 不阻断
  printf '装：`claude plugin install plg@mkt`\n' > "$PW/README.md"
  printf '当时跑的是 `claude plugin install old-plugin@old-market`\n' > "$PW/docs/architecture/adr/ADR-x.md"
  expect "插件名/0 ADR 里的历史命令不阻断" 0 bash "$PN" "$PW"

  # 双向钉死：ADR 豁免不得写宽成"整仓放过"
  printf '装：`claude plugin install old-plugin@mkt`\n' > "$PW/README.md"
  expect "插件名/1 ADR 豁免不得外溢到别的文档" 1 bash "$PN" "$PW"

  # 只有 ADR 有命令 = 仍然无法判定，不得因为"ADR 里有"就算数
  printf '# 门面\n什么都没教\n' > "$PW/README.md"
  expect "插件名/66 只有 ADR 有命令时不得算判定通过" 66 bash "$PN" "$PW"

  printf '{"name":"mkt","plugins":[]}\n' > "$PW/.claude-plugin/marketplace.json"
  printf '装：`claude plugin install plg@mkt`\n' > "$PW/README.md"
  expect "插件名/66 manifest 无 plugin 条目时拒绝 PASS" 66 bash "$PN" "$PW"
else
  echo "  ⚠️  跳过：无 check-plugin-name.sh"
fi

# ---------- ratchet 负样本（S5，独立脚本）----------
echo "-- ratchet.sh --"
expect "ratchet 六用例（含替换违规总数不变）" 0 bash "$ROOT/tests/probe-negative/ratchet-negative.sh"

echo
echo "== 结果：$((total-fails))/$total 符合预期 $([ $fails -eq 0 ] && echo '✅' || echo '❌') =="
exit $([ $fails -eq 0 ] && echo 0 || echo 1)
