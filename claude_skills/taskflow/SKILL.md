---
name: taskflow
description: Interactive orchestrator for taking a taskdir from start to done with the precision of code. Run at task start (the launcher hints it, or type /taskflow). Sequences six gated phases — Explore, Define Criteria, Plan, Implement, Validate, Finalize — delegating token-heavy no-input work to isolated subagents (taskflow-explorer / taskflow-implementer / taskflow-validator) while the main Opus session owns every interactive decision gate. Re-enterable for follow-on increments.
---

# taskflow — the taskdir conductor

Codifies how a taskdir goes from start to done. The flow that the todo-system
CLAUDE.md only *describes* in prose is enacted here as an ordered, gated
procedure. Run this in the **main interactive session on Opus** (the
orchestrator must be the smartest model); it delegates token-heavy,
no-user-input work to isolated subagents and keeps its own context small.

## Core principles
- **Context minimization.** Hold only: the goal note, small phase digests, the
  approved criteria, and the approved plan. NEVER pull raw file dumps or edit
  churn into the conductor's context — that is precisely what the subagents are
  for. This realizes "distribute the intrinsic tokens across independent
  sessions so per-session context stays small."
- **One falsifiable oracle.** `./validate.do` exiting 0 (`PASS>=1 FAIL=0`) is
  the canonical definition of done. `/goal` and judgment never override it.
- **The human owns direction.** The conductor proposes; the user disposes at
  each GATE. Gates are STOP points — do not proceed past one without the user.

## Trivial-task collapse (check FIRST)
If the taskdir is small — time estimate < ~0.5h, or a single-file / single-step
change — **COLLAPSE**: skip subagent fan-out and run Explore + Plan + Implement
inline in this session. Still do Criteria (lightweight) and Validate, still
honor the gates. Per-subagent spin-up + re-briefing overhead only pays off when
task size justifies it; most taskdirs here are small.

## The six phases

### 1. Explore — subagent: `taskflow-explorer` [haiku, read-only]
Dispatch `taskflow-explorer` (Task tool, `subagent_type: taskflow-explorer`).
It reads the goal note + taskdir + relevant filesystem context + any relevant web searches
and returns a `<=40`-line digest (relevant files, inferred intent, constraints,
risks, open questions). Merge it; post a 3-bullet read to the user.
- **GATE A** (light, skippable for trivial): "Is this the right framing/scope?"
  Catches a wrong-problem before any effort is spent planning.

### 2. Define Criteria — NORTH STAR (before Plan) — skill: `define-acceptance-and-validation-criteria`
The most important gate: define what the task IS and what "done" means **before
planning**. Everything downstream is built on this north star, so get it right.
- Invoke the `define-acceptance-and-validation-criteria` skill. It derives 1–5
  verifiable criteria and scaffolds `validate.do`.
- **Quality bar** The criteria + restated goal must clear
  the `prompt_qa_policy.md` bar — Context, Action, Result all present; a
  competent agent could execute first-try without guessing. Drive it with:
  ```
  /goal "validate.do holds 1–5 '# === Criterion' headers, each stating a
  verifiable property, that together satisfy prompt_qa_policy.md; surface any gap as guidance for the next turn.
  prompt_qa_policy.md:
  $(cat /home/erandalex/main/todo/.infra/prompt_qa_policy.md)"
  ```
  Let the session self-iterate the criteria to the bar, then the goal clears.
- **GATE C (LOAD-BEARING):** show the criteria headers; user approves / edits /
  adds / removes. Do not plan until the north star is locked.

### 3. Plan — conductor [opus, in-session]
From the locked criteria + digest, draft a plan and **decompose the work into
meaningfully distinct features** (each independently implementable and
verifiable). Enter plan mode and call **ExitPlanMode** — a NATIVE blocking gate.
- **GATE B (load-bearing, native):** user approves / edits / rejects, unlimited
  rounds. Implementation cannot begin until approval.

