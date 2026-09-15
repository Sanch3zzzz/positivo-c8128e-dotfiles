#!/usr/bin/env bash
# Print de tela inteira -> ~/Images/Prints/, copia pro clipboard e notifica.
set -euo pipefail

DIR="$HOME/Images/Prints"
mkdir -p "$DIR"

F="$DIR/$(date +%Y-%m-%d_%H%M%S).png"
grim "$F"
wl-copy <"$F"

notify-send -t 2500 "Screenshot" "$(basename "$F") — copiado para o clipboard"