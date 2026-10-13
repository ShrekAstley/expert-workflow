# Expert Workflow

A skill plus a small team of subagents that routes each part of a request to the right model tier.

| Agent | Model | Job |
|-------|-------|-----|
| `expert` | Opus | Design decisions, root-cause debugging, security/concurrency-sensitive code, reviewing risky diffs |
| `worker` | Sonnet | Well-specified implementation, tests, docs, migrations, executing the expert's plan |
| `scout` | Haiku | Read-only search, summarization, condensing logs and test output |
| `quick` | Haiku | Easy edits and chores: renames, formatting, boilerplate, doc/config tweaks, run-and-report |

The `expert-workflow` skill turns your main session into an orchestrator: triage, decompose, delegate with a complete brief, run independent units in parallel, verify, and escalate to the expert when a worker struggles. Trivial requests are handled directly, with no delegation overhead.

## Automatic by default

Nothing needs to be invoked. On Claude Code, a `SessionStart` hook loads the standing policy (`hooks/policy.md`) and a `UserPromptSubmit` hook reinforces it on every prompt, so routing and skill selection do not depend on the model deciding to load the skill. Each response starts with a visible line such as `[orchestrator] Routing: none matched | quick x1 | one-line rename`, so you can see what it chose. Delegation is required beyond a single small action, and routing is Haiku-first: `quick`/`scout` for easy work, `worker` (Sonnet) for well-specified implementation, `expert` (Opus) only for hard decisions. OpenCode (`orchestrator` agent plus an `AGENTS.md` policy block) and Cursor (`alwaysApply` rule) get the same behavior. In `--copy` mode on Claude Code (no plugin hooks), the policy is added to `CLAUDE.md` between `expert-workflow` markers instead; `--uninstall` removes only that block.

## Agents identify themselves

Every agent labels its output: the orchestrator opens with `[orchestrator] Routing: ...`, and subagents begin their replies with `[expert · Opus]`, `[worker · Sonnet]`, `[quick · Haiku]` or `[scout · Haiku]`. The orchestrator keeps that attribution when relaying their work and ends its final report with an `Agents:` line, e.g. `Agents: scout x2 (recon), expert x1 (design), worker x2 (impl)`. The tags name the tier rather than a specific model version, so they stay correct if you change the `model:` setting.

## Install

### Claude Code (built-in plugin installer)

Inside Claude Code:

```
/plugin marketplace add shrekastley/expert-workflow
/plugin install expert-workflow@expert-workflow
```

Or from a shell (uses `claude plugin ...` under the hood):

```bash
curl -fsSL https://raw.githubusercontent.com/shrekastley/expert-workflow/main/install.sh | bash
# project scope (shared via .claude/settings.json):
curl -fsSL https://raw.githubusercontent.com/shrekastley/expert-workflow/main/install.sh | bash -s -- claude --project
```

If the `claude` CLI is not on your PATH, the script falls back to copying files into `~/.claude`. Use `--copy` to force that.

Verify with `/agents` (you should see `expert`, `worker`, `quick`, `scout`). Agents are namespaced as `expert-workflow:expert`, etc.

### OpenCode

```bash
./install.sh opencode              # ~/.config/opencode
./install.sh opencode --project    # ./.opencode
```

Installs the three subagents, a primary `orchestrator` agent, and the skill. Models default to `anthropic/claude-opus-5-5`, `anthropic/claude-sonnet-5-5`, `anthropic/claude-haiku-4-5`; edit the `model:` line in each agent file for another provider.

### Cursor

```bash
./install.sh cursor --project      # ./.cursor  (agents, skill, rule)
./install.sh cursor                # ~/.cursor  (agents, skill)
```

Cursor identifies models by its own names, so by default `expert` inherits the model you have selected and `worker`/`scout` use `fast`. To pin models, edit `model:` in `.cursor/agents/*.md`.

### All at once / uninstall

```bash
./install.sh all
./install.sh --uninstall all
```

Run `./install.sh --help` for all options. `EXPERT_WORKFLOW_REPO` and `EXPERT_WORKFLOW_REF` override the source repo and ref.

## Usage

Just ask for work: "add rate limiting to the API and make sure it can't be bypassed". The skill triggers on non-trivial tasks, or invoke it explicitly ("use the expert-workflow skill"). In OpenCode, switch to the `orchestrator` agent. In Cursor, ask it to use the `expert-workflow` skill/rule.

## Automatic skill selection

On every prompt the orchestrator scans the skills available in the session and uses the best-matching ones (and hands the relevant rules to subagents). It does this without asking. It only stops to ask you when it is dire: the choice would materially change token/cost usage, has irreversible or external side effects, or conflicts with another skill or your instructions.

- Claude Code: a `UserPromptSubmit` hook (`hooks/hooks.json`) injects a one-line reminder each prompt; the full rules are in the skill.
- OpenCode: built into the `orchestrator` agent.
- Cursor: the rule is now `alwaysApply: true`.

## Capturing repeatable work

If the same action comes up twice or more in a session, or a task is clearly generic, the orchestrator offers (once, after delivering, in one short question) to save it as a skill, subagent, slash command, `AGENTS.md`/`CLAUDE.md` rule, or script, and recommends the best fit. `AGENTS.md` and skills are the portable options that help other LLMs and tools too. It creates nothing unless you say yes, and does not re-ask about a pattern you declined.

## Tool ledger

Agents keep `.agents/TOOLS.md` in your project: every skill, subagent, MCP server, command or script that mattered, with what it is, why it is used, how to invoke it, when to avoid it, cost/risk, status and last-used date. Future agents (any LLM, any session) read it first and update it when they finish, editing entries rather than piling up new ones. It is created automatically, with a pointer line added to `AGENTS.md` (and `CLAUDE.md` if present) so every tool finds it. It is never committed for you, and never contains secrets.

## Layout

```
.claude-plugin/        plugin.json + marketplace.json (Claude Code plugin)
skills/expert-workflow/SKILL.md   shared orchestration skill (all three tools)
agents/                Claude Code subagents (expert, worker, quick, scout)
hooks/                 Claude Code hooks (SessionStart policy + per-prompt reminder)
adapters/opencode/     OpenCode agents (model: anthropic/...)
adapters/cursor/       Cursor agents + rule
install.sh             installer / uninstaller
```

## Notes and limits

- Claude Code subagents cannot spawn subagents, so the orchestration lives in the main session and the tree stays flat.
- Delegation costs tokens and latency. The skill keeps trivial work in the main session; tune the tier table in `SKILL.md` to your taste.
- Agent frontmatter formats evolve; if a tool rejects a field, check its docs and adjust the files in `adapters/`.

## License

MIT
