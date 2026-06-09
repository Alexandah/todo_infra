# todo_infra

Infrastructure for a filesystem-based personal todo system rooted at
`~/main/todo/`. Tasks are directories ("taskdirs"); category folders
(`0_now/`, `1_today/`, `2_week/`, …) hold them; metadata is encoded in
filenames (`::Goal.hmm`, `:by_F`, `:time=2h`). This repo (`.infra/`) holds the
scripts and config that drive it.

This is also the single home for the **tmux-Claude manager** — the setup that
launches Claude Code agents into a live tmux dashboard, one pane per task.

## Layout

### Task-system tooling
- `make_taskdir`, `instantiate_taskdir_template`, `taskdir_template/` — create tasks
- `mark`, `process_inbox` — move tasks between categories / triage the inbox
- `log_time`, `summarize_past_time_estimations` — time tracking
- `make_okr`, `okr_*`, `link_to_okr` — OKR tracking
- `weekly_review`, `weekly_review.py` — review workflow
- `bash_utils` — shared helpers

### tmux-Claude manager
- `claude_hooks/` — hook scripts driving the tmux dashboard (panes move between
  running / awaiting-perms / done columns as a session changes state). Canonical
  copies; symlinked to `~/.claude/hooks/` where `settings.json` references them.
  See `claude_hooks/README.md`.
- `taskdir_tmux_launch`, `claude_task`, `_claude.do` — launch a Claude session
  into the dashboard for a given taskdir (with goal/deadline/time context)
- `claude_auto_daemon` — watches category dirs for `;claude_plz_do_this` signal
  files and auto-launches tasks
- `configure_automation` — interactive wizard to configure a taskdir's
  `_claude.do` (model, effort, plan/permission mode)
- `_view_claude_dash.do` — attach to the `claude-dash` tmux session
- `tmux.conf` — tmux config; symlinked to `~/.tmux.conf`

### Claude project config (loaded when a taskdir launches Claude)
- `CLAUDE.todo.md` — shared todo-system instructions; symlinked to
  `~/main/todo/CLAUDE.md` (auto-loaded by Claude's dir-hierarchy walk)
- `claude_skills/` — project skills (`validate-task`,
  `define-acceptance-and-validation-criteria`); symlinked to
  `~/main/todo/.claude/skills`

## Symlink / install model

Several pieces must live *outside* this repo to be found by Claude Code / tmux
(`~/.claude/hooks/`, `~/.tmux.conf`, `~/main/todo/CLAUDE.md`,
`~/main/todo/.claude/skills`). They are kept canonical here and symlinked into
place by:

```sh
make install     # create/repair all symlinks (idempotent; backs up reals to *.bak)
make uninstall   # remove the symlinks this repo created
```

Edit the **repo copy** (the symlink target), not the deployed path.

## Machine-specific layer

`~/main/todo/CLAUDE.local.md` (auto-loaded beside the tracked `CLAUDE.md`, not
version controlled) holds machine-specific content — e.g. which cross-system
personal-org areas exist on this box. Absent on a machine = silently fine.

## New machine

```sh
git clone git@github.com:Alexandah/todo_infra.git ~/main/todo/.infra
cd ~/main/todo/.infra && make install
```

Then create `~/main/todo/CLAUDE.local.md` if this machine has machine-specific
areas. (Global Claude config is a separate repo:
[`claude-config`](https://github.com/Alexandah/claude-config).)
