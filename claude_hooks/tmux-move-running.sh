#!/bin/bash
# Hook: PostToolUse, PermissionDenied
# Moves the current pane to the running column from any other column.
# Handles both perms→running and done→running (user restarts a finished Claude).
INPUT=$(cat)
[ -z "$CLAUDE_TMUX_MANAGED" ] && exit 0
[ -z "$TMUX_PANE" ] && exit 0
source "$(dirname "$0")/tmux-helpers.sh"
dash_move_task "$TMUX_PANE" running