### 4. Implement — subagent: `taskflow-implementer` [sonnet], ONE PER FEATURE
For **each distinct feature** from the plan, dispatch a separate
`taskflow-implementer` (own context), briefed with that feature's plan slice +
the locked criteria. Distinct features get distinct subagents — do not lump
unrelated work into one. Run them in the **foreground** so their decisions /
permission prompts surface to you. Each returns a short changelist + a BLOCKED
note for any out-of-scope or cross-system (`CLAUDE.local.md`) decision — surface
BLOCKED to the user.
- **/goal** (per increment, after plan approval):
  ```
  /goal "every approved feature is implemented and meets its acceptance
  criteria as recorded in validate.do"
  ```
- Collect changelists; do NOT pull full diffs into your context.

### 5. Validate — subagent: `taskflow-validator` [sonnet, FRESH context]
Dispatch `taskflow-validator` in a **fresh context** — it has not seen the
implementation reasoning. This is deliberate: an independent reviewer avoids
confirmation bias and keeps validator tokens out of your window. It:
- invokes the `validate-task` skill and adds ONLY non-trivial, falsifiable
  checks (falsifiability test: "if the code had a bug here, would this catch
  it?"), deterministic `check` first, `claude_verify` only for nebulous
  judgment;
- runs `./validate.do`;
- adversarially reads the diff against the criteria.
- **/goal:**
  ```
  /goal "./validate.do exits 0 (PASS>=1 FAIL=0) and every check is non-trivial
  and falsifiable — no tautology / source-grep checks"
  ```
  Cap the autonomous fix→revalidate loop at ~3 cycles (matches the
  constitution's autonomous-resolution rule). The conductor reads the **real
  exit code**, never trusting the evaluator alone.
- **GATE D:** show the `PASS=N FAIL=M` line + adversarial findings; user accepts
  or demands more checks.

### 6. Finalize — conductor [in-session]
- `./log.do "<one-line outcome>"` (the taskdir work log; accepts the message as
  its first CLI arg).
- **Git:** if the work touched a git repo, propose a commit (and push) and run
  it **only with explicit user approval**. Never commit/push without permission.
  - **GATE E (git):** user approves the commit message + push, or declines. Use the tool AskUserQuestion to ask the user.
- **Hand off:** report the terse validation line. Do NOT mark the task done or
  move the taskdir between categories — that is the user's call via `mark`
  (scoped autonomy).

## Re-enterable loop
If the user asks for more after Validate / Finalize, **re-enter at Criteria** for
the new increment and run Criteria → Plan → Implement → Validate again. The flow
may be a loop, not a one-shot; each increment re-locks its own north star.

## /goal — where and why (exactly three phases)
Criteria / Implement / Validate each get a `/goal` condition (above) so the
session self-iterates to that phase's quality bar without babysitting. `/goal`
is the closest native "keep working until the bar holds" loop. It is **not** the
done-oracle — `validate.do`'s exit code is. The human GATES still gate: a `/goal`
turn that needs sign-off asks the user (which pauses for input) and only clears
once the bar — and any required approval — holds.

## Enforcement — stated honestly
- **CODE-ENFORCED (hard):** ExitPlanMode (native blocking gate) and
  `validate.do`'s exit code (deterministic). These cannot be skipped.
- **MODEL-FOLLOWED (soft):** the phase ORDER and the intermediate gates are
  directives this conductor follows. This is strictly MORE codified than prose
  (an ordered, named, launcher-invoked procedure) but is not a hard interpreter.
  Do NOT add a `Stop` hook to force gates — the only `Stop` slot is taken by
  `tmux-move-done.sh`; a competing blocking `Stop` hook would create incoherent
  dashboard state.

## Anti-patterns
- Planning before the criteria north star is locked (Gate C).
- One monolithic implementer for unrelated features (fan out per feature).
- Validating in the conductor's own context (use the fresh-context subagent).
- Pulling raw file dumps / full diffs into the conductor (defeats the purpose).
- Replacing `validate.do`'s exit code with `/goal`'s soft Haiku judgment.
- Committing / pushing or marking the task done without the user.
