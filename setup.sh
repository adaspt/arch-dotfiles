#!/usr/bin/env bash
# Everything after archinstall. Run it from a terminal in GNOME, as your normal user:
#   curl -fsSL https://raw.githubusercontent.com/adaspt/arch-dotfiles/main/setup.sh | bash
# Safe to run again any time.
set -euo pipefail

REPO_DIR="$HOME/Projects/personal/arch-dotfiles"

# Decrypted secrets: on a tmpfs only this user can read, deleted on exit
SECRETS_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/arch-dotfiles-secrets"
trap 'rm -rf "$SECRETS_DIR" "$SECRETS_DIR.part"' EXIT

die() { echo "$*" >&2; exit 1; }

# Inside main, so bash reads the whole script from the pipe before running any of it
main() {
    [[ $EUID -ne 0 ]] || die "Run this as your normal user, not root."
    # The keyring, unlocked by the login screen, and GNOME settings need the GNOME session
    [[ ${XDG_CURRENT_DESKTOP:-} == *GNOME* ]] || die "Run this from a terminal in GNOME."

    system_setup
    gnome_setup
    onedrive_setup
    restore_from_onedrive

    echo
    echo "Done. Log out and back in, so GNOME Shell loads the extensions."
    echo "OneDrive keeps syncing the rest in the background: journalctl --user -u onedrive -f"
}

