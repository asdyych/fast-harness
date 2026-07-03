# 设计说明：loop-engineering-support

状态：待评审草案

## 方向

在现有 SDD workflow 之上增加一层轻量 Loop Engineering。

SDD 仍然是持久化变更记录。loop 层补充可恢复和可监督能力：当前状态、下一步、轮次计数、停止限制、证据链接和升级规则。

继续沿用 fast-harness 既有设计规则：

- 脚本只负责确定性的文件和状态管理；
- agent 负责语义判断；
- 人保持在 loop 之外，只在升级点被询问。

## 文件布局

持久化、可提交文档：

```text
docs/specs/<change-id>/
  spec.md
  design.md
  tasks.md
  learnings.md
```

本地、gitignored loop 状态：

```text
.harness/<change-id>/
  manifest.json
  checkpoints.md
  task-log.md
  state.md
  evidence/
    verify.md
    e2e.md
    review-loop.md
    loop.md
```

本地 review-loop trace：

```text
.review-loop/
  latest -> <session>
  <session>/
    meta.json
    round-01.json
    round-02.json
    summary.md
```

项目级配置：

```text
.harness/config.json
```

该文件用于记录可复用的 harness 项目配置。它应该被 git 跟踪，便于后续用户在项目中共享 harness 行为。任务执行状态仍然写入 `.harness/<change-id>/` 并保持 gitignored。

第一版至少新增：

```json
{
  "sdd_language": "zh-CN",
  "loop": {
    "max_rounds": 10,
    "max_no_progress_rounds": 2
  }
}
```

支持值：

- `en`：英文模板，默认值，向后兼容。
- `zh-CN`：简体中文模板。

## 状态模型

`manifest.json` 保持脚本拥有的 JSON 文件。新增 `loop` object：

```json
{
  "loop": {
    "phase": "planning",
    "round": 0,
    "max_rounds": 10,
    "no_progress_rounds": 0,
    "max_no_progress_rounds": 2,
    "status": "active",
    "last_progress_at": "",
    "last_tick_at": ""
  }
}
```

`state.md` 是人类可读、agent 维护的状态文件。英文模板：

```text
# Loop State: <change-id>

Goal:
Current phase:
Current checkpoint:
Last meaningful progress:
Next action:
Blockers:
Escalation:
Evidence:
```

中文模板：

```text
# Loop 状态：<change-id>

目标：
当前阶段：
当前 checkpoint：
最近有效进展：
下一步：
阻塞项：
升级条件：
证据：
```

`learnings.md` 是持久化的经验文件。英文模板：

```text
# Learnings: <change-id>

## Constraints
## Validated Patterns
## Mistakes To Avoid
## Follow-up Harness Improvements
```

中文模板：

```text
# 经验沉淀：<change-id>

## 约束
## 已验证模式
## 避免重复的错误
## 后续 Harness 改进
```

## SDD 模板语言

`harness-sdd.sh start <change-id>` 在创建模板前读取项目配置：

1. 如果 `.harness/config.json` 存在且包含 `sdd_language`，使用该值。
2. 如果未配置，默认 `en`。
3. 如果配置值不支持，失败并提示支持值，而不是默默回退。

脚本生成以下文件时都应使用同一种模板语言：

- `docs/specs/<change-id>/spec.md`
- `docs/specs/<change-id>/design.md`
- `docs/specs/<change-id>/tasks.md`
- `docs/specs/<change-id>/learnings.md`
- `.harness/<change-id>/checkpoints.md`
- `.harness/<change-id>/task-log.md`
- `.harness/<change-id>/state.md`

保留英文文件名和命令名，因为这些是跨工具稳定接口；只切换文档正文语言。

## Gitignore 策略

现有 `.gitignore` 如果直接忽略整个 `.harness/`，会导致 `.harness/config.json` 无法作为项目配置共享。实现时应改成：

```gitignore
.harness/*
!.harness/config.json
```

这样：

- `.harness/config.json` 可提交，用于共享 `sdd_language`、loop 默认轮数和无进展停止条件等项目级配置；
- `.harness/<change-id>/`、`.harness/test-accounts.json` 等执行状态和敏感本地文件继续被忽略；
- 如果未来需要更多可提交配置文件，应显式 whitelist，而不是提交整个 `.harness/`。

## Loop 事件日志

