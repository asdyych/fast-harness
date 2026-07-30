# fast-harness

`fast-harness` 是 `mattpocock/skills` 的轻量自动编排与本地能力补充包，可在 Codex 和 CC（Claude Code）中使用。它不复制 Matt 的规划、任务、实现或验证规范，而是读取已安装的上游 skills 并按完整或快速路线串联。

职责划分：

- `mattpocock/skills` 负责工程主流程：需求澄清、spec、tickets、TDD、实现、诊断和代码审查。
- `fast-harness` 的共享核心提供完整/快速流程路由、自动 checkpoint commit/push、Trace Browser E2E 和跨模型第二意见。
- 宿主专属能力单独适配：CC 额外提供会话规则和破坏性操作 guard；Codex 继续使用自身 sandbox、approval 和项目 `AGENTS.md`。
- 每个项目通过自己的 `package.json`、`Makefile`、CI 和 agent instructions 定义启动与验证命令。

## 安装

### CC

```text
/plugin marketplace add ch-royde/fast-harness
/plugin install fast-harness@fast-harness
/plugin install mattpocock-skills@fast-harness
```

然后在每个项目首次使用 Matt 工程流程前运行：

```text
/setup-matt-pocock-skills
```

它会配置 issue tracker、triage labels、`CONTEXT.md` 和 ADR 布局。

### Codex

从本仓库根目录安装 fast-harness 的 Codex 插件：

```bash
codex plugin marketplace add .
codex plugin add fast-harness@fast-harness
```

Matt 当前没有原生 Codex 插件，使用其官方推荐的 Agent Skills 安装方式：

```bash
npx skills@latest add mattpocock/skills
```

安装时选择 Codex 和需要的 skills，并包含 `setup-matt-pocock-skills`。随后在目标项目中运行一次 setup skill。

两个宿主使用同一组共享 skills：

| 能力 | Codex | CC |
|---|---|---|
| Matt 工程流程 | 直接调用已安装 skill | 使用 `/skill-name` |
| 自动流程 | 调用 `fast-harness-full` / `fast-harness-quick` 或说触发短语 | `/fast-harness-full` / `/fast-harness-quick` |
| 分批本地提交 | 调用 `checkpoint-commits` | `checkpoint-commits` 或 SessionStart rule |
| Trace Browser E2E | 调用 `e2e-browser` | `e2e-browser` 或 `/e2e` |
| 默认 review | 调用 `cross-review` | `cross-review`、`/review` 或 `/cross-review` |
| Session rules / destructive guard | 项目规则与宿主权限机制 | plugin hooks |

## 自动流程

直接调用 `/fast-harness-full <目标>`，或说“按照 harness 的流程去实现”等同义表达时，运行完整路线：

```text
grill 后的上下文 / Goal
  -> to-spec
  -> to-tickets
  -> 逐 ticket implement（复杂独立切片自动分派）
  -> checkpoint commit/push
  -> cross-review
  -> 相关验证 + 最终 commit/push
```

直接调用 `/fast-harness-quick <目标>`，或说“快速实现”、`quick implement` 时，跳过 spec 和 tickets：

```text
明确目标
  -> implement（复杂独立切片也可自动分派）
  -> checkpoint commit/push
  -> cross-review
  -> 相关验证 + 最终 commit/push
```

完整路线适合 grill 后进入 Goal 的多阶段任务；快速路线适合目标清楚、能在单个上下文完成的改动。wrapper 在每个阶段读取已安装的 Matt `SKILL.md`，所以上游流程升级后无需在 fast-harness 复制更新。

两条路线都先证明最小可用的端到端闭环，再考虑边界加固。只有明确验收要求、已复现缺陷、正常输入可达、阻塞核心流程或存在可信安全/数据损坏风险的边界情况才进入当前范围。每个行为切片优先保留一个代表性成功路径测试；失败路径只覆盖明确行为、真实分支或回归。验收检查和直接受影响的既有测试通过后即停止扩展，不默认补齐理论输入组合、穷举矩阵、全仓测试或无具体失败场景的防御性处理。

