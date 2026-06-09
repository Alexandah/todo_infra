---
name: define-acceptance-and-validation-criteria
description: Use to define what completion looks like when starting work in a taskdir. Derives 1–5 acceptance criteria via critical thinking on goal+context first, Q&A with the user only when self-resolution fails, then writes them as section-header comments in a fresh validate.do skeleton (helpers + schema + exit logic). Pairs with validate-task (which fills in checks during work and runs at end).
tools: Read, Write, Edit, AskUserQuestion, Grep, Glob
---

# define-acceptance-and-validation-criteria

You own the criteria. Derive them yourself first; treat the user as a
last-resort tiebreaker, not a default.

## Workflow

1. **Read context.** Goal note (`::*.hmm`), task title, time estimate, any
   other taskdir files (drafts, specs, prior `log.do`). Read enough of the
   surrounding repo / parent taskdirs to understand intent.
2. **Critical-thinking pass.** Draft 1–5 concrete, verifiable criteria that
   drill to the essential core of "done". Err on fewer. Each criterion must
   be objectively verifiable as done or not done by *some* method (shell
   check, file inspection, behavioral observation, judgment call).
3. **Self-resolve ambiguity.** If something seems ambiguous, try to resolve
   it from context before asking. The user picked this task because they
   trust your judgment on shape.
4. **Ask only when genuinely stuck.** If a criterion's intent is irresolvable
   from context (load-bearing user-specific preference, domain knowledge you
   lack, or two equally-valid framings), use `AskUserQuestion`. Batch
   questions; don't drip them.
5. **Bootstrap `validate.do`** — see `## Template` below. Copy template,
   edit copy to insert criteria headers in the marked region, `chmod +x`.
   No checks under headers yet — `validate-task` fills them in during/after
   implementation.
6. **Hand off.** Report a one-line summary of the criteria and proceed to
   implementation. The `validate-task` skill takes over at end-of-work.

## Criteria quality bar

- **Good**: "Skill file exists at `~/main/todo/.claude/skills/X/SKILL.md` and
  its frontmatter `name:` field is `X`." → verifiable.
- **Good**: "User-facing wording in the new dialog matches their stated tone
  (terse, no pleasantries)." → verifiable via `claude_verify`.
- **Bad**: "Code is clean." → not verifiable.
- **Bad**: "Implementation works." → not verifiable; says nothing.

## Template

Canonical skeleton lives at:

```
~/main/todo/.claude/skills/define-acceptance-and-validation-criteria/assets/validate.do.template
```

Contains: helpers (`check`, `claude_verify`), `VERIFIER_SCHEMA`,
output/exit logic, and a marked
`# >>> CRITERIA SECTIONS ... # <<< END CRITERIA SECTIONS` insertion region.

Steps:

1. `cp ~/main/todo/.claude/skills/define-acceptance-and-validation-criteria/assets/validate.do.template <taskdir>/validate.do`
2. `Edit` the copy: inside the marked region, replace placeholder
   `# === Criterion N: <plain-English statement> ===` lines with one
   header per real criterion (1–5 total). Leave checks empty.
3. `chmod +x <taskdir>/validate.do`.

Never edit the template in place. Copy first.

## Anti-patterns

- Asking The User before doing the critical-thinking pass.
- Spending too much time investigating something that is best answered by The User.
- Generating boilerplate criteria that match the task title without engaging with specifics.
- Producing >5 criteria — split the task or drill into the essence.
- Writing checks at this stage — that's `validate-task`'s job.
- Skipping `chmod +x`.
