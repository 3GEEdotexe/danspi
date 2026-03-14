#!/usr/bin/env bash

set -euo pipefail

LOG="$HOME/fix-apt-and-install-ssh_$(date +%Y%m%d_%H%M%S).log"
exec > >(tee -a "$LOG") 2>&1

echo "=================================================="
echo "APT repo repair + OpenSSH install"
echo "=================================================="
echo "Log: $LOG"
echo

step() {
    echo
    echo "--------------------------------------------------"
    echo "$1"
    echo "--------------------------------------------------"
}

step "1) Back up current ubuntu.sources"
sudo cp /etc/apt/sources.list.d/ubuntu.sources \
        /etc/apt/sources.list.d/ubuntu.sources.bak

step "2) Overwrite ubuntu.sources with correct Noble entries"
sudo tee /etc/apt/sources.list.d/ubuntu.sources > /dev/null <<'EOF'
Types: deb
URIs: http://ports.ubuntu.com/ubuntu-ports/
Suites: noble noble-updates noble-backports
Components: main restricted universe multiverse
Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg

Types: deb
URIs: http://ports.ubuntu.com/ubuntu-ports/
Suites: noble-security
Components: main restricted universe multiverse
Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg
EOF

step "3) Verify repo file contents"
cat /etc/apt/sources.list.d/ubuntu.sources

grep -q "Suites: noble noble-updates noble-backports" /etc/apt/sources.list.d/ubuntu.sources

step "4) Clear package metadata and refresh"
sudo apt clean
sudo rm -rf /var/lib/apt/lists/*
sudo rm -rf /var/cache/apt/archives/partial/*
sudo apt update

step "5) Show OpenSSH package versions"
apt-cache policy openssh-server openssh-client openssh-sftp-server
apt-cache madison openssh-server openssh-client openssh-sftp-server

step "6) Repair package state"
sudo dpkg --configure -a || true
sudo apt --fix-broken install -y || true

step "7) Install OpenSSH server"
sudo apt install -y openssh-server

step "8) Enable and start SSH"
sudo systemctl enable --now ssh

step "9) Verify SSH"
sudo systemctl status ssh --no-pager
sudo ss -tulpn | grep ':22' || true

step "10) Show IP address"
hostname -I

echo
echo "=================================================="
echo "Done"
echo "Connect from another computer with:"
echo "ssh $(whoami)@<PI_IP>"
echo "=================================================="
