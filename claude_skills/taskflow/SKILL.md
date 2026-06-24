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
- **One judged done-signal.** Done = the `/goal` verdict over the locked
  acceptance criteria (an LLM judgment on the session transcript), corroborated
  by the fresh-context validator's adversarial per-criterion verdict. There is
  **no deterministic oracle** — deliberately. Taskdirs are ad-hoc, not the
  sterile, contract-bound environments where mechanical check suites earn their
  keep; there, auto-generated checks almost always pass on the first try and
  only burn tokens. For genuinely engineered work, run the real tests/build and
  **surface their output in the transcript** so `/goal` can confirm they ran and
  passed.
- **The human owns direction.** The conductor proposes; the user disposes at
  each GATE. Gates are STOP points — do not proceed past one without the user.

## The six phases

### 1. Explore — subagent: `taskflow-explorer` [haiku, read-only]
Dispatch `taskflow-explorer` (Task tool, `subagent_type: taskflow-explorer`).
It reads the goal note + taskdir + relevant filesystem context + any relevant web searches
and returns a `<=40`-line digest (relevant files, inferred intent, constraints,
risks, open questions). Merge it; post a 3-bullet read to the user.
- **GATE A** (light): Use `AskUserQuestion` tool — ask "Is this the right framing/scope?" with options: Proceed / Reframe / Out of scope.
  Catches a wrong-problem before any effort is spent planning.

### 2. Define Criteria — NORTH STAR (before Plan) — skill: `define-acceptance-and-validation-criteria`
The most important gate: define what the task IS and what "done" means **before
planning**. Everything downstream is built on this north star, so get it right.
- Invoke the `define-acceptance-and-validation-criteria` skill. It derives 1–5
  verifiable acceptance criteria and persists them to `acceptance_criteria.md`.
- **Quality bar** The criteria + restated goal must clear
  the `prompt_qa_policy.md` bar — Context, Action, Result all present; a
  competent agent could execute first-try without guessing. Drive it with:
  ```
  /goal "acceptance_criteria.md holds 1–5 acceptance criteria, each a
  verifiable property, that together satisfy prompt_qa_policy.md; surface any gap as guidance for the next turn.
  prompt_qa_policy.md:
  $(cat /home/erandalex/main/todo/.infra/prompt_qa_policy.md)"
  ```
  Let the session self-iterate the criteria to the bar, then the goal clears.
- **GATE C (LOAD-BEARING):** Use `AskUserQuestion` tool — present the criteria and ask "Approve these acceptance criteria?" with options: Approve / Edit / Add criterion / Remove criterion. Do not plan until the north star is locked.

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
  criteria as locked in acceptance_criteria.md"
  ```
- Collect changelists; do NOT pull full diffs into your context.

### 5. Validate — subagent: `taskflow-validator` [sonnet, FRESH context]
Dispatch `taskflow-validator` in a **fresh context** — it has not seen the
implementation reasoning. This is deliberate: an independent reviewer avoids
confirmation bias and keeps validator tokens out of your window. It:
- reads `acceptance_criteria.md` and adversarially checks the diff against each
  criterion — actively hunting where the work FAILS the intent, not where it
  passes;
- for any criterion resting on an engineered check (tests, linter, build), RUNS
  it and **echoes the output** so the transcript shows it ran and passed — never
  greps source for a string (proves nothing the Edit tool didn't already);
- returns a **per-criterion verdict** (PASS/FAIL + why) + adversarial findings.
- **/goal:**
  ```
  /goal "every criterion in acceptance_criteria.md is met — per the validator's
  per-criterion verdict and the transcript — including that any engineered
  checks (tests/lint/build) were run and observed to pass"
  ```
  Cap the autonomous fix→revalidate loop at ~3 cycles (matches the
  constitution's autonomous-resolution rule). The done-signal is this `/goal`
  verdict plus the validator's judgment — there is no exit code to read.
- **GATE D:** Use `AskUserQuestion` tool — show the per-criterion verdict + adversarial findings and ask "Accept validation results?" with options: Accept / Demand more checks / Reject.

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
is the closest native "keep working until the bar holds" loop. At Validate it
**is** the done-signal — its verdict over the locked criteria (plus the
adversarial validator) is what "done" means; there is no deterministic oracle
beneath it, by design. The human GATES still gate: a `/goal`
turn that needs sign-off asks the user (which pauses for input) and only clears
once the bar — and any required approval — holds.

## Enforcement — stated honestly
- **CODE-ENFORCED (hard):** ExitPlanMode (native blocking gate) — the ONLY hard
  gate. It cannot be skipped.
- **MODEL-FOLLOWED (soft):** the done-signal itself — the `/goal` verdict over
  the locked criteria, plus the adversarial validator — is soft LLM judgment, by
  deliberate design: ad-hoc taskdirs lack the contracts that would make a
  deterministic exit-code oracle meaningful. The phase ORDER and the intermediate
  gates are directives this conductor follows. This is strictly MORE codified than prose
  (an ordered, named, launcher-invoked procedure) but is not a hard interpreter.
  Do NOT add a `Stop` hook to force gates — the only `Stop` slot is taken by
  `tmux-move-done.sh`; a competing blocking `Stop` hook would create incoherent
  dashboard state.

## Anti-patterns
- Planning before the criteria north star is locked (Gate C).
- One monolithic implementer for unrelated features (fan out per feature).
- Validating in the conductor's own context (use the fresh-context subagent).
- Pulling raw file dumps / full diffs into the conductor (defeats the purpose).
- Scaffolding deterministic checks for ad-hoc criteria that pass trivially — let
  `/goal` judge the transcript instead.
- Running tests/build without surfacing their output — `/goal` can only judge
  what the transcript shows.
- Committing / pushing or marking the task done without the user.
