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

## Differences

### Coinbase preset

- File: [crypto-price-Coinbase.json](./crypto-price-Coinbase.json)
- BetterTouchTool preset name: `Crypto Price Coinbase`
- Price source: Coinbase spot price API
- Button links open Coinbase asset pages

### Binance preset

- File: [crypto-price-Binance.json](./crypto-price-Binance.json)
- BetterTouchTool preset name: `Crypto Price Binance`
- Price source: Binance spot ticker API
- Button links open Binance asset pages

## Import

Import the preset you want in BetterTouchTool via `Manage Presets > Import`.

## Notes

- Coin icons are embedded directly in the preset via `BTTIconData`.
- The icon artwork is based on the `spothq/cryptocurrency-icons` set on GitHub.
- You can adjust colors, width, order, and refresh interval directly in BetterTouchTool after import.
