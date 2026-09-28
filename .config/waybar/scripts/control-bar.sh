#!/bin/bash
# Spawn control-bar.py via foot, then float and position it
foot -e python3 ~/.config/waybar/scripts/control-bar.py &
SPAWN_PID=$!
# Wait for window to appear and float it
sleep 0.5
swaymsg "[title=\"control-bar.py\"] floating enable; move position center 90%; border none" 2>/dev/null || true
