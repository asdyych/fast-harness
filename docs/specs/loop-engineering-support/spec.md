# 规格说明：loop-engineering-support

状态：待评审草案

## 目标

为 fast-harness 增加一层轻量 Loop Engineering 支持，让一个 SDD 会话可以表达并恢复一个可监督的工作循环：目标、重复动作、停止条件、进度状态、证据和人工升级点。

这层能力应该让现有 harness 流程更容易恢复和监督，但不能把 fast-harness 变成重型自治编排平台。

同时，本次变更要把 SDD 文档语言沉淀为插件级可配置能力。后续使用者可以在项目配置中指定模板语言，例如中文 `zh-CN` 或英文 `en`，而不是每次手动要求 agent 改写。

## 背景

当前 fast-harness 已经具备主要 Harness 构件：SDD 文档、本地执行账本、worktree 启动、代码级验证、真实浏览器 E2E、review-loop、clean-context 和 retro。

缺失的是一层小型 Loop 控制能力，用来回答：

- 这个循环从哪里开始？
- 每次 tick 应该重复做什么？
- 哪些证据证明有进展？
- 什么时候应该停止？
- 什么时候应该升级给 loop 外的人？

另一个缺口是 SDD 模板语言。目前 `harness-sdd.sh start` 固定生成英文模板。对于中文团队或中文主导的项目，应允许在项目级配置中声明文档语言，并让后续 `spec.md`、`design.md`、`tasks.md`、`learnings.md`、`state.md` 模板自动采用该语言。

## 范围

范围内：

- 为 SDD 会话增加显式 loop 状态文件。
- 增加 loop 停止条件字段和默认值，开发期 v1 只使用最大轮数和连续无进展次数。
- 增加一个小型确定性 loop 脚本，用于 status、tick、stop、resume 等状态记账。
- 明确 `/fast-harness-loop` 的语义推进由 agent/skill orchestration 负责，底层脚本不做语义决策。
- 增加 `loop` skill，说明 agent 如何安全运行 loop。
- 增加细粒度快捷命令：`/loop-status`、`/loop-next`、`/loop-tick`、`/loop-stop`、`/loop-resume`。
- 增加总入口 `/fast-harness-loop`，用于在停止条件约束下自动推进 loop。
- 将 loop 证据与现有 `verify`、`e2e-browser`、`review-loop`、`retro` 输出对齐。
- 补齐 loop 可审计性所需的 review-loop ledger 支持。
- 增加项目级 SDD 文档语言配置，例如 `.harness/config.json` 的 `sdd_language`。
- 调整 `.harness/` gitignore 策略，让 `.harness/config.json` 可提交，而每个任务的执行状态继续保持本地忽略。
- 让 SDD 模板根据配置生成中文或英文版本。
- 增加隐私安全的 loop 事件日志，用于审计和恢复，但不记录完整 prompt 或凭据。
- 更新 README、`sdd` skill 和 smoke tests，使行为可安装、可发现、可验证。

范围外：

- 替换现有 `sdd`、`verify`、`e2e-browser`、`review-loop` 或 `retro` 流程。
- 构建 daemon、调度服务、队列 worker 或外部自动化后端。
- 让 `/fast-harness-loop` 绕过用户确认、安全边界或破坏性操作保护。
- 在提交文件中记录完整 prompt transcript 或凭据。
- 为每个 agent 写入的 markdown 强制严格 schema。
- 在 shell 脚本中实现语义 planner、代码生成器或 agent 调度器。
- 增加自动 PR 创建、CI/CD 或部署编排。
- 自动翻译既有历史 SDD 文档。

## 成功标准

