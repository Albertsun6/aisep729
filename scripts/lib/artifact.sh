#!/usr/bin/env bash
# artifact.sh — 制品内容判定公共库（SPEC-5 同精神：单一实现，防两份拷贝漂移）
#
# 起源：reviewer 评审 finding #3 指出 sec_lines 在 check-release.sh 与 check-retire.sh
# 各有一份拷贝，且判定过宽（纯占位符制品可判"非空"）。抽到这里统一修。

# ---- 占位符判定（反向设计：默认全算未决，白名单极小）----
# 旧设计：只认 7 个字面量占位符 → <flag 名>/<N 分钟> 等全部漏网（finding #3）
# 新设计：code span 外的任何 <...> 都算未决占位符；仅门禁块的 <待填> 豁免（本就待人批）
art_has_placeholder() {  # art_has_placeholder <file> → 0=有未决占位符
  local f="${1:-}"
  [ -f "$f" ] || return 1
  sed 's/`[^`]*`//g' "$f" \
    | grep -vE '^- (批准人|决定|日期|备注)：' \
    | grep -qE '<[^>]+>'
}

# ---- 小节实质内容行数 ----
# 剔除：空行 / 整行占位符 / markdown 表头与分隔行 / 纯符号行
# finding #3：混合行如 `- **命令**：\`<启动命令>\`` 旧实现算实质内容 → 现在也剔除
art_sec_lines() {  # art_sec_lines <file> <## 小节标题> → 输出实质行数
  local f="${1:-}" sec="${2:-}"
  [ -f "$f" ] || { echo 0; return; }
  awk -v sec="$sec" '
    $0 ~ "^" sec {inside=1; next}
    inside && /^## / {inside=0}
    inside {print}
  ' "$f" \
    | grep -v '^[[:space:]]*$' \
    | grep -vE '^[[:space:]]*\|?[[:space:]-]*\|[[:space:]|:-]*$' \
    | sed 's/`[^`]*`//g' \
    | grep -vE '^[[:space:]]*[-*|[:space:]]*<[^>]*>[[:space:]|]*$' \
    | grep -vE '^[[:space:]]*[-*+|[:space:]]*$' \
    | grep -cE '[^[:space:]|<>*-]' || true
}

# ---- 表格数据行（非表头非分隔）----
art_table_rows() {  # art_table_rows <file> <## 小节标题> → 输出数据行数
  local f="${1:-}" sec="${2:-}"
  [ -f "$f" ] || { echo 0; return; }
  awk -v sec="$sec" '
    $0 ~ "^" sec {inside=1; next}
    inside && /^## / {inside=0}
    inside && /^\|/ {print}
  ' "$f" \
    | grep -vE '^\|[[:space:]-]*\|[[:space:]|:-]*$' \
    | tail -n +2 \
    | sed 's/`[^`]*`//g' \
    | grep -vcE '^\|[[:space:]|]*<[^>]*>' || true
}

# ---- 非人类署名启发式（finding #7：表不可能穷尽，故只作 WARN 不作 block）----
art_looks_nonhuman() {  # art_looks_nonhuman <字符串> → 0=疑似非人类
  local v="${1:-}"
  printf '%s' "$v" | grep -qiE '(^|[^[:alnum:]])(ai|bot|gpt|llm|copilot|cursor|codex|claude|agent)([^[:alnum:]]|$)|机器人|自动化?|系统|脚本|流水线|工具|ci|待填'
}