文章中的 `agent.log` 目标是支撑恢复、审计和自进化。fast-harness 不应记录完整 prompt transcript 或凭据，因此采用隐私安全的事件日志。

第一版可以创建 `.harness/<change-id>/loop.log.md`，或在 `task-log.md` 中建立固定的 `## Loop Events` section。推荐单独文件，便于 `/fast-harness-loop` 每轮追加。

每条事件至少记录：

```text
- Round: 3
  Action: run checkpoint 02 smoke test
  Decision: progress changed
  Evidence: .harness/<id>/evidence/loop-round-03.md
  Result: continue
  Stop reason: none
```

日志边界：

- 记录 action、decision、evidence path、result、stop reason；
- 不记录完整 prompt；
- 不记录密码、cookie 或测试账号明文；
- 不把 shell 原始长输出作为日志主体，长输出写入 evidence 文件并摘要引用。

## Commands

### `harness-loop.sh status [change-id]`

读取 `.harness/<change-id>/manifest.json` 和 `state.md`，输出：

- change id；
- loop status 和 phase；
- round 和 no-progress counters；
- current checkpoint；
- next action；
- blockers；
- stop-condition summary。

如果没有传入 id，使用最新 SDD session，行为与 `harness-sdd.sh status` 对齐。

### `harness-loop.sh tick <change-id> --progress changed|unchanged`

tick 命令只做记账：

- 增加 `loop.round`；
- 根据 `changed|unchanged` 重置或增加 `loop.no_progress_rounds`；
- 更新 `loop.last_tick_at`；
- 当 progress 为 `changed` 时更新 `loop.last_progress_at`；
- 向 `loop.log.md` 和 `task-log.md` 追加简洁记录；
- 返回明确状态行：
  - `LOOP: CONTINUE`；
  - `LOOP: STOP max-rounds`；
  - `LOOP: STOP no-progress`。

脚本不判断代码是否正确，不运行测试，不生成 agent，也不编辑持久化 spec。agent 判断语义进展，并传入 `changed` 或 `unchanged`。

### `harness-loop.sh stop <change-id> [--reason <text>]`

将 loop 标记为 stopped，并把原因写入 `manifest.json` 和 `task-log.md`。这是人工停止或自动停止后的持久化动作。

### `harness-loop.sh resume <change-id>`

将可恢复的 stopped loop 标记回 active，并输出当前状态、下一步和阻塞项。恢复后不自动执行实现，除非由 `/fast-harness-loop` 继续推进。

### 不在脚本中实现语义 `next/run`

`next` 和 `run` 涉及语义判断：当前 checkpoint 是否满足、下一步做什么、是否需要调用测试或 review。这些不应放进 shell 脚本。底层脚本只提供确定性状态原语：

- `status`
- `tick`
- `stop`
- `resume`

`/loop-next` 和 `/fast-harness-loop` 的语义推进由 command prompt + `loop` skill 中的 agent orchestration 完成。这样保持“脚本做确定性管理，agent 做语义判断”的边界。

## Claude Commands

细粒度命令：

- `/loop-status [change-id]`：只读查看当前 loop 状态。
- `/loop-next [change-id]`：agent 读取 `state.md`、`checkpoints.md`、`tasks.md` 和最近 evidence，提出下一步；执行前等待用户确认。
- `/loop-tick <change-id> changed|unchanged`：手动记录一轮进展。
- `/loop-stop <change-id> [reason]`：人工停止 loop 并记录原因。
- `/loop-resume <change-id>`：恢复 loop，先展示状态和下一步。

总入口：

- `/fast-harness-loop [change-id] [--max-rounds N] [--yes]`：自动推进 loop。

`/fast-harness-loop` 默认是保守模式：agent 读取状态、选择当前 checkpoint 的最小下一步、执行可验证动作、记录 evidence、运行必要检查，然后调用 `harness-loop.sh tick` 一次并返回总结。它不会无限跑。

`--yes` 是连续推进模式，只适用于非破坏性、范围明确、验收标准可检查的步骤；它不绕过 stop conditions、权限边界或人工升级规则。

`--yes` 每一轮必须满足硬边界：

- 绑定一个具体 checkpoint acceptance；
- 执行前工作树没有未解释的 unexpected dirty changes；
- 写入 evidence；
- 写入 loop event；
- 调用 tick；
- 任一检查无法判定或出现阻塞时停止。

