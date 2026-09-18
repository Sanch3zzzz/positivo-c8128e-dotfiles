# 00 · Lista de pacotes (checklist de instalação)

Referência rápida de **tudo** que precisa ser instalado, na ordem. Baseado no
guia completo em `01`..`05` (link pro passo a passo quando houver).

## 1 · Base do Arch (após chroot — ver `01-instalacao-arch.md`)

```bash
pacstrap -K /mnt base linux linux-firmware intel-ucode \
    networkmanager sudo git nano
```

## 2 · Ambiente gráfico (Sway + Wayland — ver `02-gui-sway-wayland.md`)

```bash
sudo pacman -S --needed \
    sway wayland xorg-xwayland foot wmenu waybar swaybg \
    swaylock mako grim slurp wl-clipboard brightnessctl playerctl \
    mesa iio-sensor-proxy evtest wev \
    pipewire pipewire-alsa pipewire-pulse wireplumber \
    noto-fonts ttf-dejavu ttf-jetbrains-mono-nerd
```

## 3 · Gestos de toque (ver `02` e `03-gestos-touch.md`)

```bash
sudo pacman -S python-evdev ydotool
```

> O daemon de gestos re-executa via `sudo -n`; acessa `/dev/input/*` e
> `/dev/uinput` sem senha (ver `root/etc/sudoers.d/10-celeron-nopasswd`).
>
> Teclado virtual na tela: `wvkbd-deskintl` (AUR; **conflita** com o pacote
> `wvkbd`). Detalhes e atalho (`MOD + k`) em `03-gestos-touch.md` §3.5.

## 4 · Tela de login (greetd + tuigreet — ver `02`)

```bash
sudo pacman -S greetd greetd-tuigreet
sudo systemctl enable --now greetd.service
```

## 5 · Área de transferência com histórico

```bash
sudo pacman -S cliphist
```

## 6 · Bluetooth (ver `04-hardware-extras.md`)

```bash
sudo pacman -S bluez bluez-utils
```

## 7 · Apps (ver `05-apps-ytermusic.md`)

```bash
# Repositórios do Arch
sudo pacman -S thunar thunar-archive-plugin foliate vlc mpv imv micro yt-dlp

# AUR (precisa de um helper como paru/yay)
paru -S floorp-bin pamac-aur
```

## 8 · ytermusic (YouTube Music no terminal — ver `05` seção 5.4)

Compilar do git master (a versão AUR `ytermusic-bin` está quebrada por 403 do
Google). Precisa de `cargo` (~15 min no Celeron N4500) e autenticação via
`headers.txt` (cookie — **não** versionado no repo).

## 9 · Manuseio de arquivos no Thunar (compactados/thumbnails/volumes)

```bash
sudo pacman -S ark tumbler thunar-volman gvfs gvfs-mtp gvfs-smb \
    p7zip unzip thunar-media-tags-plugin \
    poppler-glib ffmpegthumbnailer libgsf libgepub libopenraw \
    qt6ct
```

- `ark` = handler de extração do `thunar-archive-plugin` (botão direito:
  "Extrair aqui"/"Criar arquivo"). Associações MIME em
  `.config/mimeapps.list` já apontam os compactados para `org.kde.ark.desktop`.
- `tumbler` (+ `poppler-glib` p/ PDF, `ffmpegthumbnailer` p/ vídeo,
  `libgsf` p/ ODF, `libgepub` p/ EPUB e `libopenraw` p/ RAW) = miniaturas
  no Thunar. Reinicie `systemctl --user restart tumblerd.service`
  se instalar os opcionais depois. Obs.: `libgepub` puxa o webkit2gtk
  (~120MB).
- `thunar-volman` (+ `udisks2`, vêm juntos) = auto-montar USB/dispositivos.
- `gvfs` + `gvfs-mtp` (celular Android) + `gvfs-smb` (pastas Windows/rede).
- `thunar-media-tags-plugin` = editar tags de áudio nas Propriedades.
- `qt6ct` = tema escuro p/ apps Qt/KDE (Ark). Config já no repo
  (`.config/qt6ct/qt6ct.conf` com esquema `darker`); env
  `QT_QPA_PLATFORMTHEME=qt6ct` exportada no `start-sway`.

## 10 · Memória, bateria e idle (ver `02`, `03` e `04`)

```bash
sudo pacman -S zram-generator systemd-oomd swayidle
sudo systemctl enable --now systemd-oomd.service
systemctl --user enable --now battery-alert.timer   # unidades: ./install.sh
```

- **`zram-generator`** — swap comprimido em RAM (½ da RAM, zstd) com
  prioridade **100**, maior que o swap de disco: o eMMC (lento + desgastável)
  só vira reserva em pressão extrema. Config: `root/etc/systemd/zram-generator.conf`.
- **`systemd-oomd`** — evita a tela congelar com a memória cheia: mata o
  processo guloso no `user.slice` (drop-in
  `root/etc/systemd/system/user.slice.d/oomd.conf`).
- **`swayidle`** (com `swaylock`, já instalado) — trava aos 5min parado,
  apaga a tela aos 10min e suspende aos 30min; também trava antes de dormir
  (botão de energia/lid). Config em `.config/swayidle/config` e
  `.config/swaylock/config`.
- **Alerta de bateria baixa** — timer do usuário (`battery-alert.timer`,
  a cada 3min) notifica em 30%/15%/10% descarregando; reset ao recarregar.
  Script: `home/.local/bin/battery-alert.sh`.
- **OSD de volume e brilho** — o mako (config em `.config/mako/config`)
  mostra popup ~0,8s do nível no scroll (scripts `vol-step.sh` e
  `brightness-step.sh`).

---

**Nota:** o `install.sh` **não instala pacotes** — só copia configs. Depois de
instalar tudo acima: `./install.sh` (configs de usuário) e `./install.sh
--root` (arquivos de sistema: greetd, logind, sudoers, start-sway). Confira
com `./install.sh --check`; desfaz com `./install.sh --uninstall`. Procurou
e não achou o erro? Veja `06-troubleshooting.md`.