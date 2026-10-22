#!/usr/bin/env bash
# Terminal escorregadio (scratchpad) - abre/fecha com MOD+' (apostrophe).
# Se ja existe uma janela scratchpad, alterna mostrar/esconder.
# Senao, cria um foot novo e manda pro scratchpad.
SCRATCHPAD_APP_ID="scratchpad"

if swaymsg -q "[app_id=$SCRATCHPAD_APP_ID] scratchpad show" 2>/dev/null; then
    exit 0
fi

foot --app-id "$SCRATCHPAD_APP_ID" &

# O foot pode demorar mais que 0.3s no Celeron. Espera a janela existir
# (ate ~2s) e so entao move pro scratchpad e mostra.
for _ in {1..20}; do
    sleep 0.1
    if swaymsg -t get_tree 2>/dev/null |
        grep -Eq "\"app_id\"[[:space:]]*:[[:space:]]*\"$SCRATCHPAD_APP_ID\""; then
        swaymsg -q "[app_id=$SCRATCHPAD_APP_ID] move scratchpad" 2>/dev/null || true
        swaymsg -q "[app_id=$SCRATCHPAD_APP_ID] scratchpad show" 2>/dev/null || true
        exit 0
    fi
done

notify-send -t 2500 "Scratchpad" "O terminal não abriu a tempo." 2>/dev/null || true
exit 1
