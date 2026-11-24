# Claude Worker Relay

在 Claude Code 中向 Gemini 征求第二意见，或把一个范围明确的任务交给 Codex。两个入口都返回本轮回复和会话 ID，方便在同一个工作目录继续追问。

## 安装

在 Claude 桌面版打开 **Code → Local** 会话，在 **Customize → Plugins → Add marketplace** 中添加 `openshane/claude-worker-relay`，选择 **worker-relay** 安装，并新开一个本地 Code 会话。

Claude Code 终端版可依次执行以下命令：

```text
/plugin marketplace add openshane/claude-worker-relay
/plugin install worker-relay@claude-worker-relay
/reload-plugins
```

运行环境需要 Bash 和 Node.js 18 或以上。Windows 使用 Git Bash。使用哪个入口，就安装并登录对应的 CLI：

- **Gemini** 使用 Google Antigravity CLI（`agy`）。先运行 `agy` 登录并选择可用的 Gemini 模型。插件用规划模式启动它，并在任务前加上固定说明：不得修改文件，按固定小节作答。加 `--copy` 时，改为按文案和交互评审的格式作答。规划模式在无界面运行时拦不住写文件（[antigravity-cli#1181](https://github.com/google-antigravity/antigravity-cli/issues/1181)），agy 也没有只读开关。因此，在 Git 工作目录中，脚本会比较调用前后的工作区：Gemini 改动了文件时，返回退出码 3，并在 stderr 列出改动的路径，回复仍在 stdout。这只能事后发现改动，不能阻止，也不覆盖被 `.gitignore` 忽略的文件和工作目录之外的文件。
- **Codex** 使用 OpenAI Codex CLI（`codex`）。通过 `codex login` 登录，在 Git 工作目录中使用。插件启用 `workspace-write` 沙箱并关闭交互式提权，调查任务可在指令里明确要求只分析。MCP 服务器、插件、钩子和 ChatGPT 账号连接的应用都不受 shell 沙箱约束，所以插件不加载 `~/.codex/config.toml`，同时关闭 `apps`、`plugins` 和 `remote_plugin` 这三个 feature。推理强度默认为 `xhigh`，模型使用 Codex 默认值，可分别用环境变量 `CODEX_WORKER_EFFORT` 和 `CODEX_WORKER_MODEL` 指定。在 Windows 上，插件使用 `elevated` 沙箱，需要先在 Codex 中完成该沙箱的设置。

委派时，任务和所选工作目录内被读取的相关代码会由对应 CLI 在你的账号下处理。Gemini 的模型和用量设置沿用本地 CLI。

## 在 Claude 中使用

```text
/worker-relay:agy-ask 查看当前项目的重试逻辑，指出缺少测试的分支。
/worker-relay:codex-worker 修复导入器遇到空行时报错的问题，只修改导入器和对应测试。
```

需要接着问时，可以告诉 Claude “沿用刚才的 Gemini 会话，指出对应的测试文件”。Bash 的任务 ID 用于取回本次输出，提供方的 `session_id` 用于续接对话。

- Gemini 默认在前台等待，要求后台运行时，Claude 使用 Bash 的后台任务功能。
- Codex 任务常常超过 Bash 前台超时，因此默认在后台运行。会改动文件的任务，Claude 会先用 `git worktree add` 从当前提交建一个独立工作树，交给 Codex 在其中修改，避免两边同时改同一份代码。Codex 返回后，Claude 检查该工作树的差异并运行验证。合并分支和删除工作树由你决定。

## 单独运行脚本

下载本仓库后，在仓库根目录使用 Git Bash。把示例中的路径替换成目标项目的 Git 工作目录：

```bash
bash plugins/worker-relay/scripts/agy-ask "/path/to/project" "检查边界条件"
bash plugins/worker-relay/scripts/agy-ask --copy "/path/to/project" "评审登录页的文案和交互"
bash plugins/worker-relay/scripts/codex-worker "/path/to/project" "列出需要更新的测试"
bash plugins/worker-relay/scripts/codex-worker --resume "<session_id>" "/path/to/project" "解释第一条建议"
```

成功时 stdout 返回一行 JSON，例如：

```json
{"session_id":"01234567-1234-4321-abcd-0123456789ab","reply":"本轮回答"}
```

错误写入 stderr 并返回非零退出码。CLI 输出中夹杂的非 JSON 行会被跳过，并在 stderr 中注明。Codex 会话一开始，脚本就向 stderr 写入 `codex: session_id <id>`，因此即使运行中断，也能用 `--resume` 续接。多行任务可用 `-` 替代最后一个参数，从 stdin 传入。

## 验证

```bash
bash plugins/worker-relay/scripts/test/test_delegate.sh
```

离线测试覆盖两种 CLI 的首次调用、用大写 ID 续接、非 JSON 输出行、回复中断、服务失败和非零退出，以及 Gemini 的 `--copy` 模式和改动文件检测。Codex 已在 Windows 上通过真实账号验证两轮对话和沙箱。Gemini 的输入输出格式已与官方 headless 文档核对，但尚未用真实的 `agy` 运行过。
