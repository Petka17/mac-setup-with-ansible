#!/usr/bin/env bash

# Unified sesh picker. Works both inside and outside tmux: `sesh connect`
# attaches when outside tmux and switch-clients when already inside.
#
#   sesh-picker.sh            list active sessions + zoxide dirs + configs
#   sesh-picker.sh sessions   list active tmux sessions only
#
# Plain fzf (not fzf-tmux) keeps this portable across every caller: a shell
# prompt, a tmux display-popup, and `tmux neww` from Neovim.

set -e

if [ "${1:-}" = "sessions" ]; then
  selected=$(sesh list -t --icons | fzf \
    --no-sort --ansi --height 40% --reverse \
    --border-label ' tmux sessions ' --prompt '⚡  ')
else
  selected=$(sesh list --icons | fzf \
    --no-sort --ansi --height 40% --reverse \
    --border-label ' sesh ' --prompt '⚡  ')
fi

[ -z "$selected" ] && exit 0

sesh connect "$selected"