## Skill 行为

`loop` skill 应指导 agent：

- 长时间运行前先明确目标和停止条件；
- 行动前检查 SDD state；
- 每个有意义的执行周期前后进行 tick；
- 使用 `/loop-next` 或等价脚本先展示下一步；除 `/fast-harness-loop --yes` 的安全连续模式外，执行前应等待用户确认；
- 使用 `/fast-harness-loop` 作为自动推进入口，但每轮都保持 evidence 和 stop-condition 检查；
- 如果 checkpoint 需要运行服务，先使用 `worktree-dev`；如果只需静态文件/脚本验证，不强制启动服务。
- 如果探索、审阅或大文件读取可以独立完成，使用 `clean-context` 派 fresh sub-agent；不要把大段无关上下文塞回主线程。
- 如果任务依赖 MCP/plugin/external tool，先在 `state.md` 或 `design.md` 记录依赖和用途；除非 checkpoint 明确需要，不自动连接或配置外部系统。
- 将 evidence summary 记录到 `.harness/<change-id>/evidence/`；
- 遇到限制、阻塞、歧义、缺少凭据、破坏性操作或 review-loop 僵持时停止并询问人；
- 对独立探索或评审使用 `clean-context`；
- 只在重复 harness 摩擦或用户明确要求时使用 `retro`。

## Review-Loop Ledger

既有 review-loop 设计已经要求本地 `.review-loop/` ledger。实现最小版本：

- `init` 创建 session 目录、`meta.json` 和 latest pointer；
- agent 在 triage 后写入 `round-NN.json`；
- `summary` 渲染可读 `summary.md`；
- summary 路径被复制或引用到 `.harness/<change-id>/evidence/review-loop.md`。

第一版不需要严格 schema validation。summary 脚本应容忍缺失的可选字段，并在 JSON 无效时清晰失败。

## 错误处理

- 不在 git repo 中：失败，和现有 SDD 脚本保持一致。
- 找不到 SDD session：提示用户先 start。
- change id 非法：复用 SDD id 校验规则。
- manifest 缺失或 JSON 无效：明确失败，不猜测。
- `sdd_language` 不支持：明确失败并列出支持值。
- `.harness/config.json` 被 `.gitignore` 忽略：实现应修正 gitignore 或明确失败，避免配置不可提交。
- `/fast-harness-loop --yes` 遇到任何需要人工判断的情况：停止并输出升级原因。
- 达到停止条件：以成功退出码输出 `LOOP: STOP ...`，让 agent 升级而不是把它当成 shell failure。

## 验证

- Targeted checks:
  - 对修改过的 shell scripts 执行 `bash -n`。
  - 运行现有 `tests/harness-sdd-smoke.sh`。
  - 新增中文模板 smoke 覆盖。
  - 新增 `tests/harness-loop-smoke.sh`。
  - smoke 覆盖 `status`、`tick`、`stop`、`resume`、max-rounds stop 和 no-progress stop 的基础行为。
  - command 文档检查覆盖 `/loop-next` 和 `/fast-harness-loop` 的 agent orchestration 说明。
  - 新增或扩展 review-loop ledger smoke test。
- `/verify`:
  - 当前仓库不是典型前后端项目，除非消费项目提供配置，否则使用 shell smoke tests 作为验证。
- `/e2e`:
  - 不适用；这是 CLI/script/documentation 工作，不涉及浏览器行为。
- `/review-loop`:
  - 合并前需要运行，因为本次变更影响 harness workflow 行为。

## 风险

- 把 loop 做成调度器服务会让 harness 变重且更难信任。v1 保持文件状态和显式 tick。
- 把 `state.md` 当机器数据会让脚本脆弱。脚本只依赖 JSON，markdown 面向人和 agent。
- 记录完整 prompt 或凭据会带来隐私和安全风险。日志保持简洁且不含秘密。
- 多语言模板可能导致测试用例依赖具体文案。测试应验证关键标题和文件存在，不要过度耦合完整文本。
- `/fast-harness-loop` 容易被误解成完全自治。文档和 skill 必须强调默认单轮推进、`--yes` 有边界、任何不确定都要升级。
- 文章中的成本刹车适合企业长链路场景，但开发期 v1 不做成本或 token 预算，避免伪造精确计费。后续如接入稳定 token/cost 来源，可作为 v2 扩展。
