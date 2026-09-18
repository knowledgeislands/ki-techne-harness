#!/usr/bin/env bash
set -euo pipefail

if ((EUID != 0)); then
  echo 'run this script as root on the controller host' >&2
  exit 1
fi

script_root=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

"${script_root}/enable-secrets-encryption-on-controller.sh"

read -r -s -p 'Telegram bot token: ' TELEGRAM_BOT_TOKEN
printf '\n'
read -r -p 'Telegram operator user ID: ' TELEGRAM_OPERATOR_USER_ID
read -r -p 'Telegram operator chat ID: ' TELEGRAM_OPERATOR_CHAT_ID
read -r -p 'Telegram initial update offset: ' TELEGRAM_INITIAL_OFFSET

[[ -n ${TELEGRAM_BOT_TOKEN} ]] || { echo 'bot token cannot be empty' >&2; exit 1; }
[[ ${TELEGRAM_OPERATOR_USER_ID} =~ ^[0-9]+$ ]] || { echo 'operator user ID must be numeric' >&2; exit 1; }
[[ ${TELEGRAM_OPERATOR_CHAT_ID} =~ ^-?[0-9]+$ ]] || { echo 'operator chat ID must be numeric' >&2; exit 1; }
[[ ${TELEGRAM_INITIAL_OFFSET} =~ ^[0-9]+$ ]] || { echo 'initial update offset must be numeric' >&2; exit 1; }

export TELEGRAM_BOT_TOKEN TELEGRAM_OPERATOR_USER_ID TELEGRAM_OPERATOR_CHAT_ID TELEGRAM_INITIAL_OFFSET
trap 'unset TELEGRAM_BOT_TOKEN TELEGRAM_OPERATOR_USER_ID TELEGRAM_OPERATOR_CHAT_ID TELEGRAM_INITIAL_OFFSET' EXIT

"${script_root}/deploy-on-controller.sh"
