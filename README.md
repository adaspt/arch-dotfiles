# arch-dotfiles

Arch Linux with GNOME on a Framework laptop, a ThinkPad P14s Gen 4 and a desktop with an NVIDIA
GTX 1660 Super.

- `config/gnome.ini`: GNOME settings, loaded with `dconf load` by `setup.sh`
- `config/etc/`: copied to `/etc`
- `config/home/`: symlinked into `~`, so editing the files in `~` edits the repo

## Install

1. Boot the Arch ISO and connect to Wi-Fi (`iwctl device list` shows the device if it isn't `wlan0`):

   ```sh
   iwctl --passphrase '<password>' station wlan0 connect '<network>'
   ```

2. Run archinstall. Under **Authentication**, add one user as superuser. The install **wipes
   `/dev/nvme0n1`**; check with `lsblk` that it's the right disk. Don't chroot into the new system
   at the end; `poweroff`, remove the USB and turn the PC on.

   ```sh
   archinstall --config-url https://raw.githubusercontent.com/adaspt/arch-dotfiles/main/archinstall.json
   ```

3. Log in to GNOME, connect to the network, open Ghostty and run:

   ```sh
   curl -fsSL https://raw.githubusercontent.com/adaspt/arch-dotfiles/main/setup.sh | bash
   ```

   It asks you to sign in to OneDrive: open the link in Chrome, sign in, paste the address of the
   blank page you land on. Then it asks for the secrets passphrase. Log out and back in afterwards.

   Keep your keyring password the same as your login password, so the login screen unlocks it.

4. Then, from `~/Projects/personal/arch-dotfiles`, the scripts this machine needs:

   - ThinkPad: `./setup-lenovo.sh`, then restart
   - Desktop: `./setup-desktop.sh`, then restart
   - `./setup-dev.sh`: .NET, Azure CLI, Node.js
   - `./setup-gaming.sh`: Steam and GeForce NOW. On the desktop, after `setup-desktop.sh`

All scripts are safe to run again, e.g. after changing the repo.

## Troubleshooting

- **Ctrl+Alt+F3** opens a text login. `journalctl -b -u gdm` shows login screen errors,
  `journalctl --user -b` the GNOME session's, and `sudo systemctl disable gdm` boots to text
- OneDrive: `journalctl --user -u onedrive -f`
- Undo an update: `sudo snapper -c root list` lists the snapshots taken on every pacman and paru
  run, `sudo snapper -c root undochange 41..42` undoes one
- Desktop: `nvidia-smi` should show the GTX 1660 SUPER. `journalctl -u sshd` shows SSH logins and
  why they were refused
- ThinkPad: `lspci -k -d 8086::0300` should show `Kernel driver in use: xe`, and `lspci -d 10de:`
  nothing. Back to `i915`: `sudo rm /etc/cmdline.d/xe.conf && sudo mkinitcpio -P`, then restart

## Maintenance

- Firmware updates: `fwupdmgr refresh && fwupdmgr update`
- VPN: `nmcli connection up agersi-vpn`; it doesn't connect by itself
- Secrets archive, `Backup/secrets.tar.gz.age` in OneDrive: `ssh/` for `~/.ssh` (its `config` is
  saved as `~/.ssh/config.local`, keeping the hosts out of this public repo) and `agersi-vpn.conf`.
  To update it:

  ```sh
  mkdir -p ~/secrets/ssh && cd ~/secrets
  cp ~/.ssh/id_* ~/.ssh/known_hosts ssh/
  cp ~/.ssh/config.local ssh/config
  cp /path/to/agersi-vpn.conf .
  tar -czf - ssh agersi-vpn.conf | age --passphrase --armor -o ~/OneDrive/Backup/secrets.tar.gz.age
  cd ~ && rm -rf ~/secrets
  ```
