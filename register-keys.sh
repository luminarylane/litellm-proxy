#!/bin/sh
set -eu

required_vars="
  LITELLM_MASTER_KEY
  LITELLM_SALT_KEY
  LITELLM_OPENAI_VIRTUAL_KEY
  LITELLM_OPENAI_5_6_VIRTUAL_KEY
  LITELLM_GEMINI_VIRTUAL_KEY
"
for var_name in $required_vars; do
  eval "value=\${$var_name:-}"
  if [ -z "$value" ]; then
    echo "❌ Required environment variable '$var_name' is missing." >&2
    exit 1
  fi
done

litellm_url="${LITELLM_URL:-http://127.0.0.1:${LITELLM_PORT:-4000}}"
attempt=1
while [ "$attempt" -le 30 ]; do
  if curl --fail --silent --output /dev/null \
    --header "Authorization: Bearer ${LITELLM_MASTER_KEY}" \
    "${litellm_url}/health"; then
    break
  fi

  if [ "$attempt" -eq 30 ]; then
    echo "❌ LiteLLM proxy did not become healthy while registering virtual keys." >&2
    exit 1
  fi

  attempt=$((attempt + 1))
  sleep 1
done

register_key() {
  virtual_key="$1"
  aliases="$2"

  http_code=$(curl --silent --output /dev/null --write-out "%{http_code}" \
    --request POST "${litellm_url}/key/generate" \
    --header "Authorization: Bearer ${LITELLM_MASTER_KEY}" \
    --header "Content-Type: application/json" \
    --data "{\"key\":\"${virtual_key}\",\"aliases\":${aliases}}")

  if [ "$http_code" != "200" ] && [ "$http_code" != "201" ]; then
    echo "❌ Virtual-key registration failed with HTTP status: ${http_code}" >&2
    return 1
  fi
}

register_key "$LITELLM_OPENAI_5_6_VIRTUAL_KEY" '{"claude-opus-4-7":"openai/gpt-5.6-sol","claude-sonnet-4-6":"openai/gpt-5.6-terra","claude-haiku-4-6":"openai/gpt-5.6-luna"}'
register_key "$LITELLM_OPENAI_VIRTUAL_KEY" '{"claude-opus-4-7":"openai/gpt-5.5","claude-sonnet-4-6":"openai/gpt-5.4","claude-haiku-4-6":"openai/gpt-5.4-mini"}'
register_key "$LITELLM_GEMINI_VIRTUAL_KEY" '{"claude-opus-4-7":"gemini/gemini-3.1-pro-preview","claude-sonnet-4-6":"gemini/gemini-3.5-flash"}'

echo "✅ Registered Claude Code virtual-key aliases."
