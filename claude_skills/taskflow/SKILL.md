---
name: taskflow
description: Use when a taskdir needs to be driven from start to done — at task start (the launcher hints it, or type /taskflow), or when re-entering for a follow-on increment. Re-enterable.
---

# taskflow — the taskdir conductor

Codifies how a taskdir goes from start to done. The flow the todo-system CLAUDE.md describes in prose is enacted here as an ordered, gated procedure. Run this in the **main interactive session**; delegate token-heavy, no-user-input work to isolated subagents; keep the conductor's own context small.

## Core principles

| Principle | Rule |
|---|---|
| Context minimization | Hold only: goal note, `acceptance_criteria.md`, small phase digests, approved plan. Never pull raw file dumps or edit churn into the conductor — that is what subagents are for. The conductor delegates ALL file reading/exploration to subagents (phase 1 `taskflow-explorer`; additional read-only `taskflow-explorer` dispatches if deeper reads are needed during Plan or Validate). It never bulk-reads source/artifact files or runs exploratory grep/read directly. |
| One judged done-signal | Done = `/goal` verdict over locked acceptance criteria (LLM judgment on the transcript), corroborated by the fresh-context validator's adversarial per-criterion verdict. No deterministic oracle — deliberately. For engineered work, run real tests/build and **surface their output** so `/goal` can confirm they ran and passed. |
| Human owns direction | Conductor proposes; user disposes at each GATE. Gates are STOP points — do not proceed past one without the user. |
| Terse phase announce | Emit ONE terse line announcing each phase transition (e.g. `[Phase 2 — Define Criteria]`). No fanfare. |

## The six phases

### 1. Explore — subagent: `taskflow-explorer` [haiku, read-only]

Dispatch `taskflow-explorer` (Task tool, `subagent_type: taskflow-explorer`). It reads the goal note + taskdir + relevant filesystem context + any relevant web searches and returns a `<=40`-line digest (relevant files, inferred intent, constraints, risks, open questions). Merge it; post a 3-bullet read to the user.

- **Triage the digest's OPEN QUESTIONS** rather than silently deciding them. Try decently hard to resolve each one itself from context first — do not bother the user with anything it can settle on its own. But if it has genuinely tried and remains decently uncertain, it is **encouraged** to surface that question as a surgical `AskUserQuestion` option at GATE A rather than baking an unflagged design decision into the "Proceed" option.
- **GATE A (light):** `AskUserQuestion` — "Is this the right framing/scope?" Options: Proceed / Reframe / Out of scope. Catches a wrong-problem before any effort is spent.

### 2. Define Criteria — NORTH STAR (before Plan) — skill: `define-acceptance-and-validation-criteria`

The most important gate: define what "done" means **before planning**. Everything downstream is built on this north star.

- **REQUIRED:** Use `define-acceptance-and-validation-criteria`. It derives 1–5 verifiable acceptance criteria and persists them to `acceptance_criteria.md`.
- Quality bar — criteria + restated goal must clear `prompt_qa_policy.md` (Context, Action, Result all present; a competent agent could execute first-try without guessing). Drive it with:
  ```
  /goal "acceptance_criteria.md holds 1–5 acceptance criteria, each a
  verifiable property, that together satisfy prompt_qa_policy.md; surface any gap as guidance for the next turn.
  prompt_qa_policy.md:
  $(cat ~/main/todo/.infra/prompt_qa_policy.md)"
  ```
  Let the session self-iterate to the bar, then the goal clears.
- **GATE C (LOAD-BEARING):** `AskUserQuestion` — present the criteria, ask "Approve these acceptance criteria?" Options: Approve / Make stricter / Add criterion / Remove criterion. Do not plan until the north star is locked.

### 3. Plan — conductor [in-session]

From the locked criteria + digest, draft a plan and **decompose the work into meaningfully distinct features** (each independently implementable and verifiable). Enter plan mode and call **ExitPlanMode** — a NATIVE blocking gate.

- **GATE B (load-bearing, native):** user approves / edits / rejects, unlimited rounds. Implementation cannot begin until approval.

### 4. Implement — subagent: `taskflow-implementer` [sonnet], ONE PER FEATURE

**REQUIRED:** Use `superpowers:subagent-driven-development` (fresh subagent per feature, review after each).

For **each distinct feature** from the plan:

