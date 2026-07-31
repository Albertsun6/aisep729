#!/usr/bin/env bash
# check-skill-deps.sh — skill 声明的依赖文件必须真实存在（防 fail-open 脚手架缺口）
#
# 根因：skill 的 SOP 会引用仓内文件（分档表 / 阶段定义 / 模板 / 探针）。若脚手架没把
#   这些文件发到业务仓，skill 跑到那一步会"找不到就跳过"——**静默降级为不检查**。
#   实测案例：`e2e init/adopt` 漏发 docs/process/risk-tiers.md → e2e-review 第 1 步
#   定档无数据源 → 一切按低风险处理 → 不跑 LLM 与异构评审。
#
# 本探针自身的能力边界（**必须诚实声明**，异构评审 #5 / reviewer #2）：
#   它做的是「**显式路径引用**的静态存在性检查」，不是"守住整类 fail-open"。
#   抓不到的形态至少有：markdown 链接 `[x](path)`、花括号展开 `{a,b}-t.md`、
#   变量拼接、传递依赖（被调脚本自己的依赖）、外部工具/Action/MCP/环境变量依赖、
#   文件存在但内容是旧模板或不可执行、条款号（C14）这类非文件依赖。
#   → 对外表述只能是"显式路径引用已守住"，**不得**说"这一类问题已解决"。
#
# 用法：bash scripts/check-skill-deps.sh [<repo-root>]
# 退出码：0=全部存在  1=有缺失  66=自检失败/抽取失效/无可检对象（fail-closed）

set -euo pipefail

# ROOT 默认取 **git 顶层**而非 `.`（security 评审 #3 实测：默认 `.` 时在仓内
# 子目录跑会打印"跳过：非 e2e 仓"并 exit 0 —— 一个有 7 个 skill 的仓被判为非 e2e 仓）
if [ $# -ge 1 ]; then
  ROOT="$(cd "$1" 2>/dev/null && pwd)" || { echo "自检失败：目录不存在 $1" >&2; exit 66; }
else
  ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || ROOT="$(pwd)"
fi
cd "${ROOT}"

SKILL_DIR=".claude/skills"

# ---- 单一抽取正则：金丝雀与生产**共用同一个变量** ----
# 早期版本金丝雀用的是另一条正则，于是它只验证了"一条没人用的正则能工作"，
# 生产正则退化时照样绿（reviewer #3 实证）。共用之后金丝雀才真的守着引擎。
# 允许出现在行内任意位置（含反引号包住的整条命令里），不要求首尾贴反引号。
#
# 路径主体用**负向定界**（一串非分隔符）而非白名单字符类：白名单版本不含中文，
# 会把 `docs/research/AI时代评审门禁-调研.md` 截成 `docs/research/AI` 并误报缺失。
# 不用 LC_ALL=C —— 按字节匹配时中文会被拆碎；这里要的是按字符。
PATH_RE='(^|[^A-Za-z0-9_./-])(docs|scripts|ops|tests|bin|specs|templates|\.claude|\.github)/[^[:space:]`"'"'"'()|;、，。]*'

extract() {  # extract <file> → 每行一条路径
  # 先剔除标了 `skill-deps:platform-only` 的行：那是**平台仓 provenance**（设计出处），
  # 不随脚手架分发，业务仓没有它是正常的。豁免写在正文里、看得见、可审计——
  # 与 shell-traps:ok 同一套做法，不做"猜意图"的启发式。
  grep -v 'skill-deps:platform-only' "$1" 2>/dev/null \
    | grep -oE "${PATH_RE}" 2>/dev/null \
    | sed -E 's/^[^A-Za-z0-9_.]//' \
    | sed -E 's/[^A-Za-z0-9/>}]+$//' \
    | grep . | sort -u
}

# ---- 自检金丝雀：用生产 extract 去扫一个含已知形态的样本 ----
# 覆盖三种真实写法：反引号整路径、反引号包整条命令、裸路径。
_canary=$(mktemp)
cat > "${_canary}" <<'CANARY'
> 分档表：`docs/process/risk-tiers.md`
跑 `bash .claude/skills/e2e-review/scripts/check-review.sh specs/x/ --final` 绿后
参见 tests/probe-negative/run.sh 的契约
CANARY
_hits=$(extract "${_canary}" | grep -c . || true)
rm -f "${_canary}"
if [ "${_hits}" -lt 3 ]; then
  echo "自检失败：抽取引擎失效（金丝雀应命中 ≥3 条，实得 ${_hits}）——探针不可信" >&2
  exit 66
fi

echo "== skill 依赖文件存在性检查 ｜ ${ROOT} =="

# ---- 无可检对象 = 响亮失败，不是 PASS（异构评审 #4：探针自己 fail-open）----
if [ ! -d "${SKILL_DIR}" ]; then
  echo "FAIL(66): 无 ${SKILL_DIR} —— 无可检对象。脚手架若漏发整个 skill 目录，" >&2
  echo "          本探针必须响亮失败而非'跳过'（跳过=静默放行，正是要防的东西）。" >&2
  exit 66
fi
skill_count=$(find "${SKILL_DIR}" -name SKILL.md -maxdepth 2 2>/dev/null | grep -c . || true)
if [ "${skill_count}" -eq 0 ]; then
  echo "FAIL(66): ${SKILL_DIR} 下没有任何 SKILL.md —— 无可检对象（同上，判为失败）" >&2
  exit 66
fi

# 写目标豁免：skill 运行时**按需创建**的产出，不是读依赖。逐条写明理由，不许当垃圾桶。
# 注意：本清单属门禁规则，改它须走高风险评审（risk-tiers.md 已把 scripts/check-*.sh 列入高档）。
is_write_target() {
  case "$1" in
    docs/process/opportunity-backlog.md) return 0 ;;  # 阶段0 kill 想法时才创建
    *) return 1 ;;
  esac
}