Full 和 Quick 都会自动判断复杂度，把所有权清晰、可独立验证的代码切片交给 fresh subagent。Subagent 运行切片必要测试，并只在主 agent 分配的串行 commit 窗口提交自有文件；主 agent 负责依赖与 commit 调度、审核、集成、最终验证、cross-review 和 push。简单、重叠或产品设计未决的工作保留在主 agent。

`/fast-harness-full` 和 `/fast-harness-quick` 是固定模式入口：命令后的全部文本都视为目标，即使目标中出现 `quick` 或 `full` 也不会改变路线。原 `/harness full|quick` 继续作为兼容入口。

`checkpoint-commits` 是提交协议的唯一来源：实现任务默认按已验证行为切片创建本地提交，只暂存当前任务改动。`harness-workflow` 中 subagent 只在串行窗口提交，主 agent 审核后普通 push；普通任务仍需明确授权才 push，历史改写始终需要明确授权。

## 保留能力

### CC 会话规则

CC 的 `SessionStart` hook 注入称呼、复杂请求复述、核心闭环优先、复杂代码 delegation、完成证据、checkpoint 和 workflow 路由七项常驻规则。

配置称呼：

```bash
"<plugin-root>/scripts/harness-identity.sh" set "royde"
```

也可以设置 `HARNESS_USER_NAME`。

### CC 破坏性操作 guard

CC 的 `PreToolUse` hook 只拦截不可逆或大爆炸半径的 Bash 操作，包括：

- cloud secret/resource delete；
- `terraform` / `tofu destroy`；
- namespace、PV/PVC、deployment、statefulset、secret 等高影响 `kubectl delete`；
- `alembic downgrade`、`DROP` 和 `TRUNCATE`；
- 针对 `/`、`~`、`$HOME` 等根路径的灾难性 `rm -rf`。

确实需要执行时，在命令中加入显式确认标记：

```bash
terraform destroy -auto-approve  #DESTRUCTIVE-OK
```

这两个 hooks 是宿主适配器，不属于共享 skill 协议。Codex 使用自身 sandbox、approval 和 `AGENTS.md` 规则。

### Trace Browser E2E

Codex 和 CC 都可调用 `e2e-browser`；CC 另有 `/e2e`。它通过本地 LaunchServer `127.0.0.1:19876` 复用 Trace Browser 的指纹 profile、登录状态和 CDP 端点。只有用户明确要求时才使用需要 IPC token 的 RPA。

### Cross Review

`cross-review` 是默认 review 路径，也是 `harness-workflow` 的唯一 review 门；需要 Standards + Spec 双轴审查时再显式调用 `code-review`。它自动选择不同模型的 Codex、CC 或 Gemini peer，只接收有具体失败场景的范围内发现，修复后最多复查一次。可用 `HARNESS_HOST=codex|cc` 覆盖宿主探测。

## 目录

```text
plugins/fast-harness/
  .claude-plugin/plugin.json
  .codex-plugin/plugin.json
  hooks/
    hooks.json
    destructive_guard.sh
    session-rules.sh
  commands/
    fast-harness-full.md
    fast-harness-quick.md
    harness.md
    e2e.md
    cross-review.md
    review.md
  skills/
    fast-harness-full/SKILL.md
    fast-harness-quick/SKILL.md
    harness-workflow/SKILL.md
    checkpoint-commits/SKILL.md
    e2e-browser/SKILL.md
    cross-review/SKILL.md
  scripts/
    harness-identity.sh
    resolve-matt-skill.sh
    review-context.sh
    harness-review-peer.sh
```

## 0.2 迁移

`0.2.0` 是破坏性精简版本。迁移细节和旧入口映射见 [`docs/migration-0.2.md`](docs/migration-0.2.md)。

## License

MIT © ch-royde
