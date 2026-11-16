# arch-dotfiles

Arch Linux with niri and Noctalia on a Framework laptop (Intel).

- `archinstall.json`: the archinstall config
- `setup.sh`: everything after the first boot, in two parts with a reboot between them
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

## 3. Run the setup script, part 1

You boot to a text login. Log in as your user, connect to Wi-Fi, then run the script:

```sh
nmcli device wifi connect '<network>' --ask
curl -fsSL https://raw.githubusercontent.com/adaspt/arch-dotfiles/main/setup.sh | bash
sudo reboot
```

It asks for your sudo password. It then:

- clones this repo to `~/Projects/personal/arch-dotfiles`
- sets up Snapper snapshots of `/`, with automatic cleanup of old ones
- updates the system and installs zsh, its plugins and tools, `age`, `pacman-contrib` and `fwupd`
- enables timers for SSD TRIM, pacman cache cleanup and a monthly btrfs scrub
- installs paru, then Google Chrome, powerlevel10k and the OneDrive client from the AUR
- sets the full name on your user account and makes zsh your shell
- enables linger, so tmux sessions and OneDrive keep running after you log out
- links the config files in `config/home/` into `~`
- enables the SSH agent
- sets up the Noctalia login screen, which unlocks the keyring

Then it stops and asks you to reboot.

## 4. Run the setup script, part 2

After the reboot you get the Noctalia login screen. Log in, open a terminal with **Super+T** and run the script again:

```sh
~/Projects/personal/arch-dotfiles/setup.sh
```

Part 1 runs again and goes by quickly. Then the script:

- signs you in to OneDrive: open the link it prints in Chrome, sign in, and paste the address of the blank page you land on
- syncs `Backup/` from OneDrive, then starts the OneDrive service, which syncs the rest of the folders in `config/onedrive/sync_list` to `~/OneDrive`
- decrypts `Backup/secrets.tar.gz.age` (it asks for the passphrase) and copies the SSH keys to `~/.ssh`
- imports the WireGuard VPN `agersi-vpn`, which doesn't connect automatically: `nmcli connection up agersi-vpn`
- copies the fonts in `Backup/fonts` to `~/.local/share/fonts`

Part 2 needs the desktop session because the login screen unlocks the keyring. Keep your keyring password the same as your login password. Your SSH key passphrases are saved in the keyring the first time you use each key.

The script is safe to run again. After changing a file in `config/etc/`, run it to copy the file to `/etc`.

## Secrets archive

Part 2 reads the SSH keys and the VPN profile from `Backup/secrets.tar.gz.age` in OneDrive. To update it, put what goes into `~/.ssh` into `ssh/`, add the WireGuard profile, encrypt with a passphrase straight into OneDrive, then delete the plain copies:

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

- **Ctrl+Alt+F2** opens a text login, where you can fix things.
- `journalctl -u greetd -b` shows login screen errors. `journalctl --user -b | grep niri` shows niri errors.
- `sudo systemctl disable greetd` and a reboot take you back to the text login. From there you can start niri with `niri-session`.
- Snapper takes a snapshot before and after every pacman or paru run. `sudo snapper -c root list` lists them, and `sudo snapper -c root undochange 41..42` undoes the changes of one update.