1. Dispatch a separate `taskflow-implementer` (own context), briefed with that feature's plan slice + the locked criteria. Distinct features get distinct subagents — do not lump unrelated work into one. Run foreground so permission prompts surface.
2. **After the implementer returns:** conduct a QUICK spec-compliance review — does the changelist match the plan slice and criteria? This is a best-judgement call on the implementer's **returned summary alone** — the conductor does NOT pull the diff or read the edited files (pulling implementation detail into the conductor defeats the point of the subagent; detailed verification is the Validate phase's job). Catch obvious misses or scope creep before moving to the next feature. This is a changelist sanity check, not a full re-validation (the fresh validator does that at phase 5).
3. Surface any BLOCKED notes to the user before continuing.

**Note:** if the taskdir's work involves creating or editing skills/agents, the implementer MUST use `superpowers:writing-skills`.

Rules:
- The conductor **never edits task artifacts directly** — every implementation edit goes through a `taskflow-implementer` subagent.
- Collect changelists; do NOT pull full diffs into your context.
- `/goal` (per increment, after plan approval):
  ```
  /goal "every approved feature is implemented and meets its acceptance
  criteria as locked in acceptance_criteria.md"
  ```

### 5. Validate — subagent: `taskflow-validator` [sonnet, FRESH context]

**REQUIRED:** Use `superpowers:verification-before-completion` (evidence before claims; run the check, echo output, never claim pass without fresh output).

Dispatch `taskflow-validator` in a **fresh context** — it has not seen the implementation reasoning. This prevents confirmation bias and keeps validator tokens out of your window. It:

