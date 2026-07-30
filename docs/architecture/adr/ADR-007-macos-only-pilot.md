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
