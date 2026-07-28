#!/bin/sh

set -eu

SOURCE_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
BTT_ZCASH_INSTALL_DIR=${BTT_ZCASH_INSTALL_DIR:-"$HOME/Library/Application Support/BetterTouchTool/Zcash"}

mkdir -p "$BTT_ZCASH_INSTALL_DIR"
/usr/bin/install -m 755 \
  "$SOURCE_DIR/src/touchbar_cached_value.sh" \
  "$SOURCE_DIR/src/zcash_shielded_supply.sh" \
  "$SOURCE_DIR/src/zcash_net_shielded_flow.sh" \
  "$BTT_ZCASH_INSTALL_DIR/"

printf 'Installed BetterTouchTool Zcash helpers in:\n%s\n' "$BTT_ZCASH_INSTALL_DIR"
printf 'Next: import crypto-price-Binance.json in BetterTouchTool.\n'
