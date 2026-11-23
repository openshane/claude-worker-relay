---
name: codex-worker
description: Delegate an implementation or investigation to the local Codex CLI and retrieve its answer. Use when the user requests Codex work, or wants to continue an existing Codex worker session.
---

Choose the workspace the user designated for the task, using the current project by default. Include the requested outcome, scope of permitted changes and verification criteria in the prompt. The worker has workspace write access. For an investigation, tell it which files or behavior to inspect and to leave the files unchanged.

Run the installed script with Bash. Use a single-quoted heredoc delimiter that does not occur in the prompt so that the shell preserves its contents.

```bash
bash "${CLAUDE_SKILL_DIR}/../../scripts/codex-worker" "." - <<'WORKER_TASK'
Put the task here.
WORKER_TASK
```

For a follow-up, insert `--resume "<session_id>"` before the directory and use the same workspace. Read `reply` and retain `session_id` from the successful JSON output. Run in the foreground by default. If the user requests background work, set the Bash tool's `run_in_background` to true and retrieve its result when the task finishes. Surface a nonzero exit and its error.
