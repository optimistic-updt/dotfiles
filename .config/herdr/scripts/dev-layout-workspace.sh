#!/bin/sh
# prefix+shift+s — dev-layout.sh in a new workspace.
# A separate entry point rather than an argument, because it is not documented whether
# Herdr shell-splits the `command` string in [[keys.command]].
exec "$(dirname "$0")/dev-layout.sh" workspace
