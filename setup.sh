#!/usr/bin/env bash
# Everything after archinstall, in two parts. Run it as your normal user:
#
# 1. From the text login after the first boot:
#      curl -fsSL https://raw.githubusercontent.com/adaspt/arch-dotfiles/main/setup.sh | bash
#    Sets up the system, shell and login screen, then stops and asks for a reboot.
# 2. After the reboot, log in on the Noctalia login screen and run it again from a terminal:
#      ~/Projects/personal/arch-dotfiles/setup.sh
#    Part 1 finds its work done and goes by quickly. Then OneDrive (signing in needs a browser),
#    and SSH keys, VPN and fonts from it.
#
# Part 2 needs the desktop session because the login screen unlocks the keyring, and Chrome and
# OneDrive should be set up with it unlocked. Started from a terminal in niri, the script runs through.
# Safe to run again any time.
set -euo pipefail

FULL_NAME="Adas Petrovas"
REPO_URL=https://github.com/adaspt/arch-dotfiles.git
REPO_DIR="$HOME/Projects/personal/arch-dotfiles"

# The decrypted secrets archive. In the runtime dir, a tmpfs only this user can read:
# never written to disk, and deleted when the script exits, also after an error or Ctrl-C
SECRETS_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/arch-dotfiles-secrets"
trap 'rm -rf "$SECRETS_DIR" "$SECRETS_DIR.part"' EXIT

# Everything runs inside main, so bash has read the whole script from the pipe before running any of it.
main() {
    if [[ $EUID -eq 0 ]]; then
        echo "Run this as your normal user, not root." >&2
        exit 1
    fi

    # Piped from curl, stdin is this script. The prompts (OneDrive sign-in, age passphrase) need the terminal
    exec < /dev/tty

    system_setup

    if [[ -z ${WAYLAND_DISPLAY:-} ]]; then
        echo
        echo "Part 1 is done. Reboot (sudo reboot), log in on the Noctalia login screen,"
        echo "open a terminal (Super+T) and run the script again:"
        echo "  $REPO_DIR/setup.sh"
        exit 0
    fi

    desktop_setup

    echo
    echo "Done. OneDrive keeps syncing the rest in the background: journalctl --user -u onedrive -f"
}

