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

format_test_root=$(mktemp -d "${TMPDIR:-/tmp}/btt-price-format.XXXXXX")
trap 'rm -rf "$format_test_root"' EXIT HUP INT TERM
format_test_cache=$format_test_root/org.ruzcash.BetterTouchTool_Zcash/prices-binance.tsv
mkdir -p "$(dirname "$format_test_cache")"
printf 'BTC\t$1000.49\nETH\t$1000.49\nZEC\t$1000.49\nLTC\t$1000.49\nFIL\t$1000.49\nZEN\t$1000.49\n' > "$format_test_cache"

for format_test_symbol in BTC ETH ZEC LTC FIL ZEN; do
  formatted_high_price=$(TMPDIR=$format_test_root /bin/sh src/touchbar_cached_value.sh price binance "$format_test_symbol")
  [ "$formatted_high_price" = '$1000' ] || {
    printf '%s at or above $1000 must omit cents; got %s\n' \
      "$format_test_symbol" "$formatted_high_price" >&2
    exit 1
  }
done

printf 'LTC\t$999.49\n' > "$format_test_cache"
formatted_low_price=$(TMPDIR=$format_test_root /bin/sh src/touchbar_cached_value.sh price binance LTC)
[ "$formatted_low_price" = '$999.49' ] || {
  printf 'Prices below $1000 must preserve configured cents; got %s\n' "$formatted_low_price" >&2
  exit 1
}

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

  case "$provider" in
    binance|coinbase|okx|kucoin)
      expected_price_call_count=7
      expected_top_level_widgets='Bitcoin,Ethereum,Zcash,Litecoin,Filecoin,Horizen'
      expected_top_level_widths='112,96,112,96,96,96'
      ;;
    gemini|near-intents)
      expected_price_call_count=5
      expected_top_level_widgets='Bitcoin,Ethereum,Zcash,Litecoin'
      expected_top_level_widths='120,120,120,120'
      ;;
  esac

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
  [ "$price_call_count" -eq "$expected_price_call_count" ] || {
    printf '%s has %s price calls; expected %s\n' \
      "$preset" "$price_call_count" "$expected_price_call_count" >&2
    exit 1
  }

  top_level_widgets=$(jq -r '
    [
      .BTTPresetContent[0].BTTTriggers[]
      | select(.BTTWidgetName? != null)
      | .BTTWidgetName
    ] | join(",")
  ' "$preset")
  [ "$top_level_widgets" = "$expected_top_level_widgets" ] || {
    printf '%s has top-level widgets %s; expected %s\n' \
      "$preset" "$top_level_widgets" "$expected_top_level_widgets" >&2
    exit 1
  }

  top_level_widths=$(jq -r '
    [
      .BTTPresetContent[0].BTTTriggers[]
      | select(.BTTWidgetName? != null)
      | .BTTTriggerConfig.BTTTouchBarButtonWidth
    ] | join(",")
  ' "$preset")
  [ "$top_level_widths" = "$expected_top_level_widths" ] || {
    printf '%s has top-level widths %s; expected %s\n' \
      "$preset" "$top_level_widths" "$expected_top_level_widths" >&2
    exit 1
  }

  compact_padding_count=$(jq '
    [
      .BTTPresetContent[0].BTTTriggers[]
      | select(.BTTWidgetName? != null)
      | select(.BTTTriggerConfig.BTTTouchBarItemPadding == -2)
    ] | length
  ' "$preset")
  expected_padding_count=$(printf '%s' "$expected_top_level_widgets" | awk -F, '{ print NF }')
  [ "$compact_padding_count" -eq "$expected_padding_count" ] || {
    printf '%s does not apply compact padding to every top-level coin\n' "$preset" >&2
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
