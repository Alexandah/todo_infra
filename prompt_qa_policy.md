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

**The core rule**: a prompt fails Context only when the agent lacks a concrete anchor to begin exploration. Omitting information the agent can discover is NOT a failure.

**What agents can discover** (and thus need not be re-stated):
- Paths, file locations, file contents: use explore agents, taskdir structure, symlinks, existing code citations
- Context from CLAUDE.md files and standard Claude Code startup context: already loaded by the harness
- Project structure, conventions, roles: documented in CLAUDE.md and readable from the repo
- Standard domain knowledge: Jira workflows, API conventions, widely-documented systems (AWS, GitHub, Git, standard database patterns, etc.), common terminology
- Existing features or behavior of a codebase: discoverable by reading code, tests, comments, git history

**Fail Context only when**:
- The agent has no starting anchor (e.g., "fix the bug" with no mention of what system, repo, or codebase)
- The context is project-specific, ambiguous, non-standard, or cannot be discovered independently (e.g., a custom internal protocol with no docs, or a deadline/budget constraint)
- The required context is not in CLAUDE.md and not discoverable from the taskdir or code

### 2. Action — required
A clear statement of what to do: the task, the process or actions to take, and
a high-level description of the end result. "Fix it", "make it better",
"help with X" with no specified action fail here.

### 3. Result — required
Specific, checkable properties of the desired output: format, tone, length or
other numerical quantification, sections, validation criteria — whatever lets both human
and agent agree on when it is done. A prompt with no way to tell a good result
from a bad one fails here.

**Result checks outcome properties, not implementation steps**. The agent needs to know what constitutes done, not how to do it. Omitting technical details the agent can derive from code is not a failure:
- Exact command syntax, API arguments, internal mechanics: discoverable from existing code
- Code style, language idioms, framework conventions: inferable from the codebase or standard LLM knowledge
- How to invoke tools or integrate with existing systems: readable from CLAUDE.md or project documentation

**Fail Result only when** the agent cannot distinguish a correct result from an incorrect one without additional clarification — e.g., "make it fast" (how fast?), "improve the code" (in what dimension?), "ensure it works" (what conditions?)

### 4. Example — situational
A sample of a valid response. Required when the desired output has a
non-obvious shape, an unusual format, or a specific style that prose alone
cannot pin down. For simple, unambiguous asks, an example is not required and
its absence must not cause a FAIL.

## Explicit Bypass: Test Taskdirs

For taskdirs whose goal is obviously test-only (marked with `[TEST]`, `FAKE`, or
explicitly for testing the gate system): if the goal file contains an explicit
request for auto-approval (e.g., "pass this without QA" or "bypass gate for
testing"), the gate honors it and bypasses evaluation.

This enables rapid iteration on the prompt QA system itself while keeping the
gate intact for real taskdirs. The request must be explicit in the goal file —
automatic bypass does not apply.

## Verdict Rules

- **PASS**: all required dimensions are adequately satisfied for this request,
  and any situationally-required example is present.
- **FAIL**: name the single biggest gap — the one dimension whose absence most
  threatens a correct first-try result — in one plain sentence the human can
  act on. Do not list every flaw; surface the most important one.
- **QA-TEST-BYPASS PASS**: obvious test taskdir with explicit bypass request in
  goal file. Gate bypassed; no dimension evaluation. For testing gate changes.
- Never propose corrected wording. State what is missing, not how to write it.
- Judge the prompt as written. Do not assume the human will clarify later.
