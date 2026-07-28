# Changelog

## 2.1.0 — 2026-07-28

### Added

- Optimized provider presets for Gemini USD spot, OKX USDT spot, KuCoin USDT
  spot, and NEAR Intents reference USD prices.
- A provider-aware cache namespace and a reproducible preset generator.
- Structural tests that reject direct network calls inside preset AppleScripts.

### Changed

- Coinbase now uses the same asynchronous cache design as Binance. One public
  Advanced Trade USD spot response replaces five synchronous AppleScript
  `curl` calls, including the duplicate ZEC request in the details submenu.
- Binance now calls the provider-aware helper explicitly while the legacy v2.0
  command format remains supported.
- NEAR Intents refreshes at a lower frequency because its public token catalog
  is larger and its reference prices update less frequently than exchange
  tickers.

### Provider policy

- ZEC support is mandatory. Gemini was selected because `ZECUSD` is an active
  spot market.
- Bybit was not added because it lacks ZEC spot trading; using a ZEC perpetual
  price beside spot prices would change the meaning of the preset.
- Provider variants share a preset UUID intentionally, making source changes a
  replacement rather than creating duplicate Touch Bar layouts.

### Why

The v2.0 performance fix covered Binance price widgets but left Coinbase price
widgets on the original synchronous code path. Version 2.1 removes network I/O
from every included preset's BetterTouchTool AppleScript runner while expanding
the choice of ZEC-capable sources.

## 2.0.0 — 2026-07-28

### Changed

- Price rendering no longer waits for network requests inside BetterTouchTool's
  AppleScript runner.
- The Binance preset fetches BTC, ETH, ZEC, and LTC in one batched request
  instead of issuing one request per visible button.
- Values are refreshed asynchronously and stored in an atomic local cache.
- Connect and total request timeouts prevent a slow endpoint from blocking the
  runner indefinitely.
- The last successful value stays visible during a temporary API failure.

### Fixed

- Helper scripts are now included in the repository and installed to a stable
  per-user path by `install.sh`.
- Presets use portable home-directory paths instead of developer-specific paths.
- Stale refresh locks recover automatically after an interrupted request.

### Preserved behavior

- The 10-second display refresh interval.
- Coin order, labels, icons, widths, colors, and price formatting.
- All Binance/Coinbase links and the Zcash details submenu.

### Why

The original Binance preset performed four synchronous `curl` requests every
10 seconds, with no timeout. A slow request kept BetterTouchTool's AppleScript
runner busy and produced observed CPU spikes of 7–23%. With v2, the runner only
reads the cache; an eight-sample post-change profile was 0% CPU in six samples
and peaked briefly at 1.6%.

## 1.x — initial repository version

- Added Coinbase and Binance Touch Bar price presets.
- Added the Zcash details submenu with shielded supply and net-flow metrics.
