# 08 · Conversão de ISOs de PS1, PS2 e PSP para CHD

Scripts que embrulham o `chdman` (MAME) para converter imagens de disco
em `.chd`, com verificação de integridade antes de apagar o original.

## Dependência

```bash
sudo pacman -S mame-tools
```

O `chdman` precisa ser recente: `createdvd` (PS2/PSP) só existe a partir
do MAME 0.255. Este guia foi testado com o 0.289.

## Scripts

O `install.sh` copia os três scripts para `~/.local/bin/`:

| Script | Plataforma | Comando usado |
|---|---|---|
| `ps1-cd-para-chd.sh` | PS1 | `createcd` |
| `ps2-iso-para-chd.sh` | PS2 (DVD) | `createdvd` |
| `psp-iso-para-chd.sh` | PSP (UMD) | `createdvd -hs 2048` |

Para PS2 em CD (raro), use `ps2-iso-para-chd.sh --cd` ou o script de PS1.

## Por que CD x DVD importa

- **PS1** é CD: pode ter várias trilhas, incluindo áudio. O `.cue`
  descreve as trilhas e o `chdman` lê os `.bin` referenciados.
- **PS2/PSP** são DVD: uma trilha de dados, setor de 2048 bytes.
- Usar `createcd` em ISO de DVD (ou o contrário) gera um CHD com layout
  errado; pode não abrir ou ficar lento.

No PSP, o hunk precisa ser de 2048 bytes para o PPSSPP render bem. O
padrão do `chdman` mudou para 4096 a partir do MAME 0.263, por isso o
script fixa `-hs 2048`.

## Uso

```bash
# pasta inteira, sem subpastas
~/.local/bin/ps2-iso-para-chd.sh ~/jogos/ps2

# com subpastas e apagando os ISOs aprovados
~/.local/bin/ps2-iso-para-chd.sh -r -d ~/jogos/ps2

# PS1: converta cada disco separadamente
~/.local/bin/ps1-cd-para-chd.sh "$HOME/jogos/ps1/Jogo (Disc 1).cue"

# PSP com compressão mais compatível
~/.local/bin/psp-iso-para-chd.sh -c zlib ~/jogos/psp
```

Opções comuns:

| Opção | Efeito |
|---|---|
| `-r`, `--recursivo` | entra nas subpastas |
| `-d`, `--apagar` | apaga a origem após o `verify` |
| `-f`, `--forcar` | sobrescreve `.chd` existente |
| `-c`, `--codec` | escolhe a compressão |
| `-j`, `--threads` | limita threads do `chdman` |
| `-h`, `--ajuda` | mostra a ajuda |

Variáveis de ambiente: `CHD_CODEC` e `CHD_THREADS`.

## Fluxo de segurança

1. Se já existe `.chd` e não foi usado `-f`, o arquivo é pulado.
2. A saída é criada como `.chd.part` na mesma pasta.
3. Em caso de falha, o `.part` é apagado e o original fica intacto.
4. `chdman verify` confere os SHA1 do `.part`.
5. Só depois do `verify` o `.part` vira `.chd`.
6. Só depois disso, com `-d`, a origem é apagada.

**Pegadinha:** se você converteu sem `-d` e depois rodar só com `-d`, o
`.chd` existente é pulado e o original **não** é apagado. Para apagar
depois, use `-f -d` (reconverte) ou apague manualmente.

## Compressão

| Codec | Uso | Observação |
|---|---|---|
| `zstd` | padrão PS2/PSP | rápido e boa taxa; exige leitor moderno |
| `zlib` | compatibilidade | arquivo maior; funciona em emuladores antigos |
| `lzma` | taxa máxima | lento para comprimir e descomprimir |
| `default` | deixa o `chdman` escolher | DVD = lzma,zlib,huff,flac; CD = cdlz,cdzl,cdfl |
| `cdzs` | CD com zstd | rápido, leitor novo |
| `cdzl` | CD com zlib | mais compatível, arquivo maior |

Compatibilidade:

- PPSSPP lê CHD desde a 1.17; zstd desde a 1.17.1. Em versão antiga use
  `-c default`.
- PCSX2 atual lê `createdvd` com zstd.
- AetherSX2/NetherSX2 antigos podem não ler `createdvd` ou zstd; a
  solução mais confiável é atualizar o emulador.
- O CHD não funciona na PSP real; no hardware o formato é CSO.

## Formatos aceitos

- PS1: `.cue` + `.bin` (recomendado) e `.iso` (só a trilha de dados).
- PS2: `.iso`.
- PSP: `.iso`.
- Não suportados pelo `chdman`: `.ccd/.img/.sub`, `.mds/.mdf`, `.pbp`.
- `.bin` sozinho, sem `.cue`, não tem informação de trilhas.

## Recuperar o original

```bash
chdman extractdvd -i jogo.chd -o jogo.iso
chdman extractcd  -i jogo.chd -o jogo.cue
```

O `extractcd` gera `.cue` + `.bin`, mas os nomes podem não ser idênticos
ao dump original.

## Verificação manual

```bash
chdman verify -i jogo.chd
chdman info -i jogo.chd
```

`info` mostra codec, tamanho do hunk e se o metadado é `CD` ou `DVD`.
