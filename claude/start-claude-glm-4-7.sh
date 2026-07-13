#!/bin/bash
# Direct Z.ai Coding Plan launcher for GLM-4.7 (short, 200k-context sessions).
set -euo pipefail

ENV_FILE=".env.local"
if [[ -f "$ENV_FILE" ]]; then
  set -a
  source "$ENV_FILE"
  set +a
fi

: "${ZAI_CODING_API_KEY:?ZAI_CODING_API_KEY must be set in the environment or local .env.local.}"

if ! command -v claude &>/dev/null; then
  echo "claude is not installed." >&2
  exit 2
fi

if [[ ! -f .mcp.json ]]; then
  echo ".mcp.json is missing in the current directory." >&2
  exit 1
fi

# GLM-4.7 is intentionally constrained to short 200k-context sessions. Every
# Claude tier is deliberately pinned to GLM-4.7; do not cross-map model tiers.
unset ANTHROPIC_API_KEY
export ANTHROPIC_BASE_URL="https://api.z.ai/api/anthropic"
export ANTHROPIC_AUTH_TOKEN="$ZAI_CODING_API_KEY"
export ANTHROPIC_MODEL="glm-4.7"
export ANTHROPIC_DEFAULT_OPUS_MODEL="glm-4.7"
export ANTHROPIC_DEFAULT_SONNET_MODEL="glm-4.7"
export ANTHROPIC_DEFAULT_HAIKU_MODEL="glm-4.7"
export CLAUDE_CODE_MAX_CONTEXT_TOKENS=200000

exec claude \
  --continue \
  --permission-mode=bypassPermissions \
  --mcp-config ./.mcp.json
