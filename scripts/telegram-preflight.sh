#!/usr/bin/env bash
set -euo pipefail

: "${TELEGRAM_BOT_TOKEN:?set TELEGRAM_BOT_TOKEN without writing it to shell history}"

telegram_api="https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}"
identity=$(curl --fail --silent --show-error --max-time 15 "${telegram_api}/getMe")
webhook=$(curl --fail --silent --show-error --max-time 15 "${telegram_api}/getWebhookInfo")

jq -n \
  --argjson identity "${identity}" \
  --argjson webhook "${webhook}" \
  '{
    ok: ($identity.ok and $webhook.ok),
    username: $identity.result.username,
    bot_id: $identity.result.id,
    has_webhook: (($webhook.result.url // "") | length > 0),
    pending_update_count: ($webhook.result.pending_update_count // 0)
  }'

if [[ $(jq -r '.result.username // ""' <<<"${identity}") != 'kitteth_bot' ]]; then
  echo 'bot identity mismatch; expected @kitteth_bot' >&2
  exit 1
fi

if [[ -n $(jq -r '.result.url // ""' <<<"${webhook}") ]]; then
  echo 'active webhook detected; refusing to displace it' >&2
  exit 1
fi
