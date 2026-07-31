#!/usr/bin/env bash
# check-branch-protection.sh — 服务端门禁的【行为证明】探针（ADR-014）
#
# 核心原则：配置回读**不能单独**作为通过依据。
#   S6 spike 实测：required checks 四项全在、GitHub 打印 "4 of 4 required status
#   checks are expected"，push 依然成功（enforce_admins 默认 false）——静默失效。
#
# 但反过来也不成立（异构评审 #1 修正）：行为证明**也不能单独**作为通过依据。
#   本探针推的是一个「没有任何 status check 的新 SHA」，它被拒可能仅仅因为
#   "required check 尚未运行"，并不证明"必须走 PR、必须有人审"。
#   故本探针的判定 = **配置不变量 ∩ 行为证明**，两者都过才 CONFIRMED。
#
# 本探针**不碰工作区、不碰索引、不建分支**（异构评审 #2 + reviewer #1）：
#   早期版本用 `git checkout -B probe && git commit --allow-empty`，两个后果都已实测复现：
#     ① `--allow-empty` 只放宽"无改动"限制，**索引里已 stage 的内容会被一并提交**
#        → 门禁失效时把用户暂存的机密推上 main（公开仓即刻泄漏）
#     ② cleanup 的 `git branch -D` 在**成功路径上也会**销毁那份暂存数据（只剩 reflog）
#   现改用 `git commit-tree` 直接造提交对象再推 SHA：无 checkout、无临时分支、无 trap。
#
# 用法：bash scripts/check-branch-protection.sh [<branch>]
#   仓库固定取当前 origin（不接受 owner/repo 参数——reviewer #7：读 A 仓配置却往 B 仓推）
#
# 退出码：
#   0  = CONFIRMED（配置不变量 + 行为证明都过）
#   1  = REFUTED（**只有一种情况**：直推真的成功了 = 门禁拦不住）
#   2  = 不可用/降级/证据不足（fail-closed，非静默；含基础设施失败）
#   66 = 自检失败（工具或前置不可用）

set -euo pipefail

BRANCH="${1:-main}"

# 基础设施类失败一律 exit 2，绝不占用 1（reviewer #6：网络抖动被播报成"门禁失效"
# 会让人去改一个没坏的东西）。1 只留给"真的推上去了"。
infra() { echo "⚠️  $*" >&2; exit 2; }
selfcheck_fail() { echo "自检失败：$*" >&2; exit 66; }

command -v git >/dev/null 2>&1 || selfcheck_fail "git 不可用"
command -v gh  >/dev/null 2>&1 || selfcheck_fail "gh CLI 不可用，无法验证服务端门禁"
gh auth status >/dev/null 2>&1 || selfcheck_fail "gh 未登录，无法验证服务端门禁"
git rev-parse --git-dir >/dev/null 2>&1 || selfcheck_fail "不在 git 工作区内"

REPO=$(gh repo view --json nameWithOwner --jq '.nameWithOwner' 2>/dev/null) \
  || infra "无法推断仓库（无 origin 远端或无访问权）"

echo "== 服务端门禁行为探针 ｜ ${REPO} @ ${BRANCH} =="

# ---- 第 0 层：分支保护是否可用（ADR-014 陷阱①）----
PROT_JSON=$(gh api "repos/${REPO}/branches/${BRANCH}/protection" 2>&1) || {
  if printf '%s' "${PROT_JSON}" | grep -qi 'Upgrade to GitHub Pro'; then
    cat >&2 <<EOF
⚠️  服务端门禁【不可用】：免费账号的私有仓不支持分支保护。
    当前仓只能按【试点模式】运行（ADR-009）：门禁记录是过程留痕，无服务端强制力。
    升级路径：① 仓库改公开，或 ② GitHub Team/Enterprise 计划。
    —— 此状态下禁止声称"门禁已启用"。
EOF
    exit 2
  fi
  printf '%s' "${PROT_JSON}" | grep -qi 'Branch not protected' \
    && { echo "❌ REFUTED 的前置都不成立：分支 ${BRANCH} 未配置任何保护规则" >&2; exit 2; }
  infra "查询分支保护失败：$(printf '%s' "${PROT_JSON}" | head -2)"
}

# ---- 第 1 层：配置不变量（必须过，且**不单独**构成通过）----
q() { gh api "repos/${REPO}/branches/${BRANCH}/protection" --jq "$1" 2>/dev/null || echo '?'; }
ADMINS=$(q '.enforce_admins.enabled')
CHECKS=$(q '(.required_status_checks.contexts // []) | join(",")')
NCHECK=$(q '(.required_status_checks.contexts // []) | length')
FORCE=$(q  '.allow_force_pushes.enabled')
DELETE=$(q '.allow_deletions.enabled')

