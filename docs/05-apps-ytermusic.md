# 05 · Aplicativos, MIME e YT Music no terminal

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
| ytermusic | YouTube Music no terminal | AUR/compilar (ver 5.4) |

O `pamac` abre pelo launcher digitando `pamac`; na primeira abertura precisa
configurar e autenticar o acesso ao AUR.

## 5.2 · Associações de arquivo (MIME)

`~/.config/mimeapps.list` define os apps padrão:

- `text/plain` → micro
- `image/png` → imv
- `video/*` → vlc
- `application/epub+zip` / `mobi` / `fb2` / `comic` → Foliate
- `text/html` / `http(s)` → Floorp

Apps com `Terminal=true` no desktop file usam a variável `$TERMINAL`, que o
`start-sway` exporta como `foot`.

## 5.3 · Wallpapers

- Wallpapers em `~/Images/Wallpapers/` (aleatório no início do sway)
- `~/.local/bin/wallpaper-random.sh` escolhe um e aplica via `swaybg`
- Trocar na hora: rodar o script de novo (`exec_always` no config do sway)

## 5.4 · YT Music no terminal (ytermusic)

### Instalação

A versão dos repositórios (AUR `ytermusic-bin`, tag beta-0.1.5) usa o
downloader `rusty_ytdl` com cliente **Android**, que o Google bloqueou —
quasi todo download falha com **403 Forbidden** no googlevideo.com (só a
primeira música baixa). O fix existe apenas no **master** do GitHub (PR
#139, usa `yt-dlp` como downloader). Solução testada:

```bash
git clone --depth 1 https://github.com/ccgauche/ytermusic
cd ytermusic
cargo build --release                 # Celeron N4500: ~15 min
sudo pacman -R ytermusic-bin
sudo install -Dm755 target/release/ytermusic /usr/bin/ytermusic
```

O binário novo grava em `~/.config/ytermusic/config.applied.toml`:

```toml
[global]
parallel_downloads = 4
downloader = "ytdlp"
```

e exige `yt-dlp` no PATH (`sudo pacman -S yt-dlp`). Empacota o `yt-dlp` para
baixar streamings.

### Autenticação (headers.txt)

**IMPORTANTE — dados sensíveis, não commitados e não versionados.** O
`~/.config/ytermusic/headers.txt` contém o cookie de login completo. Trate
como segredo.

Como gerar (testado):

1. No Firefox, instalar a extensão **"Get cookies.txt LOCALLY"**;
2. Abrir `music.youtube.com` logado e exportar os cookies (arquivo
   `music.youtube.com_cookies.txt`);
3. Gerar o header:

   ```bash
   awk -F'\t' '!/^#/ && NF>=7 {printf "%s=%s; ",$6,$7}' \
       music.youtube.com_cookies.txt | sed 's/; $//'
   ```

4. Criar `~/.config/ytermusic/headers.txt` com **2 linhas**:

   ```
   Cookie: <resultado do comando acima>
   User-Agent: Mozilla/5.0 (...)
   ```

**Pegadinha:** copiar o cookie do dev tools (aba Network) costuma vir
**truncado** com `...` no meio → cookie inválido. O método pela extensão sai
completo (~38KB, inclui SID/SSID/__Secure-1PSID = o login).

Se o app reclamar de cookie expirado: reexportar os cookies e regerar o
`headers.txt`.

### Uso

Config/credenciais: `~/.config/ytermusic/` (`config.toml` gerado no 1º uso).
Atalhos: `f` busca, `Enter` toca/entra, `s` shuffle, `Space` play/pause,
`+/-` volume, `Ctrl+→/←` próxima/anterior, `Esc` volta, `Ctrl+C/Ctrl+D` sai.
Cache local permite tocar offline músicas já baixadas.