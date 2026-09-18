#!/bin/sh
pkill -x swaybg 2>/dev/null
wallpapers_dir="$HOME/Images/Wallpapers"
wallpaper=$(find "$wallpapers_dir" -type f \( -iname "*.png" -o -iname "*.jpg" -o -iname "*.jpeg" \) 2>/dev/null | shuf -n 1)
if [ -n "$wallpaper" ]; then
    swaybg -i "$wallpaper" -m fill &
elif command -v swaybg >/dev/null 2>&1; then
    swaybg -c '#0a1628' &   # fallback: cor solida do tema (sem tela preta)
fi
