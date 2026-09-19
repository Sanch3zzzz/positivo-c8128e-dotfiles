#!/usr/bin/env bash
# status-lib.sh - checagens simples de servicos/processos, compartilhadas
# por system-status.sh (painel) e service-watchdog.sh (aviso de queda).
# Na pratica os outros scripts fazem:  source "$(dirname "$0")/status-lib.sh"
#
# svc MODO ARG -> status 0 se esta tudo bem.
#   MODO:
#     proc     processo com o nome exato (pgrep -x)
#     f        processo pela linha de comando (pgrep -f)
#     pid      pidfile com processo vivo (e o pid nele)
#     sys      unidade de sistema ativa (systemctl is-active)
#     usuario  unidade do usuario ativa
#     ligado   unidade do usuario habilitada
#     existe   caminho existe no filesystem
svc() {
    local modo="$1" arg="$2" p
    case "$modo" in
        proc)    pgrep -x "$arg" >/dev/null 2>&1 ;;
        f)       pgrep -f -- "$arg" >/dev/null 2>&1 ;;
        pid)     [[ -f "$arg" ]] && p=$(cat "$arg") && [[ -n "$p" ]] && kill -0 "$p" 2>/dev/null ;;
        sys)     systemctl is-active --quiet "$arg" ;;
        usuario) systemctl --user is-active --quiet "$arg" ;;
        ligado)  systemctl --user is-enabled --quiet "$arg" ;;
        existe)  [ -e "$arg" ] ;;
        *)       return 1 ;;
    esac
}

# Gestos de toque: pidfile OU processo (o daemon pode ter sido reiniciado
# pelo exec_always, deixando pidfile velho -> o fallback cobre isso).
touch_ok() {
    svc pid /tmp/sway-touch-gestures.pid || svc f "touch-gestures.py"
}

# Rotacao automatica: "ligada" tem pid vivo; desligada e intencional
# (alternada por MOD+o), portanto NAO e tratado como erro pelo watchdog.
autorotate_ok() {
    svc pid /tmp/sway-autorotate.pid || svc f "monitor-sensor --accel"
}

# Proxima execucao de um timer do usuario (formato humano) ou vazio.
# Ex.: tnext dotfiles-backup
tnext() { # <timer> -> proxima execucao (formato humano) ou vazio
    local raw nxt
    raw=$(systemctl --user show "$1.timer" -p NextElapseUSecRealtime --value 2>/dev/null || true)
    [[ "$raw" == "n/a" || -z "$raw" ]] && raw=""
    if [ -z "$raw" ]; then
        # Timers com OnBootSec/OnUnitActiveSec nao expoem NextElapseUSecRealtime;
        # pega a coluna NEXT do list-timers (ja resolvida pelo systemd).
        nxt=$(systemctl --user list-timers --all --no-legend 2>/dev/null |
              awk -v t="$1.timer" '$(NF-1)==t {print $1, $2, $3, $4; exit}')
        [ -n "$nxt" ] && date -d "$nxt" +'%a %d/%m %H:%M' 2>/dev/null || true
        return
    fi
    if [[ "$raw" =~ ^[0-9]+$ ]]; then
        date -d "@$((raw / 1000000))" +'%a %d/%m %H:%M' 2>/dev/null || true
    else
        date -d "$raw" +'%a %d/%m %H:%M' 2>/dev/null || true
    fi
}