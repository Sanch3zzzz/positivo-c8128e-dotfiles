#!/bin/sh
pkill -x swaybg 2>/dev/null
wallpapers_dir="$HOME/Images/Wallpapers"
wallpaper=$(find "$wallpapers_dir" -type f \( -iname "*.png" -o -iname "*.jpg" -o -iname "*.jpeg" \) | shuf -n 1)
if [ -n "$wallpaper" ]; then
    swaybg -i "$wallpaper" -m fill &
fi