#!/bin/bash
# tmux-relayout.sh — standalone relayout trigger
# Invoked by tmux's pane-exited hook (set in dash_ensure_session).
source "$HOME/.claude/hooks/tmux-helpers.sh"
dash_relayout
