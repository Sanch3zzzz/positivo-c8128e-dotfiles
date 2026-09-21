#!/usr/bin/env bash
# Tela de ajuda com os atalhos principais (aberta via MOD+/ ou MOD+?).
# Roda dentro do foot (app-id "help", painel flutuante centralizado
# configurado no sway) e fecha ao apertar qualquer tecla / fechar a janela.
set -euo pipefail

c_hdr=$'\033[1;36m'
c_sec=$'\033[1;34m'
c_key=$'\033[0;96m'
c_txt=$'\033[0;97m'
c_dim=$'\033[2;90m'
rst=$'\033[0m'

hdr() { printf "\n %s%s%s\n" "$c_hdr" "$*" "$rst"; }
sec() { printf "\n %s%s%s\n" "$c_sec" "$*" "$rst"; }
row() { printf "   %s%-26s%s%s\n" "$c_key" "$1" "$c_txt" "$2"; }

hdr "POSITIVO C8128E - ATALHOS"
printf " %s(MOD = tecla Super/Windows)%s\n" "$c_txt" "$rst"

sec "Terminal & apps"
row "MOD + t"           "Terminal (foot)"
row "MOD + Space"       "Launcher de apps (wmenu)"
row "MOD + b / e"       "Navegador (Floorp) / Arquivos (Thunar)"
row "MOD + m"           "Menu inicial (acoes do dia a dia)"
row "MOD + / ou ?"      "Esta ajuda"

sec "Janelas"
row "MOD + q"           "Fecha a janela"
row "MOD + setas"       "Move o foco"
row "MOD + Shift + setas"   "Move a janela"
row "MOD + Shift + Ctrl + setas" "Redimensiona (10px)"
row "MOD + f"           "Tela cheia"
row "MOD + Shift + f"   "Volta janelas ao tiling"
row "MOD + Shift + space"   "Janela flutuante / tiled"
row "MOD + a"           "Sobe no container pai"
row "MOD + h / v / s / w"    "Layout: split H, split V, pilha, abas"
row "MOD + arrastar"    "Reordena janela (swap no tiling)"

sec "Workspaces (1..0)"
row "MOD + 1..0"        "Vai ao workspace"
row "MOD + Shift + 1..0"    "Manda a janela para o workspace"

sec "Touchscreen"
row "Tap"               "Clique esquerdo"
row "Segurar 1 dedo"    "Clique direito"
row "Arrastar 1 dedo"   "Move / troca a janela"
row "2 dedos L/R"       "Workspace anterior / proximo"

sec "Controle e extras"
row "MOD + k"           "Teclado virtual (wvkbd)"
row "MOD + o"           "Rotacao automatica (giroscopio)"
row "MOD + p"           "Tela externa HDMI (posicao)"
row "MOD + Shift + v"   "Historico do clipboard (cliphist)"
row "MOD + r"           "Modo redimensionar"
row "MOD + Shift + c"   "Recarrega o sway"
row "MOD + '"           "Terminal escorregadio (scratchpad)"
row "MOD + Shift + e"   "Sair do sway (com confirmacao)"
row "Ctrl + Alt + Del"  "Travar / suspender / desligar / sair"
row "MOD + Print"       "Print de area (clipboard)"
row "Tecla Positivo"    "Print de tela inteira (~/Images/Prints)"
row "Tecla Copilot"     "Abre o opencode"

printf "\n%s(qualquer tecla fecha)%s\n" "$c_dim" "$rst"
read -rn1 -s || true
printf "\033[0m\n"