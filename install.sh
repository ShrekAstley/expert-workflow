#!/usr/bin/env bash
# Expert Workflow installer for Claude Code, OpenCode and Cursor.
#
#   ./install.sh                      # Claude Code, via its built-in plugin installer
#   ./install.sh opencode             # OpenCode (global by default)
#   ./install.sh cursor --project     # Cursor, into ./.cursor
#   ./install.sh all                  # everything
#   ./install.sh --uninstall [target]
#
# Remote one-liner:
#   curl -fsSL https://raw.githubusercontent.com/shrekastley/expert-workflow/main/install.sh | bash
#   curl -fsSL .../install.sh | bash -s -- opencode --project
set -euo pipefail

REPO="${EXPERT_WORKFLOW_REPO:-shrekastley/expert-workflow}"
REF="${EXPERT_WORKFLOW_REF:-main}"
PLUGIN="expert-workflow"
MARKETPLACE="expert-workflow"

TARGET=""
SCOPE=""          # claude: user|project ; others: global|project
UNINSTALL=0
FORCE_COPY=0

say()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m!!\033[0m  %s\n' "$*" >&2; }
die()  { printf '\033[1;31mxx\033[0m  %s\n' "$*" >&2; exit 1; }

usage() {
  cat <<USAGE
Usage: install.sh [claude|opencode|cursor|all] [options]

Options:
  --project        Install into the current project instead of your user profile
  --global, --user Install for your user (default)
  --copy           (claude) skip the plugin installer; copy skill + agents to ~/.claude
  --uninstall      Remove what this script installed
  --repo SLUG      GitHub repo to install from (default: $REPO)
  --ref REF        Git ref to install from (default: $REF)
  -h, --help       Show this help

Default target is 'claude'.
USAGE
}

while [ $# -gt 0 ]; do
  case "$1" in
    claude|opencode|cursor|all) TARGET="$1" ;;
    --project) SCOPE="project" ;;
    --global|--user) SCOPE="user" ;;
    --copy) FORCE_COPY=1 ;;
    --uninstall) UNINSTALL=1 ;;
    --repo) shift; REPO="${1:?--repo needs a value}" ;;
    --ref) shift; REF="${1:?--ref needs a value}" ;;
    -h|--help) usage; exit 0 ;;
    *) usage >&2; die "Unknown argument: $1" ;;
  esac
  shift
done
TARGET="${TARGET:-claude}"
SCOPE="${SCOPE:-user}"

# ---- locate sources (local checkout, else fetch) ---------------------------
SRC=""
TMP=""
cleanup() { [ -n "$TMP" ] && rm -rf "$TMP"; return 0; }
trap cleanup EXIT

find_local_src() {
  local here
  here="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd)" || return 1
  [ -f "$here/skills/expert-workflow/SKILL.md" ] && [ -d "$here/adapters" ] && SRC="$here"
}

ensure_src() {
  [ -n "$SRC" ] && return 0
  find_local_src && return 0
  TMP="$(mktemp -d)"
  say "Fetching $REPO@$REF"
  if command -v git >/dev/null 2>&1 && git clone -q --depth 1 --branch "$REF" "https://github.com/$REPO.git" "$TMP/src" 2>/dev/null; then
    SRC="$TMP/src"
  elif command -v curl >/dev/null 2>&1 && command -v tar >/dev/null 2>&1; then
    mkdir -p "$TMP/src"
    curl -fsSL "https://github.com/$REPO/archive/refs/heads/$REF.tar.gz" | tar -xz --strip-components=1 -C "$TMP/src" \
      || die "Could not download $REPO@$REF"
    SRC="$TMP/src"
  else
    die "Need git, or curl+tar, to fetch $REPO"
  fi
}

