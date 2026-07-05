#!/usr/bin/env bash

# sesh picker. Works both inside and outside tmux: `sesh connect` attaches when
# outside tmux and switch-clients when already inside. Lists active sessions +
# ~/code/*/* projects + the extra dirs from ~/.config/sesh-extra-dirs.
#
# The list is curated (not zoxide history): every ~/code/*/* project plus a
# few pinned destinations, deduped against the sessions already running. Each
# line is "<display>\t<connect-target>" — fzf shows the label (folder icon, and
# ~/code/ hidden so projects read as owner/repo) while `sesh connect` receives
# the real path. Connect by path lets the sesh.toml [[wildcard]] set up windows.
#
# Plain fzf (not fzf-tmux) keeps this portable across every caller: a shell
# prompt, a tmux display-popup, and `tmux neww` from Neovim.

set -e

# Non-repo destinations to always offer, one per line in
# ~/.config/sesh-extra-dirs (written by tasks/tmux.yml from the
# sesh_extra_dirs list in local.yml). Leading ~/ is expanded; blank
# lines and # comments are skipped.
EXTRA_DIRS=()
extra_dirs_file="${XDG_CONFIG_HOME:-$HOME/.config}/sesh-extra-dirs"
if [ -f "$extra_dirs_file" ]; then
  while IFS= read -r line; do
    case "$line" in '' | '#'*) continue ;; esac
    EXTRA_DIRS+=("${line/#\~\//$HOME/}")
  done < "$extra_dirs_file"
fi

# sesh's own directory icon (U+F114) in cyan; hex escape works under bash 3.2.
DIR_ICON=$'\033[36m\xef\x84\x94\033[39m'

picker_list() {
  # Active tmux sessions + configured sessions (e.g. ungit), deduped by sesh.
  # Target = same line (sesh strips its own icon on connect).
  sesh list -t -c -d --icons | while IFS= read -r line; do
    printf '%s\t%s\n' "$line" "$line"
  done

  # Paths already backing a session — skip these below to avoid duplicates.
  local active
  active=$(sesh list -t --json | jq -r '.[].Path')

  local dir label
  for dir in ~/code/*/*/ "${EXTRA_DIRS[@]}"; do
    [ -d "$dir" ] || continue                  # unmatched glob / missing extra
    dir=${dir%/}                               # strip trailing slash
    [[ $dir == *.worktrees ]] && continue      # worktrees have their own picker
    grep -qxF "$dir" <<< "$active" && continue # already an active session
    if [[ $dir == "$HOME"/code/* ]]; then
      label=${dir#"$HOME"/code/} # hide ~/code → owner/repo
    elif [[ $dir == "$HOME"/* ]]; then
      label=${dir#"$HOME"/} # other home paths → drop ~/
    else
      label=$dir
    fi
    printf '%s %s\t%s\n' "$DIR_ICON" "$label" "$dir"
  done
}

selected=$(picker_list | fzf \
  --no-sort --ansi --height 40% --reverse \
  --delimiter=$'\t' --with-nth=1 --accept-nth=2 \
  --border-label ' sesh ' --prompt '⚡  ')

[ -z "$selected" ] && exit 0

sesh connect "$selected"
