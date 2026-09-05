#!/bin/sh

# Return cached Touch Bar values immediately and refresh stale values in the
# background. This keeps BetterTouchTool's AppleScript runner away from slow
# network calls while preserving the configured 10-second widget interval.

set -u
umask 077

MODE=${1:-}
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
CACHE_DIR=${TMPDIR:-/tmp}/org.ruzcash.BetterTouchTool_Zcash
SUPPLY_CACHE=$CACHE_DIR/shielded-supply.tsv
FLOW_CACHE=$CACHE_DIR/net-shielded-flow.tsv
DEFAULT_CACHE_TTL_SECONDS=9

mkdir -p "$CACHE_DIR" || exit 1

cache_value() {
  cv_file=$1
  cv_wanted_key=$2
  cv_tab=$(printf '\t')

  [ -r "$cv_file" ] || return 1
  while IFS="$cv_tab" read -r cv_key cv_value; do
    if [ "$cv_key" = "$cv_wanted_key" ] && [ -n "$cv_value" ]; then
      printf '%s' "$cv_value"
      return 0
    fi
  done < "$cv_file"
  return 1
}

format_price() {
  fp_display=$1
  fp_numeric=${fp_display#\$}
  fp_whole=${fp_numeric%%.*}

  case "$fp_whole" in
    ''|*[!0-9]*) printf '%s' "$fp_display"; return ;;
  esac

  if [ "$fp_whole" -ge 1000 ]; then
    printf '$%.0f' "$fp_numeric"
  else
    printf '%s' "$fp_display"
  fi
}

cache_is_fresh() {
  cache_file=$1
  cache_ttl_seconds=$2
  [ -f "$cache_file" ] || return 1

  modified_at=$(stat -f %m "$cache_file" 2>/dev/null) || return 1
  now=$(date +%s)
  age=$((now - modified_at))
  [ "$age" -ge 0 ] && [ "$age" -lt "$cache_ttl_seconds" ]
}

start_refresh() {
  refresh_mode=$1
  cache_file=$2
  cache_ttl_seconds=$3
  lock_dir=$cache_file.lock

  cache_is_fresh "$cache_file" "$cache_ttl_seconds" && return 0
  if ! mkdir "$lock_dir" 2>/dev/null; then
    # A hard-killed refresh must not disable future updates forever.
    lock_modified_at=$(stat -f %m "$lock_dir" 2>/dev/null) || return 0
    lock_now=$(date +%s)
    lock_age=$((lock_now - lock_modified_at))
    [ "$lock_age" -gt 30 ] || return 0
    rmdir "$lock_dir" 2>/dev/null || return 0
    mkdir "$lock_dir" 2>/dev/null || return 0
  fi

  nohup /bin/sh "$SCRIPT_DIR/touchbar_cached_value.sh" \
    "--refresh-$refresh_mode" "$cache_file" "$lock_dir" \
    </dev/null >/dev/null 2>&1 &
}

supported_symbols() {
  case "$1" in
    binance|coinbase|okx|kucoin)
      printf '%s\n' BTC ETH ZEC LTC FIL ZEN
      ;;
    gemini|near-intents)
      printf '%s\n' BTC ETH ZEC LTC
      ;;
    *)
      return 1
      ;;
  esac
}

expected_symbol_count() {
  supported_symbols "$1" | awk 'END { print NR }'
}

symbol_is_supported() {
  provider=$1
  symbol=$2

  for supported_symbol in $(supported_symbols "$provider"); do
    if [ "$supported_symbol" = "$symbol" ]; then
      return 0
    fi
  done
  return 1
}

price_cache_ttl() {
  case "$1" in
    near-intents)
      # The public token reference prices update less often than exchange
      # tickers, and the response contains the full supported-token catalog.
      printf '29'
      ;;
    *)
      printf '%s' "$DEFAULT_CACHE_TTL_SECONDS"
      ;;
  esac
}

start_price_refresh() {
  provider=$1
  cache_file=$2
  cache_ttl_seconds=$3
  lock_dir=$cache_file.lock

  cache_is_fresh "$cache_file" "$cache_ttl_seconds" && return 0
  if ! mkdir "$lock_dir" 2>/dev/null; then
    lock_modified_at=$(stat -f %m "$lock_dir" 2>/dev/null) || return 0
    lock_now=$(date +%s)
    lock_age=$((lock_now - lock_modified_at))
    [ "$lock_age" -gt 30 ] || return 0
    rmdir "$lock_dir" 2>/dev/null || return 0
    mkdir "$lock_dir" 2>/dev/null || return 0
  fi

  nohup /bin/sh "$SCRIPT_DIR/touchbar_cached_value.sh" \
    --refresh-prices "$provider" "$cache_file" "$lock_dir" \
    </dev/null >/dev/null 2>&1 &
}

