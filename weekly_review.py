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

# Python owns the saved review file directly (no `tee` in the .do wrapper).
# This lets us capture typed answers into the file WITHOUT echoing them back
# to the terminal a second time, and keeps interactive TUI escape-garbage
# (lf/less/timer) out of the artifact.
_review_path = os.environ.get("WEEKLY_REVIEW_FILE")
_out = open(_review_path, "w") if _review_path else None

def tee_print(*args, **kwargs):
    """Print program output to the terminal AND the saved review file."""
    print(*args, **kwargs)
    if _out is not None:
        print(*args, file=_out, **kwargs)
        _out.flush()

def ask(prompt):
    """Prompt on the terminal (tty echoes the typed text once); record the
    answer into the saved review file only — no visible second print."""
    answer = input(prompt)
    if _out is not None:
        _out.write(f"{prompt}{answer}\n")
        _out.flush()
    return answer

def capture_actions():
    """Capture follow-up action items as todo-snippets, one per line.
    Blank line finishes. Each item -> `todo <item>` (creates new/<item>) and is
    recorded into the review artifact. Non-coercive: blank straight away = skip."""
    tee_print("    Capture follow-up actions as todo-snippets (one per line, blank to finish):")
    while True:
        item = input("    ACTION> ").strip()
        if not item:
            break
        subprocess.run([str(HERE / "todo"), item])
        if _out is not None:
            _out.write(f"    ACTION> {item}\n")
            _out.flush()

def run_lf(prompt_msg, path, extra_cmds=""):
    cmd = f'set promptfmt "{prompt_msg} \\033[34;1m%d\\033[0m\\033[1m%f\\033[0m"'
    args = ["lf", "-command", cmd, "-command", "set ratios 2:3"]
    if extra_cmds:
        for c in extra_cmds.split(";"):
            args.extend(["-command", c.strip()])
    args.append(str(path))
    subprocess.run(args)

def run_lf_select(prompt_msg, path, extra_cmds=""):
    cmd = f'set promptfmt "{prompt_msg} \\033[34;1m%d\\033[0m\\033[1m%f\\033[0m"'
    args = ["lf", "-print-selection", "-command", cmd, "-command", "map q", "-command", "set ratios 2:3"]
    if extra_cmds:
        for c in extra_cmds.split(";"):
            args.extend(["-command", c.strip()])
    args.append(str(path))
    result = subprocess.run(args, capture_output=True, text=True)
    return [Path(p).name for p in result.stdout.strip().split("\n") if p]

def indent(text, spaces=4):
    return "\n".join(" " * spaces + line for line in text.split("\n"))

# 0. Preliminary Logistics
tee_print("0. Preliminary Logistics")
tee_print("i. Walk around the house & Identify what draws your attention. Fix what can be fixed in <=10m ; otherwise, Gather thoughts & things for further processing.")
time.sleep(3)
subprocess.run(["timer", "-m", "10"])

tee_print("ii. Translate any left-over iPhone todo reminders, recurring thoughts, unread messages, hand-written notes, etc, into inputs for todo system.")
time.sleep(3)
run_lf("Press T to create a taskdir for any left-over iPhone todos, recurring thoughts, unread messages, hand-written notes, etc.", Path.home() / "main/todo/new")

tee_print("iii. Update the timestamp for any people under ../relationships/* interacted with this week.")
time.sleep(3)
run_lf("Press t to mark anyone you interacted with this week.", Path.home() / "main/relationship", "set sortby time;set info time;set reverse")

tee_print("iv. Schedule a meet-up with someone from your relationship view.")
time.sleep(3)
subprocess.run([str(HERE / "schedule_meetup_from_relationship")])

tee_print("v. Mark tasks under ../todo/wait/* as no longer waiting if applicable.")
time.sleep(3)
run_lf("Press x to mark tasks as no longer waiting if applicable & Write follow-up documentation.", Path.home() / "main/todo/wait")
tee_print()

# 1. Post-Mortem of Goals
tee_print("1. Post-Mortem of Goals")
tee_print("i. Review time estimations for the past week.")
time.sleep(3)
tee_print("Incomplete tasks:")
time.sleep(1)

incomplete_dirs = []
for cat in ["0_now", "1_today", "2_week"]:
    cat_path = TODO_ROOT / cat
    if cat_path.exists():
        incomplete_dirs.extend([d for d in cat_path.iterdir() if d.is_dir()])

for t in incomplete_dirs:
    tee_print(indent(t.name))
    colon_files = list(t.glob(":*"))
    for f in sorted(colon_files):
        tee_print(indent(f.name, 8))
    tee_print()

time.sleep(1)
tee_print("Completed tasks + estimation summary:")
time.sleep(1)
_summary = subprocess.run([str(HERE / "summarize_past_time_estimations"), "8"], capture_output=True, text=True)
tee_print(indent(_summary.stdout.rstrip("\n"), 4))
tee_print()
time.sleep(1)

tee_print("Write 2 sentence summary-- How was the overall accuracy? Were there any patterns in the misestimations?")
postmortem_of_time = ask("    2 SENTENCES> ")

tee_print("ii. Write 2 sentences analyzing why progress was good/mediocre/bad towards particular goals.")
postmortem_of_progress = ask("    2 SENTENCES> ")

