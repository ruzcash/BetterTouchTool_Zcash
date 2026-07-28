# BetterTouchTool Crypto Price Presets

Touch Bar presets for live BTC, ETH, ZEC, and LTC prices, with a Zcash details
submenu for shielded supply and net shielded flow.

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

- [crypto-price-Binance.json](./crypto-price-Binance.json) — recommended,
  asynchronous and batched in v2
- [crypto-price-Coinbase.json](./crypto-price-Coinbase.json) — legacy Coinbase
  price source; its Zcash detail metrics use the v2 helper

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

Then import `crypto-price-Binance.json` in BetterTouchTool using
`Manage Presets > Import`.

Running `install.sh` again safely updates an existing v2 installation.

## Behavior preserved from v1

- Coins and order: `BTC`, `ETH`, `ZEC`, `LTC`
- Currency: USD
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
- Binance prices use one batched request for all four symbols.
- Requests have a 2-second connection timeout and a 6-second total timeout.
- Cache files are replaced atomically only after a complete successful result.
- During an API failure, the last successful value remains visible. Before the
  first successful refresh, the widget displays `waiting`.

Runtime cache files are stored under macOS's per-user temporary directory and
do not need manual maintenance.

## Files

- `crypto-price-Binance.json` — optimized Binance preset
- `crypto-price-Coinbase.json` — Coinbase preset
- `install.sh` — installs or updates the runtime helper
- `src/touchbar_cached_value.sh` — cache and network refresh logic
- `src/zcash_shielded_supply.sh` and `src/zcash_net_shielded_flow.sh` —
  compatibility entry points

## Notes

- Coin artwork is based on the `spothq/cryptocurrency-icons` set on GitHub.
- Colors, widths, order, and display interval can still be adjusted directly in
  BetterTouchTool.
