#!/usr/bin/env python3

"""Generate provider presets from the reviewed Binance layout.

This is a development helper only. BetterTouchTool users do not need Python;
the generated JSON files are committed and the runtime helper is POSIX shell.
"""

from __future__ import annotations

import base64
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
        "symbols": ("BTC", "ETH", "ZEC", "LTC", "FIL", "ZEN"),
        "urls": {
            "BTC": "https://www.binance.com/en/price/bitcoin",
            "ETH": "https://www.binance.com/en/price/ethereum",
            "ZEC": "https://www.binance.com/en/price/zcash",
            "LTC": "https://www.binance.com/en/price/litecoin",
            "FIL": "https://www.binance.com/en/price/filecoin",
            "ZEN": "https://www.binance.com/en/price/horizen",
        },
    },
    "coinbase": {
        "title": "Coinbase",
        "filename": "crypto-price-Coinbase.json",
        "symbols": ("BTC", "ETH", "ZEC", "LTC", "FIL", "ZEN"),
        "urls": {
            "BTC": "https://www.coinbase.com/price/bitcoin",
            "ETH": "https://www.coinbase.com/price/ethereum",
            "ZEC": "https://www.coinbase.com/price/zcash",
            "LTC": "https://www.coinbase.com/price/litecoin",
            "FIL": "https://www.coinbase.com/price/filecoin",
            "ZEN": "https://www.coinbase.com/price/horizen",
        },
    },
    "gemini": {
        "title": "Gemini",
        "filename": "crypto-price-Gemini.json",
        "symbols": ("BTC", "ETH", "ZEC", "LTC"),
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
        "symbols": ("BTC", "ETH", "ZEC", "LTC", "FIL", "ZEN"),
        "urls": {
            "BTC": "https://www.okx.com/trade-spot/btc-usdt",
            "ETH": "https://www.okx.com/trade-spot/eth-usdt",
            "ZEC": "https://www.okx.com/trade-spot/zec-usdt",
            "LTC": "https://www.okx.com/trade-spot/ltc-usdt",
            "FIL": "https://www.okx.com/trade-spot/fil-usdt",
            "ZEN": "https://www.okx.com/trade-spot/zen-usdt",
        },
    },
    "kucoin": {
        "title": "KuCoin",
        "filename": "crypto-price-KuCoin.json",
        "symbols": ("BTC", "ETH", "ZEC", "LTC", "FIL", "ZEN"),
        "urls": {
            "BTC": "https://www.kucoin.com/trade/BTC-USDT",
            "ETH": "https://www.kucoin.com/trade/ETH-USDT",
            "ZEC": "https://www.kucoin.com/trade/ZEC-USDT",
            "LTC": "https://www.kucoin.com/trade/LTC-USDT",
            "FIL": "https://www.kucoin.com/trade/FIL-USDT",
            "ZEN": "https://www.kucoin.com/trade/ZEN-USDT",
        },
    },
    "near-intents": {
        "title": "NEAR Intents Reference",
        "filename": "crypto-price-NEAR-Intents.json",
        "symbols": ("BTC", "ETH", "ZEC", "LTC"),
        "urls": {
            "BTC": "https://near-intents.org/",
            "ETH": "https://near-intents.org/",
            "ZEC": "https://near-intents.org/",
            "LTC": "https://near-intents.org/",
        },
    },
}

FULL_LAYOUT = ("BTC", "ETH", "ZEC", "LTC", "FIL", "ZEN")
TOP_LEVEL_WIDTH_BY_LAYOUT_SIZE = {
    4: 120,
    6: 96,
}
FULL_LAYOUT_WIDE_SYMBOLS = {"BTC", "ZEC"}
TOP_LEVEL_ITEM_PADDING = -2
SYMBOL_WIDGETS = {
    "Bitcoin": "BTC",
    "Ethereum": "ETH",
    "Zcash": "ZEC",
    "Litecoin": "LTC",
    "Filecoin": "FIL",
    "Horizen": "ZEN",
}
WIDGET_SYMBOLS = {symbol: widget for widget, symbol in SYMBOL_WIDGETS.items()}


