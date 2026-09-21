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

Apps com `Terminal=true` no desktop file usam a variável `$TERMINAL`, que o
`start-sway` exporta como `foot`.

## 5.3 · Wallpapers

- Wallpapers em `~/Images/Wallpapers/` (aleatório no início do sway)
- `~/.local/bin/wallpaper-random.sh` escolhe um e aplica via `swaybg`
- Trocar na hora: rodar o script de novo — ele já faz `pkill -x swaybg`
  antes de subir, então re-rodadas manuais não empilham instâncias. O config
  do sway usa `exec` (não `exec_always`) pra não duplicar o `swaybg` a cada
  `reload` (ver `02` §2.11).