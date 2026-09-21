# 02 · Ambiente gráfico (Sway + Wayland)

## 2.1 · Pacotes base do ambiente

```bash
sudo pacman -S --needed \
    sway wayland xorg-xwayland foot wmenu waybar swaybg seatd \
    swaylock mako grim slurp wl-clipboard brightnessctl playerctl \
    mesa iio-sensor-proxy evtest wev \
    pipewire pipewire-alsa pipewire-pulse wireplumber \
    noto-fonts ttf-dejavu ttf-jetbrains-mono-nerd
```

O `wl-clipboard` fornece os comandos `wl-copy`/`wl-paste` (clipboard do
Wayland). Para **histórico da área de transferência**, instale também:

```bash
sudo pacman -S cliphist
```

## 2.2 · seatd (permissões de sessão)

```bash
sudo pacman -S seatd
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
./install.sh                 # configs do usuário (preflight + pastas de imagens)
./install.sh --root          # arquivos de sistema (start-sway, logind, sudoers, zram)

./install.sh --check         # valida pacotes, grupos, timers e arquivos
./install.sh --uninstall     # restaura o último backup (o --root desfaz os de sistema)
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

### Área de transferência com histórico (cliphist)

O `cliphist` guarda tudo que você copiar (texto e imagem):

- Daemon: `exec wl-paste --watch cliphist store` — roda no init do sway e
  vai acumulando o histórico em `~/.cache/cliphist/db`.
- Atalho **`MOD + Shift + v`**: abre o histórico num `wmenu`, escolhe um item e ele
  é copiado de volta pro clipboard (`cliphist list | wmenu | cliphist
  decode | wl-copy`).
- Limpar o histórico se quiser: `cliphist wipe`.

### Ajustes manuais únicos que não estão nos dotfiles

- **DPI** do touchpad/sensibilidade pode variar por unidade; o config usa
  `accel_profile flat` + `pointer_accel 0.3`, `tap_button_map lrm`. Sinta e
  ajuste em `~/.config/sway/config`.

## 2.8 · Terminal escorregadio (scratchpad)

Atalho **`MOD + '`** abre/fecha um foot "escorregadio" sobre as janelas
(estilo Guake/yakuake), usando o scratchpad nativo do sway.

- Script: `~/.config/sway/scripts/toggle-scratchpad.sh`
- Se nenhuma janela scratchpad existe, ele cria um `foot --app-id scratchpad`
  e manda pro scratchpad; se já existe, alterna entre mostrar e esconder.
