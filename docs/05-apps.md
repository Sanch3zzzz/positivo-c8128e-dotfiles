# 05 · Aplicativos e MIME

## 5.1 · Apps instalados

| App | Função | Instalação |
|---|---|---|
| floorp | Navegador (fork Firefox) | `paru -S floorp-bin` |
| thunar | Gerenciador de arquivos | `sudo pacman -S thunar thunar-archive-plugin` |
| foliate | Leitor de EPUB/MOBI/FB2/comic | `sudo pacman -S foliate` |
| vlc | Vídeo/áudio | `sudo pacman -S vlc` |
| mpv | Vídeo leve | `sudo pacman -S mpv` |
| imv | Visualizador de imagens | `sudo pacman -S imv` |
| micro | Editor de texto de terminal | `sudo pacman -S micro` |
| pamac | Loja de apps (AUR) | `paru -S pamac-aur` |

O `pamac` abre pelo launcher digitando `pamac`; na primeira abertura precisa
configurar e autenticar o acesso ao AUR.

## 5.2 · Associações de arquivo (MIME)

`~/.config/mimeapps.list` define os apps padrão:

- `text/plain` → micro
- `image/png` → imv
- `video/mp4` → vlc
- `application/epub+zip` / `mobi` / `fb2` / `comic` → Foliate
- `text/html` / `http(s)` → Floorp

Edite o arquivo para adicionar mais extensões de vídeo/imagem conforme os
apps que preferir (o `mimeapps.list` mapeia tipos específicos, não
wildcards).

> O `mimeapps.list` deste repo usa o `userapp-Floorp-PY6MV3.desktop`? Esse é
> um ID **gerado pelo xdg** na máquina original, e não existe em outra
> conta. Depois de instalar o Floorp (e antes de qualquer coisa), rode
> `xdg-settings set default-web-browser floorp.desktop` para regravar as
> entradas `http(s)`/`text/html` com o nome de verdade. Se trocar de
> navegador, use o `.desktop` do seu navegador no mesmo comando.

## 5.4 · Trocar o navegador

O Floorp é o padrão do repo, mas dá pra usar qualquer outro. São dois pontos:

1. **Launchers (MOD + b e menu inicial):**
   - Crie `~/.config/sway/browser.conf` com `set $browser <seu-navegador>`
     (ex.: `set $browser firefox`) — o config do sway já faz `include` desse
     arquivo, então ele sobrescreve o `floorp` padrão automaticamente.
   - O menu inicial (MOD + m) usa `xdg-open`, então já segue o navegador
     padrão do sistema.
2. **Navegador padrão do sistema (links fora do sway):**
   `xdg-settings set default-web-browser firefox.desktop`

Instalação por repo: Arch → `sudo pacman -S firefox` (ou `chromium`,
`brave-bin` no AUR, etc.). O daemon de gestos entende switches de aba para
Floorp e Firefox de fábrica (`touch-gestures.py`, lista `BROWSERS`).

Apps com `Terminal=true` no desktop file usam a variável `$TERMINAL`, que o
`start-sway` exporta como `foot`.

## 5.3 · Wallpapers

- Wallpapers em `~/Images/Wallpapers/` (aleatório no início do sway)
- `~/.local/bin/wallpaper-random.sh` escolhe um e aplica via `swaybg`
- Trocar na hora: rodar o script de novo — ele já faz `pkill -x swaybg`
  antes de subir, então re-rodadas manuais não empilham instâncias. O config
  do sway usa `exec` (não `exec_always`) pra não duplicar o `swaybg` a cada
  `reload` (ver `02` §2.11).