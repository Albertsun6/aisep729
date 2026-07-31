# ADR-007：试点仅 macOS 实测（设计层承接与豁免范围）

- 状态：accepted
- 日期：2026-07-31
- 关联：NFR-1（用户决策 2026-07-31）· ADR-005

## 背景与驱动力

用户在 PRD 阶段裁决"仅 macOS"。设计层需要明确此决策买到什么、豁免什么、边界在哪。

## 备选方案

### 选项 A：仅 macOS 实测，Linux 完全不管
- 优点：appetite 最省；脚本可放心用 BSD 语法（sed -i ''、无 GNU 长参数）
- 代价：企业受众 CI 多为 Linux——GitHub Actions 外环若用 ubuntu runner 会立刻踩 BSD/GNU 差异

### 选项 B：仅 macOS 实测 + 两条最小护栏：①CI runner 显式钉 `macos-latest`；②脚本避免已知 BSD/GNU 高危差异写法（清单入手册）
- 优点：不增加实测负担，但把"未来 Linux 化"的返工面缩到最小
- 代价：macos runner 计费分钟数倍于 ubuntu（试点量级可忽略）

### 选项 C：macOS+Linux 双实测
- 优点：受众保障最好
- 代价：PRD 已否（appetite 约束），不重开

## 决定

选 B。决定性理由：用户的范围决策照办，但设计上花零成本护栏避免把"仅 macOS"变成"绑死 macOS"。

## 后果

- ✅ 试点全链路在单一环境可复现；CI 行为与本地一致
- ⚠️ 手册"已知限制"节必须写明 Linux 未验证 + 高危写法清单
- 可复议条件：观察窗出现企业线索（PRD NFR-1 触发条件）→ Linux 验证立项（走门禁⓪）

---

## 附录：macOS 高危写法清单（实测积累，M2-D 补）

本 ADR 选项 B 承诺的"高危写法清单"，由实际踩坑积累而成，已全部固化为 `scripts/check-shell-traps.sh` 的可执行检查：

| # | 高危写法 | 后果 | 正确写法 |
|---|---|---|---|
| 1 | `$var` 紧跟中文标点，如 `"$name（…）"` | bash 把标点字节并入变量名 → `unbound variable`（`set -u` 下直接崩） | `${var}（…）` |
| 2 | **`grep -P`（PCRE）** | macOS 自带 BSD grep 不支持，报 `invalid option -- P`；若配 `2>/dev/null \|\| true` 则**静默失效**——探针永远 PASS，最危险的失败模式 | 用 ERE：`LC_ALL=C grep -E '…[^ -~]'`（`LC_ALL=C` 使 `[^ -~]` 按字节匹配从而命中中文） |
| 3 | `grep -r --include` 传**单个文件路径** | 静默返回空（不报错），单文件检查形同虚设 | 单文件走 `grep -n`，目录才用 `-r --include` |
| 4 | `sed -i` 不带 `''` | BSD 需 `sed -i ''`，GNU 不需要 | `sed -i ''`（本仓统一 BSD 语法） |
| 5 | `$(cmd \| grep -c …) \|\| echo 0` | `grep -c` 无匹配时**已输出 0 但退出码 1**，`\|\| echo 0` 追加第二行 → 破坏整数比较 | `n=$(… \| grep -c …); : "${n:=0}"` |

**教训（#2 尤其）**：探针的失败必须**响亮**。任何 `2>/dev/null || true` 都可能把"工具不可用"伪装成"检查通过"——故 `check-shell-traps.sh` 现在带**自检金丝雀**（先用已知陷阱样本验证扫描引擎可用，不可用即 exit 66），负样本套件也增加了「纯 BSD grep 环境」用例。
