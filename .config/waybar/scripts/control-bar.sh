#!/bin/bash
export DISPLAY=:0
export XDG_RUNTIME_DIR=/run/user/1000
export WAYLAND_DISPLAY=wayland-1
export SWAYSOCK=$(ls /run/user/1000/sway-ipc.*.sock 2>/dev/null | head -1)
swaymsg "exec python3 /home/gustavosp/.config/waybar/scripts/control-bar.py $1" 2>/dev/null
sleep 1.5
swaymsg "[title=\"control-bar.py\"] floating enable, move position center bottom, border none" 2>/dev/null || true