# ---------- Part 1: needs no desktop session ----------
system_setup() {
    # An existing clone is left as it is, local changes included
    if [[ ! -d "$REPO_DIR/.git" ]]; then
        echo "==> Cloning this repo to $REPO_DIR"
        mkdir -p "$(dirname "$REPO_DIR")"
        git clone "$REPO_URL" "$REPO_DIR"
    fi

    # Copied, not linked: files in /etc have to be owned by root
    echo "==> Copying system config (greetd, PAM keyring unlock)"
    sudo cp -r "$REPO_DIR/config/etc/." /etc/

    # archinstall installs snapper and snap-pac but creates no config, so snap-pac takes no snapshots.
    # This runs before the update below so that the update is the first thing snapshotted.
    echo "==> Setting up Snapper snapshots of /"
    if [[ ! -f /etc/snapper/configs/root ]]; then
        sudo snapper -c root create-config /
    fi
    sudo systemctl enable --now snapper-cleanup.timer

    echo "==> Updating the system and installing packages"
    local packages=(
        # System maintenance and firmware updates
        pacman-contrib fwupd
        # Shell, and the tools .zshrc uses
        zsh zsh-autosuggestions zsh-syntax-highlighting zsh-history-substring-search
        tmux eza fzf zoxide yazi
        # Decrypts the secrets archive in part 2
        age
        # CLI tools
        less bat btop htop fd ripgrep 7zip wl-clipboard
        # Apps
        qbittorrent
        # Coding agents (T3 Code comes from the AUR, Claude Code from its installer, both below)
        openai-codex
        # Development
        azure-cli dotnet-sdk-10.0 nvm
        # Gaming. lib32-vulkan-intel is named here, or --noconfirm would pick the NVIDIA driver for Steam.
        # flatpak is for GeForce NOW, installed in part 2.
        steam lib32-vulkan-intel flatpak
    )
    sudo pacman -Syu --needed --noconfirm "${packages[@]}"

    # fstrim: btrfs already trims with discard=async, but this also covers the FAT32 /boot.
    # paccache: keeps the last 3 versions of each package in the pacman cache.
    # btrfs-scrub@-: checks the root filesystem for corruption once a month.
    echo "==> Enabling maintenance timers"
    sudo systemctl enable --now fstrim.timer paccache.timer btrfs-scrub@-.timer

    echo "==> Installing paru and AUR packages"
    if ! command -v paru >/dev/null; then
        local build_dir
        build_dir=$(mktemp -d)
        git clone https://aur.archlinux.org/paru-bin.git "$build_dir"
        (cd "$build_dir" && makepkg -si --noconfirm)
        rm -rf "$build_dir"
    fi
    local aur_packages=(
        google-chrome visual-studio-code-bin
        zsh-theme-powerlevel10k
        onedrive-abraunegg
        t3code-bin
    )
    paru -S --needed --noconfirm --skipreview "${aur_packages[@]}"

    # The native install rather than the AUR package: it updates itself as soon as a release is out
    echo "==> Installing Claude Code"
    [[ -x "$HOME/.local/bin/claude" ]] || curl -fsSL https://claude.ai/install.sh | bash

    # In its own bash: nvm isn't written for set -euo pipefail. Installs the latest 24.x, or keeps it
    # if already there, and makes it the default for new shells
    echo "==> Installing Node.js 24 with nvm"
    mkdir -p "$HOME/.nvm"
    bash -c 'source /usr/share/nvm/init-nvm.sh && nvm install 24 && nvm alias default 24'

    echo "==> Setting your full name and zsh as your shell"
    sudo chfn -f "$FULL_NAME" "$USER"
    if [[ "$(getent passwd "$USER" | cut -d: -f7)" != /usr/bin/zsh ]]; then
        sudo chsh -s /usr/bin/zsh "$USER"
    fi

    # Keeps tmux sessions and the OneDrive service running after you log out
    sudo loginctl enable-linger "$USER"

    # Symlinked, so editing ~/.config/niri/config.kdl edits the file in the repo.
    # Each file is linked on its own, so ~/.config and ~/.ssh keep everything else in them.
    echo "==> Linking config files into ~"
    local file rel
    while IFS= read -r -d '' file; do
        rel=${file#"$REPO_DIR/config/home/"}
        mkdir -p "$(dirname "$HOME/$rel")"
        ln -sfn "$file" "$HOME/$rel"
    done < <(find "$REPO_DIR/config/home" -type f -print0)
    chmod 700 "$HOME/.ssh"
    niri validate

    echo "==> Enabling the SSH agent"
    systemctl --user enable gcr-ssh-agent.socket

    echo "==> Enabling the login screen"
    sudo noctalia-greeter-apply-appearance --setup-system
    sudo systemctl enable greetd
}

# ---------- Part 2: in the desktop session ----------
desktop_setup() {
    setup_onedrive

    # Skipped once the keys are there, so running again doesn't ask for the passphrase
    if [[ ! -f "$HOME/.ssh/id_ed25519" ]]; then
        unlock_secrets
        echo "==> Copying SSH keys"
        # Not the archive's config: ~/.ssh/config links to the repo, and copying over it would write
        # into the repo. It goes to config.local, which the repo's config includes.
        find "$SECRETS_DIR/ssh" -mindepth 1 -maxdepth 1 ! -name config -exec cp -r {} "$HOME/.ssh/" \;
        [[ ! -f "$SECRETS_DIR/ssh/config" ]] || cp "$SECRETS_DIR/ssh/config" "$HOME/.ssh/config.local"
    fi
    find "$HOME/.ssh" -maxdepth 1 -type f -name "id_*" ! -name "*.pub" -exec chmod 600 {} +
    find "$HOME/.ssh" -maxdepth 1 -type f -name "*.pub" -exec chmod 644 {} +
    [[ ! -f "$HOME/.ssh/config.local" ]] || chmod 600 "$HOME/.ssh/config.local"
    [[ ! -f "$HOME/.ssh/authorized_keys" ]] || chmod 600 "$HOME/.ssh/authorized_keys"
    [[ ! -f "$HOME/.ssh/known_hosts" ]] || chmod 644 "$HOME/.ssh/known_hosts"

    # Imported once and not connected automatically: nmcli connection up agersi-vpn
    if ! nmcli connection show agersi-vpn &>/dev/null; then
        unlock_secrets
        echo "==> Importing the WireGuard VPN"
        # nmcli names the connection after the file
        nmcli connection import type wireguard file "$SECRETS_DIR/agersi-vpn.conf"
        nmcli connection modify agersi-vpn connection.autoconnect no
        nmcli connection down agersi-vpn || true
    fi

    # Microsoft fonts can't be in a public repo, so they come from OneDrive
    if [[ -d "$HOME/OneDrive/Backup/fonts" ]]; then
        echo "==> Copying fonts from OneDrive"
        mkdir -p "$HOME/.local/share/fonts"
        cp -r "$HOME/OneDrive/Backup/fonts/." "$HOME/.local/share/fonts/"
        fc-cache -f
    fi

    # Copied out of OneDrive, so it stays if the original is moved or deleted
    local wallpaper="winter-mountain-3840x2160-24311.jpg"
    if [[ -f "$HOME/OneDrive/Backup/$wallpaper" ]]; then
        echo "==> Copying the wallpaper from OneDrive"
        mkdir -p "$HOME/Pictures/Wallpapers"
        cp "$HOME/OneDrive/Backup/$wallpaper" "$HOME/Pictures/Wallpapers/"
    fi

    # NVIDIA's installer sets GeForce NOW up as a user flatpak, which updates through flatpak after that.
    # It writes GeForceNOWSetup.log to its working directory, so it runs in a temp dir.
    if ! flatpak info --user com.nvidia.geforcenow &>/dev/null; then
        echo "==> Installing GeForce NOW"
        flatpak remote-add --user --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
        local gfn_dir
        gfn_dir=$(mktemp -d)
        curl -fSL -o "$gfn_dir/GeForceNOWSetup.bin" https://international.download.nvidia.com/GFNLinux/GeForceNOWSetup.bin
        chmod +x "$gfn_dir/GeForceNOWSetup.bin"
        if ! (cd "$gfn_dir" && ./GeForceNOWSetup.bin); then
            echo "GeForce NOW install failed, see $gfn_dir/GeForceNOWSetup.log" >&2
            exit 1
        fi
        rm -rf "$gfn_dir"
    fi
}

# OneDrive client syncing the folders in config/onedrive/sync_list into ~/OneDrive
setup_onedrive() {
    local config_dir="$HOME/.config/onedrive"

    # Copied, not linked: changing config or sync_list makes the client refuse to sync until --resync,
    # so a git pull shouldn't change them under the running client. Existing files are kept.
    mkdir -p "$config_dir"
    for f in config sync_list; do
        [[ -f "$config_dir/$f" ]] || cp "$REPO_DIR/config/onedrive/$f" "$config_dir/$f"
    done

    systemctl --user is-enabled --quiet onedrive && return 0

    echo "==> Signing in to OneDrive"
    if [[ ! -f "$config_dir/refresh_token" ]]; then
        echo "Open the link below in Chrome, sign in, then paste the address of the blank page you land on."
        # Exits non-zero after signing in, because it wasn't told to sync
        onedrive || true
        if [[ ! -f "$config_dir/refresh_token" ]]; then
            echo "OneDrive sign-in failed." >&2
            exit 1
        fi
    fi

    # Only Backup/ now, since the rest of part 2 needs it and the full first sync can take long.
    # The first sync with a sync_list needs --resync, as there's no saved state yet
    echo "==> Syncing OneDrive Backup/"
    onedrive --sync --single-directory Backup --resync --resync-auth

    # The service syncs the rest in the background, and keeps syncing (linger) when you're logged out
    systemctl --user enable --now onedrive
}

# Decrypts Backup/secrets.tar.gz.age from OneDrive into SECRETS_DIR, once per run. Asks for the age passphrase.
# Contents: ssh/ (for ~/.ssh) and agersi-vpn.conf
unlock_secrets() {
    local archive="$HOME/OneDrive/Backup/secrets.tar.gz.age"
    [[ ! -d "$SECRETS_DIR" ]] || return 0
    if [[ ! -f "$archive" ]]; then
        echo "$archive not found. Is OneDrive synced? See: journalctl --user -u onedrive" >&2
        exit 1
    fi
    echo "==> Decrypting the secrets archive"
    # Into .part first, so a wrong passphrase doesn't leave a half-filled SECRETS_DIR behind
    rm -rf "$SECRETS_DIR.part"
    mkdir -m 700 "$SECRETS_DIR.part"
    age --decrypt "$archive" | tar -xz -C "$SECRETS_DIR.part"
    mv "$SECRETS_DIR.part" "$SECRETS_DIR"
}

main "$@"
