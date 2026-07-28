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
  -> 逐 ticket implement + checkpoint commit/push
  -> cross-review
  -> 相关验证 + 最终 commit/push
```

直接调用 `/fast-harness-quick <目标>`，或说“快速实现”、`quick implement` 时，跳过 spec 和 tickets：

```text
明确目标
  -> implement + checkpoint commit/push
  -> cross-review
  -> 相关验证 + 最终 commit/push
```

完整路线适合 grill 后进入 Goal 的多阶段任务；快速路线适合目标清楚、能在单个上下文完成的改动。两条路线都只执行一次不同模型的 `cross-review`，不再叠加普通 `code-review`。需要 Matt 的 Standards + Spec 双轴审查时仍可显式调用 `code-review`。wrapper 在每个阶段读取已安装的 Matt `SKILL.md`，所以上游流程升级后无需在 fast-harness 复制更新。

两条路线都先证明最小可用的端到端闭环，再考虑边界加固。只有明确验收要求、已复现缺陷、正常输入可达、阻塞核心流程或存在可信安全/数据损坏风险的边界情况才进入当前范围。每个行为切片优先保留一个代表性成功路径测试；失败路径只覆盖明确行为、真实分支或回归。验收检查和直接受影响的既有测试通过后即停止扩展，不默认补齐理论输入组合、穷举矩阵、全仓测试或无具体失败场景的防御性处理。

`/fast-harness-full` 和 `/fast-harness-quick` 是固定模式入口：命令后的全部文本都视为目标，即使目标中出现 `quick` 或 `full` 也不会改变路线。原 `/harness full|quick` 继续作为兼容入口。

Matt 的 `implement` 上游只要求完成后提交，没有定义长任务的中间提交策略。fast-harness 通过共享 `checkpoint-commits` skill 和 CC SessionStart rule 补充以下契约：实现与修 bug 默认授权在当前分支创建本地提交；每完成一个可独立理解、已通过相关检查的行为切片就提交一次，不把大段已验证 diff 留到任务末尾。进入 `harness-workflow` 后，每个 checkpoint 都立即普通 push 到当前分支。用户或仓库明确要求不提交或不 push 时，以该要求为准。

提交前必须检查工作树，只暂存当前任务的文件或 hunks，不得卷入用户已有改动。每个 commit 应可构建、可回退，消息描述已建立的行为或约束，不使用 `WIP`。小型单步任务可以只做一个最终 commit；大任务按行为边界分批，而不是按行数或时间机械切分。

自动 push 授权只在用户触发 `harness-workflow` 后生效；普通零散任务仍需明确授权才 push。创建 PR、`amend`、`rebase`、`squash`、`reset`、force-push 和其他历史改写始终需要用户明确授权。普通 push 失败时保留本地 commit 并记录待推送 SHA，绝不通过 force-push 或自动改写历史解决。

## 保留能力

### CC 会话规则

CC 的 `SessionStart` hook 在 startup、clear 和 compact 后注入六条规则：

1. 每次回复以已配置的用户名开头，作为上下文漂移信号。
2. 复杂或多步骤任务先复述目标、范围和交付物，等待确认后再执行；已识别的 harness workflow 触发短语本身视为路线确认，不重复询问。
3. 核心闭环验证优先；不实现或测试投机性边界，验收与直接受影响测试通过后停止扩展。
4. 没有当前变更的新鲜命令输出，不得宣称修复、测试通过或完成。
5. 实现任务按已验证的行为切片创建本地 checkpoint commits；harness workflow 内自动普通 push，且始终禁止自动改写历史。
6. 识别完整流程与快速实现触发短语，并路由到 `harness-workflow`。

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

Codex 和 CC 都可调用 `e2e-browser`；CC 另有 `/e2e` 命令别名。该能力优先连接本地 Trace Browser LaunchServer：

```text
GET  http://127.0.0.1:19876/api/profiles
GET  http://127.0.0.1:19876/api/launch/<launchCode>
POST http://127.0.0.1:19876/api/launch
```

从 launch 响应读取 `debugPort` 或 `cdpUrl`，再通过 Playwright 或其他 CDP 工具驱动真实业务流程。技能复用 Trace Browser 管理的指纹 profile 和已登录 session，不再维护独立 Chrome profile 或 plaintext test-account store。

Trace Browser RPA 位于 `127.0.0.1:64606/trace/proto`，需要应用注入的 IPC token；只有用户显式要求 RPA 时才使用。

### Cross Review

Codex 和 CC 都可调用 `cross-review`；CC 另有 `/review` 和 `/cross-review` 命令别名。单独使用时，`cross-review` 是默认的 review 路径；需要 Matt 的 Standards + Spec 审查时再显式调用 `code-review`。进入 `harness-workflow` 后，`cross-review` 是唯一 review 门，不再重复运行 `code-review`。它不是另一套 review 工作流。

它会：

1. 使用 `review-context.sh` 一次收集 diff、base、文件列表和 peer 可用性。
2. 使用 `harness-review-peer.sh --peer auto` 调用不同模型的 Codex、CC 或 Gemini peer。
3. 同时检查目标、仓库规则或 spec 偏差，以及正确性、安全、数据丢失、并发和明确的范围膨胀；只接收有 `file:line`、严重级别和具体失败场景的实质发现，并排除无法通过核心闭环准入标准的理论边界与投机性加固。
4. 修复后最多复查一次，然后输出共识或未决项。

在 Codex 中，`auto` 优先选择 CC；在其他宿主中优先选择 Codex。自动探测不可用时可设置 `HARNESS_HOST=codex|cc`。这里的 `cc` 是公开宿主标签，脚本会通过版本信息识别真正的 CC CLI，不会把系统 C 编译器误当成 reviewer。Codex peer 使用 read-only sandbox，CC peer 使用 plan mode 且禁用工具。CLI 超时或无最终结果时，wrapper 会保留诊断日志，但不会在仓库中创建 review ledger。

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
