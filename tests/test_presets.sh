#!/bin/sh

set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$ROOT"

command -v jq >/dev/null 2>&1 || {
  printf 'jq is required for preset validation\n' >&2
  exit 1
}

sh -n src/touchbar_cached_value.sh
python3 -m py_compile scripts/generate_presets.py

expected_uuid=3A49CBCE-DE02-4F8F-A70E-6BA367ACD683

for provider_file in \
  binance:crypto-price-Binance.json \
  coinbase:crypto-price-Coinbase.json \
  gemini:crypto-price-Gemini.json \
  okx:crypto-price-OKX.json \
  kucoin:crypto-price-KuCoin.json \
  near-intents:crypto-price-NEAR-Intents.json
do
  provider=${provider_file%%:*}
  preset=${provider_file#*:}

  jq empty "$preset"

  preset_uuid=$(jq -r '.BTTPresetUUID' "$preset")
  [ "$preset_uuid" = "$expected_uuid" ] || {
    printf '%s has an unexpected preset UUID\n' "$preset" >&2
    exit 1
  }

  price_call_count=$(jq --arg provider "$provider" '
    [
      .. | objects | .BTTTouchBarAppleScriptString? // empty
      | select(contains(" price " + $provider + " "))
    ] | length
  ' "$preset")
  [ "$price_call_count" -eq 5 ] || {
    printf '%s has %s price calls; expected 5\n' "$preset" "$price_call_count" >&2
    exit 1
  }

  direct_network_count=$(jq '
    [
      .. | objects | .BTTTouchBarAppleScriptString? // empty
      | select(contains("curl ") or contains("https://"))
    ] | length
  ' "$preset")
  [ "$direct_network_count" -eq 0 ] || {
    printf '%s still performs network work inside AppleScript\n' "$preset" >&2
    exit 1
  }
done

printf 'All provider presets are valid and non-blocking.\n'
