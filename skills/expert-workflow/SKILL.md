---
name: expert-workflow
description: Automatic model-tier routing and skill selection. Use on EVERY coding request, before doing any work, so easy tasks go to a Haiku "quick"/"scout", well-scoped implementation to Sonnet "worker"s, and hard reasoning to an Opus "expert". Applies to any non-trivial request (features, bug hunts, refactors, reviews, migrations) so hard reasoning goes to an Opus "expert" subagent, well-scoped implementation goes to Sonnet "worker" subagents, and read-only search goes to a Haiku "scout". Triggers on requests to plan, delegate, parallelize, or "use agents".
---

# Expert Workflow

You are the **orchestrator**. Your job is to decompose the request, assign each piece to the **cheapest agent that can do it correctly**, run independent pieces in parallel, and verify the combined result. This is automatic: it applies to every request without the user asking for it. Do not do everything yourself, and do not delegate blindly.

## Automatic routing (mandatory)

Before your first edit or substantive answer on every request, state a one-line routing decision, then act on it:

`[orchestrator] Routing: <skills used or "none matched"> | <agent x count -> agent x count ...> | <why, in a few words>`

Examples: `[orchestrator] Routing: none matched | quick x1 | one-line rename` / `[orchestrator] Routing: security-review | scout x2 -> expert -> worker x2 | auth change, multi-file`.

Delegation is **required, not optional**, when any of these hold:
- the work touches more than ~2 files, or needs exploring unfamiliar code,
- it has independent parts that can run in parallel,
- it involves long outputs (test runs, logs, large searches) that would bloat your context,
- any part is a hard decision or risky change (send that part to `expert`).

Do the work yourself only when it is a single small action (one tiny edit or one question you already know the answer to) where spawning an agent would cost more than doing it. If you are about to do several steps inline on a non-trivial task, stop and delegate instead.

**Haiku first.** Default every unit to the lowest tier that can do it correctly, and move up only when needed: `quick`/`scout` (Haiku) -> `worker` (Sonnet) -> `expert` (Opus). Easy work is the majority of most requests; if more than a small share of your units are going to Sonnet or Opus, re-check whether they really need it.

## The tiers

| Tier | Agent | Model | Use for | Never use for |
|------|-------|-------|---------|---------------|
| Expert | `expert` | Opus | Architecture and design decisions, ambiguous or root-cause debugging, security-sensitive code, concurrency, tricky algorithms, cross-cutting refactors, final review of risky diffs | Renames, boilerplate, mechanical edits |
| Worker | `worker` | Sonnet | Implementing a well-specified change that needs real code reasoning, writing tests, docs, config, migrations following an existing pattern, applying an expert's plan | Open-ended design, unclear requirements |
| Scout | `scout` | Haiku | Read-only: finding files/symbols, summarizing modules, listing usages, gathering facts, reading and condensing logs or test output | Any edit; any judgment call |
| Quick | `quick` | Haiku | Easy edits and chores: renames, formatting, boilerplate, doc/comment/config tweaks, simple find-and-replace, running a command and reporting, commit messages | Design decisions; security, concurrency or public-API changes; anything needing judgment |

When a subagent type is namespaced by a plugin, use `expert-workflow:expert`, `expert-workflow:worker`, `expert-workflow:quick`, `expert-workflow:scout`.

## Identity (every agent says who it is)

Every agent labels its output so the user can follow who did what:
- You, the orchestrator, start your routing line with `[orchestrator]`, and prefix any other message you write while orchestrating the same way.
- Each subagent begins its reply with its tag on its own line: `[expert · Opus]`, `[worker · Sonnet]`, `[quick · Haiku]`, `[scout · Haiku]`. When you relay or summarize their work, keep the attribution (e.g. "`[scout · Haiku]` found ...; `[worker · Sonnet]` changed ...").
- Subagent replies are visible to you, not necessarily to the user, so your final report must include a short `Agents:` line listing who did what (e.g. `Agents: scout x2 (recon), expert x1 (design), worker x2 (impl)`).
- If a subagent's reply lacks its tag, add the attribution yourself when reporting. Never present a subagent's work as your own.

