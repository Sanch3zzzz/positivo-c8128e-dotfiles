#!/usr/bin/env bash
set -euo pipefail

BIN=wvkbd-mobintl

if pgrep -x "$BIN" >/dev/null 2>&1; then
    pkill -RTMIN -x "$BIN"
else
    "$BIN" --fn 'JetBrainsMono Nerd Font Mono 14' </dev/null >/dev/null 2>&1 &
    disown
fi