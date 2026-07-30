# ADR-003：hooks 定位为本地确定性检查，安全边界在服务端

- 状态：accepted
- 日期：2026-07-31
- 关联：SR-3 · NFR 四级验证 · 宪法 C3 · 调研 Round 1 修正实证

## 背景与驱动力

必须明确"什么拦得住 AI 的坏产出"。官方 hooks 文档原文：`if` 过滤 best-effort/fail-open，"use the permission system rather than a hook to enforce a hard allow or deny"。

## 备选方案

### 选项 A：hooks 当强制门禁（Stop/PostToolUse 视为安全边界）
- 优点：实现最省（客户端配置即全部）
- 代价：客户端可改、fail-open、官方明示非硬策略——给受训企业错误安全感，出事即咨询事故

### 选项 B：四级分层——CLAUDE.md 建议 → LLM 评审 → hooks 本地确定性检查 → 服务端不可绕过（受保护分支+required checks+发布审批+managed settings）
- 优点：与官方语义一致；每级职责清晰；Spotify/Anthropic 一手实践同构
- 代价：完整故事依赖远程仓与 CI（M3 才闭环）；试点前期只有前三级

### 选项 C：跳过 hooks，只做 CI 硬门禁
- 优点：只信服务端最保险
- 代价：丢失秒级本地反馈（Spotify 实证 Stop hook 拦截在开 PR 前最省时）；验证税全压到 CI

## 决定

选 B。决定性理由：既要本地快（hooks），又绝不把安全边界建在客户端（官方原文+调研 Round 1 被抓修正的教训）。

## 后果

- ✅ 手册可给企业讲清"哪层防什么"；hooks 失效不产生安全事故
- ⚠️ M3 前服务端级缺位——期间制品级把关靠探针+人审，如实告知
- 可复议条件：官方 hooks 提供服务端强制模式时重估（新 ADR）
