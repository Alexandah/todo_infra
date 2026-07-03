#!/bin/bash
# tmux-zen-toggle.sh — toggle Zen view mode on the claude-dash session.
# Bind via: bind z run-shell "bash ~/.claude/hooks/tmux-zen-toggle.sh"
source "$(dirname "$0")/tmux-helpers.sh"

# Guard: do nothing if the dash session doesn't exist.
tmux has-session -t "$CLAUDE_DASH_SESSION" 2>/dev/null || exit 0

# Serialize the toggle with a non-blocking flock on a DEDICATED lockfile.
# We use fd 8 (not fd 9) to avoid colliding with dash_zen_render/dash_relayout,
# which flock CLAUDE_DASH_LOCKFILE on fd 9 within the same process.
# A second rapid press that can't acquire the lock exits silently (no-op).
_ZEN_TOGGLE_LOCK=/tmp/claude-dash-zen-toggle.lock
(
    flock -n 8 || exit 0

    view=$(tmux show-options -t "$CLAUDE_DASH_SESSION" -v @view 2>/dev/null || true)

    if [ "$view" != "zen" ]; then
        # --- ENTER ZEN ---
        # Create the placeholder pane FIRST, BEFORE touching @view or any option.
        # Split off the TALLEST pane so the split can't fail on a 2-row header
        # (relayout shrinks headers to 2 rows, which have no room to split).
        src=$(tmux list-panes -t "$CLAUDE_DASH_SESSION:$CLAUDE_DASH_WINDOW" \
            -F '#{pane_height} #{pane_id}' 2>/dev/null | sort -rn | head -1 | awk '{print $2}')
        placeholder=$(tmux split-window \
            -t "${src:-$CLAUDE_DASH_SESSION:$CLAUDE_DASH_WINDOW}" \
            -d -P -F '#{pane_id}' \
            "printf '\033[7m  ZEN \xe2\x80\x94 nothing needs you right now  \033[0m\n'; sleep infinity" 2>/dev/null)

        # CRITICAL: if the split failed, $placeholder is empty. The set-option -p
        # calls below would then run with `-t ""`, which tmux silently retargets
        # to the ACTIVE pane (a column header) — stamping @column zen onto it and
        # permanently breaking move-to-running. Bail with no side effects instead.
        if [ -z "$placeholder" ]; then
            exit 0
        fi

        tmux set-option -t "$CLAUDE_DASH_SESSION" @view zen
        tmux set-option -p -t "$placeholder" remain-on-exit on
        tmux set-option -p -t "$placeholder" @column zen
        tmux set-option -p -t "$placeholder" @zen_placeholder 1
        tmux set-option -t "$CLAUDE_DASH_SESSION" @zen_placeholder_pane "$placeholder"

        # Reconcile stacks from live pane state before render (self-healing:
        # catches panes that transitioned before stack-tracking was installed).
        _dash_zen_seed_stacks

        dash_zen_render
    else
        # --- EXIT ZEN ---
        tmux set-option -t "$CLAUDE_DASH_SESSION" @view normal
        tmux set-option -u -t "$CLAUDE_DASH_SESSION" @zen_main 2>/dev/null || true

        # Unzoom if window is currently zoomed.
        target="$CLAUDE_DASH_SESSION:$CLAUDE_DASH_WINDOW"
        zoomed=$(tmux display-message -t "$target" -p '#{window_zoomed_flag}' 2>/dev/null)
        [ "$zoomed" = "1" ] && tmux resize-pane -Z -t "$target" 2>/dev/null

        # Kill the placeholder pane if it still exists.
        placeholder=$(tmux show-options -t "$CLAUDE_DASH_SESSION" -v @zen_placeholder_pane 2>/dev/null || true)
        if [ -n "$placeholder" ]; then
            live=$(tmux list-panes -s -t "$CLAUDE_DASH_SESSION" -F '#{pane_id}' 2>/dev/null || true)
            if printf '%s\n' "$live" | grep -Fxq "$placeholder"; then
                tmux kill-pane -t "$placeholder" 2>/dev/null || true
            fi
            tmux set-option -u -t "$CLAUDE_DASH_SESSION" @zen_placeholder_pane 2>/dev/null || true
        fi

        dash_relayout
    fi
) 8>"$_ZEN_TOGGLE_LOCK"
