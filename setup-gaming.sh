#!/usr/bin/env bash
# Steam and GeForce NOW. Run it from a terminal in GNOME, after setup.sh. Safe to run again any time.
set -euo pipefail

if [[ $EUID -eq 0 ]]; then
    echo "Run this as your normal user, not root." >&2
    exit 1
fi
if [[ ${XDG_CURRENT_DESKTOP:-} != *GNOME* ]]; then
    echo "Run this from a terminal in GNOME, not from a text login or over SSH." >&2
    exit 1
fi

# Steam needs the 32-bit packages in multilib, which Arch ships commented out
if ! grep -q '^\[multilib\]' /etc/pacman.conf; then
    echo "==> Enabling the multilib repo"
    sudo sed -i '/^#\[multilib\]$/,/^#Include/ s/^#//' /etc/pacman.conf
    grep -q '^\[multilib\]' /etc/pacman.conf || { echo "Couldn't enable multilib in /etc/pacman.conf" >&2; exit 1; }
fi

# lib32-vulkan-intel is named here, or --noconfirm would pick the NVIDIA driver for Steam
echo "==> Installing Steam and flatpak"
sudo pacman -Syu --needed --noconfirm steam lib32-vulkan-intel flatpak

# NVIDIA's installer sets it up as a user flatpak. It writes its log to the working directory,
# so it runs in a temp dir.
if ! flatpak info --user com.nvidia.geforcenow &>/dev/null; then
    echo "==> Installing GeForce NOW"
    flatpak remote-add --user --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
    gfn_dir=$(mktemp -d)
    curl -fSL -o "$gfn_dir/GeForceNOWSetup.bin" https://international.download.nvidia.com/GFNLinux/GeForceNOWSetup.bin
    chmod +x "$gfn_dir/GeForceNOWSetup.bin"
    if ! (cd "$gfn_dir" && ./GeForceNOWSetup.bin); then
        echo "GeForce NOW install failed, see $gfn_dir/GeForceNOWSetup.log" >&2
        exit 1
    fi
    rm -rf "$gfn_dir"
fi

echo
echo "Done."
