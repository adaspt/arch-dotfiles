#!/usr/bin/env bash
# Sets up snapshots, maintenance timers, niri, Noctalia, the login screen, Chrome and the SSH agent
# after archinstall. Run it as your normal user from a TTY after the first boot:
#   curl -fsSL https://raw.githubusercontent.com/adaspt/arch-dotfiles/main/setup.sh | bash
# Safe to run again, also from the clone: ~/Projects/personal/arch-dotfiles/setup.sh
set -euo pipefail

FULL_NAME="Adas Petrovas"
REPO_URL=https://github.com/adaspt/arch-dotfiles.git
REPO_DIR="$HOME/Projects/personal/arch-dotfiles"

# Everything runs inside main, so bash has read the whole script from the pipe before running any of it.
main() {
    if [[ $EUID -eq 0 ]]; then
        echo "Run this as your normal user, not root." >&2
        exit 1
    fi

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
        local build_dir
        build_dir=$(mktemp -d)
        git clone https://aur.archlinux.org/paru-bin.git "$build_dir"
        (cd "$build_dir" && makepkg -si --noconfirm)
        rm -rf "$build_dir"
    fi
    paru -S --needed --noconfirm --skipreview google-chrome

    # Symlinked, so editing ~/.config/niri/config.kdl edits the file in the repo.
    # Each file is linked on its own, so ~/.config and ~/.ssh keep everything else in them.
    echo "==> Linking niri and SSH config into ~"
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

    echo
    echo "Done. Reboot to get the Noctalia login screen: sudo reboot"
}

main "$@"