copy_files() { # copy_files <src-dir> <dest-dir> <glob-ext>
  mkdir -p "$2"
  local f
  for f in "$1"/*; do
    [ -f "$f" ] && cp "$f" "$2/$(basename "$f")" && echo "    + $2/$(basename "$f")"
  done
  return 0
}

remove_files() { # remove_files <src-dir> <dest-dir>
  local f dest
  for f in "$1"/*; do
    dest="$2/$(basename "$f")"
    [ -f "$dest" ] && rm -f "$dest" && echo "    - $dest"
  done
  return 0
}

# ---- Claude Code -----------------------------------------------------------
claude_scope() { [ "$SCOPE" = "project" ] && echo project || echo user; }

claude_copy_root() { [ "$SCOPE" = "project" ] && echo "$PWD/.claude" || echo "$HOME/.claude"; }

claude_install_copy() {
  ensure_src
  local root; root="$(claude_copy_root)"
  say "Copying skill and agents into $root"
  mkdir -p "$root/skills/expert-workflow"
  cp "$SRC/skills/expert-workflow/SKILL.md" "$root/skills/expert-workflow/SKILL.md"
  echo "    + $root/skills/expert-workflow/SKILL.md"
  copy_files "$SRC/agents" "$root/agents"
}

install_claude() {
  if [ "$FORCE_COPY" -eq 0 ] && command -v claude >/dev/null 2>&1; then
    local source_arg
    if find_local_src; then source_arg="$SRC"; else source_arg="$REPO"; fi
    say "Installing with Claude Code's plugin installer (scope: $(claude_scope))"
    claude plugin marketplace add "$source_arg" \
      || warn "marketplace add reported an error (it may already be added); continuing"
    claude plugin install "$PLUGIN@$MARKETPLACE" --scope "$(claude_scope)" \
      || die "claude plugin install failed. Try inside Claude Code:  /plugin marketplace add $REPO  then  /plugin install $PLUGIN@$MARKETPLACE"
    say "Done. Restart Claude Code (or run /reload-plugins), then ask for work, or run /agents to see expert, worker, scout."
  else
    [ "$FORCE_COPY" -eq 1 ] || warn "'claude' CLI not found on PATH; falling back to a plain file copy."
    claude_install_copy
    say "Done. Restart Claude Code. For the managed install later, run inside Claude Code:"
    echo "    /plugin marketplace add $REPO"
    echo "    /plugin install $PLUGIN@$MARKETPLACE"
  fi
}

uninstall_claude() {
  if command -v claude >/dev/null 2>&1; then
    say "Removing Claude Code plugin"
    claude plugin uninstall "$PLUGIN@$MARKETPLACE" --scope "$(claude_scope)" || warn "plugin was not installed via the plugin installer"
    claude plugin marketplace remove "$MARKETPLACE" || true
  fi
  ensure_src
  local root; root="$(claude_copy_root)"
  say "Removing copied files under $root (if any)"
  rm -f "$root/skills/expert-workflow/SKILL.md"; rmdir "$root/skills/expert-workflow" 2>/dev/null || true
  remove_files "$SRC/agents" "$root/agents"
}

# ---- OpenCode --------------------------------------------------------------
opencode_root() { [ "$SCOPE" = "project" ] && echo "$PWD/.opencode" || echo "${XDG_CONFIG_HOME:-$HOME/.config}/opencode"; }

install_opencode() {
  ensure_src
  local root; root="$(opencode_root)"
  say "Installing for OpenCode into $root"
  copy_files "$SRC/adapters/opencode/agents" "$root/agents"
  mkdir -p "$root/skills/expert-workflow"
  cp "$SRC/skills/expert-workflow/SKILL.md" "$root/skills/expert-workflow/SKILL.md"
  echo "    + $root/skills/expert-workflow/SKILL.md"
  say "Done. Restart OpenCode. Pick the 'orchestrator' agent (Tab), or @expert / @worker / @scout directly."
  echo "    Models are set in the agent files' 'model:' field; edit them if you use a different provider."
}

uninstall_opencode() {
  ensure_src
  local root; root="$(opencode_root)"
  say "Removing OpenCode files from $root"
  remove_files "$SRC/adapters/opencode/agents" "$root/agents"
  rm -f "$root/skills/expert-workflow/SKILL.md"; rmdir "$root/skills/expert-workflow" 2>/dev/null || true
}

# ---- Cursor ----------------------------------------------------------------
cursor_root() { [ "$SCOPE" = "project" ] && echo "$PWD/.cursor" || echo "$HOME/.cursor"; }

install_cursor() {
  ensure_src
  local root; root="$(cursor_root)"
  say "Installing for Cursor into $root"
  copy_files "$SRC/adapters/cursor/agents" "$root/agents"
  mkdir -p "$root/skills/expert-workflow"
  cp "$SRC/skills/expert-workflow/SKILL.md" "$root/skills/expert-workflow/SKILL.md"
  echo "    + $root/skills/expert-workflow/SKILL.md"
  if [ "$SCOPE" = "project" ]; then
    copy_files "$SRC/adapters/cursor/rules" "$root/rules"
  else
    warn "Cursor rules are project-scoped; skipped. Re-run with --project inside a repo to add the rule."
  fi
  say "Done. Restart Cursor. Edit 'model:' in $root/agents/*.md to pin specific models (default: expert inherits your chosen model, worker/scout use 'fast')."
}

uninstall_cursor() {
  ensure_src
  local root; root="$(cursor_root)"
  say "Removing Cursor files from $root"
  remove_files "$SRC/adapters/cursor/agents" "$root/agents"
  rm -f "$root/skills/expert-workflow/SKILL.md"; rmdir "$root/skills/expert-workflow" 2>/dev/null || true
  remove_files "$SRC/adapters/cursor/rules" "$root/rules"
}

# ---- dispatch --------------------------------------------------------------
run() {
  local action="$1" tool="$2"
  if [ "$UNINSTALL" -eq 1 ]; then "uninstall_$tool"; else "install_$tool"; fi
  : "$action"
}

case "$TARGET" in
  all) for t in claude opencode cursor; do run x "$t"; done ;;
  *)   run x "$TARGET" ;;
esac
