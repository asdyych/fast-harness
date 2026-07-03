# 任务清单：loop-engineering-support

- [x] 与用户确认第一阶段规划范围。
- [x] 创建 `loop-engineering-support` SDD scaffold。
- [x] 起草 spec、design、tasks 和执行 checkpoints。
- [x] 根据用户要求将 SDD 规划文档改为中文。
- [x] 将 SDD 模板语言配置纳入本次设计范围。
- [x] 将 `/loop-*` 细粒度命令和 `/fast-harness-loop` 自动化总入口纳入设计范围。
- [x] 根据复核补充配置 gitignore 策略、事件日志、agent/script 边界和 `--yes` 硬边界。
- [x] 根据开发期 v1 范围，移除成本/token 预算刹车，保留轮数和无进展停止条件。
- [x] 请用户评审规划草案，然后再进入实现。
- [x] 增加 loop-aware SDD scaffolding：`state.md`、`learnings.md` 和 manifest loop 默认值。
- [x] 增加 SDD 模板语言配置：默认英文，支持 `zh-CN` 中文模板。
- [x] 调整 `.gitignore`，允许 `.harness/config.json` 被提交，同时继续忽略任务执行状态。
- [x] 增加隐私安全 loop event log。
- [x] 增加确定性 loop status/tick/stop/resume 脚本和 smoke test。
- [x] 增加 `loop` skill、`/loop-*` command 和 `/fast-harness-loop` 文档，并明确 worktree/sub-agent/plugin 组装规则。
- [x] 实现本地 review-loop session ledger 和 summary generation。
- [x] 更新 README、`sdd` skill 和仓库级 smoke verification。
- [x] 运行最终验证和 review-loop 后再 finish。
