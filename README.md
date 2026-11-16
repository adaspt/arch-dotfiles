# arch-dotfiles

Arch Linux with niri and Noctalia on a Framework laptop (Intel).

- `archinstall.json`: the archinstall config
- `setup.sh`: everything after the first boot
- `config/etc/`: files that `setup.sh` copies to `/etc`
- `config/home/`: files that `setup.sh` symlinks into `~`, so editing them in `~` edits the repo

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

You boot to a text login. Log in as your user, connect to Wi-Fi, then run the script:

```sh
nmcli device wifi connect '<network>' --ask
curl -fsSL https://raw.githubusercontent.com/adaspt/arch-dotfiles/main/setup.sh | bash
sudo reboot
```

It asks for your sudo password. It then:

- clones this repo to `~/Projects/personal/arch-dotfiles`
- sets up Snapper snapshots of `/`, with automatic cleanup of old ones
- updates the system and installs `pacman-contrib` and `fwupd`
- enables timers for SSD TRIM, pacman cache cleanup and a monthly btrfs scrub
- sets the full name on your user account
- installs paru and Google Chrome
- links the niri and SSH config into `~`
- enables the SSH agent
- sets up the Noctalia login screen, which unlocks the keyring

After the reboot you get the Noctalia login screen. Keep your keyring password the same as your login password. Your SSH key passphrases are saved in the keyring the first time you use each key.

The script is safe to run again. After changing a file in `config/etc/`, run `~/Projects/personal/arch-dotfiles/setup.sh` to copy it to `/etc`.

## Firmware updates

Framework publishes BIOS and other firmware updates through fwupd. To check for and install them:

```sh
fwupdmgr refresh
fwupdmgr update
```

## If something breaks

- **Ctrl+Alt+F2** opens a text login, where you can fix things.
- `journalctl -u greetd -b` shows login screen errors. `journalctl --user -b | grep niri` shows niri errors.
- `sudo systemctl disable greetd` and a reboot take you back to the text login. From there you can start niri with `niri-session`.
- Snapper takes a snapshot before and after every pacman or paru run. `sudo snapper -c root list` lists them, and `sudo snapper -c root undochange 41..42` undoes the changes of one update.
