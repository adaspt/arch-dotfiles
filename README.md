# arch-dotfiles

Arch Linux with GNOME on a Framework laptop (Intel).

- `archinstall.json`: the archinstall config, which installs GNOME
- `setup.sh`: everything after archinstall; `setup-dev.sh` and `setup-gaming.sh` add to it by hand
- `config/gnome.ini`: GNOME settings, loaded with `dconf load` on every run of `setup.sh`
- `config/etc/`: copied to `/etc`
- `config/home/`: symlinked into `~`, so editing the files in `~` edits the repo
- `config/onedrive/`: OneDrive client config, copied once to `~/.config/onedrive`

## Install

1. Boot the Arch ISO and connect to Wi-Fi (`iwctl device list` shows the device if it isn't `wlan0`):

   ```sh
   iwctl --passphrase '<password>' station wlan0 connect '<network>'
   ```

2. Run archinstall. Under **Authentication**, add one user as superuser. The install **wipes
   `/dev/nvme0n1`**. Don't chroot into the new system at the end; `poweroff`, remove the USB and
   turn the laptop on.

   ```sh
   archinstall --config-url https://raw.githubusercontent.com/adaspt/arch-dotfiles/main/archinstall.json
   ```

3. Log in to GNOME, connect to Wi-Fi, open Ghostty and run:

   ```sh
   curl -fsSL https://raw.githubusercontent.com/adaspt/arch-dotfiles/main/setup.sh | bash
   ```

   It installs the packages and apps, applies the GNOME settings, then signs in to OneDrive (open
   the link in Chrome, sign in, paste the address of the blank page you land on). From OneDrive's
   `Backup/` it restores the SSH keys and the `agersi-vpn` WireGuard VPN (asking for the secrets
   passphrase), the fonts and the wallpaper. Log out and back in afterwards.

   Keep your keyring password the same as your login password, so the login screen unlocks it. It's
   safe to run again, from `~/Projects/personal/arch-dotfiles/setup.sh`.

4. Optionally, on machines that need them:

   - `setup-dev.sh`: .NET SDK 10 with ASP.NET Core and `dotnet ef`, Azure CLI, Azure Functions Core
     Tools, Node.js 24 with nvm
   - `setup-gaming.sh`: Steam, and GeForce NOW as a user flatpak

## Secrets archive

`Backup/secrets.tar.gz.age` holds `ssh/` (what goes into `~/.ssh`; its `config` holds the hosts and
is saved as `~/.ssh/config.local`, so they stay out of this public repo) and `agersi-vpn.conf`. To
update it:

```sh
mkdir -p ~/secrets/ssh && cd ~/secrets
cp ~/.ssh/id_* ~/.ssh/known_hosts ssh/
cp ~/.ssh/config.local ssh/config
cp /path/to/agersi-vpn.conf .
tar -czf - ssh agersi-vpn.conf | age --passphrase --armor -o ~/OneDrive/Backup/secrets.tar.gz.age
cd ~ && rm -rf ~/secrets
```

## Maintenance

- Firmware updates: `fwupdmgr refresh && fwupdmgr update`
- VPN: `nmcli connection up agersi-vpn`; it doesn't connect by itself
- Snapper snapshots every pacman and paru run: `sudo snapper -c root list` lists them,
  `sudo snapper -c root undochange 41..42` undoes one update
- **Ctrl+Alt+F3** opens a text login. `journalctl -b -u gdm` shows login screen errors,
  `journalctl --user -b` the GNOME session's, and `sudo systemctl disable gdm` boots to text
