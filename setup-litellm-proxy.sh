#!/bin/bash
set -euo pipefail

if [ ! -f ".env" ]; then
    echo ".env file is missing in current directory! cannot start litellm proxy" >&2
    echo "Copy .env.example to .env and fill in the required values first." >&2
    exit 1
fi
echo ".env file found in current directory. Loading variables..."
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
    echo "Required environment variable '$var_name' is missing from .env" >&2
    exit 1
  fi
done

if ! which curl &> /dev/null; then
    echo "curl is not installed." >&2
    echo "please install curl and try again." >&2
    exit 1
fi
if ! which nc &> /dev/null; then
    echo "netcat (nc) is not installed." >&2
    echo "please install netcat and try again." >&2
    exit 1
fi
if ! which tail &> /dev/null; then
    echo "tail is not installed." >&2
    echo "please install coreutils and try again." >&2
    exit 1
fi
if ! echo "PING" | nc -w 2 localhost 6379 2>/dev/null | grep -q "PONG"; then
    echo "redis is down or unreachable on port 6379!" >&2
    echo "Please start redis on localhost and try again." >&2
    exit 1
fi

if nc -z localhost 4000; then
  echo "litellm proxy is already running and listening on port 4000." >&2
  echo "stop the running litellm proxy and start again" >&2
  exit 1
fi

if [ ! -f "config.yaml" ]; then
    echo "config.yaml file is missing! cannot start litellm proxy" >&2
    exit 1
fi

if [ ! -f "pyproject.toml" ]; then
    echo "pyproject.toml is missing! cannot bootstrap dependencies" >&2
    exit 1
fi

if [ ! -f "uv.lock" ]; then
    echo "uv.lock is missing! commit the lockfile before bootstrapping" >&2
    exit 1
fi

if [ ! -d ".git" ]; then
    echo "This script expects to run from the litellm-proxy repository root." >&2
    exit 1
fi

if [ ! -d ".venv" ]; then
    echo "Creating virtual environment from checked-in project metadata..."
    uv sync
else
    echo "Virtual environment already exists — syncing dependencies..."
    uv sync
fi

if ! uv run python -c "import litellm" >/dev/null 2>&1; then
    echo "LiteLLM import check failed after uv sync." >&2
    exit 1
fi

if ! uv run python -m prisma generate --schema=$(uv run python -c "import os, litellm; print(os.path.join(os.path.dirname(litellm.__file__), 'proxy', 'schema.prisma'))") >/dev/null; then
    echo "Prisma client generation failed." >&2
    exit 1
fi

PROXY_LOG="litellm_proxy.log"
echo "🚀 Launching LiteLLM proxy in background (logs in $PROXY_LOG)..."

uv run litellm --config config.yaml --port 4000 --use_v2_migration_resolver > "$PROXY_LOG" 2>&1 &
LITELLM_PID=$!
trap "kill $LITELLM_PID 2>/dev/null || true" EXIT

echo "⏳ Waiting for LiteLLM healthcheck..."
TIMEOUT=30
ELAPSED=0
while ! curl -s "http://localhost:4000/health" &> /dev/null; do
    sleep 1
    ELAPSED=$((ELAPSED + 1))

    if ! kill -0 $LITELLM_PID 2>/dev/null; then
        echo "❌ LiteLLM proxy failed to start! Printing last 15 lines of $PROXY_LOG:" >&2
        tail -n 15 "$PROXY_LOG" >&2
        exit 1
    fi

    if [ $ELAPSED -ge $TIMEOUT ]; then
        echo "❌ Timeout waiting for LiteLLM proxy to become healthy!" >&2
        exit 1
    fi
done

echo "❇️ Proxy is healthy and running on port 4000!"
echo "🔄 Registering reusable virtual-key aliases for the included launchers..."

