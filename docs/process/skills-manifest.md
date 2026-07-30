# Skills Manifest（唯一能力清单）

> 七个 e2e-* skill 的权威登记（异构评审阻断#3 的修复：拓扑唯一来源）。scaffold 生成与 SPEC-18 结构探针共同读取本表。改本表=改产品能力面，走门禁②级评审。
> 口径：tasks 产出归 e2e-implement 第 1 步（不设独立 tasks skill）。

| skill | 生命周期段 | 入口门禁（第 0 步校验） | 主产物 | 探针 |
|---|---|---|---|---|
| e2e-discovery | 1 战略/立项 | 无（起点） | specs/<f>/prfaq.md | check-prfaq.sh |
| e2e-requirements | 2 产品发现 | ⓪=go | specs/<f>/prd.md（+stories.md） | check-prd.sh |
| e2e-design | 3 定义/设计 | ①=批准 | specs/<f>/{spec,plan}.md + ADR + constitution/spine（平台级） | check-design.sh |
| e2e-implement | 4 构建（tasks+实现） | ②=批准 | specs/<f>/tasks.md（每条带验证）+ 代码与测试 | check-tasks.sh（M2） |
| e2e-review | 4 构建（内环评审） | tasks 存在且实现中 | 结构化 findings（评审记录留痕） | check-review.sh（M2） |
| e2e-release | 5 交付/运营 | **③=服务端事件**（远程：gh PR 合并+checks 绿；本地降级：merge+测试绿） | PRR 核对记录 + runbook | check-release.sh（M2） |
| e2e-retire | 6 退役 | ④=批准 | deprecation 计划（迁移/通知/支持期） | check-retire.sh（M2） |

结构约定（SPEC-18 逐项检查）：每 skill 目录 = `SKILL.md + templates/ + scripts/check-*.sh`；对应阶段定义文档在 `docs/process/stages/`；阶段名词入 `docs/glossary.md`。
