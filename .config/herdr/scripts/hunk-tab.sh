#!/bin/sh
# prefix+d — open (or reuse) a "hunk" tab in the current workspace and run `hunk diff`.
set -u

LOG="${HOME}/.config/herdr/hunk-tab.log"
die() { printf '%s: %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$1" >>"$LOG"; exit 1; }

# This runs detached with no terminal, so PATH is not guaranteed to include Homebrew.
# HERDR_BIN_PATH is injected by Herdr but undocumented as file-vs-directory; trust it only
# when it is an executable file, then fall back to PATH, then to known install locations.
HERDR=""
if [ -n "${HERDR_BIN_PATH:-}" ] && [ -x "${HERDR_BIN_PATH}" ]; then
  HERDR="$HERDR_BIN_PATH"
elif command -v herdr >/dev/null 2>&1; then
  HERDR=herdr
else
  for c in /opt/homebrew/bin/herdr /usr/local/bin/herdr "$HOME/.local/bin/herdr"; do
    [ -x "$c" ] && { HERDR="$c"; break; }
  done
fi
[ -n "$HERDR" ] || die "herdr binary not found (PATH=$PATH)"

JQ=""
if command -v jq >/dev/null 2>&1; then
  JQ=jq
else
  for c in /usr/bin/jq /opt/homebrew/bin/jq /usr/local/bin/jq; do
    [ -x "$c" ] && { JQ="$c"; break; }
  done
fi
[ -n "$JQ" ] || die "jq not found (PATH=$PATH)"

LABEL="hunk"
WS="${HERDR_ACTIVE_WORKSPACE_ID:-}"
CWD="${HERDR_ACTIVE_PANE_CWD:-}"

[ -n "$WS" ] || exit 0

# True when the pane's shell is at its prompt with nothing else in the foreground.
# An idle shell reports *itself* in foreground_processes, so compare against shell_pid
# rather than testing for an empty list.
pane_at_prompt() {
  "$HERDR" pane process-info --pane "$1" 2>/dev/null \
    | "$JQ" -e '.result.process_info
             | .shell_pid as $s
             | ($s != null) and all(.foreground_processes[]?; .pid == $s)' >/dev/null 2>&1
}

tab=$("$HERDR" tab list --workspace "$WS" 2>/dev/null \
  | "$JQ" -r --arg l "$LABEL" 'first(.result.tabs[] | select(.label == $l) | .tab_id) // empty')

if [ -n "$tab" ]; then
  pane=$("$HERDR" pane list --workspace "$WS" 2>/dev/null \
    | "$JQ" -r --arg t "$tab" 'first(.result.panes[] | select(.tab_id == $t) | .pane_id) // empty')
  "$HERDR" tab focus "$tab" >/dev/null 2>&1
  [ -n "$pane" ] || exit 0

  # Something is already running there (hunk itself, an editor, anything). Focus only —
  # sending the command would just type keystrokes into that program.
  pane_at_prompt "$pane" || exit 0
else
  if [ -n "$CWD" ]; then
    out=$("$HERDR" tab create --workspace "$WS" --cwd "$CWD" --label "$LABEL" --focus 2>/dev/null)
  else
    out=$("$HERDR" tab create --workspace "$WS" --label "$LABEL" --focus 2>/dev/null)
  fi
  pane=$(printf '%s' "$out" | "$JQ" -r '.result.root_pane.pane_id // empty')
  [ -n "$pane" ] || exit 1

  # `pane run` is send-text + Enter; wait for the new shell to reach its prompt first.
  i=0
  while [ "$i" -lt 50 ]; do
    pane_at_prompt "$pane" && break
    sleep 0.1
    i=$((i + 1))
  done
fi

"$HERDR" pane run "$pane" hunk diff >/dev/null 2>&1
