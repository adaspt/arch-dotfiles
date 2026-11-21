#!/usr/bin/env bash
# The desktop: Hyprland, Noctalia (bar, launcher, notifications, lock screen, wallpaper) and the
# Noctalia login screen, with the config in config/hyprland-noctalia/. Run it as your normal user from
# the text login after archinstall, before setup.sh:
#   curl -fsSL https://raw.githubusercontent.com/adaspt/arch-dotfiles/main/setup-hyprland-noctalia.sh | bash
# Then reboot, log in to Hyprland, open a terminal (Super+T) and run setup.sh. Safe to run again.
set -euo pipefail

REPO_URL=https://github.com/adaspt/arch-dotfiles.git
REPO_DIR="$HOME/Projects/personal/arch-dotfiles"
CONFIG_DIR="$REPO_DIR/config/hyprland-noctalia"

# Everything runs inside main, so bash has read the whole script from the pipe before running any of it.
main() {
    if [[ $EUID -eq 0 ]]; then
        echo "Run this as your normal user, not root." >&2
        exit 1
    fi

    if [[ ! -d "$REPO_DIR/.git" ]]; then
        echo "==> Cloning this repo to $REPO_DIR"
        mkdir -p "$(dirname "$REPO_DIR")"
        git clone "$REPO_URL" "$REPO_DIR"
    fi

    echo "==> Updating the system and installing Hyprland, Noctalia and its login screen"
    sudo pacman -Syu --needed --noconfirm \
        hyprland xdg-desktop-portal-hyprland xdg-desktop-portal-gtk \
        noctalia noctalia-greeter

    # Copied, not linked: files in /etc have to be owned by root. After the install, as greetd's
    # files would otherwise conflict with it.
    echo "==> Copying system config (login screen, power button)"
    sudo cp -r "$CONFIG_DIR/etc/." /etc/

    # Each file is linked on its own, so ~/.config keeps its other files
    echo "==> Linking the Hyprland and Noctalia config into ~"
    local file rel
    while IFS= read -r -d '' file; do
        rel=${file#"$CONFIG_DIR/home/"}
        mkdir -p "$(dirname "$HOME/$rel")"
        ln -sfn "$file" "$HOME/$rel"
    done < <(find "$CONFIG_DIR/home" -type f -print0)
    local hypr_check
    if ! hypr_check=$(Hyprland --verify-config -c "$HOME/.config/hypr/hyprland.lua" 2>&1); then
        echo "$hypr_check" >&2
        exit 1
    fi

    echo "==> Enabling the login screen"
    sudo noctalia-greeter-apply-appearance --setup-system
    sudo systemctl enable greetd

    echo
    echo "Done. Reboot (sudo reboot), log in to Hyprland, open a terminal (Super+T) and run:"
    echo "  curl -fsSL https://raw.githubusercontent.com/adaspt/arch-dotfiles/main/setup.sh | bash"
}

main "$@"
