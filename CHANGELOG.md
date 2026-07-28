# Changelog

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
- Presets no longer contain a developer-specific `/Users/ak/...` path.
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
