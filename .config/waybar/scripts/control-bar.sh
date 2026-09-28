#!/bin/bash
# Spawn control-bar.py via swaymsg exec, then float and position it
swaymsg "exec python3 /home/gustavosp/.config/waybar/scripts/control-bar.py $1" 2>/dev/null
sleep 1
swaymsg "[title=\"control-bar.py\"] floating enable, move position center 90%, border none" 2>/dev/null || true
