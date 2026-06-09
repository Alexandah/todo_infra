# claude_hooks — TMUX-Claude manager hook scripts

These are the hook scripts for the tmux-Claude session dashboard. They are the
**canonical** copies; `~/.claude/hooks/*.sh` are symlinks into this directory
(created by `make install` at the repo root).

`~/.claude/settings.json` wires them by absolute path, e.g.:

```
"command": "bash $HOME/.claude/hooks/tmux-save-session-id.sh"
```

so the symlinks must exist at `~/.claude/hooks/` for the hooks to fire.

| script | hook event | role |
|--------|-----------|------|
| `tmux-save-session-id.sh` | UserPromptSubmit | save session id to taskdir `.last_session_id` |
| `tmux-move-perms.sh` | PermissionRequest | move pane to "perms" column |
| `tmux-move-running.sh` | PostToolUse / PermissionDenied | move pane to "running" column |
| `tmux-move-done.sh` | Stop | move pane to "done" column |
| `tmux-relayout.sh` | (called by tmux hooks) | rebalance the three columns |
| `tmux-helpers.sh` | (library) | shared dashboard pane-management functions |

## Install / restore symlinks

From the repo root:

```
make install
```

Idempotent — safe to re-run. Backs up any pre-existing real file to `*.bak`.
