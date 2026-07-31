#!/usr/bin/env bash
# gate.sh — 门禁记录解析公共库（SPEC-5：单一实现，各探针 source 之）
#
# 为什么要有这个库：阶段0 实跑曾抓到"模板/制品/探针三者对门禁块写法不一致"的漂移，
# 四个探针各自 grep 就是四个漂移源。此库是唯一实现（宪法 C2 可执行验证的基础设施）。
#
# 门禁块契约（SPEC-1/2，ADR-009 试点模式）：制品尾部四行
#   - 批准人：<x>
#   - 决定：<值>        ⓪∈{go,modify,kill}；①②④⑤∈{批准,打回}；待批=<待填>
#   - 日期：<x>
#   - 备注：<x>
#
# 用法：
#   source "$(gate_lib_path)" ; 或调用方自行定位后 source
#   gate_decision <file>            → 输出决定值（待批输出 PENDING，异常输出 UNKNOWN）
#   gate_status   <file>            → 输出人类可读状态
#   gate_require  <file> <合法值...> → 不满足则打印原因并 return 64

# 找仓库根（优先 git，回退到含 docs/constitution.md 的祖先目录）
gate_repo_root() {
  local d
  d=$(git rev-parse --show-toplevel 2>/dev/null) && { printf '%s\n' "$d"; return 0; }
  d=$(pwd)
  while [ "$d" != "/" ]; do
    [ -f "$d/docs/constitution.md" ] && { printf '%s\n' "$d"; return 0; }
    d=$(dirname "$d")
  done
  return 1
}

# 提取"决定："的值；无门禁块→UNKNOWN，待填→PENDING
#
# ⚠️ 本函数是**整套门禁的信任根**——所有串锁都读它。曾有一个 critical 缺陷：
#   旧实现是 `grep '^- 决定：' | head -1`（**全文首匹配胜**），而门禁块契约是
#   「制品**尾部**四行」。于是执行者只要在正文任意早处写一行 `- 决定：go`，
#   尾部块保持 `<待填>`，探针即判 PASS、下游打印 `GATE0: go ✓` ——
#   **人翻到文末只看到"待批"，机器却认为已批准**。
#   实测复现：正文第 3 行插入 `- 决定：go`，尾部四行全 `<待填>` → `门禁⓪=决定：go`。
#   这同时击穿 C1（串锁）与 C14（执行者不得自批），且**自批在人的视野里不可见**。
#
# 现在的规则（两条，都 fail-closed）：
#   ① 只认**从文件尾部向上**锚定到的门禁块（`门禁… 记录` 之后的那一段）
#   ② 全文出现 >1 条 `^- 决定：` 一律判 UNKNOWN —— **歧义即拒绝**，不猜哪条是真的
gate_decision() {
  local f="${1:-}" line val n
  [ -f "$f" ] || { printf 'UNKNOWN\n'; return 0; }

  # ② 歧义即 fail-closed：多条决定行无法判断哪条权威
  n=$(grep -cE '^- 决定：' "$f" 2>/dev/null || true); : "${n:=0}"
  [ "$n" -gt 1 ] && { printf 'UNKNOWN\n'; return 0; }
  [ "$n" -eq 0 ] && { printf 'UNKNOWN\n'; return 0; }

  # ① 该唯一一条必须落在**门禁记录块之后**（尾部锚定），否则不认
  local dec_ln blk_ln
  dec_ln=$(grep -nE '^- 决定：' "$f" | head -1 | cut -d: -f1)
  blk_ln=$(grep -nE '门禁.{0,3}记录' "$f" | tail -1 | cut -d: -f1)
  [ -n "$blk_ln" ] || { printf 'UNKNOWN\n'; return 0; }
  [ "$dec_ln" -gt "$blk_ln" ] || { printf 'UNKNOWN\n'; return 0; }

  line=$(grep -E '^- 决定：' "$f" | head -1)
  val=$(printf '%s' "$line" | sed -E 's/^- 决定：[[:space:]]*//; s/[[:space:]]*(<!--.*)?$//')
  case "$val" in
    '<待填>'|'') printf 'PENDING\n' ;;
    *) printf '%s\n' "$val" ;;
  esac
}

gate_status() {
  local d; d=$(gate_decision "${1:-}")
  case "$d" in
    PENDING) printf 'PENDING(待人批)\n' ;;
    UNKNOWN) printf 'UNKNOWN(门禁块缺失或格式异常)\n' ;;
    *) printf '决定：%s\n' "$d" ;;
  esac
}

