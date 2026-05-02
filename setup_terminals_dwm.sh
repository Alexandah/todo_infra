#!/bin/bash

WORK_TIME_HRS=1
WORK_TIME_MIN=35

SESSION="daily"

tmux new-session -d -s "$SESSION" -x "$(tput cols)" -y "$(tput lines)" "/home/erandalex/main/todo/.infra/begin_daily_workflow"
tmux split-window -t "$SESSION" -v -p 10 "countdown -hr $WORK_TIME_HRS -m $WORK_TIME_MIN"
tmux select-pane -t "$SESSION:0.0"

$TERMINAL_COMMAND -e tmux attach-session -t "$SESSION"
