# 06 · Troubleshooting (FAQ consolidada)

As "pegadinhas" espalhadas pelas docs, reunidas aqui pra quem está instalando
(ou em outra máquina).

## Toque/gestos

### O daemon de gestos não funciona / nada clica
- Log: `cat /tmp/sway-touch-gestures.log` (o daemon também registra erros).
- Verifique se está rodando: `pgrep -af touch-gestures.py`.
- Dependências: `python-evdev` (módulo) e `ydotool` (daemon do usuário:
  `systemctl --user status ydotool.service`).
- **Touchscreen com outro nome** → o script só aceita `REQUIRED_NAME =
  "FTSC1000:00 2808:509C"` (topo de `touch-gestures.py`). Se o seu device é
  outro, descubra com `ls /proc/bus/input/devices | grep -i touch` / `evtest`
  e ajuste a constante.
- Sem permissão em `/dev/input/eventX`: o script re-executa via `sudo -n`
  (NOPASSWD do sudoers). Verifique `sudo -n true`.

### Tap vira clique duplo no navegador
Proposital: o Floorp/Firefox já converte o toque em clique nativo — o daemon
**ignora** o tap quando um navegador está focado (lista `BROWSERS` no script).

### Arrastar não faz swap / faz scroll da página
Tem que **segurar ~1s antes** de arrastar (`DRAG_HOLD`); arrastar na hora é
scroll do navegador.

## Teclado virtual (wvkbd)

### `MOD + k` não abre teclado
- Pacote certo é **`wvkbd-deskintl` (AUR)** — **não** `wvkbd` (os dois
  conflitam).
- Verifique o binário: `command -v wvkbd-deskintl`.
- Log/marcador: `/tmp/wvkbd-visible` (o script usa `SIGUSR1/SIGUSR2`).

## Áudio

### Sem som / sink errado
- `wpctl status` → veja o sink padrão.
- Se mudou a saída e os apps não acompanharam: `pactl list short
  sink-inputs` (o `audio-menu.sh` já move as entradas ativas).
- Pipewire parado: `systemctl --user status wireplumber pipewire`.

## Brilho

### Setas de brilho / scroll não mudam nada
- Lista os devices: `brightnessctl -l` (o deste notebook é um backlight
  ACPI; em outro hardware o nome pode mudar).
- O passo por scroll é `BRIGHTNESS_STEP` (padrão 5) em
  `~/.config/waybar/scripts/brightness-step.sh`.

## Rotação automática

### A tela gira pro lado errado
Inverta `90` e `270` no `map_orient()` de `~/.config/sway/scripts/autorotate.sh`.
O sensor varia por unidade; o mapa atual (`right-up → 90`) vale para este
exemplar específico.

- Logs: `/tmp/sway-autorotate.log` e `/tmp/sway-touch-gestures.log`.

## Sway / reload

### Cada `reload` duplica algo (barra, wallpaper)
É o `exec_always`. Serviços únicos (waybar, swaybg, swayidle) usam `exec`;
oscripts com `exec_always` precisam de trava própria (o `touch-gestures.py`
tem `flock`, o `wallpaper-random.sh` dá `pkill -x swaybg`). Não adicione
`exec_always` em serviço de processo único.

### A trava/suspensão automática (swayidle) não funciona
Se `pgrep -a swayidle` não retorna nada, o config provavelmente tem erro de
sintaxe e o swayidle abortou. Teste com
`swayidle -d -C ~/.config/swayidle/config`: **`resume` não é evento
standalone** no swayidle 1.9 — ele só existe como sufixo de uma linha
`timeout`:

```conf
timeout 600 'swaymsg "output * dpms off"' resume 'swaymsg "output * dpms on"'
```

(errado: `timeout 600 '...'` seguido de uma linha `resume '...'` — isso dá
`Unexpected keyword "resume"` e mata todos os timeouts). O hook de wake do
logind é `after-resume`, esse sim é um evento válido. Como o sway sobe o
swayidle com `exec` (não `exec_always`), depois de corrigir reinicie a
sessão ou rode `pkill swayidle; swayidle -w -C ~/.config/swayidle/config &`.

### Validar a config sem derrubar a sessão
```bash
sway --validate -c ~/.config/sway/config
```

### `MOD + '` (scratchpad) não abre
No ABNT2 a tecla é a **à esquerda do `1`** (produz `'`/`"`, keysym
`apostrophe`). `grave` só existe em `AltGr+Shift` e o bind é
`$mod+apostrophe` — nunca `$mod+grave`.

## Menu de ações (`Ctrl + Alt + Delete`)

Não abre? Faltam `wmenu`/`swaynag` (parte do `sway`/`wmenu`). O script é
`~/.config/sway/scripts/power-actions.sh`.

## Instalação

### Tela preta no primeiro boot
Sem imagens em `~/Images/Wallpapers`, o `wallpaper-random.sh` usa **cor
sólida** (`#0a1628`) como fallback — não é erro. Para wallpaper real, copie
imagens `.png/.jpg` para `~/Images/Wallpapers`.

### "Faltam dependências" no install.sh
O instalador não instala pacotes de propósito; rode `./install.sh --check`
para a lista completa e confira `docs/00-pacotes.md`.