# arch-dotfiles

Arch Linux with GNOME on a Framework laptop (Intel).

- `archinstall.json`: the archinstall config, which installs GNOME and its login screen (GDM)
- `setup.sh`: everything after archinstall: system, shell, tools, apps, OneDrive and secrets
- `setup-dev.sh`: development tools, run by hand on machines that need them
- `setup-gaming.sh`: Steam and GeForce NOW, run by hand on machines that need them
- `config/gnome.ini`: GNOME settings, which `setup.sh` loads with `dconf load`
- `config/etc/`: files that `setup.sh` copies to `/etc`
- `config/home/`: files that `setup.sh` symlinks into `~`, so editing them in `~` edits the repo
- `config/onedrive/`: OneDrive client config, copied once to `~/.config/onedrive`

## 1. Connect to Wi-Fi on the install USB

Boot the Arch ISO, then:

```sh
iwctl station wlan0 scan
iwctl station wlan0 get-networks
iwctl --passphrase '<password>' station wlan0 connect '<network>'
ping -c 3 archlinux.org
```

If your device isn't `wlan0`, `iwctl device list` shows its name.

## 2. Run archinstall

1. Start archinstall with the config:

   ```sh
   archinstall --config-url https://raw.githubusercontent.com/adaspt/arch-dotfiles/main/archinstall.json
   ```

2. Under **Authentication**, add one user and mark it as superuser (sudo).
3. Check the summary, then choose **Install**. The disk section **wipes `/dev/nvme0n1`**.
4. When archinstall asks whether to chroot into the new system, choose **no**.
5. Run `poweroff`.
6. Once the laptop is off, remove the USB and turn the laptop back on.

## 3. Run the setup script

You boot to the GNOME login screen. Log in, connect to Wi-Fi from the menu at the top right, then
open a terminal (press **Super**, type `ghostty`) and run:

```sh
curl -fsSL https://raw.githubusercontent.com/adaspt/arch-dotfiles/main/setup.sh | bash
```

It asks for your sudo password, and stops if it isn't run from GNOME. It:

- clones this repo to `~/Projects/personal/arch-dotfiles`
- sets up Snapper snapshots of `/`, with automatic cleanup of old ones
- updates the system and installs zsh with its plugins, CLI tools, `age`, `pacman-contrib`, `fwupd`,
  mpv, qBittorrent, Gradia, Codex, and the AppIndicator and Caffeine GNOME extensions
- copies the systemd units that copy your monitor layout to the login screen to `/etc`
- enables timers for SSD TRIM, pacman cache cleanup and a monthly btrfs scrub
- installs paru, then Google Chrome, VS Code, powerlevel10k, the OneDrive client and T3 Code from the AUR
- installs Claude Code with its own installer, so it updates itself
- sets the full name on your user account and makes zsh your shell
- enables linger, so tmux sessions and OneDrive keep running after you log out
- links the config files in `config/home/` into `~`
- sets Loupe as the default app for images, and mpv for video and audio
- enables the SSH agent
- clones my GNOME extensions (launcher, window-keys) to `~/Projects/personal` and links them into GNOME
- applies the GNOME settings in `config/gnome.ini`: keyboard layouts, shortcuts, dock apps, extensions,
  screen lock and suspend timeouts, weather location
- keeps the login screen's monitor layout the same as yours, every time Settings > Displays saves it
- limits battery charging to preserve battery health, where the battery supports it
- signs you in to OneDrive: open the link it prints in Chrome, sign in, and paste the address of the blank page you land on
- syncs `Backup/` from OneDrive, then starts the OneDrive service, which syncs the rest of the folders in `config/onedrive/sync_list` to `~/OneDrive`
- decrypts `Backup/secrets.tar.gz.age` (it asks for the passphrase) and copies the SSH keys to `~/.ssh`
- imports the WireGuard VPN `agersi-vpn`, which doesn't connect automatically: `nmcli connection up agersi-vpn`
- copies the fonts in `Backup/fonts` to `~/.local/share/fonts`
- copies the wallpaper from `Backup/` to `~/Pictures/Wallpapers` and sets it as the background

Then log out and back in, so GNOME Shell loads the extensions.

It needs the GNOME session because the login screen unlocks the keyring, which Chrome and OneDrive
use. Keep your keyring password the same as your login password. Your SSH key passphrases are saved
in the keyring the first time you use each key.

The script is safe to run again, from `~/Projects/personal/arch-dotfiles/setup.sh`. It writes the
settings in `config/gnome.ini` again each time, so change GNOME settings there to keep them. After
changing a file in `config/etc/`, run it to copy the file to `/etc`.

## Development tools

On machines that build code locally, run this after `setup.sh`:

```sh
~/Projects/personal/arch-dotfiles/setup-dev.sh
```

It installs the .NET SDK 10 with ASP.NET Core, the EF Core tools (`dotnet ef`), Azure CLI, Azure Functions Core Tools, and Node.js 24 with nvm. Safe to run again.

## Gaming

On machines for gaming, run this from a terminal in GNOME, after `setup.sh`:

```sh
~/Projects/personal/arch-dotfiles/setup-gaming.sh
```

It installs Steam, and GeForce NOW with NVIDIA's installer, as a user flatpak. Safe to run again.

## Secrets archive

`setup.sh` reads the SSH keys and the VPN profile from `Backup/secrets.tar.gz.age` in OneDrive. To update it, put what goes into `~/.ssh` into `ssh/`, add the WireGuard profile, encrypt with a passphrase straight into OneDrive, then delete the plain copies:

```sh
mkdir -p ~/secrets/ssh && cd ~/secrets
cp ~/.ssh/id_* ~/.ssh/known_hosts ssh/
cp ~/.ssh/config.local ssh/config
cp /path/to/agersi-vpn.conf .
tar -czf - ssh agersi-vpn.conf | age --passphrase --armor -o ~/OneDrive/Backup/secrets.tar.gz.age
cd ~ && rm -rf ~/secrets
```

`ssh/config` holds your SSH hosts. The script saves it as `~/.ssh/config.local`, which the `~/.ssh/config` in this repo includes, so the hosts stay out of this public repo.

## Firmware updates

Framework publishes BIOS and other firmware updates through fwupd. To check for and install them:

```sh
fwupdmgr refresh
fwupdmgr update
```

## If something breaks

- **Ctrl+Alt+F3** opens a text login, where you can fix things.
- `journalctl -b -u gdm` shows login screen errors. `journalctl --user -b` shows the GNOME session's.
- `sudo systemctl disable gdm` and a reboot take you back to the text login.
- Snapper takes a snapshot before and after every pacman or paru run. `sudo snapper -c root list` lists them, and `sudo snapper -c root undochange 41..42` undoes the changes of one update.
