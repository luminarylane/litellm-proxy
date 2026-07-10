#!/bin/bash
set -euo pipefail

REPO_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

usage() {
  cat <<'EOF'
Usage: ./run.sh [docker|local]

  docker  Start the self-contained LiteLLM, Postgres, and Redis Docker Compose stack.
  local   Start the host-managed LiteLLM runtime from ./local/run.sh.

Without an argument, choose the deployment mode interactively.
EOF
}

start_docker() {
  if ! command -v docker >/dev/null 2>&1; then
    echo "❌ Docker with the Compose plugin is required for Docker mode." >&2
    exit 1
  fi

  if [[ ! -f "$REPO_DIR/.env" ]]; then
    echo "❌ .env is missing. Copy .env.example to .env and set the required secrets first." >&2
    exit 1
  fi

  exec docker compose --project-directory "$REPO_DIR" up --detach
}

start_local() {
  exec "$REPO_DIR/local/run.sh"
}

case "${1:-}" in
  docker)
    start_docker
    ;;
  local)
    start_local
    ;;
  "")
    printf 'Choose LiteLLM deployment mode:\n'
    printf '  1) Docker Compose (recommended; LiteLLM + Postgres + Redis)\n'
    printf '  2) Local host runtime (requires externally managed Redis + Postgres)\n'
    read -r -p 'Enter choice [1-2]: ' choice

    case "$choice" in
      1) start_docker ;;
      2) start_local ;;
      *)
        echo "❌ Invalid choice. Run ./run.sh docker or ./run.sh local." >&2
        exit 1
        ;;
    esac
    ;;
  -h|--help|help)
    usage
    ;;
  *)
    echo "❌ Unknown deployment mode: $1" >&2
    usage >&2
    exit 1
    ;;
esac
