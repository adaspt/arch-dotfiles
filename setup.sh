#!/usr/bin/env bash
# Sets up snapshots, maintenance timers, niri, Noctalia, the login screen, Chrome and the SSH agent
# after archinstall. Run it as your normal user from a TTY after the first boot:
#   curl -fsSL https://raw.githubusercontent.com/adaspt/arch-dotfiles/main/setup.sh | bash
set -euo pipefail

FULL_NAME="Adas Petrovas"
REPO_URL=https://github.com/adaspt/arch-dotfiles.git
REPO_DIR=$(mktemp -d)
trap 'rm -rf "$REPO_DIR"' EXIT

# Everything runs inside main, so bash has read the whole script from the pipe before running any of it.
main() {
    if [[ $EUID -eq 0 ]]; then
        echo "Run this as your normal user, not root." >&2
        exit 1
    fi

    git clone --depth 1 "$REPO_URL" "$REPO_DIR/repo"

    echo "==> Copying system config (greetd, PAM keyring unlock)"
    sudo cp -r "$REPO_DIR/repo/config/etc/." /etc/

    # archinstall installs snapper and snap-pac but creates no config, so snap-pac takes no snapshots.
    # This runs before the update below so that the update is the first thing snapshotted.
    echo "==> Setting up Snapper snapshots of /"
    if [[ ! -f /etc/snapper/configs/root ]]; then
        sudo snapper -c root create-config /
    fi
    sudo systemctl enable --now snapper-cleanup.timer

    echo "==> Updating the system"
    sudo pacman -Syu --needed --noconfirm pacman-contrib fwupd

    # fstrim: btrfs already trims with discard=async, but this also covers the FAT32 /boot.
    # paccache: keeps the last 3 versions of each package in the pacman cache.
    # btrfs-scrub@-: checks the root filesystem for corruption once a month.
    echo "==> Enabling maintenance timers"
    sudo systemctl enable --now fstrim.timer paccache.timer btrfs-scrub@-.timer

    echo "==> Setting your full name"
    sudo chfn -f "$FULL_NAME" "$USER"

    echo "==> Installing paru and Google Chrome"
    if ! command -v paru >/dev/null; then
        git clone https://aur.archlinux.org/paru-bin.git "$REPO_DIR/paru-bin"
        (cd "$REPO_DIR/paru-bin" && makepkg -si --noconfirm)
    fi
    paru -S --needed --noconfirm --skipreview google-chrome

    echo "==> Copying niri and SSH config"
    cp -r "$REPO_DIR/repo/config/home/." "$HOME/"
    chmod 700 "$HOME/.ssh"
    niri validate

    echo "==> Enabling the SSH agent"
    systemctl --user enable gcr-ssh-agent.socket

    echo "==> Enabling the login screen"
    sudo noctalia-greeter-apply-appearance --setup-system
    sudo systemctl enable greetd

    echo
    echo "Done. Reboot to get the Noctalia login screen: sudo reboot"
}

main "$@"
