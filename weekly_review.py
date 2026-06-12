#!/usr/bin/env python3
import os
import subprocess
import sys
import time
from pathlib import Path


def _no_traceback_on_interrupt(exctype, value, tb):
    if exctype is KeyboardInterrupt:
        print("\nInterrupted.", file=sys.stderr)
    else:
        sys.__excepthook__(exctype, value, tb)

sys.excepthook = _no_traceback_on_interrupt

HERE = Path(__file__).resolve().parent
TODO_ROOT = HERE.parent

def run_lf(prompt_msg, path, extra_cmds=""):
    cmd = f'set promptfmt "{prompt_msg} \\033[34;1m%d\\033[0m\\033[1m%f\\033[0m"'
    args = ["lf", "-command", cmd]
    if extra_cmds:
        for c in extra_cmds.split(";"):
            args.extend(["-command", c.strip()])
    args.append(str(path))
    subprocess.run(args)

def run_lf_select(prompt_msg, path, extra_cmds=""):
    cmd = f'set promptfmt "{prompt_msg} \\033[34;1m%d\\033[0m\\033[1m%f\\033[0m"'
    args = ["lf", "-print-selection", "-command", cmd, "-command", "map q"]
    if extra_cmds:
        for c in extra_cmds.split(";"):
            args.extend(["-command", c.strip()])
    args.append(str(path))
    result = subprocess.run(args, capture_output=True, text=True)
    return [Path(p).name for p in result.stdout.strip().split("\n") if p]

def indent(text, spaces=4):
    return "\n".join(" " * spaces + line for line in text.split("\n"))

# 0. Preliminary Logistics
print("0. Preliminary Logistics")
print("i. Walk around the house & Identify what draws your attention. Fix what can be fixed in <=10m ; otherwise, Gather thoughts & things for further processing.")
time.sleep(3)
input("\tPress ENTER when done.")

print("ii. Translate any left-over iPhone todo reminders, recurring thoughts, unread messages, hand-written notes, etc, into inputs for todo system.")
time.sleep(3)
run_lf("Press T to create a taskdir for any left-over iPhone todos, recurring thoughts, unread messages, hand-written notes, etc.", Path.home() / "main/todo")

print("iii. Update the timestamp for any people under ../relationships/* interacted with this week.")
time.sleep(3)
run_lf("Press t to mark anyone you interacted with this week.", Path.home() / "main/relationship", "set sortby time;set info time;set reverse")

print("iv. Schedule a meet-up with someone from your relationship view.")
time.sleep(3)
subprocess.run([str(HERE / "schedule_meetup_from_relationship")])

print("v. Mark tasks under ../todo/wait/* as no longer waiting if applicable.")
time.sleep(3)
run_lf("Press x to mark tasks as no longer waiting if applicable & Write follow-up documentation.", Path.home() / "main/todo/wait")
print()

# 1. Post-Mortem of Goals
print("1. Post-Mortem of Goals")
print("i. Review time estimations for the past week.")
time.sleep(3)
print("Incomplete tasks:")
time.sleep(1)

incomplete_dirs = []
for cat in ["0_now", "1_today", "2_week"]:
    cat_path = TODO_ROOT / cat
    if cat_path.exists():
        incomplete_dirs.extend([d for d in cat_path.iterdir() if d.is_dir()])

for t in incomplete_dirs:
    print(indent(t.name))
    colon_files = list(t.glob(":*"))
    for f in sorted(colon_files):
        print(indent(f.name, 8))
    print()

time.sleep(1)
print("Completed tasks + estimation summary:")
time.sleep(1)
print(indent("", 4), end="")
subprocess.run([str(HERE / "summarize_past_time_estimations"), "8"])
print()
time.sleep(1)

print("Write 2 sentence summary-- How was the overall accuracy? Were there any patterns in the misestimations?")
postmortem_of_time = input("    2 SENTENCES> ")
print(postmortem_of_time)

print("ii. Write 2 sentences analyzing why progress was good/mediocre/bad towards particular goals.")
postmortem_of_progress = input("    2 SENTENCES> ")
print(postmortem_of_progress)

print("iii. Write 1-3 sentence list of insights to keep in mind this week, so as to improve our efforts.")
insights_on_goals = input("    3 SENTENCES> ")
print(insights_on_goals)
print()

# 2. Post-Mortem of Habits
print("2. Post-Mortem of Habits")
print("i. Look at the chart of explicitly tracked habits. Write 1-2 sentences describing what you see.")
postmortem_of_tracked_habits = input("    2 SENTENCES> ")
print(postmortem_of_tracked_habits)

