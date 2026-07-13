#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

choose_profile() {
  clear
  echo "╔══════════════════════════════════════════════════════════════╗"
  echo "║                  CLAUDE CODE • WORK MODE                     ║"
  echo "╚══════════════════════════════════════════════════════════════╝"
  echo
  echo "  [1] Fast      Focused edits, searches, and quick fixes"
  echo "               Lower reasoning + 4k thinking cap"
  echo "  [2] Balanced  Everyday implementation and debugging  [default]"
  echo "               Model-tuned reasoning + 8k thinking cap"
  echo "  [3] Deep      Architecture, difficult bugs, and broad reviews"
  echo "               Higher reasoning + 16k thinking cap"
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
echo "      Opus / Sonnet / Haiku family"
echo "  [2] GPT-5.6      1.05M • Strong general-purpose coding"
echo "      Sol / Terra / Luna family"
echo "  [3] GPT-5.4      400k • Capable, balanced API option"
echo "      GPT-5.5 / GPT-5.4 / GPT-5.4-mini family"
echo "  [4] Kimi Coding Plan    262k • Direct Kimi; not LiteLLM-metered"
echo "  [5] Z.ai GLM-5.2  1M • Direct Z.ai; all Claude tiers map to GLM-5.2"
echo "  [6] Z.ai GLM-4.7  200k • Direct Z.ai; all Claude tiers map to GLM-4.7"
echo "  [7] Gemini 3.1   1M  • Large-context analysis and coding"
echo
echo "  [q] Quit"
echo
read -r -p "Choose model [1-7]: " choice

case "$choice" in
  1)
    MODEL_LABEL="Claude family"
    LAUNCHER="$SCRIPT_DIR/start-claude-claude.sh"
    ;;
  2)
    MODEL_LABEL="GPT-5.6 family"
    LAUNCHER="$SCRIPT_DIR/start-claude-gpt-5-6.sh"
    ;;
  3)
    MODEL_LABEL="GPT-5.4 family"
    LAUNCHER="$SCRIPT_DIR/start-claude-gpt-5-4.sh"
    ;;
  4)
    MODEL_LABEL="Kimi Coding Plan"
    LAUNCHER="$SCRIPT_DIR/start-claude-kimi.sh"
    ;;
  5)
    MODEL_LABEL="Z.ai GLM-5.2"
    LAUNCHER="$SCRIPT_DIR/start-claude-glm-5-2.sh"
    ;;
  6)
    MODEL_LABEL="Z.ai GLM-4.7 (short 200k-context sessions)"
    LAUNCHER="$SCRIPT_DIR/start-claude-glm-4-7.sh"
    ;;
  7)
    MODEL_LABEL="Gemini 3.1 family"
    LAUNCHER="$SCRIPT_DIR/start-claude-gemini.sh"
    ;;
  q|Q)
    exit 0
    ;;
  *)
    echo "❌ Invalid model. Choose 1-7, or q to quit." >&2
    exit 1
    ;;
esac

choose_profile
echo "▶ Starting $MODEL_LABEL in $CLAUDE_PROFILE mode..."
CLAUDE_PROFILE="$CLAUDE_PROFILE" "$LAUNCHER"
