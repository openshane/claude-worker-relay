---
name: codex-worker
description: Delegate an implementation or investigation to the local Codex CLI and retrieve its answer. Use when the user requests Codex work, or wants to continue an existing Codex worker session.
---

Give Codex a working directory that you do not edit while it runs. For a task that may change files, record `git rev-parse HEAD` and `git status --short` in the project the user designated (the current project by default), then create a separate worktree from that commit:

```bash
git worktree add -b codex/<topic> "../<repo>-codex-<topic>" HEAD
```

Uncommitted changes in the project do not reach the new worktree; if the task depends on them, ask the user how to carry them over. An investigation may run in the project itself: tell Codex which files or behavior to inspect and to leave the files unchanged, and compare `git status --short` afterwards.

Include the requested outcome, scope of permitted changes and verification criteria in the prompt. The worker can write only inside its directory. The script ignores the user's Codex configuration, so set `CODEX_WORKER_MODEL` or `CODEX_WORKER_EFFORT` (default `xhigh`) in the command when the user asks for a particular model or effort.

Start the script with the Bash tool's `run_in_background` set to true, because Codex tasks often outlast the foreground timeout. Use a single-quoted heredoc delimiter that does not occur in the prompt so that the shell preserves its contents.

```bash
bash "${CLAUDE_SKILL_DIR}/../../scripts/codex-worker" "../<repo>-codex-<topic>" - <<'WORKER_TASK'
Put the task here.
WORKER_TASK
```

When the task finishes, read `reply` and retain `session_id` from the JSON on stdout. As soon as the session starts, the script also writes `codex: session_id <id>` to stderr, so a run that failed or was stopped can still be continued. For a follow-up, insert `--resume "<session_id>"` before the directory and use the same directory. Surface a nonzero exit and its error.

Then review the diff in the worktree and run the verification yourself before reporting the result. Merging the branch and removing the worktree are the user's decisions.
