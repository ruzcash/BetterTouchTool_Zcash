# BetterTouchTool Crypto Price Presets

Touch Bar presets for live BTC, ETH, ZEC, and LTC prices, with a Zcash details
submenu for shielded supply and net shielded flow.

## Version 2.1

Version 2.1 extends the non-blocking cache architecture to every included
provider. Coinbase no longer performs five synchronous network requests inside
BetterTouchTool, and optimized presets are now included for Gemini, OKX,
KuCoin, and NEAR Intents reference prices.

ZEC availability is a release requirement. Providers without a current ZEC
market are not included.

## Version 2.0

Version 2 moves network work out of BetterTouchTool's AppleScript runner. The
recommended Binance preset reads values from a fast local cache while a helper
updates all four prices in one background request.

This fixes the main performance problem in the original version: four
synchronous requests were executed every 10 seconds, and none had a timeout.
If one endpoint was slow, the AppleScript runner stayed busy waiting for it.

See [CHANGELOG.md](./CHANGELOG.md) for the complete v2 change list and measured
before/after results.

## Included presets

- [crypto-price-Binance.json](./crypto-price-Binance.json) — Binance USDT spot
- [crypto-price-Coinbase.json](./crypto-price-Coinbase.json) — Coinbase USD
  spot
- [crypto-price-Gemini.json](./crypto-price-Gemini.json) — Gemini USD spot
- [crypto-price-OKX.json](./crypto-price-OKX.json) — OKX USDT spot
- [crypto-price-KuCoin.json](./crypto-price-KuCoin.json) — KuCoin USDT spot
- [crypto-price-NEAR-Intents.json](./crypto-price-NEAR-Intents.json) — reference
  USD prices for native BTC, ETH, ZEC, and LTC supported by NEAR Intents

Each preset has the same layout and Zcash details submenu. Provider variants
intentionally share a BetterTouchTool preset UUID, so importing a different
source replaces the current variant instead of duplicating all buttons.

## Install

The presets use a small local helper for non-blocking network updates. From the
repository directory, run:

```sh
./install.sh
```

The installer copies the helper scripts to:

```text
~/Library/Application Support/BetterTouchTool/Zcash/
```

Then import one `crypto-price-*.json` provider preset in BetterTouchTool using
`Manage Presets > Import`.

Running `install.sh` again safely updates an existing v2 installation.

## Behavior preserved from v1

- Coins and order: `BTC`, `ETH`, `ZEC`, `LTC`
- Display prefix: `$`; Coinbase and Gemini use USD, Binance/OKX/KuCoin use
  USDT, and NEAR Intents provides a reference USD price
- Display refresh interval: every 10 seconds
- Formatting: BTC and ETH use whole dollars; ZEC and LTC use two decimals
- Theme: black buttons, white text, embedded coin icons
- BTC, ETH, LTC, and the inner ZEC button open their exchange pages
- The top-level ZEC button opens `Zcash Details`
- `Zcash Details` includes ZEC price, shielded supply, net shielded flow, and
  a gray Back button

## How v2 avoids blocking BetterTouchTool

- A widget reads its cached value immediately, normally in 20–30 ms.
- A stale cache starts one detached refresh protected by a lock.
- Every provider refresh retrieves all four symbols in one public request.
- Each provider has its own cache, so switching presets cannot show values from
  the previous source.
- Requests have a 2-second connection timeout and a 6-second total timeout.
- Cache files are replaced atomically only after a complete successful result.
- During an API failure, the last successful value remains visible. Before the
  first successful refresh, the widget displays `waiting`.

Runtime cache files are stored under macOS's per-user temporary directory and
do not need manual maintenance.

## Files

- `crypto-price-*.json` — generated provider presets
- `install.sh` — installs or updates the runtime helper
- `src/touchbar_cached_value.sh` — cache and network refresh logic
- `src/zcash_shielded_supply.sh` and `src/zcash_net_shielded_flow.sh` —
  compatibility entry points
- `scripts/generate_presets.py` — development-time preset generator
- `tests/test_presets.sh` — structural validation for all preset variants

## Notes

- Coin artwork is based on the `spothq/cryptocurrency-icons` set on GitHub.
- Colors, widths, order, and display interval can still be adjusted directly in
  BetterTouchTool.