tee_print("iii. Write 1-3 sentence list of insights to keep in mind this week, so as to improve our efforts.")
capture_actions()
tee_print()

# 2. Post-Mortem of Habits
tee_print("2. Post-Mortem of Habits")
tee_print("i. Look at the chart of explicitly tracked habits. Write 1-2 sentences describing what you see.")
postmortem_of_tracked_habits = ask("    2 SENTENCES> ")

tee_print("ii. Review list of all habits. Identify those having difficulty with compliance.")
time.sleep(3)
habits_needing_attention = run_lf_select(
    "Mark habits struggling with compliance, Press Enter to confirm selection.",
    Path.home() / "main/habit"
)
tee_print("Habits -- those needing attention:")
tee_print(indent("\n".join(habits_needing_attention)))
time.sleep(1)

tee_print("iii. Write 2 sentences evaluating the results, trying to explain what caused them.")
postmortem_of_difficult_habits = ask("    2 SENTENCES> ")

tee_print("iv. Write 1-3 sentence list of actions to resolve the encountered difficulties with compliance.")
capture_actions()
tee_print()

# 3. Post-Mortem of Agreements
tee_print("3. Post-Mortem of Agreements")
tee_print("i. Recall for 3m: How well did I adhere to my agreements this week?")
subprocess.run(["timer", "-m", "3"])

#tee_print("ii. Read aloud from the Constitution's articles: ONLY the numbered lines")
#time.sleep(3)
#constitution = Path.home() / "main/agreements/A1:Constitution_for_the_Sovereignty_of_Alexander"
#with open(constitution) as f:
#    numbered_lines = [line for line in f if line.strip() and line.lstrip()[0].isdigit() and "." in line.split()[0]]
#subprocess.run(["less"], input="".join(numbered_lines), text=True)

tee_print("ii. Skim my agreements, relating them to my recent efforts.")
time.sleep(3)
agreements_for_further_focus = run_lf_select(
    "Skim your agreements, considering how they relate to my efforts. Mark any to revise or for further focus, Press ENTER to confirm selection.",
    Path.home() / "main/agreements"
)
tee_print("Agreements -- for further focus:")
tee_print(indent("\n".join(agreements_for_further_focus)))
time.sleep(1)

tee_print("iii. Write 3 sentences evaluating my compliance.")
postmortem_of_agreement_compliance = ask("    3 SENTENCES> ")

tee_print("iv. Write list of 1-3 actions to take in light of the evaluation, so as to curate & adhere to realistic & just agreements.")
capture_actions()
tee_print()

# OKR Weekly Check
#tee_print("OKR Weekly Check")
#result = subprocess.run([str(HERE / "okr_check")])
#if result.returncode != 0:
#    tee_print("(okr_check skipped or no OKRs found)")
#tee_print()

# 4. Time-estimation of Allocatable Work
QUOTA_DAILY_WORK_HOURS = 1.5
DAYS_IN_WORK_WEEK = 6

prev_week_file = TODO_ROOT / "2_week/.time_allocation"
month_file = TODO_ROOT / "3_month/.time_allocation"
prev_week_work_hrs_quota = prev_week_file.read_text().strip() if prev_week_file.exists() else str(QUOTA_DAILY_WORK_HOURS * DAYS_IN_WORK_WEEK)
month_work_hrs_quota = float(month_file.read_text().strip()) if month_file.exists() else 0

tee_print("4. Time-estimation of Allocatable Work")
_cal = subprocess.run(["cal", "-m"], capture_output=True, text=True)
tee_print(_cal.stdout.rstrip("\n"))

daily_work_quota = ask(f"    Minimum hours of personal work per day [{QUOTA_DAILY_WORK_HOURS}]> ") or str(QUOTA_DAILY_WORK_HOURS)
daily_work_quota = float(daily_work_quota)

work_days = ask(f"    Days in work week (excluding today, and remember: take Sundays off, and assume 1.5 days lost per week) [{DAYS_IN_WORK_WEEK}]> ") or str(DAYS_IN_WORK_WEEK)
work_days = int(work_days)

estimated_work_hours = round(daily_work_quota * work_days, 2)
tee_print(f"    Estimated work hours: {estimated_work_hours}")
prev_week_file.write_text(str(estimated_work_hours))
time.sleep(1)
tee_print()

hours_worked_last_week = ask(f"    Hours to subtract from remaining monthly allocation ({month_work_hrs_quota}h) [{prev_week_work_hrs_quota}]> ") or prev_week_work_hrs_quota
hours_worked_last_week = float(hours_worked_last_week)
month_work_hrs_quota = round(month_work_hrs_quota - hours_worked_last_week, 2)
tee_print(f"    Remaining work hours in month: {month_work_hrs_quota}")
month_file.write_text(str(month_work_hrs_quota))
time.sleep(1)
tee_print()

# 5. Review of Domains
#tee_print("5. Review of Domains")
#tee_print("i. Skim the domains-of-concern, identify those relevant to planning for this week.")
#time.sleep(3)
#relevant_domains_of_concern = run_lf_select(
#    "Mark domains relevant to planning for this week, Press Enter to confirm selection.",
#    TODO_ROOT / "#domain"
#)
#tee_print("Domains of Concern -- the weekly plan must account for:")
#tee_print(indent("\n".join(relevant_domains_of_concern)))
#time.sleep(1)
#tee_print()

if _out is not None:
    _out.close()
