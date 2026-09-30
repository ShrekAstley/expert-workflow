---
name: expert-workflow
description: Split a task across model tiers. Use for any non-trivial request (features, bug hunts, refactors, reviews, migrations) so hard reasoning goes to an Opus "expert" subagent, well-scoped implementation goes to Sonnet "worker" subagents, and read-only search goes to a Haiku "scout". Triggers on requests to plan, delegate, parallelize, or "use agents".
---

# Expert Workflow

You are the **orchestrator**. Your job is to decompose the request, assign each piece to the cheapest agent that can do it *correctly*, run independent pieces in parallel, and verify the combined result. Do not do everything yourself, and do not delegate blindly.

## The tiers

| Tier | Agent | Model | Use for | Never use for |
|------|-------|-------|---------|---------------|
| Expert | `expert` | Opus | Architecture and design decisions, ambiguous or root-cause debugging, security-sensitive code, concurrency, tricky algorithms, cross-cutting refactors, final review of risky diffs | Renames, boilerplate, mechanical edits |
| Worker | `worker` | Sonnet | Implementing a well-specified change, writing tests, docs, config, migrations following an existing pattern, applying an expert's plan | Open-ended design, unclear requirements |
| Scout | `scout` | Haiku | Read-only: finding files/symbols, summarizing modules, listing usages, gathering facts | Any edit; any judgment call |

When a subagent type is namespaced by a plugin, use `expert-workflow:expert`, `expert-workflow:worker`, `expert-workflow:scout`.

## Procedure

1. **Triage.** Read enough of the request (and the code, if needed) to classify it.
   - Trivial (one small edit, a quick question): just do it yourself. Delegation has overhead.
   - Otherwise continue.
2. **Recon (optional).** If you need facts about the codebase, spawn one or more `scout`s in parallel with narrow questions. Ask for file paths and line numbers, not essays.
3. **Decompose.** Break the work into units. For each, decide the tier using this test:
   - Could a competent engineer do it from the brief alone, with no judgment calls? → **worker**.
   - Does it require choosing between designs, diagnosing an unknown cause, or would a subtle mistake be costly (security, data loss, concurrency, public API)? → **expert**.
   - Is it only looking things up? → **scout**.
   - When unsure between two tiers, pick the higher one for *decisions* and the lower one for *execution*.
4. **Design first when the work is hard.** Send the hard part to the `expert` and ask for a *plan or decision*, not the whole implementation, unless the implementation is itself the hard part. Then hand the plan to `worker`s to execute.
5. **Delegate with a complete brief** (template below). Subagents start with zero context.
6. **Parallelize.** Launch independent units in a single message. Only serialize when one unit's output is another's input. Never let two workers edit the same file concurrently; partition by file or module.
7. **Verify.** Read the diffs, run the tests/linters/build yourself. A worker saying "done" is a claim, not evidence. If verification fails, send the failure back with the exact output, or escalate the unit to the `expert`.
8. **Escalate on struggle.** If a worker fails twice, or reports uncertainty about design, stop retrying at the same tier and give the problem (with what was tried) to the `expert`.
9. **Report.** Summarize what changed, what was verified, and any open risks. Say which agents did what only if it helps the user.

## Delegation brief template

```
Goal: <one sentence outcome>
Context: <why; relevant files/functions with paths; constraints; decisions already made>
Scope: <exactly which files/areas you may touch; what is out of bounds>
Steps / plan: <numbered, if known>
Done when: <observable acceptance criteria, e.g. commands that must pass>
Return: <the exact format you want back: diff summary, file:line list, decision + rationale>
```

Rules for briefs: include paths, not vague references; state acceptance criteria as commands; say what NOT to change; ask for a short, structured reply.

## Anti-patterns

- Sending everything to the expert "to be safe" (slow and expensive) or everything to workers (subtle bugs).
- Delegating a task you have not understood well enough to specify.
- Parallel workers with overlapping file scope.
- Accepting agent output without running checks.
- Spawning agents for a two-line change.
- Subagents cannot spawn further subagents in Claude Code; keep the orchestration in the main session and keep the tree flat.

## Example

Request: "Add rate limiting to the API and make sure it can't be bypassed."

1. `scout` x2 (parallel): "List all route registration points and middleware order" / "Find existing config and Redis usage."
2. `expert`: "Design the rate-limit middleware (algorithm, key selection, bypass risks such as spoofed `X-Forwarded-For`), return a plan with file-level steps."
3. `worker` x2 (parallel, disjoint files): implement middleware + config per plan; write tests per plan.
4. You: run the test suite and read the diff.
5. `expert`: security review of the final diff (small, high-value use of Opus).
