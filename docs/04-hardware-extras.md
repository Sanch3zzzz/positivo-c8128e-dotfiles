# 04 · Hardware — extras (BT, energia, relógio, teclas)

## 4.1 · Bluetooth

Hardware: Realtek RTL8821C (USB).

```bash
sudo pacman -S bluez bluez-utils
sudo systemctl enable --now bluetooth.service
```

Controle pela waybar (`#bluetooth`):

- **clique esquerdo**: menu com os dispositivos pareados (conecta/
  desconecta)
- **clique do meio**: liga o BT
- **clique direito**: desliga o BT

## 4.2 · Energia (governor + teto de frequência)

**`power-profiles-daemon` NÃO funciona** neste hardware (sem
`platform_profile` no ACPI e o `epp` do `intel_pstate` é read-only em
alguns estados). Por isso o controle é por governador + `scaling_max_freq`:

| Modo | governor | teto |
|---|---|---|
| Performance | performance | máx (2,8 GHz) |
| Balanceado | powersave | máx (2,8 GHz) |
| Economia | powersave | base (1,1 GHz) |

O bar usa `~/.config/waybar/scripts/power-menu.sh`:

- **clique esquerdo** no ícone de energia: menu (3 modos)
- **clique direito**: ciclo Performance → Balanceado → Economia
- tooltip mostra o modo atual

O script precisa de root para escrever em
`/sys/devices/system/cpu/cpufreq/policy*` → é o motivo do NOPASSWD no
sudoers (configurado em [01 · dentro do chroot](01-instalacao-arch.md#15-dentro-do-chroot)).

Opção mais restrita que o `%wheel NOPASSWD: ALL`: criar um NOPASSWD só para
o power-menu:

```
gustavosp ALL=(ALL) NOPASSWD: /home/<user>/.config/waybar/scripts/power-menu.sh
```

## 4.3 · Botão de energia e tampa (lid)

Comportamento via drop-ins do logind (`/etc/systemd/logind.conf.d/`,
incluídos no repo):

```ini
# power-button.conf
[Login]
HandlePowerKey=suspend

# lid.conf
[Login]
HandleLidSwitch=suspend
HandleLidSwitchExternalPower=suspend
```

## 4.4 · Relógio

```bash
sudo timedatectl set-timezone America/Sao_Paulo
sudo systemctl enable --now systemd-timesyncd.service
```

## 4.5 · Brilho / áudio / mídia na tecla de função

Os binds ficam no config do sway: `XF86Audio*`, `XF86MonBrightness*`. Tudo
com `--locked` para funcionar com a tela travada (swaylock).

Screenshot:
- Tecla **Positivo** (`XF86Launch8`): tela inteira → `grim`, salva em
  `~/Images/Prints/`, copia pro clipboard (`wl-copy`).
- `MOD + Print`: seleção de área (grim + slurp) direto pro clipboard.

## 4.6 · Teclas especiais do C8128E

### Tecla Positivo (print de tela inteira)

- Físicamente é `KEY_F17` (kernel 187).
- O sway usa **keycodes XKB = kernel + 8** → kernel 187 vira xkb 195 =
  `FK17`, cuja keysym no layout `br` é `XF86Launch8` (**não** F17 — por isso
  `bindsym F17` não disparava).
- Bind que funciona:

  ```conf
  bindsym XF86Launch8 exec ~/.config/sway/scripts/screenshot-full.sh
  ```

**Atenção:** o `bindsym --code 187` (estilo numérico) **não existe** no sway
1.12; use sempre keysym.

### Tecla Copilot (abre o opencode)

- O firmware emite o **combo** `Super + Shift + Search` (scancodes
  `6e + db + 2a`) — não manda um scancode único.
- Bind no sway:

  ```conf
  bindsym $mod+Shift+XF86Search exec $term /home/<user>/.opencode/bin/opencode
  ```

## 4.7 · Diagnóstico rápido de teclas

```bash
evtest /dev/input/*            # scancodes brutos (teclado interno AT)
wev                            # keysym real dentro da sessão Wayland
xkbcli compile-keymap --rules evdev --model abnt2 --layout br   # keymap
```

## 4.8 · Tela externa (HDMI / micro-HDMI)

O C8128E possui uma saída micro-HDMI. Ao conectar um monitor ou TV, o sway
detecta automaticamente; o script `external-display.sh` (em
`~/.config/sway/scripts/`) cuida da posição e escala:

- **`MOD + p`**: abre um menu (wmenu) com as opções Direita / Esquerda /
  Acima / Abaixo / Desconectar.
- **hotplug (plugou / tirou)**: um daemon em background **avisa** e abre
  o menu — nunca muda a posição sozinho, só quando você escolher.
- **Escala automática** baseado na resolução externa (2160p → 1,5; 1440p
  → 1,25; 1080p e abaixo → 1,0). Para ajuste manual:

  ```bash
  swaymsg output HDMI-A-1 scale 1.25
  swaymsg output HDMI-A-1 mode 1920x1080@60Hz
  ```

### Como ver o nome do output externo

```bash
swaymsg -t get_outputs          # JSON bruto (procure por HDMI-A-1, DP-1 etc.)
swaymsg -t get_outputs -r | python3 -c "import json,sys; [print(o['name'],o['active']) for o in json.load(sys.stdin)]"
```

> **Pegadinhas (testadas no aparelho, sway 1.12):**
> - O `get_outputs` **não tem mais `width`/`height` no topo** do objeto;
>   eles estão em `current_mode` (fallback `rect`). Ler `o["width"]`
>   direto dá `KeyError` e derruba o script.
> - **Coordenadas negativas** (`position -1920 0`) precisam ser passadas
>   numa **única string**: `swaymsg output HDMI-A-1 position -1920 0` faz
>   o swaymsg engolir o `-1920` como opção (`invalid option -- '1'`).
>   Use `swaymsg "output HDMI-A-1 position -1920 0 scale 1.00"`.
> - Depois de `output <name> disable`, o output **continua na lista** de
>   `get_outputs` (só `active=0`). Para religar: `swaymsg output <name>
>   enable` (ou replug).

### Mover workspace pra tela externa

```bash
swaymsg workspace 2; swaymsg move workspace to output HDMI-A-1
```

### Áudio por HDMI

Quando a TV é conectada, o `PulseAudio/PipeWire` pode adicionar um novo
sink. Para direcionar o áudio (pode variar):

```bash
pactl list sinks short              # veja os sinks disponíveis
pactl set-sink-volume @DEFAULT_SINK@ 100%
pactl set-default-sink <sink-name>  # direciona o áudio pra TV
```