# 02 · Ambiente gráfico (Sway + Wayland)

## 2.1 · Pacotes base do ambiente

```bash
sudo pacman -S --needed \
    sway wayland xorg-xwayland foot wmenu waybar swaybg \
    swaylock mako grim slurp wl-clipboard brightnessctl playerctl \
    mesa iio-sensor-proxy evtest wev \
    pipewire pipewire-alsa pipewire-pulse wireplumber \
    noto-fonts ttf-dejavu ttf-jetbrains-mono-nerd
```

## 2.2 · seatd (permissões de sessão)

```bash
sudo systemctl enable --now seatd.service
sudo usermod -aG seat $USER
```

## 2.3 · Acesso ao touchscreen para leitura dos eventos

O daemon de gestos lê `/dev/input/eventX`. Duas partes:

- **python-evdev** (para o script):

  ```bash
  sudo pacman -S python-evdev
  ```

- **ydotool** (daemon que simula cliques em `/dev/uinput`):

  ```bash
  sudo pacman -S ydotool
  systemctl --user enable --now ydotool.service
  ```

  Acessar `/dev/input/*` e `/dev/uinput` sem senha exige estar no grupo
  `input` **ou** (como aqui) rodar o daemon de gestos via `sudo -n` — o
  script `touch-gestures.py` re-executa como root sozinho quanto não tem
  permissão (ver [03 · gestos](03-gestos-touch.md)).

## 2.4 · Instalar os dotfiles

```bash
git clone https://github.com/<seu-usuario>/positivo-c8128e-dotfiles.git
cd positivo-c8128e-dotfiles
./install.sh                 # configs do usuario
sudo ./install.sh --root     # arquivos de sistema (start-sway, logind, sudoers)
```

## 2.5 · Tela de login ao ligar (greetd + tuigreet)

O sway agora sobe por um **display manager minimalista** (greetd + greeter
tuigreet em TUI): ao ligar o notebook cai direto na tela de login no VT 1 e,
após autenticar, roda `/usr/local/bin/start-sway` e abre a sessão Wayland.

```bash
sudo pacman -S greetd greetd-tuigreet
sudo systemctl enable --now greetd.service
```

Config: `root/etc/greetd/config.toml` (copiado por `./install.sh --root`):

```toml
[terminal]
vt = 1

[default_session]
command = "tuigreet --time --cmd /usr/local/bin/start-sway"
user = "greeter"

# [initial_session]
# command = "/usr/local/bin/start-sway"
# user = "gustavosp"
```

- `--time` mostra o relógio na tela de login; `--cmd` define o que rodar
  após o login.
- `[initial_session]` comentado **exige senha em toda inicialização**;
  descomente se quiser autologin.
- O usuário `greeter` (uid/gid 966) é criado pelo próprio pacote.

O `/usr/local/bin/start-sway` exporta as variáveis de sessão Wayland e o
`TERMINAL=foot` (usado por apps com `Terminal=true`). Depois de instalar,
deslogue/relogue uma vez para o `TERMINAL` valer na sessão.

> No config deste repo o sway inicia o waybar com `exec` (não
> `exec_always`) para não vazar uma barra nova a cada reload do sway.

> **Manual (opcional):** o alias `sway` no `~/.bashrc` ainda funciona para
> subir em um TTY manual (ex.: `Ctrl+Alt+F2`):
> `alias sway='exec newgrp seat -c /usr/bin/sway'`

## 2.6 · Áudio

O pipewire já vem habilitado pelos pacotes. Confira o padrão de saída com:

```bash
wpctl status
```

## 2.7 · Primeiro boot do sway

Ao ligar, digite usuário (`gustavosp`) e senha na tela de login (tuigreet)
e o sway abre. Atalho para abrir o terminal: **`MOD + t`** (foot). Sair do
sway (`MOD + Shift + e`) volta para a tela de login.

### Ajustes manuais únicos que não estão nos dotfiles

- **DPI** do touchpad/sensibilidade pode variar por unidade; o config usa
  `accel_profile flat` + `pointer_accel 0.3`, `tap_button_map lrm`. Sinta e
  ajuste em `~/.config/sway/config`.

## 2.8 · Waybar standalone

O waybar sobe via `exec waybar` no config do sway (não usa o bar do sway).
Se quiser recarregar a barra após editar:

```bash
pkill waybar && waybar
```

Estrutura (config/scripts) no repo:

- `~/.config/waybar/config.jsonc` (nome obrigatório: `config.jsonc` ou
  `config` — o waybar **não** procura `config.json`)
- `~/.config/waybar/style.css`
- `~/.config/waybar/scripts/network-menu.sh`, `audio-menu.sh`,
  `bluetooth-menu.sh`, `power-menu.sh`, `vol-step.sh`

Continuação: [03 · gestos de toque](03-gestos-touch.md).