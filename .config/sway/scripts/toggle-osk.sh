#!/usr/bin/env bash
set -euo pipefail

BIN=wvkbd-deskintl
STATE=/tmp/wvkbd-visible

if pgrep -x "$BIN" >/dev/null 2>&1; then
    if [[ -f "$STATE" ]]; then
        pkill -SIGUSR1 -x "$BIN"
        rm -f "$STATE"
    else
        pkill -SIGUSR2 -x "$BIN"
        touch "$STATE"
    fi
else
    "$BIN" --fn 'JetBrainsMono Nerd Font Mono 14' --alpha 175 --non-exclusive </dev/null >/dev/null 2>&1 &
    disown
    touch "$STATE"
fi

pkill -RTMIN+5 waybar 2>/dev/null || true