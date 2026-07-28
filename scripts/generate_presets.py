#!/usr/bin/env python3

"""Generate provider presets from the reviewed Binance layout.

This is a development helper only. BetterTouchTool users do not need Python;
the generated JSON files are committed and the runtime helper is POSIX shell.
"""

from __future__ import annotations

import copy
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
TEMPLATE = ROOT / "crypto-price-Binance.json"

# All provider variants intentionally share a preset UUID. Importing another
# source replaces the current variant instead of duplicating every Touch Bar
# button in BetterTouchTool.
PRESET_UUID = "3A49CBCE-DE02-4F8F-A70E-6BA367ACD683"

PROVIDERS = {
    "binance": {
        "title": "Binance",
        "filename": "crypto-price-Binance.json",
        "urls": {
            "BTC": "https://www.binance.com/en/price/bitcoin",
            "ETH": "https://www.binance.com/en/price/ethereum",
            "ZEC": "https://www.binance.com/en/price/zcash",
            "LTC": "https://www.binance.com/en/price/litecoin",
        },
    },
    "coinbase": {
        "title": "Coinbase",
        "filename": "crypto-price-Coinbase.json",
        "urls": {
            "BTC": "https://www.coinbase.com/price/bitcoin",
            "ETH": "https://www.coinbase.com/price/ethereum",
            "ZEC": "https://www.coinbase.com/price/zcash",
            "LTC": "https://www.coinbase.com/price/litecoin",
        },
    },
    "gemini": {
        "title": "Gemini",
        "filename": "crypto-price-Gemini.json",
        "urls": {
            "BTC": "https://exchange.gemini.com/trade/BTCUSD",
            "ETH": "https://exchange.gemini.com/trade/ETHUSD",
            "ZEC": "https://exchange.gemini.com/trade/ZECUSD",
            "LTC": "https://exchange.gemini.com/trade/LTCUSD",
        },
    },
    "okx": {
        "title": "OKX",
        "filename": "crypto-price-OKX.json",
        "urls": {
            "BTC": "https://www.okx.com/trade-spot/btc-usdt",
            "ETH": "https://www.okx.com/trade-spot/eth-usdt",
            "ZEC": "https://www.okx.com/trade-spot/zec-usdt",
            "LTC": "https://www.okx.com/trade-spot/ltc-usdt",
        },
    },
    "kucoin": {
        "title": "KuCoin",
        "filename": "crypto-price-KuCoin.json",
        "urls": {
            "BTC": "https://www.kucoin.com/trade/BTC-USDT",
            "ETH": "https://www.kucoin.com/trade/ETH-USDT",
            "ZEC": "https://www.kucoin.com/trade/ZEC-USDT",
            "LTC": "https://www.kucoin.com/trade/LTC-USDT",
        },
    },
    "near-intents": {
        "title": "NEAR Intents Reference",
        "filename": "crypto-price-NEAR-Intents.json",
        "urls": {
            "BTC": "https://near-intents.org/",
            "ETH": "https://near-intents.org/",
            "ZEC": "https://near-intents.org/",
            "LTC": "https://near-intents.org/",
        },
    },
}

WIDGET_SYMBOLS = {
    "Bitcoin": "BTC",
    "Ethereum": "ETH",
    "Zcash": "ZEC",
    "Litecoin": "LTC",
}


def apple_script(provider: str, symbol: str) -> str:
    helper = (
        '/bin/sh \\"$HOME/Library/Application Support/BetterTouchTool/'
        f'Zcash/touchbar_cached_value.sh\\" price {provider} {symbol}'
    )
    return (
        "try\r"
        f'return do shell script "{helper}"\r'
        "on error\r"
        'return "waiting"\r'
        "end try"
    )


def rewrite_widgets(value: object, provider: str, urls: dict[str, str]) -> int:
    changed = 0
    if isinstance(value, dict):
        widget_name = value.get("BTTWidgetName")
        symbol = WIDGET_SYMBOLS.get(widget_name)
        config = value.get("BTTTriggerConfig")
        if symbol and isinstance(config, dict) and "BTTTouchBarAppleScriptString" in config:
            config["BTTTouchBarAppleScriptString"] = apple_script(provider, symbol)
            if "BTTOpenURL" in value:
                value["BTTOpenURL"] = urls[symbol]
            changed += 1
        for child in value.values():
            changed += rewrite_widgets(child, provider, urls)
    elif isinstance(value, list):
        for child in value:
            changed += rewrite_widgets(child, provider, urls)
    return changed


def main() -> None:
    template = json.loads(TEMPLATE.read_text(encoding="utf-8"))
    for provider, settings in PROVIDERS.items():
        preset = copy.deepcopy(template)
        preset["BTTPresetName"] = f"Crypto Price {settings['title']}"
        preset["BTTPresetUUID"] = PRESET_UUID
        changed = rewrite_widgets(preset, provider, settings["urls"])
        if changed != 5:
            raise RuntimeError(
                f"Expected five price widgets for {provider}, changed {changed}"
            )
        output = ROOT / settings["filename"]
        output.write_text(
            json.dumps(preset, ensure_ascii=False, indent=2) + "\n",
            encoding="utf-8",
        )


if __name__ == "__main__":
    main()
