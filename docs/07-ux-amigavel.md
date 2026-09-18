# 07 · Experiência amigável (ajuda, boas-vindas, backup, menu inicial)

Recursos que facilitam o dia a dia, sem peso: todos usam o que já está
instalado (`foot`, `wmenu`, `notify-send`/mako, `systemd`).

## 7.1 · Ajuda na tela — `MOD + /` ou `MOD + ?`

Abre um painel flutuante (foot, `app-id=help`, centralizado) com a tabela
de atalhos principais. Fecha com qualquer tecla ou `MOD + q`.

- Bind duplo no config do sway (`mod+slash` e `mod+question`) porque na
  ABNT2 a interrogação vive na mesma tecla do `/` (com Shift).
- Regras do painel: `for_window [app_id="help"] floating enable, move
  position center` + `resize set 1100px 80ppt`.
- Script: `~/.config/sway/scripts/help-screen.sh`.

## 7.2 · Boas-vindas no login

No **primeiro** login, uma notificação (mako) mostra dicas rápidas. Depois
não incomoda mais (marcador em `~/.config/sway/.welcome-done`).

- Rode de novo quando quiser:

  ```bash
  ~/.config/sway/scripts/welcome.sh --again
  ```

- Script: `~/.config/sway/scripts/welcome.sh` (chamado com `exec` no
  config — roda a cada start do sway, mas o marcador barra repetições).

## 7.3 · Menu inicial — `MOD + m`

Launcher estilo "home" com as ações do dia a dia: Terminal, Navegador,
Arquivos, Print de tela, Tela externa (HDMI), Sistema (energia), Rotação
automática, Teclado virtual e Ajuda.

- Script: `~/.config/sway/scripts/home-menu.sh`.

## 7.4 · Backup automático (timer do usuário)

Backup semanal dos configs e Imagens (prints + wallpapers) para
`~/Backup/dots/<timestamp>/dots.tgz`, retendo só as **8 cópias mais
recentes**.

- Agendado para **segunda às 10:00** (`dotfiles-backup.timer`,
  `Persistent=true` — roda atrasado se a máquina estiver desligada).
- `dotfiles-backup.service` roda o script com prioridade baixa
  (`Nice=19`, `IOSchedulingClass=idle`) para não pesar no Celeron.
- O que entra no tarball: `.config/{sway,waybar,mako,swayidle,swaylock,
  systemd,qt6ct,mimeapps.list}`, `~/.local/bin` e `~/Images`.

Para rodar/inspecionar manualmente:

```bash
~/.local/bin/backup-dots.sh            # faz agora + poda os antigos
ls -lt ~/Backup/dots/                   # cronologia das cópias
systemctl --user list-timers dotfiles-backup.timer   # próxima execução
```

Para restaurar algo de um backup:

```bash
tar -tzf ~/Backup/dots/<timestamp>/dots.tgz    # lista o conteúdo
tar -xzf ~/Backup/dots/<timestamp>/dots.tgz -C ~  # restaura tudo
```

> Dica: aumentar a retenção? edite `KEEP=` no
> `~/.local/bin/backup-dots.sh`.

## 7.5 · Status do sistema e watchdog

### Painel de status — `MOD + i`

Abre um painel flutuante (foot, `app-id=status`) com três blocos:

- **Sessão sway**: waybar, mako, swayidle (auto-trava), swaybg (wallpaper),
  cliphist, daemon da tela externa, gestos de toque e rotação automática;
- **Unidades do usuário**: timers `dotfiles-backup`, `battery-alert`,
  `service-watchdog` e `ydotool.service` (com a próxima execução);
- **Sistema**: greetd, oomd, rede, bluetooth, zram, bateria, disco `/`
  (eMMC), RAM e temperatura da CPU.

Itens **PARADO** aparecem em vermelho; fecha com qualquer tecla.
Script: `~/.config/sway/scripts/system-status.sh`.

### Watchdog — avisa se algo cair

O timer `service-watchdog.timer` roda **a cada 10 min** o
`service-watchdog.sh`, checando os processos e unidades críticos. Se algo
cair, manda uma notificação (mako, crítica) dizendo o que parou; quando o
serviço voltar, avisa a restauração.

- Critérios monitorados: waybar, mako, swayidle, swaybg, cliphist,
  ydotool, daemon da tela externa e gestos de toque.
- Não alerta para a **rotação automática** desligada (é toggle manual via
  `MOD + o`) nem para o serviço nunca iniciado naquela sessão.
- Estado fica em `/tmp/sway-service-watchdog.state` (evita repetir aviso).
- Para rodar na hora: `systemctl --user start service-watchdog.service`.