finish_refresh() {
  temporary_file=$1
  lock_dir=$2
  [ -n "$temporary_file" ] && rm -f "$temporary_file"
  rmdir "$lock_dir" 2>/dev/null || true
}

finish_price_refresh() {
  temporary_file=$1
  response_file=$2
  lock_dir=$3
  [ -n "$temporary_file" ] && rm -f "$temporary_file"
  [ -n "$response_file" ] && rm -f "$response_file"
  rmdir "$lock_dir" 2>/dev/null || true
}

fetch_price_response() {
  provider=$1
  response_file=$2

  case "$provider" in
    binance)
      curl -fsS --connect-timeout 2 --max-time 6 \
        'https://data-api.binance.vision/api/v3/ticker/price?symbols=%5B%22BTCUSDT%22%2C%22ETHUSDT%22%2C%22ZECUSDT%22%2C%22LTCUSDT%22%2C%22FILUSDT%22%2C%22ZENUSDT%22%5D' \
        > "$response_file"
      ;;
    coinbase)
      curl -fsS --connect-timeout 2 --max-time 6 \
        'https://api.coinbase.com/api/v3/brokerage/market/products?product_ids=BTC-USD&product_ids=ETH-USD&product_ids=ZEC-USD&product_ids=LTC-USD&product_ids=FIL-USD&product_ids=ZEN-USD&product_type=SPOT' \
        > "$response_file"
      ;;
    gemini)
      curl -fsS --connect-timeout 2 --max-time 6 \
        'https://api.gemini.com/v1/pricefeed' \
        > "$response_file"
      ;;
    okx)
      curl -fsS --connect-timeout 2 --max-time 6 \
        'https://www.okx.com/api/v5/market/tickers?instType=SPOT' \
        > "$response_file"
      ;;
    kucoin)
      curl -fsS --connect-timeout 2 --max-time 6 \
        'https://api.kucoin.com/api/v1/market/allTickers' \
        > "$response_file"
      ;;
    near-intents)
      curl -fsS --connect-timeout 2 --max-time 6 \
        'https://1click.chaindefuser.com/v0/tokens' \
        > "$response_file"
      ;;
    *)
      return 2
      ;;
  esac
}