echo "-- 第1层 配置不变量 --"
printf '   %-22s %s\n' "enforce_admins"  "${ADMINS}"
printf '   %-22s %s（%s 项）\n' "required checks" "${CHECKS:-（无）}" "${NCHECK}"
printf '   %-22s %s\n' "allow_force_pushes" "${FORCE}"
printf '   %-22s %s\n' "allow_deletions"    "${DELETE}"

inv_fail=0
[ "${ADMINS}" = "true" ]  || { echo "   ❌ enforce_admins 非 true —— admin 可绕过一切（ADR-014 陷阱②）"; inv_fail=1; }
[ "${NCHECK}" -ge 1 ] 2>/dev/null || { echo "   ❌ 无 required status checks —— 没有任何确定性门禁"; inv_fail=1; }
[ "${FORCE}" = "false" ]  || { echo "   ❌ 允许强推 —— 历史可被覆写"; inv_fail=1; }
[ "${DELETE}" = "false" ] || { echo "   ❌ 允许删分支 —— 保护可被整体移除"; inv_fail=1; }
[ "${inv_fail}" -eq 0 ] && echo "   ✅ 配置不变量全部满足"

# ---- 演员身份：不证明就不许声称（reviewer #5）----
# 非 admin 的写权限用户直推受保护分支**本来就会**被拒，与 enforce_admins 无关。
# 若不确认当前身份是 admin，就不得输出"含 admin"——那正是 ADR-014 的全部要害。
IS_ADMIN=$(gh api "repos/${REPO}" --jq '.permissions.admin' 2>/dev/null || echo '?')
if [ "${IS_ADMIN}" = "true" ]; then
  ACTOR_NOTE="（当前身份为 admin，故本证明覆盖 admin 绕过路径）"
else
  ACTOR_NOTE="（当前身份**非 admin**，本证明仅覆盖普通写权限路径，未覆盖 admin 绕过）"
fi

# ---- 第 2 层：行为证明 ----
echo "-- 第2层 行为证明：尝试直推 ${BRANCH}，必须被拒 --"
git fetch -q origin "${BRANCH}" || infra "fetch origin/${BRANCH} 失败"

# 造一个与 origin/BRANCH 同 tree 的提交对象：不动索引、不动工作区、不建分支。
BASE=$(git rev-parse "origin/${BRANCH}") || infra "无法解析 origin/${BRANCH}"
TREE=$(git rev-parse "origin/${BRANCH}^{tree}") || infra "无法解析 tree"
PROBE_SHA=$(git commit-tree "${TREE}" -p "${BASE}" \
  -m "probe: 直推受保护分支应被拒绝（check-branch-protection.sh，不含任何改动）") \
  || infra "commit-tree 失败"

PUSH_LOG=$(mktemp)
trap 'rm -f "${PUSH_LOG}"' EXIT

if git push origin "${PROBE_SHA}:refs/heads/${BRANCH}" >"${PUSH_LOG}" 2>&1; then
  cat >&2 <<EOF
❌ REFUTED：直推 ${BRANCH} 成功了 —— 服务端门禁未真正生效。
   最常见原因：enforce_admins = false（当前值：${ADMINS}）。
   修复：gh api -X POST repos/${REPO}/branches/${BRANCH}/protection/enforce_admins
   ⚠️ 本次探针提交（${PROBE_SHA}，与原 tree 完全相同、无任何文件改动）已进入 ${BRANCH}，需人工回退。
EOF
  exit 1
fi

if ! grep -qiE 'protected branch|GH006|must be made through a pull request' "${PUSH_LOG}"; then
  echo "⚠️  推送被拒，但拒绝原因不是分支保护 —— 证据不成立（fail-closed 判为不通过）" >&2
  sed -n '1,6p' "${PUSH_LOG}" >&2
  exit 2
fi
echo "   ✅ 服务端拒绝了直推 ${ACTOR_NOTE}"

# ---- 合取判定：两层都过才算 CONFIRMED ----
if [ "${inv_fail}" -ne 0 ]; then
  cat >&2 <<EOF

⚠️  行为证明通过，但**配置不变量未满足** —— 判为不通过（exit 2）。
   行为探针推的是「无 status check 的新 SHA」，它被拒可能只因为 check 未运行，
   并不证明"必须走 PR / 必须有人审"。两层取交集才是有效证据（异构评审 #1）。
EOF
  exit 2
fi

echo "✅ CONFIRMED：配置不变量 ∩ 行为证明 双双成立"
exit 0
