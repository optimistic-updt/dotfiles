#!/bin/sh
# prefix+s       — turn the current tab into the dev layout
# prefix+shift+s — build the same layout in a new workspace
#
#   +-------------+-------------+
#   |             |   server    |
#   |   claude    +-------------+
#   |             |     git     |
#   +-------------+-------------+
set -u
. "$(dirname "$0")/lib.sh"

MODE="${1:-here}"

case "$MODE" in
  workspace)
    out=$("$HERDR" workspace create --cwd "$ROOT" --label "$(basename "$ROOT")" --focus 2>/dev/null) \
      || die "workspace create failed"
    left=$(printf '%s' "$out" | "$JQ" -r '.result.root_pane.pane_id // empty')
    ;;
  here)
    [ -n "$WS" ] || die "no active workspace"
    [ -n "$TAB" ] || die "no active tab"
    [ -n "$PANE" ] || die "no active pane"
    require_single_pane_tab "$WS" "$TAB"
    left="$PANE"
    ;;
  *) die "unknown mode: $MODE" ;;
esac
[ -n "$left" ] || die "no root pane id"

right=$("$HERDR" pane split --pane "$left" --direction right --ratio 0.5 --cwd "$ROOT" --no-focus 2>/dev/null \
  | "$JQ" -r '.result.pane.pane_id // empty')
[ -n "$right" ] || die "split right failed"

bottom=$("$HERDR" pane split --pane "$right" --direction down --ratio 0.5 --cwd "$ROOT" --no-focus 2>/dev/null \
  | "$JQ" -r '.result.pane.pane_id // empty')
[ -n "$bottom" ] || die "split down failed"

"$HERDR" pane rename "$left" agent >/dev/null 2>&1
"$HERDR" pane rename "$right" server >/dev/null 2>&1
"$HERDR" pane rename "$bottom" git >/dev/null 2>&1

# Focus already sits on the left pane: `workspace create --focus` lands on the root pane
# and both splits are --no-focus.

if wait_prompt "$left"; then
  "$HERDR" pane run "$left" claude >/dev/null 2>&1
else
  say "left pane never reached a prompt; skipped claude"
fi

run_dev "$right"
run_git_status "$bottom"
