#!/usr/bin/env bash
# Backup dos dotfiles + Imagens (prints/wallpapers) para ~/Backup/dots/.
# Agendado pelo timer .config/systemd/user/dotfiles-backup.timer
# (tambem pode rodar na mao:  ~/.local/bin/backup-dots.sh).
# Mantem apenas as ultimas KEEP copias.
set -euo pipefail

DST_ROOT="$HOME/Backup/dots"
KEEP=8
STAMP="$(date +%Y%m%d_%H%M%S)"
DST="$DST_ROOT/$STAMP"

# Pastas/arquivos do $HOME a incluir (relativos ao $HOME). So entra o que existir.
ITEMS=(.config/sway
       .config/waybar
       .config/mako
       .config/swayidle
       .config/swaylock
       .config/systemd
       .config/qt6ct
       .config/mimeapps.list
       .local/bin
       Images)

include=()
for it in "${ITEMS[@]}"; do
    [ -e "$HOME/$it" ] && include+=("$it")
done

[ "${#include[@]}" -eq 0 ] && exit 0

mkdir -p "$DST"
# tar evita dependencias novas (rsync nao e garantido). Desvio de erro: a
# flag -f preserva retorno 0 se algum arquivo sumir no meio do backup.
tar -czf "$DST/dots.tgz" -C "$HOME" "${include[@]}" 2>/dev/null || true

# Retencao: os nomes sao YYYYMMDD_HHMMSS, entao ordenacao alfabetica ja e
# cronologica. Apaga os mais antigos alem das KEEP mais recentes.
old=$(find "$DST_ROOT" -mindepth 1 -maxdepth 1 -type d | sort | head -n -$KEEP)
[ -z "$old" ] || rm -rf $old

notify-send -t 4000 "Backup dos dotfiles" "Pronto: $(basename "$DST")/dots.tgz" || true