system_setup() {
    [[ -d "$REPO_DIR/.git" ]] || git clone https://github.com/adaspt/arch-dotfiles.git "$REPO_DIR"

    # archinstall creates no snapper config, so snap-pac snapshots nothing until this.
    # Before the update, so the update is the first thing snapshotted
    echo "==> Setting up Snapper snapshots of /"
    [[ -f /etc/snapper/configs/root ]] || sudo snapper -c root create-config /
    sudo systemctl enable --now snapper-cleanup.timer

    echo "==> Updating the system and installing packages"
    local packages=(
        pacman-contrib fwupd
        rtkit        # realtime priority, so PipeWire audio doesn't crackle under load
        qt6-wayland  # qBittorrent native on Wayland, not blurry through XWayland
        zsh zsh-autosuggestions zsh-syntax-highlighting zsh-history-substring-search
        tmux eza fzf zoxide yazi age
        less bat btop htop fd ripgrep jq rsync lazygit 7zip wl-clipboard
        mpv qbittorrent gradia openai-codex
        gnome-shell-extension-appindicator gnome-shell-extension-caffeine
    )
    sudo pacman -Syu --needed --noconfirm "${packages[@]}"

    # fstrim is for the FAT32 /boot: btrfs already trims with discard=async
    echo "==> Enabling maintenance timers"
    sudo systemctl enable --now fstrim.timer paccache.timer btrfs-scrub@-.timer

    # Copied, not linked, as files in /etc have to be owned by root
    echo "==> Copying config/etc to /etc, and your monitor layout to the login screen"
    sudo cp -r "$REPO_DIR/config/etc/." /etc/
    sudo systemctl daemon-reload
    sudo systemctl enable --now "gdm-monitors@$USER.path"
    sudo systemctl start "gdm-monitors@$USER.service"

    echo "==> Installing paru and AUR packages"
    if ! command -v paru >/dev/null; then
        local build_dir
        build_dir=$(mktemp -d)
        git clone https://aur.archlinux.org/paru-bin.git "$build_dir"
        (cd "$build_dir" && makepkg -si --noconfirm)
        rm -rf "$build_dir"
    fi
    paru -S --needed --noconfirm --skipreview \
        google-chrome visual-studio-code-bin zsh-theme-powerlevel10k onedrive-abraunegg t3code-bin

    # The native installer, as it updates itself
    echo "==> Installing Claude Code"
    [[ -x "$HOME/.local/bin/claude" ]] || curl -fsSL https://claude.ai/install.sh | bash

    echo "==> Setting your full name and zsh as your shell"
    sudo chfn -f "Adas Petrovas" "$USER"
    [[ $(getent passwd "$USER" | cut -d: -f7) == /usr/bin/zsh ]] || sudo chsh -s /usr/bin/zsh "$USER"

    # Linger keeps tmux sessions and OneDrive running after you log out
    echo "==> Enabling linger and the SSH agent"
    sudo loginctl enable-linger "$USER"
    systemctl --user enable gcr-ssh-agent.socket

    # File by file, so ~/.config and ~/.ssh keep their other files
    echo "==> Linking config/home into ~"
    local file rel
    while IFS= read -r -d '' file; do
        rel=${file#"$REPO_DIR/config/home/"}
        mkdir -p "$(dirname "$HOME/$rel")"
        ln -sfn "$file" "$HOME/$rel"
    done < <(find "$REPO_DIR/config/home" -type f -print0)

    # Every type each app lists, so images don't open in Chrome
    echo "==> Setting Loupe for images, mpv for video and audio"
    local desktop mimes
    for desktop in org.gnome.Loupe.desktop mpv.desktop; do
        IFS=';' read -ra mimes < <(sed -n 's/^MimeType=//p' "/usr/share/applications/$desktop")
        xdg-mime default "$desktop" "${mimes[@]}"
    done
}

gnome_setup() {
    # Cloned to personal projects to work on them. Over HTTPS, as there's no SSH key yet
    echo "==> Installing my GNOME extensions"
    local extensions_dir="$HOME/.local/share/gnome-shell/extensions" name dir
    mkdir -p "$extensions_dir"
    for name in launcher window-keys; do
        dir="$HOME/Projects/personal/gnome-shell-extension-$name"
        if [[ -d "$dir/.git" ]]; then
            git -C "$dir" pull --ff-only || echo "Couldn't update $dir, keeping it as it is."
        else
            git clone "https://github.com/adaspt/gnome-shell-extension-$name.git" "$dir"
        fi
        # Compiled schemas are gitignored
        [[ ! -d "$dir/schemas" ]] || glib-compile-schemas --strict "$dir/schemas"
        ln -sfnT "$dir" "$extensions_dir/$name@adaspt"
    done

    echo "==> Applying config/gnome.ini"
    dconf load / < "$REPO_DIR/config/gnome.ini"

    # "Preserve Battery Health" in Settings > Power, kept by UPower rather than dconf
    echo "==> Limiting battery charge, where supported"
    local battery
    for battery in $(upower -e | grep battery_); do
        upower -i "$battery" | grep -q 'charge-threshold-supported: *yes' || continue
        gdbus call --system --dest org.freedesktop.UPower --object-path "$battery" \
            --method org.freedesktop.UPower.Device.EnableChargeThreshold true >/dev/null
    done
}

onedrive_setup() {
    local config_dir="$HOME/.config/onedrive" f

    # Copied, not linked: after a change to these, the client refuses to sync until --resync
    mkdir -p "$config_dir"
    for f in config sync_list; do
        [[ -f "$config_dir/$f" ]] || cp "$REPO_DIR/config/onedrive/$f" "$config_dir/$f"
    done

    systemctl --user is-enabled --quiet onedrive && return 0

    if [[ ! -f "$config_dir/refresh_token" ]]; then
        echo "==> Signing in to OneDrive"
        echo "Open the link below in Chrome, sign in, then paste the address of the blank page you land on."
        onedrive || true  # exits non-zero, as it wasn't told to sync
        [[ -f "$config_dir/refresh_token" ]] || die "OneDrive sign-in failed."
    fi

    # Backup/ first, as the rest of this script needs it; the service syncs the rest.
    # --resync, as a first sync with a sync_list has no saved state yet
    echo "==> Syncing OneDrive Backup/"
    onedrive --sync --single-directory Backup --resync --resync-auth
    systemctl --user enable --now onedrive
}

restore_from_onedrive() {
    local backup="$HOME/OneDrive/Backup" wallpaper="winter-mountain-3840x2160-24311.jpg" key

    if [[ ! -f "$HOME/.ssh/id_ed25519" ]]; then
        unlock_secrets
        echo "==> Copying SSH keys"
        # ~/.ssh/config links to this repo and includes config.local, which holds the hosts
        find "$SECRETS_DIR/ssh" -mindepth 1 -maxdepth 1 ! -name config -exec cp -r {} "$HOME/.ssh/" \;
        [[ ! -f "$SECRETS_DIR/ssh/config" ]] || cp "$SECRETS_DIR/ssh/config" "$HOME/.ssh/config.local"
    fi
    chmod -R go-rwx "$HOME/.ssh"

    # Not connected automatically: nmcli connection up agersi-vpn
    if ! nmcli connection show agersi-vpn &>/dev/null; then
        unlock_secrets
        echo "==> Importing the WireGuard VPN"
        nmcli connection import type wireguard file "$SECRETS_DIR/agersi-vpn.conf"
        nmcli connection modify agersi-vpn connection.autoconnect no
        nmcli connection down agersi-vpn || true
    fi

    if [[ -d "$backup/fonts" ]]; then
        echo "==> Copying fonts from OneDrive"
        mkdir -p "$HOME/.local/share/fonts"
        cp -r "$backup/fonts/." "$HOME/.local/share/fonts/"
        fc-cache -f
    fi

    # Copied, so it stays if the original is moved or deleted
    if [[ -f "$backup/$wallpaper" ]]; then
        echo "==> Setting the wallpaper from OneDrive"
        mkdir -p "$HOME/Pictures/Wallpapers"
        cp "$backup/$wallpaper" "$HOME/Pictures/Wallpapers/"
        for key in picture-uri picture-uri-dark; do
            gsettings set org.gnome.desktop.background "$key" "file://$HOME/Pictures/Wallpapers/$wallpaper"
        done
    fi
}

# Decrypts Backup/secrets.tar.gz.age into SECRETS_DIR: ssh/ for ~/.ssh, and agersi-vpn.conf
unlock_secrets() {
    local archive="$HOME/OneDrive/Backup/secrets.tar.gz.age"
    [[ ! -d "$SECRETS_DIR" ]] || return 0
    [[ -f "$archive" ]] || die "$archive not found. Is OneDrive synced? See: journalctl --user -u onedrive"
    echo "==> Decrypting the secrets archive"
    # Into .part first, so a wrong passphrase leaves no half-filled SECRETS_DIR
    rm -rf "$SECRETS_DIR.part"
    mkdir -m 700 "$SECRETS_DIR.part"
    age --decrypt "$archive" | tar -xz -C "$SECRETS_DIR.part"
    mv "$SECRETS_DIR.part" "$SECRETS_DIR"
}

# Piped from curl, stdin is this script, and the prompts need the terminal.
# Only main's stdin, as bash reads the rest of the script from its own stdin after main
main "$@" < /dev/tty
