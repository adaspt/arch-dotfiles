#!/usr/bin/env bash
# Everything after archinstall, in two parts. Run it as your normal user:
#
# 1. From the text login after the first boot:
#      curl -fsSL https://raw.githubusercontent.com/adaspt/arch-dotfiles/main/setup.sh | bash
#    Sets up the system, shell and login screen, then stops and asks for a reboot.
# 2. After the reboot, log in on the Noctalia login screen and run it again from a terminal:
#      ~/Projects/personal/arch-dotfiles/setup.sh
#    Sets up OneDrive (signing in needs a browser), and SSH keys, VPN and fonts from it.
#
# Part 2 needs the desktop session because the login screen unlocks the keyring, and Chrome and
# OneDrive should be set up with it unlocked. Safe to run again any time.
set -euo pipefail

FULL_NAME="Adas Petrovas"
REPO_URL=https://github.com/adaspt/arch-dotfiles.git
REPO_DIR="$HOME/Projects/personal/arch-dotfiles"

# Decrypted secrets: on a tmpfs only this user can read, deleted on exit, error or Ctrl-C
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
    if [[ ! -d "$REPO_DIR/.git" ]]; then
        echo "==> Cloning this repo to $REPO_DIR"
        mkdir -p "$(dirname "$REPO_DIR")"
        git clone "$REPO_URL" "$REPO_DIR"
    fi

    # archinstall creates no snapper config, so snap-pac takes no snapshots until this runs.
    # Before the update, so the update is the first thing snapshotted.
    echo "==> Setting up Snapper snapshots of /"
    if [[ ! -f /etc/snapper/configs/root ]]; then
        sudo snapper -c root create-config /
    fi
    sudo systemctl enable --now snapper-cleanup.timer

    echo "==> Updating the system and installing packages"
    local packages=(
        # System maintenance and firmware updates
        pacman-contrib fwupd
        # Realtime priority for PipeWire, so audio doesn't crackle under load
        rtkit
        # Desktop: Hyprland, Noctalia (bar, launcher, notifications, lock screen, wallpaper) and the
        # Noctalia login screen
        hyprland xdg-desktop-portal-hyprland xdg-desktop-portal-gtk
        noctalia noctalia-greeter
        # Lets Qt apps (qBittorrent) run natively on Wayland, instead of blurry through XWayland
        qt6-wayland
        # Shell, and the tools .zshrc uses
        zsh zsh-autosuggestions zsh-syntax-highlighting zsh-history-substring-search
        tmux eza fzf zoxide yazi
        # Decrypts the secrets archive in part 2
        age
        # CLI tools
        less bat btop htop fd ripgrep 7zip wl-clipboard
        # Apps. Nautilus is the file manager on Super+E. Loupe opens images, mpv video and audio.
        nautilus gnome-text-editor loupe mpv qbittorrent
        # Coding agents
        openai-codex
    )
    sudo pacman -Syu --needed --noconfirm "${packages[@]}"

    # Copied, not linked: files in /etc have to be owned by root. After the install, as greetd's
    # files would otherwise conflict with it.
    echo "==> Copying system config (greetd, PAM keyring unlock, power button)"
    sudo cp -r "$REPO_DIR/config/etc/." /etc/

    # fstrim is for the FAT32 /boot: btrfs already trims with discard=async. btrfs-scrub@- scrubs /.
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

    # The native installer, not the AUR package: it updates itself
    echo "==> Installing Claude Code"
    [[ -x "$HOME/.local/bin/claude" ]] || curl -fsSL https://claude.ai/install.sh | bash

    echo "==> Setting your full name and zsh as your shell"
    sudo chfn -f "$FULL_NAME" "$USER"
    if [[ "$(getent passwd "$USER" | cut -d: -f7)" != /usr/bin/zsh ]]; then
        sudo chsh -s /usr/bin/zsh "$USER"
    fi

    # Keeps tmux sessions and the OneDrive service running after you log out
    sudo loginctl enable-linger "$USER"

    # Each file is linked on its own, so ~/.config and ~/.ssh keep their other files
    echo "==> Linking config files into ~"
    local file rel
    while IFS= read -r -d '' file; do
        rel=${file#"$REPO_DIR/config/home/"}
        mkdir -p "$(dirname "$HOME/$rel")"
        ln -sfn "$file" "$HOME/$rel"
    done < <(find "$REPO_DIR/config/home" -type f -print0)
    chmod 700 "$HOME/.ssh"
    local hypr_check
    if ! hypr_check=$(Hyprland --verify-config -c "$HOME/.config/hypr/hyprland.lua" 2>&1); then
        echo "$hypr_check" >&2
        exit 1
    fi

    # GNOME creates these at login, Hyprland doesn't
    echo "==> Creating Downloads, Documents, Music, Videos and the other home folders"
    xdg-user-dirs-update

    # Every file type each app's .desktop file lists, so images don't open in Chrome
    echo "==> Setting Loupe for images and mpv for video and audio"
    local desktop mimes
    for desktop in org.gnome.Loupe.desktop mpv.desktop; do
        IFS=';' read -ra mimes < <(sed -n 's/^MimeType=//p' "/usr/share/applications/$desktop")
        xdg-mime default "$desktop" "${mimes[@]}"
    done

    echo "==> Telling VS Code to keep secrets in gnome-keyring"
    mkdir -p "$HOME/.vscode"
    [[ -f "$HOME/.vscode/argv.json" ]] || cp "$REPO_DIR/config/vscode/argv.json" "$HOME/.vscode/argv.json"

    echo "==> Enabling the SSH agent"
    systemctl --user enable gcr-ssh-agent.socket

    echo "==> Enabling the login screen"
    sudo noctalia-greeter-apply-appearance --setup-system
    sudo systemctl enable greetd
}

# ---------- Part 2: in the desktop session ----------
desktop_setup() {
    setup_onedrive

    if [[ ! -f "$HOME/.ssh/id_ed25519" ]]; then
        unlock_secrets
        echo "==> Copying SSH keys"
        # ~/.ssh/config links to the repo, so the archive's config goes to config.local, which it includes
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
}

setup_onedrive() {
    local config_dir="$HOME/.config/onedrive"

    # Copied, not linked: changing config or sync_list makes the client refuse to sync until --resync,
    # so a git pull shouldn't change them under the running client.
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

    # Only Backup/ for now: part 2 needs it, and the full first sync can take long.
    # --resync because a first sync with a sync_list has no saved state yet
    echo "==> Syncing OneDrive Backup/"
    onedrive --sync --single-directory Backup --resync --resync-auth

    systemctl --user enable --now onedrive
}

# Decrypts the archive from OneDrive into SECRETS_DIR. Contents: ssh/ (for ~/.ssh) and agersi-vpn.conf
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