- **Pegadinhas (testado):**
  - O atalho é `$mod+apostrophe`, NÃO `$mod+grave`. `grave` (a crase `` ` ``) é
    US-cêntrico: no layout BR/ABNT2 esse keysym só existe no **AltGr+Shift** da
    tecla à direita do P, então `MOD+grave` nunca dispara na prática. A tecla à
    esquerda do `1` (posição do backtick no US) no ABNT2 produz `apostrophe`
    (`'`/`"`), sem Shift — por isso é ela que funciona.
  - O flag do foot é `--app-id` (com hífen). `--app_id` NÃO existe e o foot
    aborta com "unrecognized option".
  - A detecção NÃO pode ser `swaymsg -t get_tree | grep '"app_id":"scratchpad"'`:
    o JSON do sway é indentado (`"app_id": "scratchpad"`, com espaço) e o grep
    nunca casa, fazendo abrir um foot NOVO a cada tecla. Solução robusta: usar
    o exit code do próprio swaymsg — `swaymsg -q "[app_id=scratchpad]
    scratchpad show"` retorna 0 se existe (e alterna mostrar/esconder) e 2 se
    não existe (cria).

Também há **`MOD + shift + f`**: joga **todas** as janelas flutuantes de volta
ao layout tiled (`[floating] floating disable`). Útil quando o drag-window.py
ou algum app deixa janela solta por engano.

**Pegadinha (testado):** o sway NÃO remove aspas no `bindsym`. 
`bindsym $mod+Shift+f '[floating] floating disable'` (com aspas) vira um
comando inválido e **nada acontece** — o binding nem roda. Tem que ser **sem**
aspas: `bindsym $mod+Shift+f [floating] floating disable`. O `[floating]` no
início do comando funciona porque o sway considera o resto da linha como o
comando. O mesmo bug atingia o `MOD + Shift + e` (swaynag do logout), que usava
aspas simples `'Sair do sway?'`; trocado para aspas duplas `"Sair do sway?"`
(e o sway as remove no `exec`).

## 2.9 · Waybar standalone

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
  `bluetooth-menu.sh`, `power-menu.sh`, `vol-step.sh`,
  `brightness-step.sh`

Continuação: [03 · gestos de toque](03-gestos-touch.md).

## 2.10 · Thunar completo: compactados, thumbnails, volumes e tema escuro Qt

### Arquivos compactados (ark)

O `thunar-archive-plugin` (já instalado junto do Thunar) só precisa de um
handler no PATH. Instale o `ark` e o botão direito em `.zip`/`.tar.gz`/`.7z`
passa a oferecer **"Extrair aqui"**, **"Extrair para..."** e **"Criar
arquivo..."** automaticamente — sem configuração.

Para o **duplo clique** abrir no Ark, as associações MIME já estão em
`.config/mimeapps.list` (`application/zip`, `application/gzip`, `application/x-tar`,
`application/x-7z-compressed`, `application/vnd.rar`, etc. →
`org.kde.ark.desktop`).

Backends de linha de comando: `7zip` (comando `7z`) e `unzip`.

```bash
sudo pacman -S ark p7zip unzip
```

### Miniaturas (tumbler)

```bash
sudo pacman -S tumbler poppler-glib ffmpegthumbnailer \
    libgsf libgepub libopenraw
```

O daemon `tumblerd` é ativado por D-Bus (`org.freedesktop.thumbnails.
Thumbnailer1`) quando o Thunar abre uma pasta. Suporta imagens por padrão;
`poppler-glib` habilita PDF, `ffmpegthumbnailer` habilita vídeo, `libgsf`
ODF, `libgepub` EPUB e `libopenraw` RAW. Se instalar esses opcionais depois,
reinicie o serviço: `systemctl --user restart tumblerd.service`. Obs.:
`libgepub` puxa o `webkit2gtk` (~120MB).

### Volumes removíveis e rede (thunar-volman + gvfs)

```bash
sudo pacman -S thunar-volman gvfs gvfs-mtp gvfs-smb
```

- `thunar-volman` (+`udisks2`) monta USBs/pendrives automaticamente.
- `gvfs-mtp` → celular Android via USB (daemon `/usr/lib/gvfsd-mtp`).
- `gvfs-smb` → compartilhamentos Windows/rede (daemon `/usr/lib/gvfsd-smb`).

Os daemons do gvfs sobem sob demanda via D-Bus.

### Tags de áudio (thunar-media-tags-plugin)

```bash
sudo pacman -S thunar-media-tags-plugin
```

Plugin thunarx que adiciona edição de tags (título/artista/álbum) nas
Propriedades do arquivo de áudio. Plugin novo exige reabrir o Thunar.

### Tema escuro p/ apps Qt/KDE (qt6ct)

Apps KDE (ex.: o Ark) abrem com a paleta clara padrão do Qt fora do Plasma.
Solução: instalar o `qt6ct` e apontar para um esquema escuro —

```bash
sudo pacman -S qt6ct
```

- Config: `~/.config/qt6ct/qt6ct.conf` (estilo `Fusion`, paleta custom
  `/usr/share/qt6ct/colors/darker.conf` — ver `.config/qt6ct/qt6ct.conf` no repo).
- É preciso exportar `QT_QPA_PLATFORMTHEME=qt6ct`. Adicionado no
  `root/usr/local/bin/start-sway` — **só vale do próximo login em diante**;
  para testar na sessão atual: `env QT_QPA_PLATFORMTHEME=qt6ct ark`.

## 2.11 · Idle, trava de tela, bateria e feedback de volume/brilho

### Travar e apagar tela (swayidle + swaylock)

O sway sobe o `swayidle -w -C ~/.config/swayidle/config` junto com o mako:

| Tempo parado | Ação |
|---|---|
| 5 min | `swaylock -f` (trava, tema em `~/.config/swaylock/config`) |
| 10 min | tela apaga (`output * dpms off`); volta com qualquer tecla |
| 30 min | `systemctl suspend` |

`before-sleep` também trava antes de suspender (botão de energia ou lid).

### Menu de ações (`Ctrl + Alt + Delete`)

Abre o `power-actions.sh` (wmenu): **Travar / Suspender / Reiniciar /
Desligar / Sair**. Reiniciar/Desligar/Sair pedem confirmação via swaynag.
O `MOD + Shift + e` continua sendo o sair direto.

### Alerta de bateria baixa

Waybar já pinta o ícone em aviso/crítico; agora um timer do usuário
(`~/.config/systemd/user/battery-alert.timer`, a cada 3 min) dispara um
`notify-send` (crítico, sem timeout) quando descarrega abaixo de **30%**,
**15%** e **10%** — avisando 1x por limiar. Reset ao recarregar.

### OSD de volume e brilho

`vol-step.sh` (scroll do volume) e `brightness-step.sh` (scroll do brilho,
novo) mostram um popup no mako por ~0,8s com o nível atual. O mako agora
tem config (`~/.config/mako/config`) com o tema Dark Azul.

### Fix: wallpaper sem vazar swaybg

O `wallpaper-random.sh` trocou de `exec_always` para `exec` — cada `reload`
do sway duplicava o `swaybg` (mesmo problema que o waybar teve). O script
também chama `pkill -x swaybg` antes de subir, pra re-rodadas manuais não
empilharem instâncias. A wallpaper continua viva entre reloads (o sway não
mata o `swaybg` no reload).