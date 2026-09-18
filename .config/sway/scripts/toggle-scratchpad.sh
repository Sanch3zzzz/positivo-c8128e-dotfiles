#!/usr/bin/env bash
# Terminal escorregadio (scratchpad) - abre/fecha com MOD+' (apostrophe).
# Se ja existe uma janela scratchpad, alterna mostrar/esconder.
# Senao, cria um foot novo e manda pro scratchpad.
SCRATCHPAD_APP_ID="scratchpad"

if swaymsg -q "[app_id=$SCRATCHPAD_APP_ID] scratchpad show" 2>/dev/null; then
    exit 0
fi

foot --app-id "$SCRATCHPAD_APP_ID" &
sleep 0.3
swaymsg "[app_id=$SCRATCHPAD_APP_ID] move scratchpad"
