#!/usr/bin/env bash
# Development tools for machines that build code locally: .NET, Azure and Node.js.
# Run it after part 1 of setup.sh, which installs paru. Safe to run again any time.
set -euo pipefail

if [[ $EUID -eq 0 ]]; then
    echo "Run this as your normal user, not root." >&2
    exit 1
fi

echo "==> Installing development packages"
packages=(
    # The ASP.NET packages are separate on Arch; without them, web projects fail with NETSDK1226.
    dotnet-sdk-10.0 aspnet-targeting-pack-10.0 aspnet-runtime-10.0
    azure-cli nvm
)
sudo pacman -Syu --needed --noconfirm "${packages[@]}"
paru -S --needed --noconfirm --skipreview azure-functions-core-tools-bin

echo "==> Installing the EF Core tools (dotnet ef)"
[[ -x "$HOME/.dotnet/tools/dotnet-ef" ]] || dotnet tool install --global dotnet-ef

# In its own bash: nvm isn't written for set -euo pipefail
echo "==> Installing Node.js 24 with nvm"
mkdir -p "$HOME/.nvm"
bash -c 'source /usr/share/nvm/init-nvm.sh && nvm install 24 && nvm alias default 24'

echo
echo "Done. Open a new terminal to use nvm and dotnet ef."
