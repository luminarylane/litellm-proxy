#!/bin/bash
# Shared plumbing for the Codex launchers. Sourced, not executed.
#
# Codex talks to OpenAI natively — prompt caching works, prompt shape is native,
# so these launchers are simpler than the Claude ones: they only pick a model
# tier and a reasoning-effort per work mode. No cache/prompt workarounds needed.
#
# Model IDs below match what the OpenAI API served through the old LiteLLM route
# (confirmed by real spend logs) and codex's own config default (gpt-5.6-sol).
# If codex uses different aliases on your account, run `codex models` in a
# terminal and adjust the case blocks in the launchers.

require_codex() {
  if ! command -v codex &>/dev/null; then
    echo "❌ codex is not installed (brew install codex / npm i -g @openai/codex)." >&2
    exit 2
  fi
  echo "✅ codex is installed."
}