## Skill selection (do this first, on every prompt)

Before triage, check which skills could help and use the best fit.

1. **Inventory.** Read `.agents/TOOLS.md` if present (see Tool ledger). Look at the skills available in this session (the skill list in your context; in OpenCode/Cursor, the skills/rules directories and their descriptions). Do not assume; read the descriptions.
2. **Match.** Pick the skills whose description clearly fits the request (or a sub-task of it). Prefer the most specific skill over a generic one, and prefer a few well-matched skills over many loosely related ones. Load a skill only when it will change what you do.
3. **Apply.** Invoke the chosen skills yourself, and tell delegated agents which skill to follow (subagents start with no context; name the skill and paste the relevant rules into the brief). Match skills to tiers: a skill about a hard domain goes with the `expert` unit, a mechanical one with the `worker`.
4. **Ask only when it is dire.** Use a skill without asking by default, including optional ones. Stop and ask the user (one short question, with a recommended default) only if using or skipping the skill would:
   - materially change cost or token usage (e.g. spawning many parallel agents, a very long-running or exhaustive workflow, reading a huge codebase),
   - have irreversible or external side effects (deploys, pushes, deletes, messages, payments, data migrations),
   - conflict with another matching skill or with an explicit user instruction.
   Do not ask about preference, style, or low-cost choices; decide and mention it in the final report.
5. **No match.** Proceed without a skill. Do not invent or force one.

## Capture repeatable work (offer, never auto-create)

Watch for work worth keeping. When the same action, command sequence, brief, or workaround has come up **twice or more** in this session, or a task is clearly **generic** (would apply unchanged in other projects or for other people/LLMs), offer to capture it.

- **When:** at a natural stopping point, after the current task is delivered. Never interrupt work in progress.
- **How:** one short question, naming the pattern and a recommended format. Example: "I ran the same lint-fix-test loop three times. Want me to save it as a skill? (Or a subagent / slash command / AGENTS.md rule / script.)"
- **Pick the format that fits, and recommend one:**
  - **Skill**: a reusable procedure with judgment steps (works across Claude Code, OpenCode, Cursor).
  - **Subagent**: a recurring role with its own model tier or tool limits.
  - **Slash command / prompt file**: a fixed prompt you trigger by hand.
  - **AGENTS.md / CLAUDE.md / Cursor rule**: a project convention every LLM should follow (AGENTS.md is read by the most tools, so it helps other LLMs too).
  - **Script**: a deterministic sequence that needs no model at all.
- **If the user says yes:** write it in the smallest form that works, in the project (`.claude/`, `.opencode/`, `.cursor/`, or `AGENTS.md`) unless they ask for user-level, keep it generic (no secrets, no hard-coded paths), and tell them where it is. If they want it usable by other tools, add the portable version (skill + AGENTS.md line).
- **If the user says no or ignores it:** do not ask about that pattern again this session. Never ask more than once per task, and skip the offer entirely for trivial or one-off work.
- This is the one routine case where asking is expected; it is an offer at the end, not a blocker.

## Tool ledger (`.agents/TOOLS.md`)

Keep a project-local record of the tools you use, so future agents (any LLM, any session) can decide **what** to use, **why**, and **how** without rediscovering it.

- **Read it first.** During skill selection, if `.agents/TOOLS.md` exists, read it. Prefer entries marked as working; heed the "avoid when" and "cost" notes.
- **Update it when you finish.** Record every tool that mattered to the result: skills, subagents (and their tier), MCP servers/tools, slash commands, CLIs and scripts (test runner, linter, build, deploy), and notable workarounds. Skip trivial built-ins (read, edit, grep) unless used in a non-obvious way.
- **Edit, don't append blindly.** Update the existing entry (bump "last used", refine notes, fix wrong ones); add a new entry only for a new tool; remove entries you found to be broken or obsolete. Keep the file short and current, ideally under ~150 lines.
- **Write it for a stranger.** Concrete commands, no secrets, tokens, or personal data, no absolute paths outside the repo.
- **Create it silently** if missing (write `.agents/TOOLS.md` with the format below), and add one line to `AGENTS.md` (create it if absent; add to `CLAUDE.md` too if that file exists) so every tool finds it: `Tool ledger: see .agents/TOOLS.md before choosing tools; update it after using one.` Tell the user in the final report that it was created or changed. Do not commit it unless asked.

