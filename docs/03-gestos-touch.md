# 03 · Gestos de toque e rotação (modo tablet)

## 3.1 · Como funciona

Dois componentes independentes:

1. **Daemon de gestos** (`~/.config/sway/scripts/touch-gestures.py`) — lê o
   touchscreen via evdev e traduz gestos em comandos;

2. **ydotool** — daemon em userspace que injeta cliques em `/dev/uinput`
   (roda como serviço do usuário `ydotool.service`).

O script usa o `swaymsg` para mover o cursor até o ponto e o ydotool para
clicar. Tudo em software: nenhuma dependência de drivers proprietários da
Positivo.

## 3.2 · Gesto → ação

| Gesto | Ação | Condição |
|---|---|---|
| Tap (toque rápido e parado) | Clique esquerdo no ponto | < 0,25s e movimento < 12px |
| Segurar 1 dedo parado | Clique direito no ponto | ≥ 0,6s e movimento < 12px |
| Arrastar 1 dedo | Swap da janela no tiling | segurar ~1,0s antes de arrastar, ≥ 100px |
| Arrastar 1 dedo (janela flutuante) | Move a janela livremente | mesma regra do hold |
| Deslizar 2 dedos L/R | Workspace next / prev | ≥ 60px e dominância horizontal |

Limiares configuráveis no topo do script:

```python
MOVE_STEP = 16        # passo de "move" durante arraste de flutuante
DRAG_ARM  = 14        # movimento minimo p/ considerar arraste
DRAG_HOLD = 1.0       # segurar antes de arrastar (evita swap ao rolar pagina)
SWIPE_TH  = 60        # deslocamento p/ swipe de 2 dedos
SWAP_DIST = 100       # deslocamento minimo p/ ativar swap
TAP_TIME  = 0.25      # max duracao p/ contar como tap
LONG_PRESS = 0.60     # min duracao p/ segurar = clique direito
TAP_MOVE  = 12        # movimento max p/ contar como toque parado
```

Hardcoded para a tela de **1366x768**:

```python
SCREEN_W, SCREEN_H = 1366, 768
REQUIRED_NAME = "FTSC1000:00 2808:509C"
```

## 3.3 · O porquê das pegadinhas

- **Tap não clica em navegadores.** O Floorp/Firefox/Chromium converte o
  toque em clique nativo por conta própria; se o daemon também clicasse,
  virava clique duplo (upvote marcava e desmarcava). O script consulta a
  árvore do sway (`swaymsg -t get_tree`) e ignora o tap quando há um
  navegador focado. Lista em `BROWSERS`.

- **Segurar antes de arrastar.** Arrastar na hora é scroll da página (o
  toque nativo); só vira swap depois do `DRAG_HOLD`.

- **`sudo -n` automático.** O script tenta abrir `/dev/input/eventX`;
  sem permissão re-executa como root via `sudo -n` (por isso o NOPASSWD do
  grupo wheel — ou, mais restrito, NOPASSWD para `/usr/bin/python3
  /home/.../touch-gestures.py`).

## 3.4 · Rotação automática (giroscópio)

Sensor **mxc4005** exposto pelo **iio-sensor-proxy** (serviço DBus).

Script: `~/.config/sway/scripts/autorotate.sh` — atalho **`MOD + o`**
liga/desliga.

- Ao ligar: sobe o `monitor-sensor --accel`, lê a orientação pelo DBus e
  aplica `swaymsg output eDP-1 transform <N>`.
- **Pausa o daemon de gestos** (`kill -STOP <pid>`, pid em
  `/tmp/sway-touch-gestures.pid`): com a tela rotacionada, as coordenadas
  fixas 1366x768 dos gestos quebrariam; o toque nativo (ya transformado pelo
  sway) continua funcionando — o que basta para o Foliate virar páginas.
- Ao desligar: mata o `monitor-sensor`, volta `transform 0` e retoma o
  daemon (`kill -CONT`).

Logs: `/tmp/sway-autorotate.log` e `/tmp/sway-touch-gestures.log`.

Mapa orientação → transform (validado no aparelho; varia por modelo):

| Orientação lida | transform |
|---|---|
| normal | 0 |
| right-up | 90 |
| bottom-up | 180 |
| left-up | 270 |

Caso gire pro lado errado, inverta `90` e `270` no `map_orient()` do script.

## 3.5 · Teclado virtual (wvkbd-deskintl)

`~/.config/sway/scripts/toggle-osk.sh`, atalho **`MOD + k`**. Alterna liga/
desliga do `wvkbd-deskintl` (ATIVO: instale `wvkbd-deskintl` do AUR — o
layout `deskintl` tem melhor suporte nativo a retrato e **conflita** com o
pacote `wvkbd`).

Como o teclado virtual **não tem tecla MOD**, há também um **botão na
waybar** (módulo `custom/osk`, ícone de teclado, ao lado do bluetooth)
que chama o mesmo script. O toggle usa sinais determinísticos do wvkbd
(`SIGUSR1` esconde / `SIGUSR2` mostra) e mantém um marcador de estado em
`/tmp/wvkbd-visible`, para `MOD + k` e o botão ficarem consistentes.

Pegadinha: usar `pkill -RTMIN` (toggle) + `pgrep` não serve pra saber se
está visível — o wvkbd continua vivo quando escondido. E no waybar, botão
com `exec` sem `interval` fica re-executando o script em loop (derruba a
barra num Celeron); preferir botão fixo (`format` + `on-click`).

## 3.6 · Drag de janela com mouse/touchpad

Mesma ideia do gesto de arrastar, mas acionado por **`MOD + botão 1`
arrastar** — funciona em touchpad (físico) e mouse.

- Em janela **tiled**: a janela vira "fantasma" seguindo o cursor; ao
  **soltar** faz **swap** com a janela sob o cursor (mesmo workspace).
- Em janela já **flutuante**: move livremente (sem swap).

Script: `~/.config/sway/scripts/drag-window.py`, binds no sway config
(`~/.config/sway/config`):

```
bindsym --whole-window $mod+Button1 exec ~/.config/sway/scripts/drag-window.py start
bindsym --whole-window --release $mod+Button1 exec ~/.config/sway/scripts/drag-window.py end
```

### Por que no sway 1.12

- O IPC **não expõe a posição absoluta do cursor** (`get_seats` só tem
  name/capabilities/focus/devices), então o fantasma é movido por
  **deslocamento** lido do evdev: touchpad ABS normalizado para 1366x768
  (X 0–1260 / 720 → `pos * 1366/1260`, etc.) e mouse REL.
- O **`floating_modifier` nativo foi removido**: o drag nativo do sway
  engolia o evento de soltar (a janela ficava flutuante). O script cuida de
  tudo.
- O "soltar" é detectado por **duas vias**: o bind `--release` (escreve
  `/tmp/sway-drag-window.stop`) **ou** o `BTN_LEFT = 0` físico lido no evdev
  (root via `sudo -n`).
- **Swap só com movimento real (≥ 30px)**: `MOD + clique` seco na janela não
  reordena nada — só re-flutua e re-tila no lugar.

### Detalhes de implementação

- Flutuante no `get_tree` é nó `floating_con` (não `con`) — as funções de
  buscas tratam os dois (`WIN_TYPES`).
- Antes de dar `floating enable` o script grava o **centro original** em
  `/tmp/sway-drag-window.state` (`nid mode cx cy`); no final compara com o
  centro final p/ decidir swap; o alvo é a **menor** janela que contém o
  centro do fantasma (`leaf_containing`).
- Log: `/tmp/sway-drag-window.log` (erros e motivo do fim do drag).