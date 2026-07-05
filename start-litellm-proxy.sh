#!/bin/bash
set -euo pipefail

if [ ! -f ".env" ]; then
    echo "❌ ERROR: .env file is missing in current directory! cannot start LiteLLM proxy" >&2
    echo "Copy .env.example to .env and fill in the required values first." >&2
    exit 1
fi
echo "✅ .env file found in current directory. Loading variables..."
# shellcheck disable=SC1091
set -a
source .env
set +a

if ! which uv &> /dev/null; then
    echo "❌ ERROR: uv is not installed." >&2
    echo "please install uv: https://docs.astral.sh/uv/getting-started/installation/" >&2
    exit 1
fi
echo "✅ uv is installed."

if [ ! -d ".venv" ]; then
    echo "❌ ERROR: .venv is missing." >&2
    echo "please run ./setup-litellm-proxy.sh first." >&2
    exit 1
fi

if ! uv run python -c "import litellm" >/dev/null 2>&1; then
    echo "❌ ERROR: litellm is not installed in the local virtual environment." >&2
    echo "please run ./setup-litellm-proxy.sh first." >&2
    exit 1
fi
echo "✅ litellm is installed."

if [ ! -f "config.yaml" ]; then
    echo "❌ ERROR: config.yaml file is missing! cannot start LiteLLM proxy" >&2
    exit 1
fi
echo "✅ config.yaml file found."

if ! which nc &> /dev/null; then
    echo "❌ ERROR: netcat (nc) is not installed." >&2
    exit 1
fi

if ! echo "PING" | nc -w 2 localhost 6379 2>/dev/null | grep -q "PONG"; then
    echo "❌ ERROR: redis is down or unreachable on port 6379!" >&2
    echo "Please start redis on localhost" >&2
    exit 1
fi
echo "✅ redis is active and caching!"

if nc -z localhost 4000; then
  echo "LiteLLM proxy is already running and listening on port 4000." >&2
  echo "stop the running LiteLLM proxy and start again" >&2
  exit 1
fi
echo "✅ LiteLLM proxy is not running already"

echo "Starting LiteLLM proxy with the .env and config.yaml in the current directory..."
uv run litellm --config config.yaml --port 4000 --use_v2_migration_resolver --num_workers 4 --telemetry False
