#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

clear

echo "============================="
echo "CLAUDE CODE AI MODEL SELECTOR"
echo "============================="
echo "[1] Anthropic Claude family - Opus, Sonnet and Haiku, all 1M context window, Opus Default"
echo "[2] OpenAI GPT 5.6 family - Opus->Sol, Sonnet-Terra and Haiku->Luna, all 1M context window, Sonnet Default"
echo "[3] OpenAI GPT 5.4 family -  Opus->5.5, Sonnet->5.4 and Haiku->5.4-mini, all 400k context window, Sonnet Default"
echo "[4] Kimi Code K2.7 - Sonnet level only, 262k context window"
echo "[5] Z.ai GLM-5.2 - Opus level only, 1M context window"
echo "[6] Z.ai GLM-4.7 - Sonnet level only, 200k context window"
echo "[7] Google Gemini family - Opus/Sonnet->3.1-pro-preview, Haiku->3.5-Flash, 1M context window"
echo "[Any Other Key] Exit"
echo "======================================"

read -p "Enter your choice [1-7]: " choice

case $choice in
    1)
        echo "✅ Anthropic Claude family"
        "$SCRIPT_DIR/start-claude-claude.sh"
        ;;
    2)
        echo "✅ OpenAI GPT 5.6 family"
        "$SCRIPT_DIR/start-claude-gpt-5-6.sh"
        ;;
    3)
        echo "✅ OpenAI GPT 5.4 family"
        "$SCRIPT_DIR/start-claude-gpt-5-4.sh"
        ;;
    4)
        echo "✅ Kimi Code K2.7 only"
        "$SCRIPT_DIR/start-claude-kimi.sh"
        ;;
    5)
        echo "✅ Z.ai GLM-5.2 only"
        "$SCRIPT_DIR/start-claude-glm-5-2.sh"
        ;;
    6)
        echo "✅ Z.ai GLM-4.7 only"
        "$SCRIPT_DIR/start-claude-glm-4-7.sh"
        ;;
    7)
        echo "✅ Google Gemini family"
        "$SCRIPT_DIR/start-claude-gemini.sh"
        ;;
    *)
        echo "❌ Error: Invalid selection. Please choose a number between 1 and 7."
        exit 1
        ;;
esac
