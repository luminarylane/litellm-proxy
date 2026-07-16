#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

# Work mode maps to model tier + reasoning effort inside each family launcher.
choose_profile() {
  clear
  echo "╔══════════════════════════════════════════════════════════════╗"
  echo "║                     CODEX • WORK MODE                        ║"
  echo "╚══════════════════════════════════════════════════════════════╝"
  echo
  echo "  [1] Fast      Quick edits, searches, trivial fixes"
  echo "               Cheapest tier + low reasoning"
  echo "  [2] Balanced  Everyday implementation and debugging  [default]"
  echo "               Mid tier + medium reasoning"
  echo "  [3] Deep      Architecture, hard bugs, broad reviews"
  echo "               Flagship tier + high reasoning"
  echo
  read -r -p "Choose work mode [1-3, Enter=Balanced]: " profile_choice
  case "$profile_choice" in
    ""|2) CODEX_PROFILE="default" ;;
    1) CODEX_PROFILE="fast" ;;
    3) CODEX_PROFILE="deep" ;;
    *)
      echo "❌ Invalid work mode. Choose 1, 2, or 3." >&2
      exit 1
      ;;
  esac
}

clear
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║                    CODEX • MODEL SELECTOR                    ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo
echo "  [1] GPT-5.6   stronger family (sol / terra / luna)"
echo "  [2] GPT-5.4   leaner, token-thrifty family (5.5 / 5.4 / 5.4-mini)"
echo
echo "  Native GPT via OpenAI Codex — caching works, no LiteLLM bridge."
echo
echo "  [q] Quit"
echo
read -r -p "Choose family [1-2]: " choice

case "$choice" in
  1) LAUNCHER="start-codex-gpt-5-6.sh" ;;
  2) LAUNCHER="start-codex-gpt-5-4.sh" ;;
  q|Q) exit 0 ;;
  *)
    echo "❌ Invalid choice. Choose 1, 2, or q." >&2
    exit 1
    ;;
esac

choose_profile
echo "▶ Work mode: $CODEX_PROFILE"
CODEX_PROFILE="$CODEX_PROFILE" exec "$SCRIPT_DIR/$LAUNCHER" "$@"