print("ii. Review list of all habits. Identify those having difficulty with compliance.")
time.sleep(3)
habits_needing_attention = run_lf_select(
    "Mark habits struggling with compliance, Press Enter to confirm selection.",
    Path.home() / "main/habit"
)
print("Habits -- those needing attention:")
print(indent("\n".join(habits_needing_attention)))
time.sleep(1)

print("iii. Write 2 sentences evaluating the results, trying to explain what caused them.")
postmortem_of_difficult_habits = input("    2 SENTENCES> ")
print(postmortem_of_difficult_habits)

print("iv. Write 1-3 sentence list of actions to resolve the encountered difficulties with compliance.")
actions_to_improve_habit_compliance = input("    3 SENTENCES> ")
print(actions_to_improve_habit_compliance)
print()

# 3. Post-Mortem of Agreements
print("3. Post-Mortem of Agreements")
print("i. Recall for 3m: How well did I adhere to my agreements this week?")
subprocess.run(["timer", "-m", "3"])

print("ii. Read aloud from the Constitution's articles: ONLY the numbered lines")
time.sleep(3)
constitution = Path.home() / "main/agreements/A1:Constitution_for_the_Sovereignty_of_Alexander"
with open(constitution) as f:
    numbered_lines = [line for line in f if line.strip() and line.lstrip()[0].isdigit() and "." in line.split()[0]]
subprocess.run(["less"], input="".join(numbered_lines), text=True)

print("iii. Skim the rest of my agreements, relating them to my recent efforts.")
time.sleep(3)
agreements_for_further_focus = run_lf_select(
    "Skim your agreements, considering how they relate to my efforts. Mark any A3s to review for upgrade/revision, or any others for further focus, Press ENTER to confirm selection.",
    Path.home() / "main/agreements"
)
print("Agreements -- for further focus:")
print(indent("\n".join(agreements_for_further_focus)))
time.sleep(1)

print("iv. Write 3 sentences evaluating my compliance.")
postmortem_of_agreement_compliance = input("    3 SENTENCES> ")
print(postmortem_of_agreement_compliance)

print("v. Write list of 1-3 actions to take in light of the evaluation, so as to curate & adhere to realistic & just agreements.")
actions_to_improve_agreement_compliance = input("    3 SENTENCES> ")
print(actions_to_improve_agreement_compliance)
print()

# OKR Weekly Check
print("OKR Weekly Check")
result = subprocess.run([str(HERE / "okr_check")])
if result.returncode != 0:
    print("(okr_check skipped or no OKRs found)")
print()

# 4. Time-estimation of Allocatable Work
QUOTA_DAILY_WORK_HOURS = 1.5
DAYS_IN_WORK_WEEK = 6

prev_week_file = TODO_ROOT / "2_week/.time_allocation"
month_file = TODO_ROOT / "3_month/.time_allocation"
prev_week_work_hrs_quota = prev_week_file.read_text().strip() if prev_week_file.exists() else str(QUOTA_DAILY_WORK_HOURS * DAYS_IN_WORK_WEEK)
month_work_hrs_quota = float(month_file.read_text().strip()) if month_file.exists() else 0

print("4. Time-estimation of Allocatable Work")
subprocess.run(["cal", "-m"])

daily_work_quota = input(f"    Minimum hours of personal work per day [{QUOTA_DAILY_WORK_HOURS}]> ") or str(QUOTA_DAILY_WORK_HOURS)
daily_work_quota = float(daily_work_quota)

work_days = input(f"    Days in work week (excluding today) [{DAYS_IN_WORK_WEEK}]> ") or str(DAYS_IN_WORK_WEEK)
work_days = int(work_days)

estimated_work_hours = round(daily_work_quota * work_days, 2)
print(f"    Estimated work hours: {estimated_work_hours}")
prev_week_file.write_text(str(estimated_work_hours))
time.sleep(1)
print()

hours_worked_last_week = input(f"    Hours to subtract from remaining monthly allocation ({month_work_hrs_quota}h) [{prev_week_work_hrs_quota}]> ") or prev_week_work_hrs_quota
hours_worked_last_week = float(hours_worked_last_week)
month_work_hrs_quota = round(month_work_hrs_quota - hours_worked_last_week, 2)
print(f"    Remaining work hours in month: {month_work_hrs_quota}")
month_file.write_text(str(month_work_hrs_quota))
time.sleep(1)
print()

# 5. Review of Domains
print("5. Review of Domains")
print("i. Skim the domains-of-concern, identify those relevant to planning for this week.")
time.sleep(3)
relevant_domains_of_concern = run_lf_select(
    "Mark domains relevant to planning for this week, Press Enter to confirm selection.",
    TODO_ROOT / "#domain"
)
print("Domains of Concern -- the weekly plan must account for:")
print(indent("\n".join(relevant_domains_of_concern)))
time.sleep(1)
print()
