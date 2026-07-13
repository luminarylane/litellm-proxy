#!/bin/bash
set -euo pipefail

ENV_FILE=".env.local"
if [[ -f "$ENV_FILE" ]]; then
  set -a
  source "$ENV_FILE"
  set +a
fi

: "${KIMI_CODING_API_KEY:[REDACTED:API key param] must be set in the environment or local .env.local.}"

if ! command -v claude &>/dev/null; then
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

unset ANTHROPIC_API_KEY
export ANTHROPIC_BASE_URL="https://api.kimi.com/coding/"
export ANTHROPIC_AUTH_TOKEN="$KIMI_CODING_API_KEY"
export CLAUDE_CODE_AUTO_COMPACT_WINDOW=262144

claude \
  --continue \
  --permission-mode=bypassPermissions \
  --mcp-config ./.mcp.json
