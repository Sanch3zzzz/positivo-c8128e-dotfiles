# Positivo C8128E · Arch Linux + Sway

Configurações e guia **passo a passo completo** para deixar esse notebook
(Positivo C8128E, Celeron N4500) rodando **Arch Linux + Sway** com:

- Sway 1.12 (Wayland), foot, wmenu, waybar, mako
- **Gestos de toque de verdade** na touchscreen (tap = clique, segurar =
  clique direito, arrastar = swap de janela, 2 dedos = troca de workspace)
- Rotação automática de tela pelo giroscópio (modo tablet)
- Teclado virtual na tela (wvkbd), leitor de EPUB (Foliate)
- Controle de energia por software (governor + teto de frequência)
- Bluetooth, Wi-Fi, áudio e mídia tudo pela barra (waybar)

Escrito para hardware **Intel Celeron N4500 / UHD Graphics (Jasper Lake)**,
mas quase tudo reaproveitável em qualquer notebook com touchscreen.

## Hardware

| Componente | Modelo |
|---|---|
| CPU | Intel Celeron N4500 @ 1.10 GHz (Jasper Lake) |
| RAM | 7,5 GB |
| GPU | Intel UHD Graphics |
| Touchscreen | FocalTech FTSC1000 (`FTSC1000:00 2808:509C`) |
| Giroscópio | mxc4005 (`/dev/iio:device0`) |
| Bluetooth/Wi-Fi | Realtek RTL8821C (USB) |
| Tela | eDP-1, 1366x768 |

## Estrutura do repositório

```
├── README.md
├── install.sh                 # copia tudo pro lugar (com backup)
├── docs/
│   ├── 00-pacotes.md            # checklist: tudo que precisa instalar
│   ├── 01-instalacao-arch.md    # Arch do zero (particionamento, base, boot)
│   ├── 02-gui-sway-wayland.md # seatd, sway, foot, waybar, mako, audio
│   ├── 03-gestos-touch.md     # daemon de gestos + ydotool + rotação
│   ├── 04-hardware-extras.md  # BT, energia, relógio, teclas extras
│   └── 05-apps-ytermusic.md   # apps, MIME, ytermusic, wallpapers
├── .config/                   # configs do usuário (sway, waybar, mako, MIME)
├── home/                      # scripts do $HOME (~/.local/bin)
└── root/                      # arquivos de sistema (referência)
    ├── etc/systemd/logind.conf.d/power-button.conf
    ├── etc/sudoers.d/10-celeron-nopasswd
    └── usr/local/bin/start-sway
```

## Início rápido (pós-Arch instalado)

```bash
git clone https://github.com/<seu-usuario>/positivo-c8128e-dotfiles.git
cd positivo-c8128e-dotfiles
./install.sh            # instala configs do usuário (não mexe em root)
```

Ou manualmente, seguindo o `docs/` na ordem. O guia completo começa na
[instalação do Arch do zero](docs/01-instalacao-arch.md).

## Atalhos principais (MOD = Super/Windows)

| Atalho | Ação |
|---|---|
| `MOD + t` | Abre terminal (foot) |
| `MOD + Space` | Launcher (wmenu) |
| `MOD + b` / `MOD + e` | Navegador (Floorp) / Arquivos (Thunar) |
| `MOD + q` | Fecha janela |
| `MOD + shift + setas` | Move janela |
| `MOD + shift + i/j/k/l` | Move janela (i=up, k=down, j=left, l=right) |
| `MOD + shift + ctrl + setas` | Redimensiona (10px) |
| `MOD + arrastar` (btn esq.) | Drag real: reordena janela no tiling (swap) ou move flutuante |
| `MOD + shift + f` | Joga todas as janelas flutuantes de volta ao tiling |
| `MOD + h/v/s/w` | Layout split H/V, stacked, tabbed |
| `MOD + 1..0` | Vai ao workspace 1-10 |
| `MOD + shift + 1..0` | Move janela ao workspace 1-10 |
| `MOD + Print` | Screenshot de área (clipboard) |
| `MOD + Shift + v` | Histórico da área de transferência (cliphist) |
| Tecla `Positivo` | Print de tela inteira → `~/Images/Prints/` |
| `MOD + o` | Liga/desliga rotação automática (giroscópio) |
| `MOD + k` | Teclado virtual (wvkbd) |
| `MOD + grave` | Terminal escorregadio (scratchpad) abre/fecha |
| Tecla `Copilot` | Abre o opencode |

Nota: as teclas `Positivo` e `Copilot` são exclusivas desse notebook. Ver
[docs/04-hardware-extras.md](docs/04-hardware-extras.md).

## Gestos de toque

| Gesto | Ação |
|---|---|
| Tap (toque rápido parado) | Clique esquerdo no ponto |
| Segurar 1 dedo 0,6s | Clique direito no ponto |
| Arrastar 1 dedo (segura ~1s) | Swap da janela no tiling / move flutuante |
| Deslizar 2 dedos L/R | Workspace next / prev |

Detalhes, limiares e pegadinhas: [docs/03-gestos-touch.md](docs/03-gestos-touch.md).

## Screenshots

Sem capturas por enquanto — o tema é **Dark Azul Vibrante** (`#0a1628` de
fundo, acento `#2f66a8`), fonte JetBrainsMono Nerd Font.