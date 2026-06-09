---
name: validate-task
description: Use after completing implementation in taskdirs for post-task validation with a re-runnable, exit-code-honest enactor. Scaffold and run validate.do for a taskdir, proceduralizing acceptance criteria into deterministic shell checks plus optional claude -p verifier checks for nebulous judgment calls.
tools: Read, Write, Edit, Bash, Grep, Glob
---

# validate-task

Scaffold a `validate.do` script in the current taskdir. Two purposes:

1. **Precise documentation** of what "done" means for this taskdir.
2. **Mechanical enactor** — re-runnable, idempotent, exit-code-honest.

This is the **deterministic prong**. The agent-judgment prong (your reading
of the diff and output) is separate and equally required — see global
CLAUDE.md.

## When to use

- Any non-trivial taskdir → required (multi-step, multi-file, anything
  with clear "done" criteria).
- Trivial single-line edit → skip; run narrowest inline check.

## Per-task-type map

- **Code**: tests, linter, type-checker, formatter, build. Narrowest scope
  first (file/module touched), broaden if quick.
- **Config / dotfile / shell**: `bash -n`, `jq . <file>`, source in subshell,
  dry-run.
- **Markdown / notes**: re-read, `grep` for required content, structural
  checks (balanced fences, heading present).
- **Scripts**: create a minimal fixture, invoke the script/function with
  representative input, assert on side effects or output — NOT on source text.

## Design rules

- **Iteratively refine** during work — push coverage of "done" closer to
  exhaustive. Add a check whenever you spot a property that should hold.
- **Falsifiability test**: before writing any check, ask "if the code had a
  bug here, would this catch it?" If no — don't write it.
- **Deterministic-first**: primitive terminating shell ops. Fast, cheap,
  reproducible, non-trivial.
- **`claude_verify` only for nebulous judgment** — prose quality, intent
  match, subjective fitness. Never for things shell can check.
- **Run deterministic checks BEFORE verifier checks** — don't burn tokens
  on already-broken state.
- **Strict JSON enforcement** — verifier prompt embeds the expected schema
  literally; output is parsed AND shape-checked; malformed = FAIL, never
  silent.
- **Idempotent**: re-running = same result, no side effects beyond
  stdout/stderr.
- **Exit code honest**: `exit 0` only if all checks pass.
- **Output**: `[PASS] <name>` or `[FAIL] <name> — <reason>` per check, then
  `PASS=N FAIL=M` summary line.
- **Anti-recursion**: `validate.do` must not invoke validation OF itself.

## API reference

`validate.do` is bootstrapped by `define-acceptance-and-validation-criteria`
from
`~/main/todo/.claude/skills/define-acceptance-and-validation-criteria/assets/validate.do.template`.
Helpers + schema + exit logic already live in the file you're editing.
You add calls only.

Functions:
- `check <name> <cmd...>` — deterministic. Exit 0 of `<cmd>` = PASS.
- `claude_verify <name> <criterion>` — headless `claude -p` judgment.
  Strict JSON shape-check enforced inside.

Conventions:
- Section header: `# === Criterion N: <plain-English statement> ===`
- Add calls directly under their criterion section.
- Output: `[PASS] <name>` / `[FAIL] <name> — <reason>`, then `PASS=N FAIL=M`.
- Exit 0 iff `FAIL=0`.

Example section (behavioral fixture, then nebulous):

```bash
# === Criterion 1: script creates :time_worked file with correct value ===
# Default: run the actual script with a fixture + mocked interactive tools.
# Stub fzf (and any other interactive tools) so the script runs non-interactively.
_td=$(mktemp -d)
_mock_bin=$(mktemp -d)
echo "1.00" > "$_td/.time_orig"; touch "$_td/:time=0.50h"
echo -e '#!/bin/bash\necho "0.25"' > "$_mock_bin/fzf"; chmod +x "$_mock_bin/fzf"
PATH="$_mock_bin:$PATH" /path/to/script "$_td" <...args...>
check "crit1_time_worked_created"  test -f "$_td/:time_worked=.50h"
rm -rf "$_td" "$_mock_bin"

# === Criterion 2: <plain-English statement; nebulous, needs judgment> ===
claude_verify "crit2_<short_name>" "<criterion text + inline content / path>"
```

**For testing script logic, prefer in this order:**
1. **Run whole script** with fixture + mocked interactive tools (stub `fzf`/`read`/etc. in PATH). Default. Always tests the real file.
2. **Extract marked block + eval** — only when running the whole script causes unavoidable destructive side effects (e.g., moves directories, writes to production paths). Add `# BEGIN_X` / `# END_X` markers in source; `sed`+`eval` in validate.do. Begrudgingly accepted edge case.
3. **Copy logic into helper** — never. Drifts silently.

**grep on source is almost always wrong for code/script tasks.** It proves
only that a string exists in the file — which the Edit tool already
guaranteed. Use it only for content artifacts (notes, markdown) where the
text IS the deliverable.

If existing `validate.do` is malformed (missing helpers, broken structure):
re-copy template from the path above and merge criteria sections back.

## Workflow

1. **Check `validate.do`.** If missing OR no `# === Criterion` markers
   present, invoke the `define-acceptance-and-validation-criteria` skill
   first. Otherwise proceed.
2. For each criterion section: add deterministic `check` calls (preferred),
   and/or a single `claude_verify` call for genuinely nebulous criteria.
   Iterate during implementation — every property that should hold and
   isn't checked → add a check under its criterion.
3. Run `./validate.do`. On non-zero exit, autonomous-resolution loop.
4. On `PASS=N FAIL=0` AND own judgment passes, append a `log.do` entry by
   running `./log.do "<one-line outcome message>"` in the taskdir (the
   taskdir's `log.do` accepts the message as its 1st CLI arg).
5. Report one-line outcome.

## Anti-patterns

- **Tautology checks** — grepping a source file for a string you just wrote.
  Catches nothing; Edit already guaranteed the string landed. Only valid for
  content artifacts (markdown, notes) where text IS the deliverable.
- **Copy-pasted logic in helpers** — duplicating code from the script under
  test into a `_run_X()` helper in validate.do. The copy drifts silently.
  Use extract+eval with markers instead.
- Silent skip on missing tools — always FAIL with reason.
- Verifier without strict JSON schema check — flaky parses.
- Burning verifier tokens before deterministic checks pass.
- `claude_verify` for things shell can check.
- Running script as part of itself (recursion).
- Conflating `log.do` (human narrative) with validator output (mechanical).
