# Expert Workflow

A skill plus a small team of subagents that routes each part of a request to the right model tier.

| Agent | Model | Job |
|-------|-------|-----|
| `expert` | Opus | Design decisions, root-cause debugging, security/concurrency-sensitive code, reviewing risky diffs |
| `worker` | Sonnet | Well-specified implementation, tests, docs, migrations, executing the expert's plan |
| `scout` | Haiku | Read-only search and summarization |

The `expert-workflow` skill turns your main session into an orchestrator: triage, decompose, delegate with a complete brief, run independent units in parallel, verify, and escalate to the expert when a worker struggles. Trivial requests are handled directly, with no delegation overhead.

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

Verify with `/agents` (you should see `expert`, `worker`, `scout`). Agents are namespaced as `expert-workflow:expert`, etc.

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

## Layout

```
.claude-plugin/        plugin.json + marketplace.json (Claude Code plugin)
skills/expert-workflow/SKILL.md   shared orchestration skill (all three tools)
agents/                Claude Code subagents (expert, worker, scout)
hooks/hooks.json       Claude Code UserPromptSubmit hook (per-prompt skill-selection reminder)
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
