# BetterTouchTool Crypto Price Presets

This repository contains BetterTouchTool Touch Bar presets for live crypto prices.

## Included presets

- [crypto-price-Coinbase.json](./crypto-price-Coinbase.json)
- [crypto-price-Binance.json](./crypto-price-Binance.json)

## Shared behavior

Both presets use the same layout and formatting:

- Coins: Bitcoin, Ethereum, Zcash, Litecoin
- Order: `BTC`, `ETH`, `ZEC`, `LTC`
- Currency: USD
- Refresh interval: every 10 seconds
- Formatting: `BTC` and `ETH` are rounded to whole dollars, `ZEC` and `LTC` show 2 decimal places
- Theme: black buttons, white text, embedded coin icons
- Pressing `ZEC` opens a second-level `Zcash Details` menu with live `Zcash`, `Shielded Supply`, `Net Shielded Flow`, and a gray `Back` button

## Differences

### Coinbase preset

- File: [crypto-price-Coinbase.json](./crypto-price-Coinbase.json)
- BetterTouchTool preset name: `Crypto Price Coinbase`
- Price source: Coinbase spot price API
- `BTC`, `ETH`, and `LTC` buttons open Coinbase asset pages
- The top-level `ZEC` button opens the `Zcash Details` submenu
- The `Zcash` button inside that submenu opens the Coinbase Zcash page

### Binance preset

- File: [crypto-price-Binance.json](./crypto-price-Binance.json)
- BetterTouchTool preset name: `Crypto Price Binance`
- Price source: Binance spot ticker API
- `BTC`, `ETH`, and `LTC` buttons open Binance asset pages
- The top-level `ZEC` button opens the `Zcash Details` submenu
- The `Zcash` button inside that submenu opens the Binance Zcash page

## Import

Import the preset you want in BetterTouchTool via `Manage Presets > Import`.

## Notes

- Coin icons are embedded directly in the preset via `BTTIconData`.
- The icon artwork is based on the `spothq/cryptocurrency-icons` set on GitHub.
- You can adjust colors, width, order, and refresh interval directly in BetterTouchTool after import.
- The `Zcash Details` submenu reads shielded metrics from the local helper scripts in `src/zcash_shielded_supply.sh` and `src/zcash_net_shielded_flow.sh`.
