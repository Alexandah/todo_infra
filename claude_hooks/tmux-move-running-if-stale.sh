#!/bin/bash
# Hook: MessageDisplay
# Moves perms→running, but only if the pane has been in perms longer than
# GUARD_MS. Needed because MessageDisplay can fire for trailing/flushed text
# right after a fresh PermissionRequest in the same turn — moving unconditionally
# would clobber a permission prompt the user hasn't seen yet. A stale perms
# (from the old bug: stuck during plan-revision thinking with no tool-event
# hook firing) is safe to clear once past the guard window.
INPUT=$(cat)
[ -z "$CLAUDE_TMUX_MANAGED" ] && exit 0
[ -z "$TMUX_PANE" ] && exit 0
source "$(dirname "$0")/tmux-helpers.sh"

GUARD_MS=400

col=$(tmux show-options -p -t "$TMUX_PANE" -v @column 2>/dev/null)
[ "$col" != "perms" ] && exit 0

# Measure age BEFORE sleeping — sleeping first then measuring "now - ts"
# always yields age >= sleep duration, defeating the freshness check.
ts=$(tmux show-options -p -t "$TMUX_PANE" -v @column_ts 2>/dev/null)
now=$(date +%s%3N)
age=$(( now - ${ts:-0} ))
[ "$age" -lt "$GUARD_MS" ] && exit 0

# Stale already — re-verify it's stable (not mid-transition) before acting.
sleep 0.1
col=$(tmux show-options -p -t "$TMUX_PANE" -v @column 2>/dev/null)
[ "$col" != "perms" ] && exit 0

dash_move_task "$TMUX_PANE" running
