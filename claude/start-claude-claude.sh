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

CLAUDE_PROFILE="${CLAUDE_PROFILE:-default}"
case "$CLAUDE_PROFILE" in
  fast)
    MAX_THINKING_TOKENS=4000
    CLAUDE_CODE_MAX_OUTPUT_TOKENS=16384
    CLAUDE_CODE_EFFORT_LEVEL="low"
    ;;
  default)
    MAX_THINKING_TOKENS=8000
    CLAUDE_CODE_MAX_OUTPUT_TOKENS=32768
    CLAUDE_CODE_EFFORT_LEVEL="medium"
    ;;
  deep)
    MAX_THINKING_TOKENS=16000
    CLAUDE_CODE_MAX_OUTPUT_TOKENS=32768
    CLAUDE_CODE_EFFORT_LEVEL="high"
    ;;
  *)
    echo "❌ Invalid CLAUDE_PROFILE: $CLAUDE_PROFILE (use fast, default, or deep)." >&2
    exit 1
    ;;
esac

echo "⚙️  Profile: $CLAUDE_PROFILE | thinking: $MAX_THINKING_TOKENS | output: $CLAUDE_CODE_MAX_OUTPUT_TOKENS | effort: $CLAUDE_CODE_EFFORT_LEVEL"

export CLAUDE_PROJECT_DIR="$(pwd)"
export CLAUDE_CODE_NO_FLICKER=1
export MCP_CONNECTION_NONBLOCKING=true
export MAX_THINKING_TOKENS
export CLAUDE_CODE_MAX_OUTPUT_TOKENS
export CLAUDE_CODE_EFFORT_LEVEL
export BASH_MAX_OUTPUT_LENGTH=12000
export BASH_DEFAULT_TIMEOUT_MS=180000

claude \
  --continue \
  --chrome \
  --permission-mode=bypassPermissions \
  --brief \
  --mcp-config ./.mcp.json \
  --name="Anthropic Claude" \
  "${remote_control_args[@]}"
