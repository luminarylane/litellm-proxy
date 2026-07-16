#!/bin/bash
# OpenAI Codex on the GPT-5.4 family (400k context; the token-lean option you
# found "sipped" vs 5.6). Native GPT — caching works, no bridge.
# Work mode (CODEX_PROFILE) maps to model tier + reasoning effort:
#   fast    -> gpt-5.4-mini + low     (quick edits, searches, trivial fixes)
#   default -> gpt-5.4      + medium  (everyday implementation and debugging)
#   deep    -> gpt-5.5      + high    (architecture, hard bugs, broad reviews)
# Passes through any extra args (e.g. a prompt) to codex.
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_common.sh
source "$SCRIPT_DIR/_common.sh"

require_codex

CODEX_PROFILE="${CODEX_PROFILE:-default}"
case "$CODEX_PROFILE" in
  fast)    MODEL="gpt-5.4-mini"; EFFORT="low" ;;
  default) MODEL="gpt-5.4";      EFFORT="medium" ;;
  deep)    MODEL="gpt-5.5";      EFFORT="high" ;;
  *)
    echo "❌ Invalid CODEX_PROFILE: $CODEX_PROFILE (use fast, default, or deep)." >&2
    exit 1
    ;;
esac
echo "⚙️  Codex GPT-5.4 | mode: $CODEX_PROFILE | model: $MODEL | reasoning: $EFFORT"

exec codex -m "$MODEL" -c model_reasoning_effort="$EFFORT" "$@"