parse_price_response() {
  provider=$1
  response_file=$2
  temporary_file=$3

  case "$provider" in
    binance)
      awk '
        BEGIN { RS = "}"; FS = "\"" }
        function field(name, i) {
          for (i = 1; i < NF; i++) if ($i == name) return $(i + 2)
          return ""
        }
        {
          symbol = field("symbol")
          price = field("price")
          if (symbol == "BTCUSDT") printf "BTC\t$%.0f\n", price
          if (symbol == "ETHUSDT") printf "ETH\t$%.0f\n", price
          if (symbol == "ZECUSDT") printf "ZEC\t$%.2f\n", price
          if (symbol == "LTCUSDT") printf "LTC\t$%.2f\n", price
          if (symbol == "FILUSDT") printf "FIL\t$%.2f\n", price
          if (symbol == "ZENUSDT") printf "ZEN\t$%.2f\n", price
        }
      ' "$response_file" > "$temporary_file"
      ;;
    coinbase)
      awk '
        BEGIN { RS = "}"; FS = "\"" }
        function field(name, i) {
          for (i = 1; i < NF; i++) if ($i == name) return $(i + 2)
          return ""
        }
        {
          symbol = field("product_id")
          price = field("price")
          if (symbol == "BTC-USD") printf "BTC\t$%.0f\n", price
          if (symbol == "ETH-USD") printf "ETH\t$%.0f\n", price
          if (symbol == "ZEC-USD") printf "ZEC\t$%.2f\n", price
          if (symbol == "LTC-USD") printf "LTC\t$%.2f\n", price
          if (symbol == "FIL-USD") printf "FIL\t$%.2f\n", price
          if (symbol == "ZEN-USD") printf "ZEN\t$%.2f\n", price
        }
      ' "$response_file" > "$temporary_file"
      ;;
    gemini)
      awk '
        BEGIN { RS = "}"; FS = "\"" }
        function field(name, i) {
          for (i = 1; i < NF; i++) if ($i == name) return $(i + 2)
          return ""
        }
        {
          symbol = field("pair")
          price = field("price")
          if (symbol == "BTCUSD") printf "BTC\t$%.0f\n", price
          if (symbol == "ETHUSD") printf "ETH\t$%.0f\n", price
          if (symbol == "ZECUSD") printf "ZEC\t$%.2f\n", price
          if (symbol == "LTCUSD") printf "LTC\t$%.2f\n", price
        }
      ' "$response_file" > "$temporary_file"
      ;;
    okx)
      awk '
        BEGIN { RS = "}"; FS = "\"" }
        function field(name, i) {
          for (i = 1; i < NF; i++) if ($i == name) return $(i + 2)
          return ""
        }
        {
          symbol = field("instId")
          price = field("last")
          if (symbol == "BTC-USDT") printf "BTC\t$%.0f\n", price
          if (symbol == "ETH-USDT") printf "ETH\t$%.0f\n", price
          if (symbol == "ZEC-USDT") printf "ZEC\t$%.2f\n", price
          if (symbol == "LTC-USDT") printf "LTC\t$%.2f\n", price
          if (symbol == "FIL-USDT") printf "FIL\t$%.2f\n", price
          if (symbol == "ZEN-USDT") printf "ZEN\t$%.2f\n", price
        }
      ' "$response_file" > "$temporary_file"
      ;;
    kucoin)
      awk '
        BEGIN { RS = "}"; FS = "\"" }
        function field(name, i) {
          for (i = 1; i < NF; i++) if ($i == name) return $(i + 2)
          return ""
        }
        {
          symbol = field("symbol")
          price = field("last")
          if (symbol == "BTC-USDT") printf "BTC\t$%.0f\n", price
          if (symbol == "ETH-USDT") printf "ETH\t$%.0f\n", price
          if (symbol == "ZEC-USDT") printf "ZEC\t$%.2f\n", price
          if (symbol == "LTC-USDT") printf "LTC\t$%.2f\n", price
          if (symbol == "FIL-USDT") printf "FIL\t$%.2f\n", price
          if (symbol == "ZEN-USDT") printf "ZEN\t$%.2f\n", price
        }
      ' "$response_file" > "$temporary_file"
      ;;
    near-intents)
      awk '
        BEGIN { RS = "}"; FS = "\"" }
        function field(name, i) {
          for (i = 1; i < NF; i++) if ($i == name) return $(i + 2)
          return ""
        }
        function number_field(name, i, value) {
          for (i = 1; i < NF; i++) {
            if ($i == name) {
              value = $(i + 1)
              sub(/^[^0-9.+-]*/, "", value)
              sub(/[^0-9.eE+-].*$/, "", value)
              return value
            }
          }
          return ""
        }
        {
          symbol = field("symbol")
          blockchain = field("blockchain")
          price = number_field("price")
          if (symbol == "BTC" && blockchain == "btc") printf "BTC\t$%.0f\n", price
          if (symbol == "ETH" && blockchain == "eth") printf "ETH\t$%.0f\n", price
          if (symbol == "ZEC" && blockchain == "zec") printf "ZEC\t$%.2f\n", price
          if (symbol == "LTC" && blockchain == "ltc") printf "LTC\t$%.2f\n", price
        }
      ' "$response_file" > "$temporary_file"
      ;;
    *)
      return 2
      ;;
  esac
}

valid_price_cache() {
  vpc_provider=$1
  vpc_file=$2
  vpc_line_count=$(awk 'END { print NR }' "$vpc_file")
  vpc_expected_count=$(expected_symbol_count "$vpc_provider")
  [ "$vpc_line_count" -eq "$vpc_expected_count" ] || return 1

  for vpc_symbol in $(supported_symbols "$vpc_provider"); do
    cache_value "$vpc_file" "$vpc_symbol" >/dev/null || return 1
  done
}

refresh_prices() {
  provider=$1
  cache_file=$2
  lock_dir=$3
  temporary_file=$(mktemp "$CACHE_DIR/prices-$provider.XXXXXX") || {
    rmdir "$lock_dir" 2>/dev/null || true
    exit 1
  }
  response_file=$(mktemp "$CACHE_DIR/response-$provider.XXXXXX") || {
    rm -f "$temporary_file"
    rmdir "$lock_dir" 2>/dev/null || true
    exit 1
  }
  trap 'finish_price_refresh "$temporary_file" "$response_file" "$lock_dir"' EXIT HUP INT TERM

  if fetch_price_response "$provider" "$response_file" &&
    parse_price_response "$provider" "$response_file" "$temporary_file" &&
    valid_price_cache "$provider" "$temporary_file"
  then
    chmod 600 "$temporary_file"
    mv -f "$temporary_file" "$cache_file"
    temporary_file=
    return 0
  fi
  return 1
}

