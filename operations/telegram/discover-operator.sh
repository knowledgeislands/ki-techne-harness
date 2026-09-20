#!/usr/bin/env bash
set -euo pipefail

: "${TELEGRAM_BOT_TOKEN:?set TELEGRAM_BOT_TOKEN without writing it to shell history}"

payload=$(curl --fail --silent --show-error --max-time 40 \
  --data-urlencode 'timeout=30' \
  --data-urlencode 'limit=20' \
  --data-urlencode 'allowed_updates=["message"]' \
  "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/getUpdates")

jq --exit-status '
  [.result[]
   | select(.message.chat.type == "private")
   | {
       update_id,
       user_id: .message.from.id,
      chat_id: .message.chat.id,
      initial_offset: (.update_id + 1),
       username: (.message.from.username // null),
       date: .message.date
     }]
' <<<"${payload}"

echo 'No update was confirmed or deleted. Verify the selected numeric IDs before deployment.' >&2