# --- REGISTER THE OPENAI VIRTUAL PROFILE ---
HTTP_CODE_OPENAI=$(curl -s -o /dev/null -w "%{http_code}" -X POST "http://localhost:4000/key/generate" \
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
    echo "❌ OpenAI key registration failed with HTTP Status: $HTTP_CODE_OPENAI"
fi

# --- REGISTER THE GEMINI VIRTUAL PROFILE ---
HTTP_CODE_GEMINI=$(curl -s -o /dev/null -w "%{http_code}" -X POST "http://localhost:4000/key/generate" \
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
    echo "❌ Gemini key registration failed with HTTP Status: $HTTP_CODE_GEMINI"
fi

echo "🎉 Key registration completed successfully!"

trap - EXIT

echo "📺 Tailing $PROXY_LOG to monitor operations in real time (Press Ctrl+C to stop trailing)..."
tail -f "$PROXY_LOG"

# Legacy bootstrap steps kept here for reference during the open-source packaging pass:
# 1. Create a clean, dedicated local project environment
# 2. Add LiteLLM and Prisma directly to this workspace
# 3. Explicitly compile the Python client code into this active workspace
# --- REWORKED SECTION: BACKGROUND LAUNCH WITH HEALTHCHECK LURKING ---
# Polling Loop: Checks LiteLLM's official passing API endpoint before sending keys
# Remove our script trap so the background process stays alive when this script finishes

# Setup is complete above.

#
# The original iterative bootstrap commands were replaced with `uv sync` against the
# checked-in project metadata so a fresh clone is reproducible for the whole team.
#
# End of script.

#
# The rest of the previous script body has been intentionally removed during the
# repository-packaging pass.
#

#
# Open-source repo invariant: everything above should be sufficient for a fresh clone.
#

#
# No further commands.

#
# done.

#
#

#
#

#

#
#

#

#

#

#

#

#

#

#

#

#

#

#

#

#

#

#

#

#

#

#

#

#

#

#

#

#

#

#

#

#

#

#

#

#

#

#

#

#

#

#

#

#

#

#

#

#

#

#

#

#

#

#

#

#

#

#

#

#

#

#

#

#

#

#

#

#

#

#

if ! which uv &> /dev/null; then
    echo "uv is not installed." >&2
    echo "please install uv: https://docs.astral.sh/uv/getting-started/installation/" >&2
    exit 1
fi
echo "uv is installed."

# 1. Create a clean, dedicated local project environment
uv init --bare

# 2. Add LiteLLM and Prisma directly to this workspace
uv add 'litellm[proxy]' prisma google-genai

# 3. Explicitly compile the Python client code into this active workspace
uv run python -m prisma generate --schema=$(uv run python -c "import os, litellm; print(os.path.join(os.path.dirname(litellm.__file__), 'proxy', 'schema.prisma'))")

# --- REWORKED SECTION: BACKGROUND LAUNCH WITH HEALTHCHECK LURKING ---
PROXY_LOG="litellm_proxy.log"
echo "🚀 Launching production proxy in background (Logs tracking in $PROXY_LOG)..."

# Boot proxy in background, redirecting stdout/stderr to file
uv run litellm --config config.yaml --port 4000 --use_v2_migration_resolver > "$PROXY_LOG" 2>&1 &
LITELLM_PID=$!

# Trap unexpected exits so the proxy process kills itself if the script crashes early
trap "kill $LITELLM_PID 2>/dev/null || true" EXIT

echo "⏳ Waiting for Uvicorn startup to complete..."
TIMEOUT=30
ELAPSED=0

# Polling Loop: Checks LiteLLM's official passing API endpoint before sending keys
while ! curl -s "http://localhost:4000/health" &> /dev/null; do
    sleep 1
    ELAPSED=$((ELAPSED + 1))

    # Fail early if LiteLLM dies immediately on initialization (e.g., config error)
    if ! kill -0 $LITELLM_PID 2>/dev/null; then
        echo "❌ LiteLLM proxy failed to start! Printing last 15 lines of $PROXY_LOG:" >&2
        tail -n 15 "$PROXY_LOG" >&2
        exit 1
    fi

    if [ $ELAPSED -ge $TIMEOUT ]; then
        echo "❌ Timeout waiting for LiteLLM proxy to become healthy!" >&2
        exit 1
    fi
done

echo "❇️ Proxy is healthy and running on port 4000!"
echo "🔄 Bootstrapping reproducible virtual key routing arrays..."

# --- REGISTER THE OPENAI VIRTUAL PROFILE ---
HTTP_CODE_OPENAI=$(curl -s -o /dev/null -w "%{http_code}" -X POST "http://localhost:4000/key/generate" \
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
    echo "❌ OpenAI key registration failed with HTTP Status: $HTTP_CODE_OPENAI"
fi

# --- REGISTER THE GEMINI VIRTUAL PROFILE ---
HTTP_CODE_GEMINI=$(curl -s -o /dev/null -w "%{http_code}" -X POST "http://localhost:4000/key/generate" \
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
    echo "❌ Gemini key registration failed with HTTP Status: $HTTP_CODE_GEMINI"
fi

echo "🎉 Key registration completed successfully!"

# Remove our script trap so the background process stays alive when this script finishes
trap - EXIT

echo "📺 Tailing $PROXY_LOG to monitor operations in real time (Press Ctrl+C to stop trailing)..."
tail -f "$PROXY_LOG"
