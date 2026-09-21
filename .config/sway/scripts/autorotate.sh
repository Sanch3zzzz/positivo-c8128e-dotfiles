#!/usr/bin/env bash
# Rotacao automatica da tela via giroscopio (iio-sensor-proxy).
# Ligado por MOD + o no config do sway.
#
# Quando liga:
#   - sobe o monitor-sensor e aplica o transform correto no output eDP-1
#   - PAUSA o daemon de gestos de touch (/tmp/sway-touch-gestures.pid),
#     porque ele usa coordenadas fixas em 1366x768 (quebraria com rotacao).
#     O leitor (foliate) recebe o toque nativo do GTK, ja transformado.
# Quando desliga:
#   - mata o monitor-sensor, volta pra transform 0 e retoma o daemon.
set -euo pipefail

OUTPUT="eDP-1"
PIDFILE="/tmp/sway-autorotate.pid"
LOG="/tmp/sway-autorotate.log"
TOUCH_PIDFILE="/tmp/sway-touch-gestures.pid"

log() { printf '[%s] %s\n' "$(date +%H:%M:%S)" "$*" >>"$LOG"; }

find_sock() {
    local s
    for s in /run/user/*/sway-ipc.*.sock; do
        [[ -S "$s" ]] && { export SWAYSOCK="$s"; return 0; }
    done
    return 1
}
find_sock || true

map_orient() {
    case "${1:-}" in
        normal)    echo 0 ;;
        right-up)  echo 90 ;;
        bottom-up) echo 180 ;;
        left-up)   echo 270 ;;
        *)         echo 0 ;;
    esac
}

apply() {
    local t
    t=$(map_orient "$1")
    swaymsg output "${OUTPUT}" transform "${t}" >/dev/null 2>&1 || true
    log "orientacao: ${1} -> transform ${t}"
}

is_on() {
    local pid=""
    [[ -f "${PIDFILE}" ]] && pid=$(cat "${PIDFILE}")
    [[ -n "${pid}" ]] && kill -0 "${pid}" 2>/dev/null
}

signal_touch() {
    local pid=""
    [[ -f "${TOUCH_PIDFILE}" ]] && pid=$(cat "${TOUCH_PIDFILE}")
    [[ -n "${pid}" ]] || return 0
    kill -"$1" "${pid}" 2>/dev/null || true
    log "touch daemon ${2} (pid ${pid})"
}

stop() {
    local pid=""
    if [[ -f "${PIDFILE}" ]]; then
        pid=$(cat "${PIDFILE}")
        if [[ -n "${pid}" ]]; then
            kill "${pid}" 2>/dev/null || true
        fi
        rm -f "${PIDFILE}"
    fi
    pkill -x monitor-sensor 2>/dev/null || true
    apply normal
    signal_touch CONT retomado
    log "rotacao automatica DESLIGADA"
    notify-send -t 1500 "Rotação automática" "Desativada" || true
}

start() {
    [[ -f "${PIDFILE}" ]] && stop
    [[ ! -f "${PIDFILE}" ]] || return 1

    : >"${LOG}"
    (
        monitor-sensor --accel | while IFS= read -r line; do
            lc="${line,,}"
            case "${lc}" in
                *"orientation changed:"* | \*orientation:*)
                    orient="${line##* }"
                    case "${orient}" in
                        normal|left-up|right-up|bottom-up)
                            apply "${orient}" ;;
                    esac
                    ;;
            esac
        done
    ) </dev/null >>/dev/null 2>>"${LOG}" &

    sleep 0.3
    echo "$(pgrep -o -f 'monitor-sensor --accel' || true)" >"${PIDFILE}"

    apply normal
    signal_touch STOP pausado
    log "rotacao automatica LIGADA (monitor-sensor pid $(cat "${PIDFILE}"))"
    notify-send -t 1500 "Rotação automática" "Ativada" || true
}

case "${1:-toggle}" in
    on)  is_on || start ;;
    off) is_on && stop ;;
    *)   if is_on; then stop; else start; fi ;;
esac