- [ ] 启动 SDD 会话时会创建 loop-aware 本地状态，且不破坏现有 SDD 行为。
- [ ] SDD 模板语言可以通过项目配置指定，至少支持 `en` 和 `zh-CN`。
- [ ] 未配置语言时保持向后兼容，默认仍可生成英文模板。
- [ ] 配置 `sdd_language: zh-CN` 后，`spec.md`、`design.md`、`tasks.md`、`learnings.md`、`state.md` 使用中文模板。
- [ ] `.harness/config.json` 可以被 git 跟踪，`.harness/<change-id>/` 继续被忽略。
- [ ] loop status 命令可以显示当前目标、阶段、轮次、下一步、阻塞项和停止条件计数。
- [ ] loop tick 命令可以更新轮次和无进展计数，并在触发限制时输出明确的停止或升级结果。
- [ ] loop manifest 至少包含 `max_rounds` 和 `max_no_progress_rounds`。
- [ ] 细粒度 `/loop-*` 命令可以分别查看、规划下一步、记录 tick、停止和恢复 loop。
- [ ] `/fast-harness-loop` 可以在已定义目标、验收标准和停止条件下自动推进 loop，并在需要人工判断时停止。
- [ ] `/fast-harness-loop --yes` 每一轮都必须绑定一个 checkpoint acceptance、写入 evidence、执行 tick，并在发现 unexpected dirty changes 时停止。
- [ ] 人类可读的 `state.md` 记录当前进度和下一步。
- [ ] 持久化的 `learnings.md` 记录可复用约束和模式。
- [ ] 隐私安全的 loop 事件日志记录 round、action、decision、evidence、result、stop reason。
- [ ] review-loop 生成本地 ledger 和 summary，且可以被 `.harness/<change-id>/evidence/review-loop.md` 引用。
- [ ] smoke tests 覆盖 SDD scaffolding、中文模板、loop tick 行为和 review-loop ledger summary 生成。
- [ ] README 记录预期链路：SDD -> loop state/tick -> verify -> e2e -> review-loop -> retro。

## Checkpoints

### Checkpoint 01: 定义 loop 状态、SDD scaffolding、模板语言配置和本地配置策略

- **Scope**: 扩展 SDD 会话 scaffolding，增加 loop 状态、持久化 learnings、事件日志、停止条件默认值和项目级模板语言配置，同时保持既有文件兼容。
- **Depends on**: none
- **Type**: infrastructure
- **Acceptance criteria**:
  - [ ] `harness-sdd.sh start <id>` 创建 `.harness/<id>/state.md`。
  - [ ] `harness-sdd.sh start <id>` 创建 `docs/specs/<id>/learnings.md`。
  - [ ] `harness-sdd.sh start <id>` 创建 `.harness/<id>/loop.log.md` 或在 `task-log.md` 中创建结构化 loop event section。
  - [ ] `.harness/<id>/manifest.json` 包含默认 loop 计数器和停止条件。
  - [ ] `.harness/config.json` 或等价项目配置可以声明 `sdd_language`。
  - [ ] `.gitignore` 允许 `.harness/config.json` 被 git 跟踪，但继续忽略 `.harness/<change-id>/` 执行状态。
  - [ ] 未配置 `sdd_language` 时，现有英文模板行为保持兼容。
  - [ ] 配置 `sdd_language: zh-CN` 时，`spec.md`、`design.md`、`tasks.md`、`learnings.md`、`state.md` 生成中文模板。
  - [ ] 现有 SDD smoke test 仍然通过。
  - [ ] 新增 smoke assertion 证明 loop 文件和中文模板被创建。
- **Files of interest**: `plugins/fast-harness/scripts/harness-sdd.sh`,
  `tests/harness-sdd-smoke.sh`, `plugins/fast-harness/skills/sdd/SKILL.md`,
  `README.md`
- **Effort estimate**: M

### Checkpoint 02: 增加确定性 loop 状态记账

- **Scope**: 增加一个小脚本，用于报告 loop 状态并记录 tick、stop、resume 等确定性状态，但不判断语义上的任务进展或下一步实现方案。
- **Depends on**: Checkpoint 01
- **Type**: infrastructure
- **Acceptance criteria**:
  - [ ] `harness-loop.sh status [change-id]` 输出 loop 阶段、轮次、无进展次数、停止限制、下一步和阻塞项。
  - [ ] `harness-loop.sh tick <change-id> --progress changed|unchanged` 确定性地更新轮次计数。
  - [ ] 连续 unchanged tick 达到配置限制时，输出停止或升级消息。
  - [ ] 达到 max-rounds 限制时，输出停止或升级消息。
  - [ ] `harness-loop.sh stop/resume` 只更新 manifest 和日志，不执行实现。
  - [ ] `harness-loop.sh` 不实现语义 `next/run` planner；下一步选择由 skill/agent 完成。
  - [ ] smoke test 覆盖 changed、unchanged、stop-limit、stop 和 resume 行为。
- **Files of interest**: `plugins/fast-harness/scripts/harness-loop.sh`,
  `tests/harness-loop-smoke.sh`
- **Effort estimate**: M

### Checkpoint 03: 增加 loop skill、细粒度命令和自动化总入口

