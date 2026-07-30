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
gate_decision() {
  local f="${1:-}" line val
  [ -f "$f" ] || { printf 'UNKNOWN\n'; return 0; }
  line=$(grep -E '^- 决定：' "$f" | head -1) || true
  [ -z "$line" ] && { printf 'UNKNOWN\n'; return 0; }
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
