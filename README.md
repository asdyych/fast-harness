# fast-harness

`fast-harness` 是 `mattpocock/skills` 的轻量本地能力补充包，可在 Codex 和 CC（Claude Code）中使用，不再维护另一套规划、任务、实现或验证流程。

职责划分：

- `mattpocock/skills` 负责工程主流程：需求澄清、spec、tickets、TDD、实现、诊断和代码审查。
- `fast-harness` 的共享核心只保留 Trace Browser E2E 和跨模型第二意见。
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
| Trace Browser E2E | 调用 `e2e-browser` | `e2e-browser` 或 `/e2e` |
| 跨模型复核 | 调用 `cross-review` | `cross-review` 或 `/cross-review` |
| Session rules / destructive guard | 项目规则与宿主权限机制 | plugin hooks |

## 工程主流程

fast-harness 不改变 Matt skills 的流程：

```text
grill-with-docs
  -> to-spec
  -> to-tickets          # 多 session 工作
  -> implement           # 内部使用 tdd，最后调用 code-review
  -> 项目原生验证命令
  -> cross-review        # 重要变更按需
  -> e2e-browser         # UI、登录或真实数据路径按需
```

小任务可以从 `implement` 或 `tdd` 直接开始；疑难 bug 使用 `diagnosing-bugs`。流程选择不明确时运行 `ask-matt`。

Matt 的 `implement` 上游默认会创建 commit。如果你采用“只有用户显式要求才 commit”的约束，CC 安装 fast-harness 后由 SessionStart rule 注入；Codex 在项目 `AGENTS.md` 中声明同一规则。

## 保留能力

### CC 会话规则

CC 的 `SessionStart` hook 在 startup、clear 和 compact 后注入四条规则：

1. 每次回复以已配置的用户名开头，作为上下文漂移信号。
2. 复杂或多步骤任务先复述目标、范围和交付物，等待确认后再执行。
3. 没有当前变更的新鲜命令输出，不得宣称修复、测试通过或完成。
4. 只有用户显式要求时才创建或 amend commit。

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

Codex 和 CC 都可调用 `cross-review`；CC 另有 `/cross-review` 命令别名。它是 Matt `code-review` 之后的可选异模型第二意见，不是另一套 review 工作流。

它会：

1. 使用 `review-context.sh` 一次收集 diff、base、文件列表和 peer 可用性。
2. 使用 `harness-review-peer.sh --peer auto` 调用不同模型的 Codex、CC 或 Gemini peer。
3. 只接收有 `file:line`、严重级别和具体失败场景的实质发现。
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
    e2e.md
    cross-review.md
  skills/
    e2e-browser/SKILL.md
    cross-review/SKILL.md
  scripts/
    harness-identity.sh
    review-context.sh
    harness-review-peer.sh
```

## 0.2 迁移

`0.2.0` 是破坏性精简版本。迁移细节和旧入口映射见 [`docs/migration-0.2.md`](docs/migration-0.2.md)。

## License

MIT © ch-royde