- **Scope**: 文档化 agent-facing loop 协议，通过共享 skill、细粒度 Claude commands 和 `/fast-harness-loop` 自动化总入口暴露。
- **Depends on**: Checkpoint 02
- **Type**: infrastructure
- **Acceptance criteria**:
  - [ ] `plugins/fast-harness/skills/loop/SKILL.md` 说明何时 start、inspect、tick、stop 和 escalate loop。
  - [ ] skill 要求长时间运行前必须明确停止条件。
  - [ ] skill 明确何时调用 `worktree-dev`、何时使用 `clean-context` 派 fresh sub-agent、何时记录 plugin/MCP 依赖而不是自动连接。
  - [ ] skill 与 `sdd`、`verify`、`e2e-browser`、`review-loop`、`clean-context`、`retro` 组合。
  - [ ] `plugins/fast-harness/commands/loop-status.md` 存在，供用户只读查看 loop 状态。
  - [ ] `plugins/fast-harness/commands/loop-next.md` 存在，用于提出下一步并在执行前等待确认。
  - [ ] `plugins/fast-harness/commands/loop-tick.md` 存在，用于手动记录 `changed|unchanged` 进展。
  - [ ] `plugins/fast-harness/commands/loop-stop.md` 存在，用于人工停止并记录原因。
  - [ ] `plugins/fast-harness/commands/loop-resume.md` 存在，用于恢复 loop 并先展示状态和下一步。
  - [ ] `plugins/fast-harness/commands/fast-harness-loop.md` 存在，用于自动推进 loop。
  - [ ] `/fast-harness-loop` 默认只推进一个 round；带 `--yes` 时也必须遵守停止条件、安全边界、checkpoint acceptance 和 evidence 记录要求。
  - [ ] README 列出 loop skill、细粒度 commands 和 `/fast-harness-loop`。
- **Files of interest**: `plugins/fast-harness/skills/loop/SKILL.md`,
  `plugins/fast-harness/commands/loop-status.md`,
  `plugins/fast-harness/commands/loop-next.md`,
  `plugins/fast-harness/commands/loop-tick.md`,
  `plugins/fast-harness/commands/loop-stop.md`,
  `plugins/fast-harness/commands/loop-resume.md`,
  `plugins/fast-harness/commands/fast-harness-loop.md`, `README.md`
- **Effort estimate**: S

### Checkpoint 04: 补齐 review-loop ledger 支持

- **Scope**: 实现本地 review-loop session ledger，满足 loop 可审计性，并与既有设计文档一致。
- **Depends on**: Checkpoint 03
- **Type**: infrastructure
- **Acceptance criteria**:
  - [ ] `harness-review-session.sh init` 创建 `.review-loop/<session>/`、`meta.json` 和 `.review-loop/latest`。
  - [ ] `.review-loop/` 被保证写入 `.gitignore`。
  - [ ] `harness-review-session.sh summary --session <dir>` 可以根据 round 文件渲染 `summary.md`。
  - [ ] summary 输出包含最终状态、轮次、finding、host decision 和 escalated items。
  - [ ] smoke test 证明 init 和 summary generation 可用。
- **Files of interest**:
  `plugins/fast-harness/scripts/harness-review-session.sh`,
  `plugins/fast-harness/skills/review-loop/SKILL.md`,
  `plugins/fast-harness/commands/review-loop.md`
- **Effort estimate**: M

### Checkpoint 05: 串联文档和验证

- **Scope**: 让新的 loop 层和模板语言配置可发现、可阅读、可验证。
- **Depends on**: Checkpoint 04
- **Type**: infrastructure
- **Acceptance criteria**:
  - [ ] README 用 fast-harness 语境解释 Context、Harness、Loop 的关系。
  - [ ] README 记录最小 loop 文件布局和命令示例。
  - [ ] README 记录 `/fast-harness-loop` 的默认单轮推进、`--yes` 连续推进和停止条件语义。
  - [ ] README 记录 `sdd_language` 配置方式和支持值。
  - [ ] README 记录 `.harness/config.json` 可提交、`.harness/<change-id>/` 本地忽略的规则。
  - [ ] README 记录 loop event log 的隐私边界：记录决策和证据，不记录完整 prompt 或凭据。
  - [ ] `bash -n` 对所有修改过的 shell scripts 通过。
  - [ ] `tests/harness-sdd-smoke.sh` 通过。
  - [ ] `tests/harness-loop-smoke.sh` 通过。
  - [ ] review-loop ledger smoke test 通过。
- **Files of interest**: `README.md`, `tests/`
- **Effort estimate**: S
