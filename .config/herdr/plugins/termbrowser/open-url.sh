#!/bin/sh
# Link-handler action for the termbrowser plugin.
# Herdr runs this on Ctrl+click of an http(s) URL with HERDR_PLUGIN_CLICKED_URL set
# (falls back to selected text / an argument so it also works as a plain action).
set -u

LOG="${HERDR_PLUGIN_STATE_DIR:-${HOME}/.config/herdr}/termbrowser.log"
say() { mkdir -p "$(dirname "$LOG")" 2>/dev/null; printf '%s: %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$1" >>"$LOG" 2>/dev/null; }
die() { say "$1"; exit 1; }

# Runs detached with no terminal, so PATH is not guaranteed to include Homebrew.
PATH="/opt/homebrew/bin:/usr/local/bin:${HOME}/.local/bin:${PATH}"
export PATH

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

command -v w3m >/dev/null 2>&1 || die "w3m not found (brew install w3m)"

CTX="${HERDR_PLUGIN_CONTEXT_JSON:-{\}}"
ctx() { printf '%s' "$CTX" | "$JQ" -r "$1 // empty" 2>/dev/null; }

URL="${HERDR_PLUGIN_CLICKED_URL:-}"
[ -n "$URL" ] || URL=$(ctx '.clicked_url')
[ -n "$URL" ] || URL=$(ctx '.selected_text')
[ -n "$URL" ] || URL="${1:-}"
URL=$(printf '%s' "$URL" | tr -d '[:space:]')
[ -n "$URL" ] || die "no URL to open (no clicked_url, selection, or argument)"

# `pane run` types the command into a shell, so the URL must be shell-safe.
# Only allow characters that can appear in a URL; anything else is refused.
case "$URL" in
  *[!A-Za-z0-9._~:/?#@!\$\&\(\)\*+,\;=%-]*) die "refusing URL with unsafe characters: $URL" ;;
esac
case "$URL" in
  http://*|https://*) ;;
  *) URL="https://$URL" ;;
esac

WS="${HERDR_WORKSPACE_ID:-}"
[ -n "$WS" ] || WS=$(ctx '.workspace_id')
[ -n "$WS" ] || WS="${HERDR_ACTIVE_WORKSPACE_ID:-}"
[ -n "$WS" ] || die "no workspace id in environment or context"

CWD=$(ctx '.focused_pane_cwd')
[ -n "$CWD" ] || CWD=$(ctx '.workspace_cwd')
[ -n "$CWD" ] || CWD="$HOME"

# Tab label: host plus a short path so several browser tabs stay tellable apart.
host=$(printf '%s' "$URL" | sed -E 's#^https?://##; s#/.*$##; s#^www\.##')
path=$(printf '%s' "$URL" | sed -E 's#^https?://[^/]*##; s#[?\#].*$##')
LABEL="🌐 ${host}${path}"
[ ${#LABEL} -le 40 ] || LABEL="$(printf '%s' "$LABEL" | cut -c1-39)…"

# True when the pane's shell is at its prompt with nothing else in the foreground.
# An idle shell reports *itself* in foreground_processes, so compare against shell_pid.
pane_at_prompt() {
  "$HERDR" pane process-info --pane "$1" 2>/dev/null \
    | "$JQ" -e '.result.process_info
             | .shell_pid as $s
             | ($s != null) and all(.foreground_processes[]?; .pid == $s)' >/dev/null 2>&1
}

out=$("$HERDR" tab create --workspace "$WS" --cwd "$CWD" --label "$LABEL" --focus 2>&1) \
  || die "tab create failed: $out"
pane=$(printf '%s' "$out" | "$JQ" -r '.result.root_pane.pane_id // empty')
[ -n "$pane" ] || die "tab create returned no root pane: $out"

# `pane run` is send-text + Enter; wait for the new shell to reach its prompt first.
i=0
while [ "$i" -lt 50 ]; do
  pane_at_prompt "$pane" && break
  sleep 0.1
  i=$((i + 1))
done

# Single-quote the URL for the shell; the character allowlist above excludes single quotes.
"$HERDR" pane run "$pane" "w3m '$URL'" >/dev/null 2>&1 || die "pane run failed for $pane"
say "opened $URL in $pane"
