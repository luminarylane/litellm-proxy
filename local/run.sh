#!/bin/bash
set -euo pipefail

REPO_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_DIR"

LITELLM_PORT="${LITELLM_PORT:-4000}"
REDIS_PORT="${REDIS_PORT:-6379}"

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
)
for var_name in "${required_vars[@]}"; do
  if [ -z "${!var_name:-}" ]; then
    echo "❌ Required environment variable '$var_name' is missing from .env" >&2
    exit 1
  fi
done
echo "✅ Required environment variables loaded."

if ! command -v uv &> /dev/null; then
    echo "❌ uv is not installed." >&2
    echo "Please install uv: https://docs.astral.sh/uv/getting-started/installation/" >&2
    exit 1
fi
echo "✅ uv is installed."

if [ ! -d ".venv" ]; then
    echo "❌ .venv is missing. Please run ./local/setup.sh first." >&2
    exit 1
fi
echo "✅ Virtual environment exists."

if ! uv run python -c "import litellm" >/dev/null 2>&1; then
    echo "❌ LiteLLM is not installed in the local virtual environment." >&2
    echo "Please run ./local/setup.sh first." >&2
    exit 1
fi
echo "✅ LiteLLM is installed."

if [ ! -f "config.yaml" ]; then
    echo "❌ config.yaml file is missing. Cannot start LiteLLM proxy." >&2
    exit 1
fi
echo "✅ config.yaml found."

if ! command -v nc &> /dev/null; then
    echo "❌ netcat (nc) is not installed." >&2
    exit 1
fi
echo "✅ netcat is installed."

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

echo "🚀 Starting LiteLLM proxy on port $LITELLM_PORT..."
uv run litellm --config config.yaml --port "$LITELLM_PORT" --use_v2_migration_resolver --num_workers 1 --telemetry False