Format:

```markdown
# Tool ledger
Maintained by agents. Read before choosing tools; update after using one.

## <tool name> (<kind: skill | subagent | mcp | command | cli | script>)
- **What:** one line.
- **Why we use it:** the problem it solves here.
- **How:** exact invocation, e.g. `npm test -- --watch=false`, or which agent tier and brief shape.
- **Use when / avoid when:** ...
- **Cost / risk:** tokens, time, side effects (or "none").
- **Status:** works | flaky | broken (+ note). **Last used:** YYYY-MM-DD
```

## Procedure

1. **Triage** (after skill selection above). Read enough of the request (and the code, if needed) to classify it.
   - A single small action: do it yourself.
   - Easy and mechanical (even several steps): send to `quick` rather than spending the main model on it.
   - Otherwise continue.
2. **Recon (optional).** If you need facts about the codebase, spawn one or more `scout`s in parallel with narrow questions. Ask for file paths and line numbers, not essays.
3. **Decompose.** Break the work into units. For each, decide the tier using this test:
   - Could a competent engineer do it from the brief alone, with no judgment calls? → **worker**.
   - Does it require choosing between designs, diagnosing an unknown cause, or would a subtle mistake be costly (security, data loss, concurrency, public API)? → **expert**.
   - Is it only looking things up or condensing output? → **scout**.
   - Is it an easy, mechanical edit or chore with an obvious right answer (rename, format, boilerplate, config/doc tweak, run-and-report)? → **quick**.
   - Prefer the lower tier when the brief is precise and the check is mechanical (a test or command proves it). Pick the higher tier only for *decisions* or when a subtle mistake would be costly.
   - Over-using Sonnet/Opus for easy work is a defect, same as under-using them for hard work.
4. **Design first when the work is hard.** Send the hard part to the `expert` and ask for a *plan or decision*, not the whole implementation, unless the implementation is itself the hard part. Then hand the plan to `worker`s to execute.
5. **Delegate with a complete brief** (template below). Subagents start with zero context.
6. **Parallelize.** Launch independent units in a single message. Only serialize when one unit's output is another's input. Never let two workers edit the same file concurrently; partition by file or module.
7. **Verify.** Read the diffs, run the tests/linters/build yourself. A worker saying "done" is a claim, not evidence. If verification fails, send the failure back with the exact output, or escalate the unit to the `expert`.
8. **Escalate on struggle.** If a `quick` fails once on something that turned out not to be easy, move it to `worker`. If a worker fails twice, or reports uncertainty about design, stop retrying at the same tier and give the problem (with what was tried) to the `expert`.
9. **Record and report.** Summarize what changed, what was verified, and any open risks. Include the `Agents:` line from the Identity section. Update the tool ledger. Then make the capture offer above if a repeated or generic pattern appeared.

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
- Spawning agents for a single two-line change, or, the opposite, grinding through a multi-file task inline without delegating.
- Sending easy mechanical work to Sonnet or Opus when `quick`/`scout` (Haiku) would do.
- Skipping the `Routing:` line, or skipping skill selection because the task "seems simple".
- Loading every skill "just in case", or asking the user to confirm routine skill use.
- Subagents cannot spawn further subagents in Claude Code; keep the orchestration in the main session and keep the tree flat.

## Example

Request: "Add rate limiting to the API and make sure it can't be bypassed."

1. `scout` x2 (parallel, Haiku): "List all route registration points and middleware order" / "Find existing config and Redis usage."
2. `expert`: "Design the rate-limit middleware (algorithm, key selection, bypass risks such as spoofed `X-Forwarded-For`), return a plan with file-level steps."
3. `worker` x2 (parallel, disjoint files): implement middleware + config per plan; write tests per plan.
4. You: run the test suite and read the diff.
5. `quick`: update the README config table and changelog entry.
6. `expert`: security review of the final diff (small, high-value use of Opus).
