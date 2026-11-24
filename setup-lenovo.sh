#!/usr/bin/env bash
# ThinkPad P14s Gen 4 only. Run it after setup.sh, then restart. Safe to run again any time.
#   - NVIDIA RTX A500 switched off, as it is defective
#   - USB controllers can't wake it from suspend, as they kept waking it
#   - xe graphics driver instead of i915, which caused problems
set -euo pipefail

REPO_DIR=$(dirname "$(readlink -f "$0")")

die() { echo "$*" >&2; exit 1; }

[[ $EUID -ne 0 ]] || die "Run this as your normal user, not root."
[[ $(</sys/class/dmi/id/product_name) == 21HF* ]] || die "This isn't a ThinkPad P14s Gen 4 (machine type 21HF)."
[[ -d $REPO_DIR/config/lenovo ]] || die "Run it from the repo: ~/Projects/personal/arch-dotfiles/setup-lenovo.sh"

restart=0 rebuild=0

# install_file PATH: copies config/lenovo/PATH to /PATH. False when /PATH was already the same
install_file() {
    cmp -s "$REPO_DIR/config/lenovo/$1" "/$1" && return 1
    echo "Installing /$1"
    sudo install -Dm644 "$REPO_DIR/config/lenovo/$1" "/$1" || die "Couldn't install /$1"
}

# archinstall.json names every machine adas-framework
if [[ $(hostnamectl hostname) != adas-lenovo ]]; then
    echo "==> Naming it adas-lenovo"
    sudo hostnamectl set-hostname adas-lenovo
fi

# Both take effect at boot. The modconf hook copies the blacklist into the boot image, so it needs a rebuild
echo "==> Switching off the NVIDIA GPU"
if install_file etc/udev/rules.d/00-remove-nvidia.rules; then restart=1; fi
if install_file etc/modprobe.d/blacklist-nvidia.conf; then rebuild=1; fi

# Also disabled now. Writing XHCI toggles it, so only while it's enabled
echo "==> Stopping USB from waking it from suspend"
install_file etc/tmpfiles.d/disable-wakeup.conf || true
if grep -q '^XHCI.*\*enabled' /proc/acpi/wakeup; then
    echo XHCI | sudo tee /proc/acpi/wakeup >/dev/null
fi

# xe binds to GPUs older than Lunar Lake only when forced, and i915 has to let go of the device.
# The arguments go in a drop-in that mkinitcpio adds to /etc/kernel/cmdline in the boot image.
# Back to i915: sudo rm /etc/cmdline.d/xe.conf && sudo mkinitcpio -P
echo "==> Switching the Intel GPU to the xe driver"
device_id=""
for dev in /sys/bus/pci/devices/*; do
    if [[ $(<"$dev/vendor") == 0x8086 && $(<"$dev/class") == 0x03* ]]; then
        device_id=$(<"$dev/device")
        device_id=${device_id#0x}
        break
    fi
done
[[ -n $device_id ]] || die "No Intel GPU found."
cmdline="i915.force_probe=!$device_id xe.force_probe=$device_id"
if [[ $(cat /etc/cmdline.d/xe.conf 2>/dev/null) != "$cmdline" ]]; then
    echo "Installing /etc/cmdline.d/xe.conf: $cmdline"
    sudo install -d /etc/cmdline.d
    echo "$cmdline" | sudo tee /etc/cmdline.d/xe.conf >/dev/null
    rebuild=1
fi

if (( rebuild )); then
    echo "==> Rebuilding the boot image"
    sudo mkinitcpio -P
    restart=1
fi

echo
if (( restart )); then
    echo "Done. Restart, then check: lspci -k -d 8086::0300 shows 'Kernel driver in use: xe',"
    echo "and lspci -d 10de: shows nothing."
else
    echo "Done. Nothing changed."
fi
