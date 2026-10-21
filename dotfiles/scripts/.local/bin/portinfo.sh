#!/usr/bin/env bash

# portinfo.sh — what's listening on a port, and where from.
#
#   portinfo.sh <port>
#
# For every process listening on <port> show its working directory and,
# when the process lives inside tmux, the session, window and pane it was
# started from — the answer to "which of my many tmux sessions did I
# start this dev server in?". The tmux location is found by walking the
# process's parent chain and matching it against every pane's pane_pid,
# so the server's shell (and therefore the right pane) is found even
# though the pane itself is only running the shell.

set -e

if [ $# -ne 1 ]; then
  echo "usage: portinfo.sh <port>" >&2
  exit 1
fi

port=$1

pids=$(lsof -tiTCP:"$port" -sTCP:LISTEN 2> /dev/null | sort -un) || true
if [ -z "$pids" ]; then
  echo "nothing is listening on port $port" >&2
  exit 1
fi

# pane_pid → "session:window.pane" for every pane in every session, one per
# line — bash 3.2 (macOS default) has no associative arrays, so lookup goes
# through awk instead of a hash. The separator tab must be baked in via $'…':
# tmux 3.7 does not decode \t escapes in format strings.
panes=
if command -v tmux > /dev/null 2>&1; then
  panes=$(tmux list-panes -a -F $'#{pane_pid}\t#{session_name}:#{window_index}.#{pane_index}' 2> /dev/null)
fi

# Walk the parent chain of $1 up to init; echo the first pane found, if any.
find_pane() {
  local p=$1 line
  while [ "$p" -gt 1 ]; do
    line=$(printf '%s\n' "$panes" | awk -F'\t' -v pid="$p" '$1 == pid { print $2; exit }')
    if [ -n "$line" ]; then
      printf '%s' "$line"
      return 0
    fi
    p=$(ps -o ppid= -p "$p" 2> /dev/null | tr -d ' ')
    [ -n "$p" ] || return 1
  done
  return 1
}

for pid in $pids; do
  command=$(ps -o command= -p "$pid" 2> /dev/null || true)
  cwd=$(lsof -a -p "$pid" -d cwd -Fn 2> /dev/null | sed -n 's/^n//p' || true)
  printf 'port %s — pid %s: %s\n' "$port" "$pid" "${command:-<exited>}"
  [ -n "$cwd" ] && printf '  cwd:  %s\n' "$cwd"
  if pane=$(find_pane "$pid"); then
    printf '  tmux: %s\n' "$pane"
  fi
done