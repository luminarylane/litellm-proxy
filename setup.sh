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

if nc -z localhost "$LITELLM_PORT"; then
  echo "❌ LiteLLM proxy is already running and listening on port $LITELLM_PORT." >&2
  echo "Stop the running proxy and try again." >&2
  exit 1
fi
echo "✅ Port $LITELLM_PORT is available."

for required_file in config.yaml pyproject.toml uv.lock; do
  if [ ! -f "$required_file" ]; then
    echo "❌ '$required_file' is missing. Cannot bootstrap the proxy." >&2
    exit 1
  fi
  echo "✅ $required_file found."
done

if [ ! -d ".git" ]; then
    echo "❌ This script expects to run from the litellm-proxy repository root." >&2
    exit 1
fi

echo "🔄 Syncing virtual environment..."
uv sync

if ! uv run python -c "import litellm" >/dev/null 2>&1; then
    echo "❌ LiteLLM import check failed after uv sync." >&2
    exit 1
fi
echo "✅ LiteLLM is installed."

prisma_schema=$(uv run python -c "import os, litellm; print(os.path.join(os.path.dirname(litellm.__file__), 'proxy', 'schema.prisma'))")
if ! uv run python -m prisma generate --schema="$prisma_schema" >/dev/null; then
    echo "❌ Prisma client generation failed." >&2
    exit 1
fi
echo "✅ Prisma client generated."

echo "🚀 Launching LiteLLM proxy in background (logs in $PROXY_LOG)..."

uv run litellm --config config.yaml --port "$LITELLM_PORT" --use_v2_migration_resolver > "$PROXY_LOG" 2>&1 &
LITELLM_PID=$!
trap "kill $LITELLM_PID 2>/dev/null || true" EXIT

echo "⏳ Waiting for LiteLLM healthcheck..."
TIMEOUT=30
ELAPSED=0
while ! curl -s "http://localhost:${LITELLM_PORT}/health" &> /dev/null; do
    sleep 1
    ELAPSED=$((ELAPSED + 1))

    if ! kill -0 "$LITELLM_PID" 2>/dev/null; then
        echo "❌ LiteLLM proxy failed to start! Printing last 15 lines of $PROXY_LOG:" >&2
        tail -n 15 "$PROXY_LOG" >&2
        exit 1
    fi

    if [ "$ELAPSED" -ge "$TIMEOUT" ]; then
        echo "❌ Timeout waiting for LiteLLM proxy to become healthy!" >&2
        exit 1
    fi
done

echo "✅ Proxy is healthy and running on port $LITELLM_PORT!"
echo "🔄 Registering reusable virtual-key aliases for the included launchers..."

# --- REGISTER THE OPENAI VIRTUAL PROFILE ---
HTTP_CODE_OPENAI=$(curl -s -o /dev/null -w "%{http_code}" -X POST "http://localhost:${LITELLM_PORT}/key/generate" \
     -H "Authorization: Bearer $LITELLM_MASTER_KEY" \
     -H "Content-Type: application/json" \
     -d "{
       \"key\": \"$LITELLM_OPENAI_VIRTUAL_KEY\",
       \"aliases\": {
         \"claude-opus-4-7\": \"openai/gpt-5.5\",
         \"claude-sonnet-4-6\": \"openai/gpt-5.4\",
         \"claude-haiku-4-6\": \"openai/gpt-5.4-mini\"
       }
     }")

if [ "$HTTP_CODE_OPENAI" -eq 200 ] || [ "$HTTP_CODE_OPENAI" -eq 201 ]; then
    echo "✅ OpenAI profile alias mapped to: $LITELLM_OPENAI_VIRTUAL_KEY"
else
    echo "❌ OpenAI key registration failed with HTTP status: $HTTP_CODE_OPENAI" >&2
fi

# --- REGISTER THE GEMINI VIRTUAL PROFILE ---
HTTP_CODE_GEMINI=$(curl -s -o /dev/null -w "%{http_code}" -X POST "http://localhost:${LITELLM_PORT}/key/generate" \
     -H "Authorization: Bearer $LITELLM_MASTER_KEY" \
     -H "Content-Type: application/json" \
     -d "{
       \"key\": \"$LITELLM_GEMINI_VIRTUAL_KEY\",
       \"aliases\": {
         \"claude-opus-4-7\": \"gemini/gemini-3.1-pro-preview\",
         \"claude-sonnet-4-6\": \"gemini/gemini-3.1-pro-preview\",
         \"claude-haiku-4-6\": \"gemini/gemini-3.5-flash\"
       }
     }")

if [ "$HTTP_CODE_GEMINI" -eq 200 ] || [ "$HTTP_CODE_GEMINI" -eq 201 ]; then
    echo "✅ Gemini profile alias mapped to: $LITELLM_GEMINI_VIRTUAL_KEY"
else
    echo "❌ Gemini key registration failed with HTTP status: $HTTP_CODE_GEMINI" >&2
fi

echo "🎉 Key registration completed successfully!"

trap - EXIT

echo "📺 Tailing $PROXY_LOG to monitor operations in real time (Press Ctrl+C to stop trailing)..."
tail -f "$PROXY_LOG"
