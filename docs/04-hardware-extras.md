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