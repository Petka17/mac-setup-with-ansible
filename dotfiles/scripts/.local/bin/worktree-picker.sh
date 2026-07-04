#!/usr/bin/env bash

# git worktree picker. One entry point, four routes:
#
#   worktree-picker.sh [switch|new|branch|remove]
#
# No argument opens an fzf menu of the routes, so a single keybinding covers
# everything while each route stays directly scriptable.
#
#   switch — pick an existing worktree, create-or-switch its tmux session
#   new    — pick an existing branch, add a worktree for it, open a session
#   branch — type a new branch name, add a worktree for it, open a session
#   remove — pick a worktree, delete it (confirm if dirty) + kill its session
#
# Meant to run from the MAIN repo checkout, inside tmux (see `bind C-g` in
# tmux.conf). Worktrees live next to the repo: <repo>.worktrees/<branch>,
# where <repo> is the folder name up to the first dot. Sessions are named
# "<repo>/<branch>" explicitly (rather than via sesh) so worktrees of
# different repos with the same branch name never collide.
#
# Plain fzf (not fzf-tmux) keeps this portable across a shell prompt and a
# tmux display-popup, same as sesh-picker.sh.

set -e

main_repo=$(git rev-parse --show-toplevel) || {
  echo "not in a git repo" >&2
  exit 1
}

base=$(basename "$main_repo")
base=${base%%.*}
wt_root=$(dirname "$main_repo")/$base.worktrees

FZF=(fzf --no-sort --ansi --height 40% --reverse --prompt '⚡  ')

# feature/foo → feature-foo: keeps .worktrees flat and removal leftover-free.
branch_to_dir() { printf '%s' "${1//\//-}"; }

# tmux rejects '.' and ':' in session names; slashes are fine.
session_name() {
  local s
  s="$base/$(branch_to_dir "$1")"
  s=${s//./_}
  printf '%s' "${s//:/_}"
}

# Create-or-switch a tmux session ($1) rooted at path ($2). Always called
# from inside tmux, so switch-client (not attach) is the right move.
connect() {
  tmux has-session -t "=$1" 2> /dev/null || tmux new-session -ds "$1" -c "$2"
  tmux switch-client -t "=$1"
}

# Worktrees of this repo as "path<TAB>branch", main checkout excluded.
list_worktrees() {
  git -C "$main_repo" worktree list --porcelain | awk -v main="$main_repo" '
    /^worktree / { path = substr($0, 10) }
    /^branch /   { br = substr($0, 8); sub("refs/heads/", "", br)
                   if (path != main) printf "%s\t%s\n", path, br }'
}

# Shared picker for switch/remove: shows branch, returns "path<TAB>branch".
pick_worktree() {
  local list
  list=$(list_worktrees)
  if [ -z "$list" ]; then
    echo "no worktrees yet — create one first" >&2
    sleep 1.5
    exit 0
  fi
  awk -F'\t' '{ printf "%s\t%s\n", $2, $0 }' <<< "$list" | "${FZF[@]}" \
    --delimiter=$'\t' --with-nth=1 --accept-nth=2,3 \
    --border-label " $1 "
}

do_switch() {
  local selected wt_path branch
  selected=$(pick_worktree 'switch worktree')
  [ -z "$selected" ] && exit 0
  IFS=$'\t' read -r wt_path branch <<< "$selected"
  connect "$(session_name "$branch")" "$wt_path"
}

do_new() {
  # Branches already checked out anywhere (incl. main) can't get a second
  # worktree — git enforces one checkout per branch — so hide them.
  local used branch wt_path
  used=$(git -C "$main_repo" worktree list --porcelain \
    | sed -n 's|^branch refs/heads/||p')
  branch=$(git -C "$main_repo" for-each-ref refs/heads \
    --format='%(refname:short)' \
    | grep -vxF -f <(printf '%s\n' "$used") \
    | "${FZF[@]}" --border-label ' worktree from branch ') || true
  [ -z "$branch" ] && exit 0
  wt_path=$wt_root/$(branch_to_dir "$branch")
  mkdir -p "$wt_root"
  git -C "$main_repo" worktree add "$wt_path" "$branch"
  connect "$(session_name "$branch")" "$wt_path"
}

do_branch() {
  local branch wt_path
  printf 'New branch name: '
  read -r branch
  [ -z "$branch" ] && exit 0
  git check-ref-format --branch "$branch" > /dev/null || {
    echo "invalid branch name: $branch" >&2
    sleep 1.5
    exit 1
  }
  wt_path=$wt_root/$(branch_to_dir "$branch")
  mkdir -p "$wt_root"
  git -C "$main_repo" worktree add -b "$branch" "$wt_path"
  connect "$(session_name "$branch")" "$wt_path"
}

do_remove() {
  local selected wt_path branch session answer force=()
  selected=$(pick_worktree 'remove worktree')
  [ -z "$selected" ] && exit 0
  IFS=$'\t' read -r wt_path branch <<< "$selected"

  if [ -n "$(git -C "$wt_path" status --porcelain)" ]; then
    answer=$(printf 'No\nYes — delete anyway\n' | "${FZF[@]}" \
      --border-label " $branch has uncommitted changes — delete? ")
    [[ $answer == Yes* ]] || exit 0
    force=(--force)
  fi

  # Removing the worktree we're currently in: move the client to the main
  # repo's session first so kill-session doesn't yank the popup away.
  session=$(session_name "$branch")
  if [ -n "${TMUX:-}" ] && [ "$(tmux display-message -p '#S')" = "$session" ]; then
    connect "$base" "$main_repo"
  fi
  tmux kill-session -t "=$session" 2> /dev/null || true
  git -C "$main_repo" worktree remove "${force[@]}" "$wt_path"
}

route="${1:-}"
if [ -z "$route" ]; then
  route=$(printf '%s\n' \
    $'switch\tjump to an existing worktree' \
    $'new\tnew worktree from an existing branch' \
    $'branch\tnew worktree on a new branch' \
    $'remove\tdelete a worktree (and its session)' \
    | "${FZF[@]}" --delimiter=$'\t' --accept-nth=1 \
      --border-label ' worktree ') || true
  [ -z "$route" ] && exit 0
fi

case "$route" in
  switch) do_switch ;;
  new) do_new ;;
  branch) do_branch ;;
  remove) do_remove ;;
  *)
    echo "usage: worktree-picker.sh [switch|new|branch|remove]" >&2
    exit 1
    ;;
esac
