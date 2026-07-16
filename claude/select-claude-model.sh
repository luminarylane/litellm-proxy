#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

# Work mode applies only to the native Claude launcher (the direct GLM/Kimi
# launchers do not read CLAUDE_PROFILE).
choose_profile() {
  clear
  echo "╔══════════════════════════════════════════════════════════════╗"
  echo "║                  CLAUDE CODE • WORK MODE                     ║"
  echo "╚══════════════════════════════════════════════════════════════╝"
  echo
  echo "  [1] Fast      Focused edits, searches, and quick fixes"
  echo "               Low effort; drops to Sonnet"
  echo "  [2] Balanced  Everyday implementation and debugging  [default]"
  echo "               Medium effort; Opus Plan Mode (Opus plans, Sonnet executes)"
  echo "  [3] Deep      Architecture, difficult bugs, and broad reviews"
  echo "               High effort; full Opus"
  echo
  read -r -p "Choose work mode [1-3, Enter=Balanced]: " profile_choice

  case "$profile_choice" in
    ""|2) CLAUDE_PROFILE="default" ;;
    1) CLAUDE_PROFILE="fast" ;;
    3) CLAUDE_PROFILE="deep" ;;
    *)
      echo "❌ Invalid work mode. Choose 1, 2, or 3." >&2
      exit 1
      ;;
  esac
}

clear
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║                 CLAUDE CODE • MODEL SELECTOR                 ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo
echo "  [1] Claude       1M  • Best subscription value; hardest work"
echo "      Opus / Sonnet / Haiku family (native, caching works)"
echo "  [2] Kimi Coding Plan    262k • Direct Kimi; not LiteLLM-metered"
echo "  [3] Z.ai GLM-5.2  1M • Direct Z.ai; all Claude tiers map to GLM-5.2"
echo "  [4] Z.ai GLM-4.7  200k • Direct Z.ai; all Claude tiers map to GLM-4.7"
echo
echo "  For GPT use OpenAI Codex (run: codex) and for Gemini use Google"
echo "  Antigravity (run: agy) directly — their own native agents, not routed"
echo "  through Claude Code."
echo
echo "  [q] Quit"
echo
read -r -p "Choose model [1-4]: " choice

case "$choice" in
  1)
    echo "▶ Starting Claude family (native)..."
    choose_profile
    echo "▶ Work mode: $CLAUDE_PROFILE"
    CLAUDE_PROFILE="$CLAUDE_PROFILE" "$SCRIPT_DIR/start-claude-claude.sh"
    ;;
  2)
    echo "▶ Starting Kimi Coding Plan (direct)..."
    exec "$SCRIPT_DIR/start-claude-kimi.sh"
    ;;
  3)
    echo "▶ Starting Z.ai GLM-5.2 (direct)..."
    exec "$SCRIPT_DIR/start-claude-glm-5-2.sh"
    ;;
  4)
    echo "▶ Starting Z.ai GLM-4.7 (direct, short 200k-context sessions)..."
    exec "$SCRIPT_DIR/start-claude-glm-4-7.sh"
    ;;
  q|Q)
    exit 0
    ;;
  *)
    echo "❌ Invalid model. Choose 1-4, or q to quit." >&2
    exit 1
    ;;
esac