- reads `acceptance_criteria.md` and adversarially checks the work against each criterion — actively hunting where it FAILS the intent, not where it passes;
- for any criterion resting on an engineered check (tests, linter, build), RUNS it and **echoes the output** — never greps source for a string (proves nothing the Edit tool didn't already);
- **for interactive / runtime systems, EXERCISES the integrated system live as the user would** — actually run it (start the process, fire the keybind/command, drive the real state) and echo what happened. Static checks (`bash -n`, logic sims, code-traces) prove syntax and isolated logic, NOT integration. They do NOT substitute for running the thing. Explicitly hunt the states a fresh artifact won't have exercised: cold-start / empty state, pre-existing state from before the change was installed, missed/late events, deployment gaps (symlink not installed, config not reloaded, CRLF). If a criterion can only be confirmed by a human driving the live UI, say so and route it to GATE D as an explicit user acceptance test rather than claiming PASS on static evidence;
- returns a **per-criterion verdict** (PASS/FAIL + why) + adversarial findings.

`/goal`:
```
/goal "every criterion in acceptance_criteria.md is met — per the validator's
per-criterion verdict and the transcript — including that any engineered
checks (tests/lint/build) were run and observed to pass"
```

Cap the autonomous fix→revalidate loop at ~3 cycles (matches the constitution's autonomous-resolution rule). Done-signal = this `/goal` verdict plus the validator's judgment.

- **GATE D:** `AskUserQuestion` — show per-criterion verdict + adversarial findings, ask "Accept validation results?" Options: Accept / Be stricter / Reject.

### 6. Finalize — conductor [in-session]

Explicit checklist:

1. **After-action report:** reflect on this run's own transcript, the work performed, and the user feedback given during it — what was rough, what needed re-explaining, where a gate mis-fired, where an instruction was ambiguous or missing. Read this task's own lines in `~/main/todo/.infra/log/taskflow_gate_choices.jsonl`: the user accepting the default/recommended option is evidence the flow worked at that point; a Reframe / "make stricter" / reject / edited-plan choice marks friction worth examining.
   - **Every non-default gate choice in this task's log lines must be explicitly accounted for.** Concluding "the gate worked as intended" is only acceptable if the agent can state what the flow would have had to do differently to not need the user's correction at all. Rationalizing away a friction signal is the failure mode.
   - **Trace each friction to its root cause before proposing a fix** — fix the cause, not the symptom that surfaced it.
   - Bar for proposing a fix: the issue **actually bit during this task**, AND the fix is a small, concrete text edit to a named file (this SKILL.md, a taskflow agent brief, an `.infra` script, a CLAUDE.md, another skill, etc.). No speculative generalization, no useless restyling, no nitpicks. **Proposing nothing is a valid and common outcome — premature systematization is a cost.**
   - At most ~3 candidate insights. May ask the user pointed, surgical questions via `AskUserQuestion` to test a hypothesis before proposing — these exploratory probes are not gates and are not logged (only the Gate E proposal dialog is).
2. **GATE E (after-action):** propose the improvement(s) via `AskUserQuestion` — Apply / Skip / Revise . Log the response **immediately on receipt** (per Stage Dialog Logging), BEFORE making any edits. On Revise: incorporate the feedback and re-ask (cap ~2 rounds). On Skip, or nothing to propose: move on cleanly.
3. **Apply approved edits** via a `taskflow-implementer` subagent — the conductor never edits directly. Skill/agent edits MUST use `superpowers:writing-skills`.
4. **Git gate:** detect whether the work touched a git repo by running `git -C <modified-file-dir> rev-parse --is-inside-work-tree` for each modified file's directory — NOT from the taskdir, which is often outside any repo. Note: after-action edits may land in a different repo than the task work (`~/main/todo/.infra` IS a git repo; `~/main/todo` itself is not) — the per-directory check can legitimately yield two repos.
   - If yes: `AskUserQuestion` — offer to commit (and optionally push) with a proposed commit message. Commit/push **only on explicit approval**.
   - **GATE F (git):** user approves the message + push, or declines.
   - If not a git repo: skip cleanly.
5. **Hand off:** report the terse validation line. Do NOT mark the task done or move the taskdir — that is the user's call via `mark` (scoped autonomy).

## Re-enterable loop

If the user asks for more after Validate / Finalize, re-enter at **Criteria** for the new increment: Criteria → Plan → Implement → Validate. Each increment re-locks its own north star.

## /goal — where and why (exactly three phases)

Criteria / Implement / Validate each get a `/goal` condition so the session self-iterates to that phase's quality bar. At Validate it **is** the done-signal — its verdict over the locked criteria plus the adversarial validator is what "done" means. The human GATES still gate: a `/goal` turn that needs sign-off asks the user and only clears once the bar — and any required approval — holds.

## Enforcement — stated honestly

- **CODE-ENFORCED (hard):** ExitPlanMode (native blocking gate) — the ONLY hard gate. It cannot be skipped.
- **MODEL-FOLLOWED (soft):** everything else — the done-signal, phase order, intermediate gates — are directives this conductor follows. This is strictly more codified than prose but is not a hard interpreter. Do NOT add a `Stop` hook to force gates — the only `Stop` slot is taken by `tmux-move-done.sh`; a competing blocking `Stop` hook would create incoherent dashboard state.

## Stage Dialog Logging

After EVERY `AskUserQuestion` gate response is received, append one JSON line to:
```
~/main/todo/.infra/log/taskflow_gate_choices.jsonl
```

Format (one line, no pretty-print):
```json
{"task":"<taskdir-goal-name>","gate":"<A|B|C|D|E|F>","phase":"<phase-name>","options":["<opt1>","<opt2>",...],"chosen":"<exact-option-text>","is_default":<true|false>}
```

Rules:
- `is_default`: `true` if user chose the **first** option listed, `false` otherwise.
- Gate B (ExitPlanMode) is a native gate — log `"chosen":"Approved"` / `"chosen":"Rejected"` / `"chosen":"Edited"` based on what the user did, `is_default` = `true` only on clean Approved.
- Gate E (Finalize / after-action) — log the Apply/Revise/Skip response BEFORE making any approved edits; a Revise round logs each ask separately. Pre-proposal exploratory `AskUserQuestion` probes (step 1 of Finalize) are not Gate E and are not logged.
- Append via Bash: `echo '<line>' >> <file>` (create file if absent, that's fine).
- Log BEFORE proceeding to next phase — do not skip on timeout or early exit.
- If the taskdir basename is ambiguous, use the full path relative to `~/main/doc/todo/`.

## Anti-patterns

- Planning before the criteria north star is locked (Gate C).
- One monolithic implementer for unrelated features — fan out per feature.
- The conductor editing task artifacts directly — **every edit goes through a `taskflow-implementer` subagent**, no exceptions.
- The conductor reading source files or running grep/read to explore directly — **delegate ALL reading to a `taskflow-explorer` subagent**; the conductor's context holds only digests, criteria, and the goal note.
- Validating in the conductor's own context — use the fresh-context subagent.
- Passing Validate on static checks alone (`bash -n` / sims / code-trace) for an interactive or runtime system without ever running it live — this is exactly how a real integration bug (cold-start, pre-existing state, deploy gap) slips a green Validate. Exercise it live, or route the live check to GATE D as a user acceptance test.
- Pulling raw file dumps / full diffs into the conductor (defeats the purpose).
- Scaffolding deterministic checks for ad-hoc criteria that pass trivially — let `/goal` judge the transcript instead.
- Running tests/build without surfacing their output — `/goal` can only judge what the transcript shows.
- Committing / pushing or marking the task done without the user.
- Skipping the post-implementer spec-compliance review before moving to the next feature.
- Turning the after-action report into a nitpick list or a speculative systematizing exercise.
- Making after-action edits in the conductor, or before Gate E's dialog has been logged.
