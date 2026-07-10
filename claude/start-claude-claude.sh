#!/bin/bash
set -euo pipefail

if ! which claude &>/dev/null; then
  echo "❌ claude is not installed." >&2
  echo "please install it and try again." >&2
  exit 2
fi
echo "✅ claude is installed."

if [[ ! -f .mcp.json ]]; then
    echo "❌ .mcp.json is missing in current directory." >&2
    echo "run this launcher from the repository you want Claude Code to work in." >&2
    exit 1
fi
echo "✅ .mcp.json found"

remote_control_args=()
if [[ -n "${TMUX_SESSION_NAME:-}" ]]; then
  remote_control_args=("--remote-control=$TMUX_SESSION_NAME")
fi

export CLAUDE_PROJECT_DIR="$(pwd)"
export CLAUDE_CODE_NO_FLICKER=1
export MCP_CONNECTION_NONBLOCKING=true

claude \
  --continue \
  --chrome \
  --permission-mode=bypassPermissions \
  --brief \
  --mcp-config ./.mcp.json \
  --name="Anthropic Claude" \
  "${remote_control_args[@]}"
