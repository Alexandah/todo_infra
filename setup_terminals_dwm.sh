#!/bin/bash

WORK_TIME_HRS=1
WORK_TIME_MIN=35
START_OF_WORK_TIME_BLOCK_MIN=15

ENCOURAGING_MESSAGE="***Please work for ${START_OF_WORK_TIME_BLOCK_MIN} minutes, even if you are tired or feel pressed for time. This maintains the habit & makes consistent progress. You always feel satisfied and proud of yourself when you do this. You deserve this happiness.***"
/home/erandalex/main/dev/misc_sh/say "$ENCOURAGING_MESSAGE" &
PRIORITIES_FILE=/home/erandalex/main/todo/:PRIORITIES_JULY_2026
YEARLY_STRATEGY_FILE=/home/erandalex/main/todo/STRATEGY_2026.hmm

SESSION="daily"

tmux new-session -d -s "$SESSION" -x "$(tput cols)" -y "$(tput lines)" "/home/erandalex/main/todo/.infra/begin_daily_workflow"
tmux split-window -t "$SESSION" -v -p 10 "echo '$ENCOURAGING_MESSAGE'; countdown -m $START_OF_WORK_TIME_BLOCK_MIN; countdown -hr $WORK_TIME_HRS -m $((WORK_TIME_MIN - START_OF_WORK_TIME_BLOCK_MIN))"
tmux select-pane -t "$SESSION:0.0"
tmux split-window -t "$SESSION" -v "cat $PRIORITIES_FILE; sleep infinity"
tmux split-window -t "$SESSION" -h "hmm $YEARLY_STRATEGY_FILE"
tmux select-pane -t "$SESSION:0.0"

$TERMINAL_COMMAND -e tmux attach-session -t "$SESSION"
