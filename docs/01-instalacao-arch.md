# 01 · Instalação do Arch Linux do zero

Guia usado neste notebook (Positivo C8128E). Assume **UEFI** (os modelos
recentes da Positivo vem com UEFI American Megatrends).

> Nota sobre segurança: é um setup pessoal para uso pontual. Siga as boas
> práticas mínimas (particionamento, senhas fortes) e adapte o que precisar.

## 1.1 · Boot da ISO

1. Grave a ISO do Arch no pendrive (`dd` ou Ventoy/BalenaEtcher).
2. Boot pelo pendrive (F12 ou a tecla de menu de boot).
3. Confirme o firmware UEFI:

   ```bash
   ls /sys/firmware/efi/efivars
   ```

   Se a pasta existir, é UEFI (neste notebook: UEFI 2.70, Secure Boot off).

## 1.2 · Rede (Wi-Fi)

```bash
iwctl
# dentro do iwctl:
station wlan0 scan
station wlan0 get-networks
station wlan0 connect NOME_DA_REDE
exit
```

Confirme com `ping -c 3 archlinux.org`.

## 1.3 · Particionamento

O disco interno é **eMMC → `/dev/mmcblk0`**. Partições usadas:

| Partição | Tamanho | Tipo | Sistema de arquivos | Mount |
|---|---|---|---|---|
| `mmcblk0p1` | 512M | ESP (EFI) | vfat | `/boot` |
| `mmcblk0p2` | 4G | swap | swap | - |
| `mmcblk0p3` | resto | raiz | ext4 | `/` |

```bash
gdisk /dev/mmcblk0     # ou fdisk
# p1: ef00 (EFI), 512M
# p2: 8200 (Linux swap), 4G
# p3: 8304 (Linux x86-64 root), resto
# escreva com 'w'
```

Formatando:

```bash
mkfs.fat -F32 /dev/mmcblk0p1
mkswap /dev/mmcblk0p2
mkfs.ext4 -L arch /dev/mmcblk0p3

mount /dev/mmcblk0p3 /mnt
mount --mkdir /dev/mmcblk0p1 /mnt/boot
swapon /dev/mmcblk0p2
```

## 1.4 · Base do sistema

```bash
pacstrap -K /mnt base linux linux-firmware intel-ucode \
    networkmanager sudo git vim

genfstab -U /mnt >> /mnt/etc/fstab
arch-chroot /mnt
```

## 1.5 · Dentro do chroot

```bash
ln -sf /usr/share/zoneinfo/America/Sao_Paulo /etc/localtime
hwclock --systohc
```

```bash
vim /etc/locale.gen        # descomente: pt_BR.UTF-8 UTF-8 e en_US.UTF-8 UTF-8
locale-gen
```

```bash
vim /etc/locale.conf       # LANG=pt_BR.UTF-8
vim /etc/vconsole.conf     # KEYMAP=br-abnt2
```

```bash
vim /etc/hostname          # ex.: positivo-c8128e
```

Senha root e usuário com privilégios:

```bash
passwd
useradd -m -G wheel -s /bin/bash gustavosp
passwd gustavosp
```

Sudo sem senha para o grupo wheel (necessário para o script de energia
escrever em `/sys`; alternativa mais restrita: NOPASSWD só para os comandos
do power-menu):

```bash
vim /etc/sudoers.d/10-celeron-nopasswd
# %wheel ALL=(ALL:ALL) NOPASSWD: ALL
```

## 1.6 · Bootloader (systemd-boot)

```bash
bootctl install
vim /boot/loader/entries/arch.conf
```

```ini
title Arch Linux
linux /vmlinuz-linux
initrd /intel-ucode.img
initrd /initramfs-linux.img
options root=PARTUUID=<UUID-da-raiz> rw
```

> Pega o PARTUUID com `blkid -s PARTUUID /dev/mmcblk0p3`. Nesta máquina
> usa-se o `root=UUID=...` (é o que está no arquivo real),
> `root=PARTUUID=...` também funciona.

## 1.7 · Configurações de rede e fim

```bash
systemctl enable NetworkManager
systemctl enable systemd-timesyncd
exit        # sair do chroot
umount -R /mnt
reboot
```

Após reiniciar, entre como `gustavosp` e siga para o
[guia do ambiente gráfico](02-gui-sway-wayland.md).