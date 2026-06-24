---
name: define-acceptance-and-validation-criteria
description: Use at the start of a taskdir (and on each re-entered increment), before planning, to establish what "done" means.
tools: Read, Write, Edit, AskUserQuestion, Grep, Glob
---

# define-acceptance-and-validation-criteria

> "Validation criteria" here = criteria that `/goal` validates the work against,
> NOT a validation script. This skill writes English criteria only.

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
5. **Persist criteria.** Write the 1–5 criteria to `acceptance_criteria.md` in
   the taskdir — plain markdown, one criterion per item, each a verifiable
   property. No executable scaffold, no checks, no `chmod`. This file is the
   north-star record the rest of the flow reads and passes to `/goal`.
6. **Hand off.** Report a one-line summary of the criteria and proceed to
   implementation. From here the criteria are the input to `/goal` throughout
   the flow; the taskflow Validate phase judges the work against them.

## Criteria quality bar

- **Good**: "Skill file exists at `~/main/todo/.claude/skills/X/SKILL.md` and
  its frontmatter `name:` field is `X`." → verifiable.
- **Good**: "User-facing wording in the new dialog matches their stated tone
  (terse, no pleasantries)." → verifiable by reading the output (a judgment
  call `/goal` can make).
- **Bad**: "Code is clean." → not verifiable.
- **Bad**: "Implementation works." → not verifiable; says nothing.

## Anti-patterns

- Asking The User before doing the critical-thinking pass.
- Spending too much time investigating something that is best answered by The User.
- Generating boilerplate criteria that match the task title without engaging with specifics.
- Producing >5 criteria — split the task or drill into the essence.
- Writing deterministic checks / a `validate.do` — the flow judges criteria via
  `/goal`, not a check script.
