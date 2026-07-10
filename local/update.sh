#!/bin/bash
set -euo pipefail

REPO_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_DIR"

if [[ ! -f .env ]]; then
  echo "❌ .env is missing. Copy .env.example to .env and set the required values first." >&2
  exit 1
fi

# shellcheck disable=SC1091
set -a
source .env
set +a

if ! command -v uv >/dev/null 2>&1; then
  echo "❌ uv is not installed. See https://docs.astral.sh/uv/getting-started/installation/." >&2
  exit 1
fi

uv lock --upgrade
uv sync

if ! command -v curl >/dev/null 2>&1; then
  echo "❌ curl is not installed." >&2
  exit 1
fi

LITELLM_URL="http://127.0.0.1:${LITELLM_PORT:-4000}" "$REPO_DIR/register-keys.sh"
