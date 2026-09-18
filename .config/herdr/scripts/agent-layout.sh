#!/bin/sh
# prefix+a       — lay the agent layout onto the current workspace
# prefix+shift+a — the same layout in a new workspace
#
#   tab 1                          tab 2
#   +-------------+-------------+  +---------------------------+
#   |    agent    |     git     |  |          server           |
#   +-------------+-------------+  +---------------------------+
#
# The agent pane is named but left at a prompt; start the agent yourself.
set -u
. "$(dirname "$0")/lib.sh"

MODE="${1:-here}"

case "$MODE" in
  workspace)
    out=$("$HERDR" workspace create --cwd "$ROOT" --label "$(basename "$ROOT")" --focus 2>/dev/null) \
      || die "workspace create failed"
    ws=$(printf '%s' "$out" | "$JQ" -r '.result.workspace.workspace_id // empty')
    agent=$(printf '%s' "$out" | "$JQ" -r '.result.root_pane.pane_id // empty')
    ;;
  here)
    [ -n "$WS" ] || die "no active workspace"
    [ -n "$TAB" ] || die "no active tab"
    [ -n "$PANE" ] || die "no active pane"
    require_single_pane_tab "$WS" "$TAB"
    ws="$WS"
    agent="$PANE"
    ;;
  *) die "unknown mode: $MODE" ;;
esac
[ -n "$ws" ] || die "no workspace id"
[ -n "$agent" ] || die "no agent pane id"

git_pane=$("$HERDR" pane split --pane "$agent" --direction right --ratio 0.5 --cwd "$ROOT" --no-focus 2>/dev/null \
  | "$JQ" -r '.result.pane.pane_id // empty')
[ -n "$git_pane" ] || die "split right failed"

"$HERDR" pane rename "$agent" agent >/dev/null 2>&1
"$HERDR" pane rename "$git_pane" git >/dev/null 2>&1

# The server gets its own tab. --no-focus leaves focus on the agent pane in tab 1;
# the existing tab keeps whatever label it already had.
server=$("$HERDR" tab create --workspace "$ws" --cwd "$ROOT" --label server --no-focus 2>/dev/null \
  | "$JQ" -r '.result.root_pane.pane_id // empty')
[ -n "$server" ] || die "server tab create failed"
"$HERDR" pane rename "$server" server >/dev/null 2>&1

run_git_status "$git_pane"
run_dev "$server"
