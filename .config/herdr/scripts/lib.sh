#!/bin/sh
# Shared helpers for the layout scripts. Sourced, never executed.
# Sets HERDR, JQ, WS, TAB, PANE, CWD, ROOT.

LOG="${HOME}/.config/herdr/layout.log"
say() { printf '%s: %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$1" >>"$LOG"; }
die() { say "$1"; exit 1; }

# These run detached with no terminal, so PATH is not guaranteed to include Homebrew.
PATH="/opt/homebrew/bin:/usr/local/bin:${HOME}/.local/bin:${PATH}"
export PATH

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

WS="${HERDR_ACTIVE_WORKSPACE_ID:-}"
TAB="${HERDR_ACTIVE_TAB_ID:-}"
PANE="${HERDR_ACTIVE_PANE_ID:-}"
CWD="${HERDR_ACTIVE_PANE_CWD:-$HOME}"

# Panes open at the repo root rather than wherever the caller happened to be.
ROOT=$(git -C "$CWD" rev-parse --show-toplevel 2>/dev/null) || ROOT=""
[ -n "$ROOT" ] || ROOT="$CWD"

# The server pane's command, most specific source first. A `.herdr-dev` file in the repo
# root wins so a project with an odd runner does not need a change here.
dev_command() {
  if [ -r "$ROOT/.herdr-dev" ]; then
    head -n 1 "$ROOT/.herdr-dev"
    return
  fi
  if [ -r "$ROOT/package.json" ]; then
    for s in dev start; do
      if "$JQ" -e --arg s "$s" '.scripts[$s] // empty' "$ROOT/package.json" >/dev/null 2>&1; then
        printf 'pnpm %s\n' "$s"
        return
      fi
    done
  fi
  for f in justfile Justfile .justfile; do
    if [ -r "$ROOT/$f" ] && grep -qE '^dev:' "$ROOT/$f"; then
      echo "just dev"
      return
    fi
  done
  if [ -r "$ROOT/Makefile" ] && grep -qE '^dev:' "$ROOT/Makefile"; then
    echo "make dev"
  fi
}

# True when the pane's shell is at its prompt with nothing else in the foreground.
# An idle shell reports *itself* in foreground_processes, so compare against shell_pid
# rather than testing for an empty list.
pane_at_prompt() {
  "$HERDR" pane process-info --pane "$1" 2>/dev/null \
    | "$JQ" -e '.result.process_info
             | .shell_pid as $s
             | ($s != null) and all(.foreground_processes[]?; .pid == $s)' >/dev/null 2>&1
}

# `pane run` is send-text + Enter, so a pane has to reach its prompt before it is usable.
wait_prompt() {
  i=0
  while [ "$i" -lt 50 ]; do
    pane_at_prompt "$1" && return 0
    sleep 0.1
    i=$((i + 1))
  done
  return 1
}

# Refuse to stack a layout on top of an existing split.
require_single_pane_tab() {
  n=$("$HERDR" pane list --workspace "$1" 2>/dev/null \
    | "$JQ" -r --arg t "$2" '[.result.panes[] | select(.tab_id == $t)] | length')
  [ "${n:-1}" = "1" ] || die "tab already has $n panes; not rebuilding"
}

# Run a detected multi-word command line in a pane, once it is at its prompt.
run_dev() {
  pane=$1
  cmd=$(dev_command)
  if [ -z "$cmd" ]; then
    say "no dev command found under $ROOT; left server pane at a prompt"
    return
  fi
  wait_prompt "$pane" || return
  # Deliberately unquoted: cmd is a short command line that needs word splitting.
  # shellcheck disable=SC2086
  "$HERDR" pane run "$pane" $cmd >/dev/null 2>&1
}

run_git_status() {
  git -C "$ROOT" rev-parse --git-dir >/dev/null 2>&1 || return
  wait_prompt "$1" || return
  "$HERDR" pane run "$1" git status -sb >/dev/null 2>&1
}
