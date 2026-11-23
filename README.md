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

- **Gemini** 使用 Google Antigravity CLI（`agy`）。先运行 `agy` 登录并选择可用的 Gemini 模型。插件用规划模式启动它。
- **Codex** 使用 OpenAI Codex CLI（`codex`）。通过 `codex login` 登录，在受信任的 Git 工作目录中使用。插件启用 `workspace-write` 沙箱并关闭交互式提权，调查任务可在指令里明确要求只分析。

委派时，任务和所选工作目录内被读取的相关代码会由对应 CLI 在你的账号下处理。模型和用量设置沿用本地 CLI。

## 在 Claude 中使用

```text
/worker-relay:agy-ask 查看当前项目的重试逻辑，指出缺少测试的分支。
/worker-relay:codex-worker 修复导入器遇到空行时报错的问题，只修改导入器和对应测试。
```

需要接着问时，可以告诉 Claude “沿用刚才的 Gemini 会话，指出对应的测试文件”。默认前台等待。要求后台运行时，Claude 使用 Bash 的后台任务功能。Bash 的任务 ID 用于取回本次输出，提供方的 `session_id` 用于续接对话。

## 单独运行脚本

下载本仓库后，在仓库根目录使用 Git Bash。把示例中的路径替换成目标项目的 Git 工作目录：

```bash
bash plugins/worker-relay/scripts/agy-ask "/path/to/project" "检查边界条件"
bash plugins/worker-relay/scripts/codex-worker "/path/to/project" "列出需要更新的测试"
bash plugins/worker-relay/scripts/codex-worker --resume "<session_id>" "/path/to/project" "解释第一条建议"
```

成功时 stdout 返回一行 JSON，例如：

```json
{"session_id":"01234567-1234-4321-abcd-0123456789ab","reply":"本轮回答"}
```

错误写入 stderr 并返回非零退出码。多行任务可用 `-` 替代最后一个参数，从 stdin 传入。

## 验证

```bash
bash plugins/worker-relay/scripts/test/test_delegate.sh
```

离线测试覆盖两种 CLI 的首次调用、按 ID 续接、回复中断、服务失败和非零退出。Codex 已在 Windows 上通过真实账号验证两轮对话。Gemini 当前的验证范围是模拟 CLI 协议。
