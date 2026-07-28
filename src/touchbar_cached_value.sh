#!/bin/sh

# Return cached Touch Bar values immediately and refresh stale values in the
# background. This keeps BetterTouchTool's AppleScript runner away from slow
# network calls while preserving the configured 10-second widget interval.

set -u
umask 077

MODE=${1:-}
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
CACHE_DIR=${TMPDIR:-/tmp}/com.ak.BetterTouchTool_Zcash
PRICE_CACHE=$CACHE_DIR/prices.tsv
SUPPLY_CACHE=$CACHE_DIR/shielded-supply.tsv
FLOW_CACHE=$CACHE_DIR/net-shielded-flow.tsv
CACHE_TTL_SECONDS=9

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

cache_is_fresh() {
  cache_file=$1
  [ -f "$cache_file" ] || return 1

  modified_at=$(stat -f %m "$cache_file" 2>/dev/null) || return 1
  now=$(date +%s)
  age=$((now - modified_at))
  [ "$age" -ge 0 ] && [ "$age" -lt "$CACHE_TTL_SECONDS" ]
}

start_refresh() {
  refresh_mode=$1
  cache_file=$2
  lock_dir=$cache_file.lock

  cache_is_fresh "$cache_file" && return 0
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

finish_refresh() {
  temporary_file=$1
  lock_dir=$2
  [ -n "$temporary_file" ] && rm -f "$temporary_file"
  rmdir "$lock_dir" 2>/dev/null || true
}

refresh_prices() {
  cache_file=$1
  lock_dir=$2
  temporary_file=$(mktemp "$CACHE_DIR/prices.XXXXXX") || {
    rmdir "$lock_dir" 2>/dev/null || true
    exit 1
  }
  trap 'finish_refresh "$temporary_file" "$lock_dir"' EXIT HUP INT TERM

  if curl -fsS --connect-timeout 2 --max-time 6 \
    'https://data-api.binance.vision/api/v3/ticker/price?symbols=%5B%22BTCUSDT%22%2C%22ETHUSDT%22%2C%22ZECUSDT%22%2C%22LTCUSDT%22%5D' |
    awk '
      BEGIN { RS = "}"; FS = "\"" }
      $2 == "symbol" && $6 == "price" {
        if ($4 == "BTCUSDT") printf "BTC\t$%.0f\n", $8
        if ($4 == "ETHUSDT") printf "ETH\t$%.0f\n", $8
        if ($4 == "ZECUSDT") printf "ZEC\t$%.2f\n", $8
        if ($4 == "LTCUSDT") printf "LTC\t$%.2f\n", $8
      }
    ' > "$temporary_file"
  then
    line_count=$(awk 'END { print NR }' "$temporary_file")
    if [ "$line_count" -eq 4 ]; then
      chmod 600 "$temporary_file"
      mv -f "$temporary_file" "$cache_file"
      temporary_file=
    fi
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
    refresh_prices "$2" "$3"
    ;;
  --refresh-supply)
    refresh_supply "$2" "$3"
    ;;
  --refresh-flow)
    refresh_flow "$2" "$3"
    ;;
  BTC|ETH|ZEC|LTC)
    start_refresh prices "$PRICE_CACHE"
    cache_value "$PRICE_CACHE" "$MODE" || printf 'waiting'
    ;;
  shielded_supply)
    start_refresh supply "$SUPPLY_CACHE"
    cache_value "$SUPPLY_CACHE" shielded_supply || printf 'waiting'
    ;;
  net_flow)
    start_refresh flow "$FLOW_CACHE"
    cache_value "$FLOW_CACHE" net_flow || printf 'waiting'
    ;;
  *)
    printf 'waiting'
    exit 2
    ;;
esac
