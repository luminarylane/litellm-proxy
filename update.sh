#!/bin/bash

uv lock --upgrade
uv sync

#!/bin/bash
set -euo pipefail

LITELLM_PORT="${LITELLM_PORT:-4000}"
REDIS_PORT="${REDIS_PORT:-6379}"
PROXY_LOG="litellm_proxy.log"

if [ ! -f ".env" ]; then
    echo "❌ .env file is missing in current directory. Cannot start LiteLLM proxy." >&2
    echo "Copy .env.example to .env and fill in the required values first." >&2
    exit 1
fi
echo "✅ .env file found. Loading variables..."

# shellcheck disable=SC1091
set -a
source .env
set +a

required_vars=(
  OPENAI_API_KEY
  GEMINI_API_KEY
  GEMINI_API_KEY_ALT
  LITELLM_MASTER_KEY
  LITELLM_DATABASE_URL
  LITELLM_OPENAI_VIRTUAL_KEY
  LITELLM_OPENAI_5_6_VIRTUAL_KEY
  LITELLM_GEMINI_VIRTUAL_KEY
)
for var_name in "${required_vars[@]}"; do
  if [ -z "${!var_name:-}" ]; then
    echo "❌ Required environment variable '$var_name' is missing from .env" >&2
    exit 1
  fi
done
echo "✅ Required environment variables loaded."

for cmd in curl nc tail; do
  if ! command -v "$cmd" &> /dev/null; then
    echo "❌ '$cmd' is not installed. Please install it and try again." >&2
    exit 1
  fi
  echo "✅ $cmd is installed."
done

if ! echo "PING" | nc -w 2 "localhost" "$REDIS_PORT" 2>/dev/null | grep -q "PONG"; then
    echo "❌ Redis is down or unreachable on port $REDIS_PORT!" >&2
    echo "Please start Redis on localhost and try again." >&2
    exit 1
fi
echo "✅ Redis is active on port $REDIS_PORT."

if ! nc -z localhost "$LITELLM_PORT"; then
  echo "❌ LiteLLM proxy is not running and listening on port $LITELLM_PORT." >&2
  echo "Start the proxy and try again." >&2
  exit 1
fi
echo "✅ LiteLLM proxy is runing and listening on Port $LITELLM_PORT"


HTTP_CODE_OPENAI=$(curl -s -o /dev/null -w "%{http_code}" -X POST "http://localhost:${LITELLM_PORT}/key/generate" \
     -H "Authorization: Bearer $LITELLM_MASTER_KEY" \
     -H "Content-Type: application/json" \
     -d "{
       \"key\": \"$LITELLM_OPENAI_5_6_VIRTUAL_KEY\",
       \"aliases\": {
         \"claude-opus-4-7\": \"openai/gpt-5.6-sol\",
         \"claude-sonnet-4-6\": \"openai/gpt-5.6-terra\",
         \"claude-haiku-4-6\": \"openai/gpt-5.6-luna\"
       }
     }")

if [ "$HTTP_CODE_OPENAI" -eq 200 ] || [ "$HTTP_CODE_OPENAI" -eq 201 ]; then
    echo "✅ OpenAI 5.6 profile alias mapped to: $LITELLM_OPENAI_5_6_VIRTUAL_KEY"
else
    echo "❌ OpenAI key registration failed with HTTP status: $HTTP_CODE_OPENAI" >&2
fi
