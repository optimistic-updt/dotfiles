#!/usr/bin/env bash
# Bootstrap terminal config on a new machine.
#
# Prereqs: oh-my-zsh installed, this repo cloned to ~/dotfiles.
# Usage:   ~/dotfiles/terminal/setup.sh
#
# Idempotent — safe to re-run anytime.
set -euo pipefail

DOTFILES="$(cd "$(dirname "$0")/.." && pwd)"
THEMES="$HOME/.oh-my-zsh/custom/themes"

# dracula theme lives in a submodule; make sure it's populated
git -C "$DOTFILES" submodule update --init terminal/dracula

ln -sfn "$DOTFILES/terminal/.zshrc" "$HOME/.zshrc"

mkdir -p "$THEMES"
ln -sfn "$DOTFILES/terminal/agnoster.zsh-theme" "$THEMES/agnoster.zsh-theme"
ln -sfn "$DOTFILES/terminal/dracula/dracula.zsh-theme" "$THEMES/dracula.zsh-theme"

echo "Done. Open a new terminal to pick up changes."