missing=0
checked=0

for skill in "${SKILL_DIR}"/*/SKILL.md; do
  [ -f "${skill}" ] || continue
  name=$(basename "$(dirname "${skill}")")
  skill_home=$(dirname "${skill}")
  per_skill=0

  while IFS= read -r path; do
    [ -n "${path}" ] || continue
    case "${path}" in *'<'*|*'>'*|*'*'*|*'{'*|*'}'*) continue ;; esac  # 占位符/通配不臆断
    is_write_target "${path}" && continue

    per_skill=$((per_skill + 1))
    checked=$((checked + 1))

    # 单一解析基准，**不做 OR 兜底**（reviewer #10：OR 会放过"本该在仓根却只在
    # skill 目录存在"的错误）。SKILL.md 已统一为仓根相对路径；templates/ 是
    # 唯一保留的 skill 私有前缀。
    case "${path}" in
      templates/*) resolved="${skill_home}/${path}" ;;
      *)           resolved="${ROOT}/${path}" ;;
    esac

    if [ ! -e "${resolved}" ]; then
      printf '  ❌ %-18s 引用了不存在的 %s\n' "${name}" "${path}"
      missing=$((missing + 1))
    fi
  done < <(extract "${skill}")

  # 单个 SKILL.md 抽出 0 条 = 抽取失效（格式变了/正则退化），不是"它没有依赖"
  if [ "${per_skill}" -eq 0 ]; then
    echo "FAIL(66): ${name}/SKILL.md 抽出 0 条路径引用 —— 判为抽取失效而非'无依赖'" >&2
    exit 66
  fi
done

echo "  已检查 ${checked} 条显式路径引用（${skill_count} 个 skill）"
if [ "${missing}" -gt 0 ]; then
  cat >&2 <<EOF

❌ FAIL：${missing} 条 skill 依赖缺失。
   后果不是"报错"，而是 skill 跑到那步**静默跳过检查**（fail-open）。
   修复：把缺失文件加入 bin/e2e 的 init/adopt 拷贝清单，或修正 SKILL.md 的引用路径。
EOF
  exit 1
fi

echo "PASS: 显式路径引用全部存在（**不代表**所有依赖形态已覆盖，见脚本抬头能力边界）"
