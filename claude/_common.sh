#!/bin/bash
# Shared PLUMBING for the Claude Code launchers — checks + backend-agnostic env.
# Deliberately holds NO cost levers (caching, compaction, effort, model tier):
# those differ per backend and live in each launcher. Sourced, not executed.

require_claude() {
  if ! command -v claude &>/dev/null; then
    echo "❌ claude is not installed." >&2
    echo "please install it and try again." >&2
    exit 2
  fi
  echo "✅ claude is installed."
}

require_mcp_json() {
  if [[ ! -f .mcp.json ]]; then
    echo "❌ .mcp.json is missing in current directory." >&2
    echo "run this launcher from the repository you want Claude Code to work in." >&2
    exit 1
  fi
  echo "✅ .mcp.json found"
}

get_context_name() {
    # 1. Try tmux
    if [ -n "${TMUX:-}" ]; then
        tmux display-message -p '#S'
    # 2. If not tmux, try git
    elif git rev-parse --is-inside-work-tree > /dev/null 2>&1; then
        basename "$(git rev-parse --show-toplevel)"
    fi
}

# require_proxy <port> — LiteLLM-routed launchers only.
require_proxy() {
  local port="$1"
  if ! nc -z localhost "$port"; then
    echo "❌ litellm is not running." >&2
    echo "clone litellm-proxy repo (https://github.com/luminarylane/litellm-proxy), configure .env from .env.docker.example, then run ./run.sh docker and try again." >&2
    exit 1
  fi
  echo "✅ litellm proxy is running and listening on port $port."
}

# export_plumbing_env — backend-agnostic env only. Cost-neutral or universally
# safe. NOTE: MAX_MCP_OUTPUT_TOKENS is intentionally NOT set here — each launcher
# picks its own cap (tighter on cacheless proxied backends).
export_plumbing_env() {
  # Umbrella flag: covers telemetry, bug-report, error-report, autoupdater.
  # Replaces the four individual DISABLE_* flags the launchers used to set.
  export CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1
  # Suppress billed side model calls (flavor text, auto summaries) — a real,
  # small token saver, distinct from the traffic umbrella above.
  export DISABLE_NON_ESSENTIAL_MODEL_CALLS=1
  # Defer MCP tool schemas, load on demand (version-dependent; safe if ignored).
  export ENABLE_TOOL_SEARCH=true
  export BASH_MAX_OUTPUT_LENGTH=12000
  export BASH_DEFAULT_TIMEOUT_MS=180000
  export CLAUDE_BASH_MAINTAIN_PROJECT_WORKING_DIR=1
  export CLAUDE_CODE_NO_FLICKER=1
  export MCP_CONNECTION_NONBLOCKING=true
  export CLAUDE_PROJECT_DIR="$(pwd)"
}
