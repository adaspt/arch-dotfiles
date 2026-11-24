#!/usr/bin/env bash
# The desktop with the NVIDIA GTX 1660 Super. Run it after setup.sh, then restart. Safe to run again any time.
set -euo pipefail

die() { echo "$*" >&2; exit 1; }

[[ $EUID -ne 0 ]] || die "Run this as your normal user, not root."
# The ThinkPad has an NVIDIA GPU too, a defective one that setup-lenovo.sh switches off
if compgen -G "/sys/class/power_supply/BAT*" >/dev/null; then die "This is a laptop, not the desktop."; fi
has_nvidia=0
for dev in /sys/bus/pci/devices/*; do
    if [[ $(<"$dev/vendor") == 0x10de && $(<"$dev/class") == 0x03* ]]; then has_nvidia=1; fi
done
(( has_nvidia )) || die "No NVIDIA GPU found."

restart=0

# archinstall.json names every machine adas-framework
if [[ $(hostnamectl hostname) != adas-work ]]; then
    echo "==> Naming it adas-work"
    sudo hostnamectl set-hostname adas-work
fi

# nvidia-open supports GTX 16xx and newer; libva-nvidia-driver decodes video in browsers
echo "==> Installing the NVIDIA driver"
pacman -Q nvidia-open &>/dev/null || restart=1
sudo pacman -Syu --needed --noconfirm nvidia-open nvidia-utils libva-nvidia-driver

# Keep video memory through suspend. GDM also falls back to X11 on NVIDIA without them
sudo systemctl enable nvidia-suspend.service nvidia-hibernate.service nvidia-resume.service

# The Arch wiki's advice for the NVIDIA driver: keeps nouveau out of the boot image
if grep -qE '^HOOKS=.*\bkms\b' /etc/mkinitcpio.conf; then
    echo "==> Removing the kms hook and rebuilding the boot image"
    sudo sed -i -E '/^HOOKS=/ s/ kms\b//' /etc/mkinitcpio.conf
    sudo mkinitcpio -P
    restart=1
fi

echo
if (( restart )); then
    echo "Done. Restart, then check: nvidia-smi shows the GTX 1660 SUPER."
else
    echo "Done."
fi
