# fast-harness 0.2 迁移说明

## 决策

从 `0.2.0` 开始，`mattpocock/skills` 是唯一工程流程层。fast-harness 不再维护第二套 spec、任务拆分、执行循环、TDD、诊断或常规代码审查流程。

fast-harness 只保留需要本地机制或明确执行边界的能力：

- CC SessionStart rules；
- CC destructive-operation guard；
- Trace Browser real-browser E2E；
- bounded cross-model second review。

## 删除内容

- `sdd`、`loop` 及 `.harness/<change-id>/` 执行账本；
- `verify` 和硬编码的 frontend/backend、TypeScript/Vitest 假设；
- `worktree-dev` 和 `.harness-dev.conf`；
- 自建 Chrome CDP manager 和 plaintext test-account store；
- `clean-context`、`retro`、Windows-only `kill-port`；
- 15 个通用 CC subagents；
- 持久化 `.review-loop/` ledger；
- `superpowers` 与 `harness-engineering-skills` companion references。

旧目录仍被 `.gitignore` 忽略，避免升级后把消费项目遗留的本地状态意外提交。fast-harness 不会主动删除这些目录。

## 旧入口映射

| 0.1 入口 | 0.2 替代 |
|---|---|
| `/sdd-start` | Matt `/grill-with-docs`，再 `/to-spec` |
| `/sdd-status` | issue tracker、spec 和 tickets |
| `/sdd-finish` | Matt `/implement` 完成状态和项目原生检查 |
| `/loop-*`、`/fast-harness-loop` | Matt `/to-tickets` 后逐 ticket 使用 `/implement` |
| `/verify` | 项目自己的 typecheck、test、lint、build 或 CI 命令 |
| `/wt-*` | 项目自己的 dev scripts、worktree hooks 或文档 |
| `/review-loop` | Matt `/code-review` 后按需 `/cross-review` |
| `/chrome-cdp` | Trace Browser `/api/profiles` 和 `/api/launch` |
| `/e2e` | 保留；实现改为 Trace Browser 优先 |
| 通用 subagents | Matt skills 内建 subagent 流程或 agent 自身 delegation |

## 分平台安装

CC 可从 fast-harness marketplace 同时安装：

```text
/plugin install fast-harness@fast-harness
/plugin install mattpocock-skills@fast-harness
```

Matt 当前尚未提供原生 Codex plugin。Codex 单独安装 fast-harness plugin，并通过 Agent Skills installer 安装 Matt skills。两个宿主使用相同的共享 `e2e-browser` 和 `cross-review` 契约：

```bash
npx skills@latest add mattpocock/skills
```

## 项目职责

消费项目需要明确自己的：

- 启动命令和本地服务依赖；
- typecheck、test、lint、build 和 E2E 前置检查；
- issue tracker 和 spec 位置；
- commit policy；
- 项目级编码和文档规则。

这些内容应放在项目脚本、CI、`AGENTS.md`、`CLAUDE.md` 或 Matt setup 生成的 `docs/agents/` 中，而不是重新加入 fast-harness 的通用流程层。
