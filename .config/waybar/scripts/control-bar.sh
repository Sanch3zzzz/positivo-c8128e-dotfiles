#!/bin/bash
export DISPLAY=:0
export XDG_RUNTIME_DIR=/run/user/1000
export WAYLAND_DISPLAY=wayland-1
swaymsg "exec foot -e python3 /home/gustavosp/.config/waybar/scripts/control-bar.py $1" 2>/dev/null
sleep 1
swaymsg "[title=\"control-bar.py\"] floating enable, move position center 90%, border none" 2>/dev/null || true