# gate_assert_legal <file> <合法值...>：校验**本文件自己**的门禁决定值合法
#
# 为什么必须有（实测事故）：7 个阶段探针里 6 个只用 gate_status **显示**决定值，
# 从不校验它是否属于契约集合。于是门禁④ 被填成"放行"（契约是 批准/打回）后
# `check-release.sh --final` 判 PASS 放行，直到门禁⑤ 入口才炸
# （`当前=放行，需要=批准`）。这是台账层的 fail-open：写错一个词能过自己那道门。
# 与 gate_require 的区别：gate_require 校验**上游**门禁（串锁），本函数校验**自己**。
# PENDING（待人批）合法——探针在非 --final 模式下允许待批状态。
gate_assert_legal() {
  local f="${1:-}"; shift
  local d; d=$(gate_decision "$f")
  [ "$d" = "PENDING" ] && return 0
  [ "$d" = "UNKNOWN" ] && { printf 'MISSING: 门禁块缺失或格式异常\n'; return 1; }
  for want in "$@"; do [ "$d" = "$want" ] && return 0; done
  printf 'MISSING: 门禁决定值非法："%s"（契约只认：%s）——写错一个词就能过自己那道门\n' "$d" "$*"
  return 1
}

# gate_require <file> <合法值...>：满足返回 0，否则打印 FAIL(64) 并返回 64
gate_require() {
  local f="${1:-}"; shift
  local d ok=1
  [ -f "$f" ] || { printf 'FAIL(64): 缺少上游制品 %s\n' "$f"; return 64; }
  d=$(gate_decision "$f")
  for want in "$@"; do [ "$d" = "$want" ] && ok=0; done
  [ $ok -eq 0 ] && return 0
  printf 'FAIL(64): 门禁未通过（当前=%s，需要=%s）——拒绝进入本阶段\n' "$d" "$*"
  return 64
}

# gate_assert_filled <制品> <模板>：制品不得是「原封不动的模板」
#
# 冷启动验收 MAJOR：check-prfaq.sh 对**一字未改的模板副本**判 PASS（exit 0）。
# 于是门禁⓪的探针可以被一份没人填过的空模板通过 —— 结构齐全，内容全是占位符。
# 这不是理论风险：抄模板正是最自然的起手式，忘了填就交是常态。
#
# 判据用**实测**定的，不是拍脑袋（数的是模板里带 <占位符> 的行有多少还原样留着）：
#   platform-pilot/prfaq.md（真实）  0/23 =   0%
#   win-loss-log/prfaq.md（真实）    0/23 =   0%
#   只填了 5 个槽                   18/23 =  78%  ← 必须拦
#   一字未改的模板                  23/23 = 100%  ← 必须拦
# 阈值取 25%：距两份真实产物有 25 个点的余量，且容得下"待批时门禁决定行
# 合法地留着 <待填>"这种情况。
gate_assert_filled() {
  local art="${1:-}" tpl="${2:-}"
  [ -f "$art" ] || { echo "FAIL(65): 制品不存在: $art" >&2; return 65; }
  [ -f "$tpl" ] || { echo "FAIL(66): 找不到模板 ${tpl} —— 无法判定是否原样照抄，拒绝 PASS" >&2; return 66; }
  local slots left pct
  slots=$(grep -E '<[^>]+>' "$tpl" | grep -cvE '^[[:space:]]*$' || true); : "${slots:=0}"
  # 模板里一个占位符都没有 = 判据失效，必须响亮而不是静默放行
  [ "$slots" -ge 3 ] || { echo "FAIL(66): 模板 ${tpl} 只有 ${slots} 个占位符行 —— 判据失效，拒绝 PASS" >&2; return 66; }
  left=$(grep -E '<[^>]+>' "$tpl" | grep -vE '^[[:space:]]*$' | grep -Fxf - "$art" 2>/dev/null | grep -c . || true)
  : "${left:=0}"
  pct=$(( left * 100 / slots ))
  if [ "$pct" -gt 25 ]; then
    printf 'FAIL(66): %s 有 %s/%s（%s%%）个占位符行**一字未改** —— 这是没填的模板，不是制品\n' \
      "$art" "$left" "$slots" "$pct" >&2
    grep -E '<[^>]+>' "$tpl" | grep -vE '^[[:space:]]*$' | grep -Fxf - "$art" 2>/dev/null | head -5 | sed 's/^/     未填: /' >&2
    return 66
  fi
  printf '  ✅ 非模板照抄（%s/%s 占位符未动，阈值 25%%）\n' "$left" "$slots"
  return 0
}
