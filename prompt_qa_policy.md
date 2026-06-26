# Prompt QA Policy

The rubric the gate judges every prompt against. 
The gate is a *referee*, not an editor: it returns PASS or FAIL with one sentence — it never rewrites the prompt. 
The point is to force the human to think the goal through clearly, training a
cybernetic feedback loop.

This policy also governs **taskdir specs** (the `.hmm` note that seeds a Claude
session): a spec is just the opening prompt of that session, so it is held to
the same bar.

## The Bar

A prompt PASSES when a competent agent, reading only that prompt (plus the
ambient context it can reasonably discover), could execute it well on the first
try without guessing at the requester's intent. If the agent would have to ask
a clarifying question or invent an unstated requirement to proceed, it FAILS.

Judge holistically, but enforce the dimensions below fairly strictly. Do not
nitpick style; do flag genuine gaps that would degrade the result.

## Dimensions

A prompt is built from up to four dimensions. Weigh which are load-bearing for
*this* request, then check them.

### 1. Context — required
Background the agent needs: the situation, relevant files/resources/locations,
and the role the agent should play (who it is, who the audience is). A prompt
that names a task with no anchoring context (what system, what files, what
goal it serves) fails here.
**IMPORTANT**: Indirect or implicit location references are fine — the agent can use explore agents, taskdir contents (including symlinks), and CLAUDE.md to discover paths autonomously. Do NOT require explicit path specifications for locations the agent can reasonably locate without them. Fail only when there is genuinely no anchor the agent could follow.
**IMPORTANT**: Count all context pulled from CLAUDE.md files and other standard Claude Code startup appendings. Do not fail for context already documented there — it exists precisely to avoid re-stating it every time. Well-known project paths, roles, and conventions documented in CLAUDE.md require no re-mention in the prompt.

### 2. Action — required
A clear statement of what to do: the task, the process or actions to take, and
a high-level description of the end result. "Fix it", "make it better",
"help with X" with no specified action fail here.

### 3. Result — required
Specific, checkable properties of the desired output: format, tone, length or
other numerical quantification, sections, validation criteria — whatever lets both human
and agent agree on when it is done. A prompt with no way to tell a good result
from a bad one fails here.
**IMPORTANT**: Result checks output *properties*, not implementation details. Exact command syntax, API arguments, or internal mechanics that can be derived from existing code (especially when that code is cited in the prompt) are NOT required here. Fail only when the agent cannot tell a correct result from an incorrect one — not when it must look up how to build it.

### 4. Example — situational
A sample of a valid response. Required when the desired output has a
non-obvious shape, an unusual format, or a specific style that prose alone
cannot pin down. For simple, unambiguous asks, an example is not required and
its absence must not cause a FAIL.

## Verdict Rules

- **PASS**: all required dimensions are adequately satisfied for this request,
  and any situationally-required example is present.
- **FAIL**: name the single biggest gap — the one dimension whose absence most
  threatens a correct first-try result — in one plain sentence the human can
  act on. Do not list every flaw; surface the most important one.
- Never propose corrected wording. State what is missing, not how to write it.
- Judge the prompt as written. Do not assume the human will clarify later.
