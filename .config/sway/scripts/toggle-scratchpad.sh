#!/usr/bin/env bash
# Terminal escorregadio (scratchpad) - abre/fecha com MOD+grave.
# Se nao existe janela scratchpad, cria um foot novo.
# Se ja existe, mostra/esconde.
SCRATCHPAD_APP_ID="scratchpad"

if swaymsg -t get_tree | grep -q "\"app_id\":\"$SCRATCHPAD_APP_ID\""; then
    swaymsg "[app_id=$SCRATCHPAD_APP_ID] scratchpad show"
else
    foot --app_id "$SCRATCHPAD_APP_ID" &
    sleep 0.3
    swaymsg "[app_id=$SCRATCHPAD_APP_ID] move scratchpad"
fi
