#!/bin/bash
export DISPLAY=:0
export XDG_RUNTIME_DIR=/run/user/1000
export WAYLAND_DISPLAY=wayland-1
# Spawn control-bar.py via foot, then float and position it
foot -e python3 /home/gustavosp/.config/waybar/scripts/control-bar.py &
sleep 0.8
swaymsg "[title=\"control-bar.py\"] floating enable, move position center 90%, border none" 2>/dev/null || true
