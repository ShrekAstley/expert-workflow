#!/usr/bin/env bash
# Appends one JSON line per agent lifecycle event to .agents/log/events.jsonl.
# Wired to PreToolUse (Agent/Task spawns), SubagentStart and SubagentStop.
# Never blocks or fails the session: all errors are swallowed.
set -u
input="$(cat 2>/dev/null || true)"
root="${CLAUDE_PROJECT_DIR:-$PWD}"
dir="$root/.agents/log"
mkdir -p "$dir" 2>/dev/null || exit 0
ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
if command -v jq >/dev/null 2>&1; then
  printf '%s' "$input" | jq -c --arg ts "$ts" '{
    ts: $ts,
    event: (.hook_event_name // "unknown"),
    session: (.session_id // null),
    agent_id: (.agent_id // null),
    agent_type: (.agent_type // .tool_input.subagent_type // null),
    description: (.tool_input.description // null),
    task: ((.tool_input.prompt // null) | if . == null then null else .[0:600] end),
    result: ((.last_assistant_message // null) | if . == null then null else .[0:600] end)
  }' >> "$dir/events.jsonl" 2>/dev/null || true
else
  printf '{"ts":"%s","raw":%s}\n' "$ts" "$(printf '%s' "$input" | tr -d '\n' | head -c 1500 | sed 's/\\/\\\\/g; s/"/\\"/g; s/^/"/; s/$/"/')" >> "$dir/events.jsonl" 2>/dev/null || true
fi
exit 0