def load_icon(filename: str) -> str:
    return base64.b64encode((ROOT / "assets" / filename).read_bytes()).decode("ascii")


CUSTOM_ICON_DATA = {
    "FIL": load_icon("filecoin-symbol.png"),
    "ZEN": load_icon("horizen-symbol.png"),
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


def top_level_triggers(preset: dict[str, object]) -> list[dict[str, object]]:
    return preset["BTTPresetContent"][0]["BTTTriggers"]


def build_top_level_button(reference: dict[str, object], symbol: str) -> dict[str, object]:
    button = copy.deepcopy(reference)
    button["BTTWidgetName"] = WIDGET_SYMBOLS[symbol]
    button["BTTIconData"] = CUSTOM_ICON_DATA[symbol]
    button["BTTOpenURL"] = PROVIDERS["binance"]["urls"][symbol]
    button["BTTTriggerConfig"]["BTTTouchBarAppleScriptString"] = apple_script("binance", symbol)
    return button


def configure_top_level_layout(preset: dict[str, object], symbols: tuple[str, ...]) -> None:
    triggers = top_level_triggers(preset)
    price_buttons: dict[str, dict[str, object]] = {}
    other_triggers: list[dict[str, object]] = []
    button_width = TOP_LEVEL_WIDTH_BY_LAYOUT_SIZE[len(symbols)]

    for trigger in triggers:
        symbol = SYMBOL_WIDGETS.get(trigger.get("BTTWidgetName"))
        if symbol in FULL_LAYOUT:
            price_buttons[symbol] = trigger
        else:
            other_triggers.append(trigger)

    reference = price_buttons.get("LTC") or next(iter(price_buttons.values()))
    for symbol in ("FIL", "ZEN"):
        if symbol not in price_buttons:
            price_buttons[symbol] = build_top_level_button(reference, symbol)
        else:
            price_buttons[symbol]["BTTIconData"] = CUSTOM_ICON_DATA[symbol]

    ordered_buttons: list[dict[str, object]] = []
    for order, symbol in enumerate(symbols, start=1):
        button = price_buttons[symbol]
        button["BTTOrder"] = order
        config = button["BTTTriggerConfig"]
        if len(symbols) == len(FULL_LAYOUT) and symbol in FULL_LAYOUT_WIDE_SYMBOLS:
            config["BTTTouchBarButtonWidth"] = 112
        else:
            config["BTTTouchBarButtonWidth"] = button_width
        config["BTTTouchBarItemPadding"] = TOP_LEVEL_ITEM_PADDING
        config.pop("BTTTouchBarItemIconWidth", None)
        ordered_buttons.append(button)

    triggers[:] = ordered_buttons + other_triggers


def rewrite_widgets(value: object, provider: str, urls: dict[str, str]) -> int:
    changed = 0
    if isinstance(value, dict):
        widget_name = value.get("BTTWidgetName")
        symbol = SYMBOL_WIDGETS.get(widget_name)
        config = value.get("BTTTriggerConfig")
        if symbol and isinstance(config, dict) and "BTTTouchBarAppleScriptString" in config:
            config["BTTTouchBarAppleScriptString"] = apple_script(provider, symbol)
            if "BTTOpenURL" in value and symbol in urls:
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
        configure_top_level_layout(preset, settings["symbols"])
        changed = rewrite_widgets(preset, provider, settings["urls"])
        expected = len(settings["symbols"]) + 1
        if changed != expected:
            raise RuntimeError(
                f"Expected {expected} price widgets for {provider}, changed {changed}"
            )
        output = ROOT / settings["filename"]
        output.write_text(
            json.dumps(preset, ensure_ascii=False, indent=2) + "\n",
            encoding="utf-8",
        )


if __name__ == "__main__":
    main()