show_price() {
  provider=$1
  symbol=$2

  case "$provider" in
    binance|coinbase|gemini|okx|kucoin|near-intents) ;;
    *) printf 'waiting'; return 2 ;;
  esac
  symbol_is_supported "$provider" "$symbol" || { printf 'waiting'; return 2; }

  price_cache=$CACHE_DIR/prices-$provider.tsv
  price_ttl=$(price_cache_ttl "$provider")
  start_price_refresh "$provider" "$price_cache" "$price_ttl"
  if cached_price=$(cache_value "$price_cache" "$symbol"); then
    format_price "$cached_price"
  else
    printf 'waiting'
  fi
}

refresh_supply() {
  cache_file=$1
  lock_dir=$2
  temporary_file=$(mktemp "$CACHE_DIR/shielded-supply.XXXXXX") || {
    rmdir "$lock_dir" 2>/dev/null || true
    exit 1
  }
  trap 'finish_refresh "$temporary_file" "$lock_dir"' EXIT HUP INT TERM

  if curl -fsS --connect-timeout 2 --max-time 6 'https://zkp.baby/' |
    awk '
      BEGIN { capture = 0; printed = 0 }
      /Total Shielded Value/ { capture = 1; next }
      capture && /ZEC/ && !printed {
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", $0)
        gsub(/ ZEC.*/, "", $0)
        gsub(/,/, "", $0)
        printf "shielded_supply\t%.3fM\n", $0 / 1000000
        printed = 1
      }
    ' > "$temporary_file"
  then
    if cache_value "$temporary_file" shielded_supply >/dev/null; then
      chmod 600 "$temporary_file"
      mv -f "$temporary_file" "$cache_file"
      temporary_file=
    fi
  fi
}

refresh_flow() {
  cache_file=$1
  lock_dir=$2
  temporary_file=$(mktemp "$CACHE_DIR/net-shielded-flow.XXXXXX") || {
    rmdir "$lock_dir" 2>/dev/null || true
    exit 1
  }
  trap 'finish_refresh "$temporary_file" "$lock_dir"' EXIT HUP INT TERM

  if curl -fsS --connect-timeout 2 --max-time 6 \
    'https://zkp.baby/index.php?action=get_chart_data' |
    awk -F'"total":"' '
      /"timestamp":/ {
        for (i = 2; i <= NF; i++) {
          split($i, value, "\"")
          values[++count] = value[1]
        }
      }
      END {
        if (count < 2) exit 1
        difference = values[count] - values[count - 1]
        sign = difference < 0 ? "-" : "+"
        if (difference < 0) difference = -difference
        if (difference >= 1000000)
          printf "net_flow\t%s%.2fM\n", sign, difference / 1000000
        else if (difference >= 1000)
          printf "net_flow\t%s%.2fK\n", sign, difference / 1000
        else
          printf "net_flow\t%s%.0f\n", sign, difference
      }
    ' > "$temporary_file"
  then
    if cache_value "$temporary_file" net_flow >/dev/null; then
      chmod 600 "$temporary_file"
      mv -f "$temporary_file" "$cache_file"
      temporary_file=
    fi
  fi
}

case "$MODE" in
  --refresh-prices)
    [ "$#" -eq 4 ] || exit 2
    refresh_prices "$2" "$3" "$4"
    ;;
  --refresh-supply)
    refresh_supply "$2" "$3"
    ;;
  --refresh-flow)
    refresh_flow "$2" "$3"
    ;;
  price)
    [ "$#" -eq 3 ] || { printf 'waiting'; exit 2; }
    show_price "$2" "$3"
    ;;
  BTC|ETH|ZEC|LTC)
    # Backwards compatibility for v2.0 presets.
    show_price binance "$MODE"
    ;;
  shielded_supply)
    start_refresh supply "$SUPPLY_CACHE" "$DEFAULT_CACHE_TTL_SECONDS"
    cache_value "$SUPPLY_CACHE" shielded_supply || printf 'waiting'
    ;;
  net_flow)
    start_refresh flow "$FLOW_CACHE" "$DEFAULT_CACHE_TTL_SECONDS"
    cache_value "$FLOW_CACHE" net_flow || printf 'waiting'
    ;;
  *)
    printf 'waiting'
    exit 2
    ;;
esac
