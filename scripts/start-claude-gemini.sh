#!/bin/bash
set -euo pipefail

# LiteLLM and model specific vars
LITELLM_BASE_URL="http://localhost:4000"
LITELLM_VIRTUAL_KEY="sk-claude-code-gemini"
LITELLM_MODEL_NAME="gemini/gemini-3.1-pro-preview"

# Default model names
DEFAULT_OPUS_MODEL="gemini/gemini-3.1-pro-preview"
DEFAULT_SONNET_MODEL="gemini/gemini-3.1-pro-preview"
DEFAULT_HAIKU_MODEL="gemini/gemini-3.5-flash"

# Model specific details, autocompact at 80%
MODEL_MAX_TOKEN_WINDOW=1000000
MODEL_AUTO_COMPACT_WINDOW=800000

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

if ! nc -z localhost 4000; then
  echo "❌ litellm is not running." >&2
  echo "clone litellm-proxy repo (https://github.com/luminarylane/litellm-proxy) then ./setup.sh and then ./run.sh and try again." >&2
  exit 1
fi
echo "✅ litellm proxy is running and listening on port 4000."

# Token use optimizations
MODEL_AUTOCOMPACT_PCT_OVERRIDE=80
MODEL_MAX_OUTPUT_TOKENS=32768
CODE_EFFORT_LEVEL="medium"
MAX_THINKING_TOKENS=4000
API_TIMEOUT_MS=300000
BASH_MAX_OUTPUT_LENGTH=25000
BASH_DEFAULT_TIMEOUT_MS=180000

export ANTHROPIC_BASE_URL=$LITELLM_BASE_URL && \
export ANTHROPIC_AUTH_TOKEN=$LITELLM_VIRTUAL_KEY && \
export ANTHROPIC_MODEL=$LITELLM_MODEL_NAME && \
export ANTHROPIC_DEFAULT_OPUS_MODEL=$DEFAULT_OPUS_MODEL && \
export ANTHROPIC_DEFAULT_SONNET_MODEL=$DEFAULT_SONNET_MODEL && \
export ANTHROPIC_DEFAULT_HAIKU_MODEL=$DEFAULT_HAIKU_MODEL && \
export CLAUDE_CODE_MAX_CONTEXT_TOKENS=$MODEL_MAX_TOKEN_WINDOW && \
export CLAUDE_CODE_AUTO_COMPACT_WINDOW=$MODEL_AUTO_COMPACT_WINDOW && \
export CLAUDE_AUTOCOMPACT_PCT_OVERRIDE=$MODEL_AUTOCOMPACT_PCT_OVERRIDE && \
export CLAUDE_CODE_MAX_OUTPUT_TOKENS=$MODEL_MAX_OUTPUT_TOKENS && \
export CLAUDE_CODE_EFFORT_LEVEL=$CODE_EFFORT_LEVEL && \
export MAX_THINKING_TOKENS=$MAX_THINKING_TOKENS && \
export API_TIMEOUT_MS=$API_TIMEOUT_MS && \
export BASH_MAX_OUTPUT_LENGTH=$BASH_MAX_OUTPUT_LENGTH && \
export BASH_DEFAULT_TIMEOUT_MS=$BASH_DEFAULT_TIMEOUT_MS && \
export CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1 && \
export DISABLE_NON_ESSENTIAL_MODEL_CALLS=1 && \
export ENABLE_TOOL_SEARCH=true && \
export DISABLE_TELEMETRY=1 && \
export CLAUDE_CODE_ENABLE_TELEMETRY=0 && \
export DISABLE_BUG_COMMAND=1 && \
export DISABLE_COST_WARNINGS=1 && \
export DISABLE_ERROR_REPORTING=1 && \
export CLAUDE_BASH_MAINTAIN_PROJECT_WORKING_DIR=1 && \
export CLAUDE_CODE_ENABLE_GATEWAY_MODEL_DISCOVERY=1 && \
export CLAUDE_CODE_NO_FLICKER=1 && \
export MCP_CONNECTION_NONBLOCKING=true && \
export CLAUDE_PROJECT_DIR=$(pwd) && \
claude \
--continue \
--permission-mode=bypassPermissions \
--brief \
--mcp-config ./.mcp.json \
--model $LITELLM_MODEL_NAME \
--name "LiteLLM-$LITELLM_MODEL_NAME"
