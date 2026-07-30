#!/usr/bin/env bash
# ratchet-negative.sh — S5 spike 负样本验证（SPEC-14 / 宪法 C13：探针必须能证伪）
#
# 验证两件事（数量比较做不到的）：
#   负样本1  新增违规           → 必须红
#   负样本2  替换违规（总数不变）→ 必须红   ← 这条是"数量比较"的致命洞
#   正样本   行号漂移（内容不变）→ 必须绿   ← 指纹不含行号的价值
#
# 退出码: 0=全部符合预期 / 1=有用例不符合预期
set -u
cd "$(dirname "$0")/../.." || exit 1
RATCHET="bash scripts/ratchet.sh"
WORK=$(mktemp -d); trap 'rm -rf "$WORK"' EXIT
fails=0

setup() {  # 造一个含存量违规的临时"仓库"
  rm -rf "$WORK/repo"; mkdir -p "$WORK/repo/scripts"
  cp scripts/ratchet.sh "$WORK/repo/scripts/"
  cat > "$WORK/repo/legacy.sh" <<'EOF'
#!/usr/bin/env bash
set -u
# TODO 存量遗留问题甲
# TODO 存量遗留问题乙
EOF
}

run_ratchet() { (cd "$WORK/repo" && eval "$RATCHET" "$@" 2>&1); }

check() {  # check <用例名> <期望退出码> <实际退出码> <输出>
  if [ "$2" = "$3" ]; then
    echo "  ✅ $1（期望退出 $2，实际 $3）"
  else
    echo "  ❌ $1（期望退出 $2，实际 $3）"; echo "$4" | sed 's/^/     /'; fails=$((fails+1))
  fi
}

echo "== S5 ratchet 负样本验证 =="

# --- 基线建立 ---
setup
out=$(run_ratchet --rebaseline); rc=$?
check "基线生成" 0 "$rc" "$out"
echo "$out" | grep -q "收录 [0-9]* 条" || { echo "  ❌ 基线未收录违规"; fails=$((fails+1)); }

# --- 正样本 A：不动 → 绿 ---
out=$(run_ratchet); rc=$?
check "正样本A 无改动 → 绿" 0 "$rc" "$out"

# --- 正样本 B：行号漂移（内容不变，位置变）→ 绿（指纹不含行号）---
cat > "$WORK/repo/legacy.sh" <<'EOF'
#!/usr/bin/env bash
set -u
echo "新增了几行无关代码"
echo "把存量违规挤到了下面（本行不含违规关键字）"
# TODO 存量遗留问题甲
# TODO 存量遗留问题乙
EOF
out=$(run_ratchet); rc=$?
check "正样本B 行号漂移 → 绿" 0 "$rc" "$out"

# --- 负样本 1：新增违规 → 红 ---
setup; run_ratchet --rebaseline >/dev/null
echo '# TODO 新加的问题丙' >> "$WORK/repo/legacy.sh"
out=$(run_ratchet); rc=$?
check "负样本1 新增违规 → 红" 1 "$rc" "$out"
echo "$out" | grep -q "新增违规" || { echo "  ❌ 未指出新增违规"; fails=$((fails+1)); }

# --- 负样本 2：替换违规（删一个旧的+加一个新的，总数不变）→ 红 ---
# 这是数量比较必然漏掉的场景：2 条 → 仍是 2 条
setup; run_ratchet --rebaseline >/dev/null
cat > "$WORK/repo/legacy.sh" <<'EOF'
#!/usr/bin/env bash
set -u
# TODO 存量遗留问题甲
# TODO 偷偷换成的新问题丁
EOF
out=$(run_ratchet); rc=$?
check "负样本2 替换违规（总数不变）→ 红" 1 "$rc" "$out"
echo "$out" | grep -q "已修" && echo "     （同时正确识别出旧违规已消失）"

# --- 负样本 3：无基线 → 65 ---
setup
out=$(run_ratchet); rc=$?
check "负样本3 基线缺失 → 65" 65 "$rc" "$out"

echo "== 结果：$([ $fails -eq 0 ] && echo '全部符合预期 ✅' || echo "$fails 项不符合预期 ❌") =="
exit $([ $fails -eq 0 ] && echo 0 || echo 1)
