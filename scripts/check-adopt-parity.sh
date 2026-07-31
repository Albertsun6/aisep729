#!/usr/bin/env bash
# check-adopt-parity.sh — adopt 装出来的能力层必须与 init 一致
#
# 为什么需要（冷启动验收 blocker）：
#   `cmd_adopt` 曾自己维护一份**平行**的文件清单。平台后来陆续加了 hook、CI 模板、
#   负样本套件、5 个探针 —— 只加进 init 的清单，adopt 那份没人记得同步。
#   实测差距：init 发 60 个文件，adopt 只发 49，缺的正好是
#   **0 个 hook / 0 个 CI / 0 条负样本 / 无 settings.json**。
#   后果不是"少点东西"：存量仓拿到一个**残废安装却以为装好了**，
#   README 教的三条验收命令第一条 FAIL、第三条文件根本不存在。
#
# 判据（**行为证明**，不是读代码）：真的各跑一遍 init 与 adopt，比对产出文件集合。
#   允许的差异只有一条：adopt 多一份 ADR-001 追认基线（存量仓才需要）。
#   任何其它差异 = 两条路装出来的东西不一样 = 有一条在骗人。
#
# 为什么不静态检查"两处都调了 install_capability_layer"：
#   那只证明**调用了**，不证明**装出来一样**。行为证明连"某个 gen_file 悄悄失败"
#   这类问题也一起钉住。
#
# 用法：bash scripts/check-adopt-parity.sh [<repo-root>]
# 退出码：0=一致  1=不一致  66=自检失败/无法判定（fail-closed）

set -uo pipefail

if [ $# -ge 1 ]; then
  ROOT="$(cd "$1" 2>/dev/null && pwd)" || { echo "自检失败：目录不存在 $1" >&2; exit 66; }
else
  ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || ROOT="$(pwd)"
fi
cd "${ROOT}"

E2E="${ROOT}/bin/e2e"
[ -x "$E2E" ] || [ -f "$E2E" ] || { echo "FAIL(66): 找不到 ${E2E} —— 无可检对象，拒绝 PASS" >&2; exit 66; }
command -v git >/dev/null 2>&1 || { echo "自检失败：需要 git（adopt 要求目标是 git 仓）" >&2; exit 66; }

# adopt 相对 init 允许多出的文件（存量仓专属产物）
ALLOWED_EXTRA="docs/architecture/adr/ADR-001-retroactive-baseline.md"

W="$(mktemp -d)" || { echo "自检失败：mktemp 失败" >&2; exit 66; }
trap 'rm -rf "${W}"' EXIT

echo "== adopt / init 能力层对等检查（行为证明）｜ ${ROOT} =="

mkdir -p "${W}/g" "${W}/b"
( cd "${W}/b" && git init -q && git -c user.email=p@x -c user.name=p commit -q --allow-empty -m base ) \
  || { echo "自检失败：无法造 git 仓" >&2; exit 66; }

bash "$E2E" init  "${W}/g" >"${W}/init.log"  2>&1; rc_i=$?
bash "$E2E" adopt "${W}/b" >"${W}/adopt.log" 2>&1; rc_a=$?
# 0=全新 2=有冲突，都算跑通；其它退出码说明命令本身坏了
case "$rc_i" in 0|2) ;; *) echo "FAIL(66): init 退出码 ${rc_i}"; sed 's/^/    /' "${W}/init.log"  >&2; exit 66;; esac
case "$rc_a" in 0|2) ;; *) echo "FAIL(66): adopt 退出码 ${rc_a}"; sed 's/^/    /' "${W}/adopt.log" >&2; exit 66;; esac

( cd "${W}/g" && find . -type f -not -path './.git/*' | sed 's|^\./||' | sort ) > "${W}/i.txt"
( cd "${W}/b" && find . -type f -not -path './.git/*' | sed 's|^\./||' | sort ) > "${W}/a.txt"

ni=$(grep -c . < "${W}/i.txt" || true); na=$(grep -c . < "${W}/a.txt" || true)
: "${ni:=0}"; : "${na:=0}"
# 无可检对象必须 fail-closed：两边都空时"集合相等"会**假绿**
if [ "$ni" -lt 10 ] || [ "$na" -lt 10 ]; then
  echo "FAIL(66): 产出文件过少（init=${ni} adopt=${na}）—— 脚手架没真的跑起来，拒绝 PASS" >&2
  exit 66
fi

# ---- 自检金丝雀：比对引擎必须真能发现差异 ----
_x=$(mktemp); _y=$(mktemp)
printf 'a\nb\n' > "$_x"; printf 'a\n' > "$_y"
_d=$(comm -23 "$_x" "$_y" | grep -c . || true); rm -f "$_x" "$_y"
if [ "${_d:-0}" -ne 1 ]; then
  echo "自检失败：比对引擎异常（金丝雀应发现 1 处差异，实得 ${_d}）" >&2; exit 66
fi

bad=0
echo "  init=${ni} 个文件 ｜ adopt=${na} 个文件"

miss=$(comm -23 "${W}/i.txt" "${W}/a.txt")
if [ -n "$miss" ]; then
  n=$(printf '%s\n' "$miss" | grep -c . || true)
  echo "  ❌ adopt **缺** ${n} 个 init 会装的文件 —— 存量仓拿到的是残废安装："
  printf '%s\n' "$miss" | sed 's/^/       - /'
  bad=$((bad + 1))
fi

extra=$(comm -13 "${W}/i.txt" "${W}/a.txt" | grep -vxF "$ALLOWED_EXTRA" || true)
if [ -n "$extra" ]; then
  echo "  ❌ adopt 多出未登记的文件（若确属存量仓专属，加进本探针的 ALLOWED_EXTRA）："
  printf '%s\n' "$extra" | sed 's/^/       - /'
  bad=$((bad + 1))
fi

# adopt 必须真的产出那份追认基线，否则"允许的差异"变成了掩盖缺失的借口
if ! grep -qxF "$ALLOWED_EXTRA" "${W}/a.txt"; then
  echo "  ❌ adopt 没产出 ${ALLOWED_EXTRA} —— 存量仓缺追溯起点"
  bad=$((bad + 1))
fi

# README 教的验收命令必须在 adopt 出来的仓里真的能跑
echo "-- adopt 产物跑 README 的验收三连 --"
for c in scripts/check-skill-deps.sh scripts/check-clause-refs.sh tests/probe-negative/run.sh; do
  if [ ! -f "${W}/b/$c" ]; then
    printf '  ❌ %s **文件不存在** —— README 教了一条跑不通的验收\n' "$c"; bad=$((bad + 1)); continue
  fi
  ( cd "${W}/b" && bash "$c" >/dev/null 2>&1 )
  rc=$?
  if [ "$rc" -eq 0 ]; then printf '  ✅ %s\n' "$c"
  else printf '  ❌ %s → exit=%s（README 说三条全绿才算成功）\n' "$c" "$rc"; bad=$((bad + 1)); fi
done

echo
if [ "$bad" -gt 0 ]; then
  cat >&2 <<'EOF'
❌ FAIL：adopt 与 init 装出来的东西不一致。
   两条路必须共用同一份清单（bin/e2e 里的 CAP_TREES / CAP_FILES）。
   各维护一份必然漂移 —— 这条探针就是因为已经漂移过一次才存在的。
EOF
  exit 1
fi
echo "PASS: adopt 与 init 能力层一致，且 adopt 产物通过 README 验收三连"
