# ADR-013：CI 内 AI 评审采用 `claude -p --bare` headless（试点降级为内环，凭据就位即启用）

- 状态：accepted
- 日期：2026-07-31
- 关联：S1 spike 结论（T-1）· SPEC-19 · 宪法 C15 · ADR-003

## 背景与驱动力

S1 拆雷实测：纯质量门禁 workflow 在 `Albertsun6/aisep729` 跑通（macos-latest，13s，四阶段探针全绿）。但外环的 **AI 评审**需要 Anthropic 凭据——仓库无 secret、本地无 API key。需决定 CI 内 AI 评审的技术路径与试点期处置。

## 备选方案

### 选项 A：`anthropics/claude-code-action`（官方 action）
- 优点：官方维护、`/install-github-app` 一键配好 GitHub App 与 secrets
- 代价：引入第三方 action 依赖（宪法 C15 要求 SHA pin 与最小权限，增加供应链面）；评审逻辑受 action 封装约束；仍需 API key

### 选项 B：`claude -p --bare` headless 自建 step
- 优点：**可复现**——`--bare` 跳过 hooks/skills/plugins/MCP/CLAUDE.md 自动发现，CI 结果不受任何人本地配置影响（官方明示 bare 是 CI 推荐模式）；**结构化可判**——`--output-format json --json-schema` 强制 finding 带 severity 字段，直接实现 SPEC-19 的"block 级 finding ≥1 → check 红"；无第三方 action，供应链更干净；评审 prompt 完全自控（可注入宪法/risk-tiers）
- 代价：需自己写 step 与判定逻辑（~30 行）；**同样需要凭据**——`--bare` 明确跳过 OAuth/keychain 读取，必须 `ANTHROPIC_API_KEY` 或 `apiKeyHelper`

### 选项 C：订阅版 OAuth token（`claude setup-token` → `CLAUDE_CODE_OAUTH_TOKEN`）
- 优点：走已有订阅，无额外计费
- 代价：`--bare` 不读 OAuth（需放弃 bare 的可复现性）；另有"订阅版 OAuth token 被限制用于第三方/CI"的报告（**single-source 未证实**，不作决策依据但足以构成风险）

## 决定

**技术路径选 B**（headless 自建），**试点期按 S1 预定降级执行**：外环只跑纯质量门禁（已绿），AI 评审留内环（本地 e2e-review skill + 异构评审，已在 M0 验证有效）。headless workflow 写成**模板但不启用**（`.github/workflows/ai-review.yml.template`），凭据就位后改名即启用。

决定性理由：B 在可复现性、结构化判定、供应链三点上都优于 A；降级不是放弃——内环 AI 评审在 M0 已实证能抓真问题（异构评审 10 阻断），外环缺的只是"自动化触发"这一层。

## 后果

- ✅ S1 拆雷完成：质量门禁部分**已实测**，AI 评审部分**方案已定且可执行**，无残留未知
- ✅ 供应链零新增依赖（宪法 C15）
- ⚠️ 试点期 PR 无自动 AI 评审——由内环 skill + 人审补位；手册须写清"企业版怎么接"（含本 ADR 的 workflow 模板与凭据配置步骤）
- ⚠️ SPEC-19 的"ai-review required check"在试点期不存在——探针与文档均标注为"企业模式项"
- 可复议条件：用户提供 API key / 官方放开订阅 token 用于 CI → 改名模板即启用（零改造）
