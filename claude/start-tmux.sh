#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

if ! which tmux &>/dev/null; then
  echo "❌ tmux is not installed." >&2
  echo "please install it and try again." >&2
  exit 1
fi
echo "✅ tmux is installed."

if ! which lazygit &> /dev/null; then
  echo "❌ lazygit is not installed." >&2
  echo "please install it and try again." >&2
  exit 1
fi
echo "✅ lazygit is installed."

TMUX_SESSION_NAME="${1:-}"
if [[ -z "$TMUX_SESSION_NAME" ]]; then
  echo "❌ please use a session name and try again." >&2
  exit 4
fi
echo "✅ TMUX_SESSION_NAME=$TMUX_SESSION_NAME"

tmux set -g pane-border-status top
tmux set -g pane-border-format " [ #{pane_title} ] "
tmux set -g pane-active-border-style "fg=green,bg=default"
tmux set -g pane-border-style "fg=default,bg=default,dim"

tmux new-session -d -s "$TMUX_SESSION_NAME" -n claude

tmux split-window -h -t "$TMUX_SESSION_NAME":1
tmux select-layout -t "$TMUX_SESSION_NAME":1 main-vertical
tmux resize-pane -t "$TMUX_SESSION_NAME":1.2 -L 80
tmux select-pane -t "$TMUX_SESSION_NAME":1.1 -T "Notes/Scratch"
tmux select-pane -t "$TMUX_SESSION_NAME":1.2 -T "Claude Code"

tmux send-keys -t "$TMUX_SESSION_NAME":1.1 "vim ~/scratch.$TMUX_SESSION_NAME.md" Enter
tmux send-keys -t "$TMUX_SESSION_NAME":1.2 "TMUX_SESSION_NAME=$(printf '%q' "$TMUX_SESSION_NAME") $(printf '%q' "$SCRIPT_DIR/select-claude-model.sh")" Enter

tmux new-window -t "$TMUX_SESSION_NAME": -n lazygit "lazygit"

tmux attach-session -t "$TMUX_SESSION_NAME":1
