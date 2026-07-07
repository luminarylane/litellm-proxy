#!/bin/bash
set -euo pipefail

for cmd in tmux claude lazygit; do
  if ! command -v "$cmd" &> /dev/null; then
    echo "❌ '$cmd' is not installed. Please install it and try again." >&2
    exit 1
  fi
  echo "✅ $cmd is installed."
done

TMUX_SESSION_NAME="${1:-}"
if [[ -z "$TMUX_SESSION_NAME" ]]; then
    echo "❌ Please provide a session name and try again." >&2
    exit 4
fi
echo "✅ TMUX_SESSION_NAME=$TMUX_SESSION_NAME"

if [[ ! -f .mcp.json ]]; then
    echo "❌ .mcp.json is missing in current directory." >&2
    echo "Run this launcher from the repository you want Claude Code to work in." >&2
    exit 1
fi
echo "✅ .mcp.json found."

if ! nc -z localhost 4000; then
    echo "❌ litellm is not running." >&2
    echo "please run it and try again, see https://github.com/luminarylane/litellm-proxy" >&2
    exit 1
fi
echo "✅ litellm proxy is running and listening on port 4000."

# LiteLLM and model specific vars
LITELLM_VIRTUAL_KEY="sk-claude-code-gemini"
LITELLM_BASE_URL="http://localhost:4000"
LITELLM_MODEL_NAME="gemini/gemini-3.1-pro-preview"
LITELLM_MODEL_MAX_TOKEN_WINDOW=1000000
LITELLM_MODEL_AUTO_COMPACT_WINDOW=800000
LITELLM_MODEL_AUTO_COMPACT_PCT_OVERRIDE=80
LITELLM_MODEL_MAX_OUTPUT_TOKENS=32768
LITELLM_DEFAULT_OPUS_MODEL="gemini/gemini-3.1-pro-preview"
LITELLM_DEFAULT_SONNET_MODEL="gemini/gemini-3.1-pro-preview"
LITELLM_DEFAULT_HAIKU_MODEL="gemini/gemini-3.5-flash"
LITELLM_CODE_EFFORT_LEVEL="medium"
LITELLM_MAX_THINKING_TOKENS=4000
LITELLM_API_TIMEOUT_MS=300000
LITELLM_BASH_MAX_OUTPUT_LENGTH=25000
LITELLM_BASH_DEFAULT_TIMEOUT_MS=180000

# Create a new detached session and start Claude in window 0
tmux new-session -d -s "$TMUX_SESSION_NAME" -n claude "export ANTHROPIC_BASE_URL=$LITELLM_BASE_URL && export ANTHROPIC_MODEL=$LITELLM_MODEL_NAME && export ANTHROPIC_AUTH_TOKEN=$LITELLM_VIRTUAL_KEY && export CLAUDE_CODE_MAX_CONTEXT_TOKENS=$LITELLM_MODEL_MAX_TOKEN_WINDOW && export CLAUDE_CODE_AUTO_COMPACT_WINDOW=$LITELLM_MODEL_AUTO_COMPACT_WINDOW && export ANTHROPIC_DEFAULT_OPUS_MODEL=$LITELLM_DEFAULT_OPUS_MODEL && export ANTHROPIC_DEFAULT_SONNET_MODEL=$LITELLM_DEFAULT_SONNET_MODEL && export ANTHROPIC_DEFAULT_HAIKU_MODEL=$LITELLM_DEFAULT_HAIKU_MODEL && export CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1 && export DISABLE_NON_ESSENTIAL_MODEL_CALLS=1 && export ENABLE_TOOL_SEARCH=true && export DISABLE_TELEMETRY=1 && export DISABLE_BUG_COMMAND=1 && export DISABLE_COST_WARNINGS=1 && export DISABLE_ERROR_REPORTING=1 && export CLAUDE_BASH_MAINTAIN_PROJECT_WORKING_DIR=1 && export CLAUDE_CODE_ENABLE_GATEWAY_MODEL_DISCOVERY=1 && export CLAUDE_CODE_MAX_OUTPUT_TOKENS=$LITELLM_MODEL_MAX_OUTPUT_TOKENS && export CLAUDE_AUTOCOMPACT_PCT_OVERRIDE=$LITELLM_MODEL_AUTO_COMPACT_PCT_OVERRIDE && export CLAUDE_CODE_ENABLE_TELEMETRY=0 && export CLAUDE_CODE_NO_FLICKER=1 && export CLAUDE_CODE_EFFORT_LEVEL=$LITELLM_CODE_EFFORT_LEVEL && export MAX_THINKING_TOKENS=$LITELLM_MAX_THINKING_TOKENS && export API_TIMEOUT_MS=$LITELLM_API_TIMEOUT_MS && export MCP_CONNECTION_NONBLOCKING=true && export BASH_MAX_OUTPUT_LENGTH=$LITELLM_BASH_MAX_OUTPUT_LENGTH && export BASH_DEFAULT_TIMEOUT_MS=$LITELLM_BASH_DEFAULT_TIMEOUT_MS && export CLAUDE_PROJECT_DIR=$(pwd) && claude --continue --permission-mode=bypassPermissions --brief --mcp-config ./.mcp.json --model $LITELLM_MODEL_NAME"

# Create window 1 and start lazygit
tmux new-window -t "$TMUX_SESSION_NAME": -n lazygit "lazygit"

# Attach to the session on the lazygit window
tmux attach-session -t "$TMUX_SESSION_NAME":0
